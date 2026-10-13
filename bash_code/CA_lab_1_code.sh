#! /bin/bash


export LC_ALL=C

echo "Enter the path to the directory /log"
read path

if [ ! -d "$path" ]; then
   echo "No such directory"
   exit 1
fi


size_kb=$(du -sk "$path" | cut -f1)

size_bytes=$((size_kb  * 1024))

limit_bytes=1073741824

percent=$(awk "BEGIN {printf \"%.2f\", ($size_bytes / $limit_bytes) * 100}")


threshold=90


echo "Directory: $path"
echo "Size: ${size_kb} KB"
echo "Used: ${percent}% of 1 GB"


if awk "BEGIN {exit !($percent > $threshold)}"; then
     echo "Threshold exceeded. Removing oldest files..."
     oldest_files=$(find "$path" -type f -printf '%T+ %p\n' | sort | head -5 | cut -d ' ' -f2-)
     if [ -z "$oldest_files" ]; then
         echo "No files to remove."
     else
         echo "$oldest_files" | while IFS= read -r file; do
             rm -f "$file"
             echo "Removed: $file"
         done


       fi


fi


