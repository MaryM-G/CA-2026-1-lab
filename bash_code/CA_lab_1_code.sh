#!/bin/bash


export LC_ALL=C

usage() {
    echo "Usage: $0 -p LOG_DIR -b BACKUP_DIR [-x THRESHOLD] [-m COUNT]"
    echo "  -p LOG_DIR    Каталог с лог-файлами"
    echo "  -b BACKUP_DIR Каталог для архивов"
    echo "  -x THRESHOLD  Порог заполнения файловой системы с % (1-100), по умолчанию 90)"
    echo "  -m COUNT      Заархивировать ровно COUNT самых старых файлов."
    echo "                Без -m архивируется минимум старых файлов"
    echo "                чтобы заполнение стыло <= THRESHOLD"
    echo "  -h            Плказать эту справку"
}

get_fs_bytes() {
    df -P -B1 "$1" | awk 'NR==2 {print $3, $3 + $4}'
}

percent_of() {
    local used="$1" total="$2"
    echo $(( (used * 100 + total - 1) / total ))
}

select_files() {
    local dir="$1" need_bytes="$2" max_count="$3"
    local freed=0 count=0 rec name blocks bsize

    SELECTED=()

    while IFS= read -r -d "" rec; do
        name="${rec#* }"
        read -r blocks bsize < <(stat -c "%b %B" -- "$dir/$name") || continue
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
        find "$dir" -maxdepth 1 -type f \
            ! -name '*.gz' ! -name '*.tgz' ! -name '*.tar' \
            ! -name '*.bz2' ! -name '*.xz' ! -name '*.zip' \
            -printf '%T@ %P\0' | sort -z -n
    )

    FREED_BYTES="$freed"
    [ "${#SELECTED[@]}" -gt 0 ]
}

main() {
    local LOG_DIR="" BACKUP_DIR="" THRESHOLD=90 MAX_COUNT=0 opt

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

    if ! [[ "$THRESHOLD" =~ ^[0-9]{1,3}$ ]] || [ "$THRESHOLD" -lt 1 ] || [ "$THRESHOLD" -gt 100 ]; then
        echo "Error: Threshold must be an integer between 1 and 100." >&2
        exit 1
    fi

    if ! [[ "MAX_COUNT" =~ ^[0-9]{1-3}$ ]]; then
        "Error: COUNT (-m) must be a non-negative integer." >&2
        exit 1
    fi

    THRESHOLD=$((10#$THRESHOLD))
    MAX_COUNT=$((10#$MAX_COUNT))

    if [ ! -d "$LOG_DIR" ]; then
        echo "Error: LOG_DIR $LOG_DIR does not exist." >&2
        exit 1
    fi

    if [ "$(realpath -m "$LOG_DIR")" == "$(realpath -m "$BACKUP_DIR")" ]; then
        echo "Error: LOG_DIR and BACKUP_DIR must be different." >&2
        exit 1
    fi

    mkdir -p "$BACKUP_DIR" 2>/dev/null || { echo "Error: Cannot create backup dir." >&2; exit 1; }


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

    local current_usage
    current_usage=$(percent_of "$used" "$total")
    echo "Current filesystem esage: ${current_usage}%"

    if [ "$current_usage" -le "$THRESHOLD" ]; then
        echo "Usage is not above threshold (${THRESHOLD}%). No rotation needed."
        exit 0
    fi

    echo "Usage exceeds threshold! Preparing rotation..."

    local bytes_to_free=$(( used - (THRESHOLD * total) / 100))
    if [ "$bytes_to_free" -lt 1 ]; then
        bytes_to_free=1
    fi
    echo "Need to free at least $bytes_to_free bytes."

    if ! select_files "$LOG_DIR" "$bytes_to_free" "$MAX_COUNT"; then
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

    if ! tar -czf "$archive_path" -C "$LOG_DIR" -- "${SELECTED[@]}"; then
        echo "Error: Failed to create archive." >&2
        rm -f -- "$archive_path"
        exit 1
    fi

    if ! gzip -t "$archive_path" 2>/dev/null || ! tar -tzf "$archive_path" >/dev/null 2>&1; then
        echo "Error: Archive verification failed. Source files will NOT be deleted." >&2
        rm -f -- "$archive_path"
        exit 1
    fi

    echo "Archive verified succesfully."

    echo "Removing source files..."
    local f
    for f in "${SELECTED[@]}"; do
        rm -f -- "$LOG_DIR/$f" || echo "Warning: Failed to remove $f" >&2
    done

    read -r used total < <(get_fs_bytes "$LOG_DIR")
    new_usage=$(percent_of "$used" "$total")
    echo "New filesystem usage: ${new_usage}%"

    if [ "$new_usage" -gt "$THRESHOLD" ]; then
        echo "Warning: Usage is still above threshold after rotation."
    fi

    exit 0
}

main "$@"