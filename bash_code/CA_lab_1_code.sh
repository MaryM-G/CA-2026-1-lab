#! /bin/bash

echo "Enter the path to the directory /log"
read path

if [ ! -e "$path" ]; then
   echo "No such directory"
   exit 1
fi

cd "$path" || exit 1

size=$(du -sh | cut -f1)
echo "$size"
 

