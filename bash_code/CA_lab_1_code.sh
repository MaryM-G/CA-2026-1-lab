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

echo "Set a threshold in percents for memory"
read threshold

if [ "$threshold" -gt 100 ]; then
   echo "A threshold $threshold is not suitable, please enter the number under 100
"
   exit 1
elif [ "$threshold" -lt 0 ]; then
   echo "A threshold $threshold is not suitable, please enter the numer over 0"
   exit 1
fi

if [ "$threshold" -ge "$percent" ]; then
   echo "No files need to be deleted"