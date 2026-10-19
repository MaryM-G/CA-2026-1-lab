#! /bin/bash


export LC_ALL=C



echo "Enter path to the directory \log:"
read -r LOG_DIR

if [ ! -d "$LOG_DIR" ]; then
   echo "This directory doesnt exist"
   exit 1
fi

IMAGE_FILE="/home/maria/1gb_lab_img"
if [ ! -f "$IMAGE_FILE" ]; then
   fallocate -l 1G "$IMAGE_FILE" 2>/dev/null
   mkfs.ext4 -F "$IMAGE_FILE" >/dev/null
fi

LOOP_DEV=$(losetup -f)
if [ -z "$LOOP_DEV" ]; then
   echo "No loop devices are availible" 
fi

losetup "$LOOP_DEV" "$IMAGE_FILE" || { echo "Losetup failed"; exit 1;}
mount "$LOOP_DEV" "$LOG_DIR" || { echo "Mount failed."; losetup -d "$LOOP_DEV"; exit 1}

usage() {
    echo "Usage: $0 -p  LOG_DIR -b BACKUP_DIR [-x THRESHOLD] [-m COUNT]"
    echo " -p LOG_DIR    Каталог с лог-файлами"
    echo " -b BACKUP_DIR Каталог для архвивов"
    echo "-x THRESHOLD   Порог заполнения файловой системы в % (1-100, по умолчанию 90)"
    echo "-m COUNT       Заархивировать ровно COUNT самых старых файловю."
    echo "               Буз -m архивируется минимум старых файлов,"
    echo "               чтобы заполнение стало <= THRESHOLD"
    echo " -h            показать эту справку"
}


get_fs_bytes() {
    df -P -B1 "$1" | awk "NR==2 {print $3, $3 + $4}"
}


percent_of() {
    local used="$1" total="$2"
    echo $(( (used * 100 + total - 1) / total ))
}


select_files() {
    local need_bytes="$1" max_count="$2"
    local freed=0 count=0 rec name blocks bsize

    SELECTED=()

    while IFS= read -r -d "" rec; do
        name="${rec#* }"
        read -r blocks bsize < <(stat -c "%b %B" -- "$LOG_DIR/$name") || continue
        SELECTED+=("$name")
        count=$((count + 1))
        freed=$((freed + blocks * bsize))

        if [ "$max_count" -gt 0 ] && [ "$count" -ge "$max_count" ]; then
            break
        fi
        if [ "$max_count" -eq 0 ] && [ "$freed" -ge "$need_bytes" ]; then
            break
        fi
    done < <(
        find "$LOG_DIR" -maxdepth 1 -type f ! -name '*.gz' ! -name '*.tgz' ! -name '*.tar' ! -name '*.bz2' ! -name '*.xz' ! -name '*.zip' -printf '%T@ %P\0' | sort -z -n
    )

    FREED_BYTES="$freed"
    [ "${#SELECTED[@]}" -gt 0 ]
}  



    LOG_DIR=""
    BACKUP_DIR=""
    THRESHOLD=90
    MAX_COUNT=0


    local opt
    while getopts "p:b:x:m:h" opt; do
        case $opt in
            p) LOG_DIR="$OPTARG" ;;
            b) BACKUP_DIR="$OPTARG" ;;
            x) THRESHOLD="$OPTARG" ;;
            m) MAX_COUNT="$OPTARG" ;;
            h) usage; exit 0 ;;
            *) usage >&2; exit 1 ;;
        esac
    done


    if [ -z "$LOG_DIR" ] || [ -z "$BACKUP_DIR" ]; then
        echo "Error: Both -p and -b are required." >&2
        usage >&2
        exit 1
    fi

    if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 1 ] || [ "$THRESHOLD" -gt 100 ]; then
        echo "Error: Threshold must be an integer between 1 and 100." >&2
        exit 1
    fi

    if [ -n "$MAX_COUNT" ] && [ "$MAX_COUNT" -eq "$MAX_COUNT" ] 2>/dev/null; then
         echo "Error: COUNT (-m) must be a non-negative integer." >&2
         exit 1
    fi

    if [ ! -d "$LOG_DIR" ]; then
        echo "Error: LOG_DIR $LOG_DIR does not exist." >&2
        exit 1
    fi

    if [ "$(realpath -m "$LOG_DIR")" == "$(realpath -m "$BACKUP_DIR")" ]; then
        echo "Error: LOG_DIR and BACKUP_DIR must be different." >&2
        exit 1
    fi

    mkdir -p "$BACKUP_DIR" 2>/dev/null || { echo "Error: Cannot create backup dir"; exit 1; }


    if [ ! -w "$BACKUP_DIR" ]; then
        echo "Error: Backup dir is not writable." >&2
        exit 1
    fi

    if [ "$(stat -c %d "$LOG_DIR")" -eq "$(stat -c %d "$BACKUP_DIR")" ]; then
        echo "Warning: BACKUP_DIR is on the same filesystem as LOG_DIR. Archives will take up space on the same fylesystem." >&2
    fi

    local used total
    read -r used total < <(get_fs_bytes "$LOG_DIR")
    if [ -z "$total"] || [ "$total" -eq 0]; then
        echo "Error: Cannot get filesystem usage for "$LOG_DIR"." >&2
        exit 1
    fi

    CURRENT_USAGE=$(percent_of "$used" "$total")
    echo "Current filesystem esage: ${CURRENT_USAGE}%"

    if [ "$CURRENT_USAGE" -le "$THRESHOLD" ]; then
        echo "Usage is below threshold (${THRESHOLD}%). No rotation needed."
        exit 0
    fi

    echo "Usage exceeds threshold! Preparing rotation..."

    local bytes_to_free=$(( used - (THRESHOLD * total) / 100))
    echo "Need to free at least $bytes_to_free bytes."

    if ! select_files "$bytes_to_free" "$MAX_COUNT"; then
        echo "Error: No files available for archiving." >&2
        exit 1
    fi

    if [ "$MAX_COUNT" -eq 0 ] && [ "$FREED_BYTES" -lt "$bytes_to_free" ]; then
        echo "Warning: all suitable files together are not enough to reach the threshold." >&2
    fi

    echo "Selected files for archiving:"
    printf "%s\n" "${SELECTED[@]}"

    local ts archive_path
    ts=$(date +%Y%m%d_%H%M%S)
    archive_path="$BACKUP_DIR/log_backup_${ts}_$$_${RANDOM}.tar.gz"

    echo "Creating archive: $archive_path"

    if ! tar -czf "$archive_path" -C "$LOG_DIR" "${SELECTED[@]}"; then
        echo "Error: Failed to create archive." >&2
        rm -f -- "$archive_path"
        exit 1
    fi

    if ! gzip -t "$archive_path" 2>/dev/null || ! tar -tzf "$archive_path" >/dev/null 2>&1; then
        echo "Error: Archive verification failed. Source files will NOT be deleted." >&2
        exit 1
    fi

    echo "Archive verified succesfully."

    echo "Removing source files..."
    local f
    for f in "${SELECTED[@]}"; do
        rm -f -- "$LOG_DIR/$f" || echo "Warning: Failed to remove $f" >&2
    done

    read -r used total < <(get_fs_bytes "$LOG_DIR")
    NEW_USAGE=$(percent_of "$used" "$total")
    echo "New filesystem usage: ${NEW_USAGE}%"

    if [ "$NEW_USAGE" -gt "$THRESHOLD" ]; then
        echo "Warning: Usage is still above threshold after rotation."
    fi

    exit 0
}