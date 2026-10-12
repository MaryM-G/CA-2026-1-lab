#! /bin/bash

echo "Enter the path to the directory /log"
read path

if [ ! -e "$path" ]; then
   echo "No such directory"
   exit 1
fi

cd "$path" || exit 1

size_kb=$(du -sk "$path" | cut -f1)

size_bytes=$((size_kb  * 1024))

limit_bytes=1073741824

percent=$(awk "BEGIN {printf \"%.2f\", ($size_bytes / $limit_bytes) * 100}")

echo "Directory: $path"
echo "Size: ${size_kb} KB"
echo "Used: ${percent}% of 1 GB"

