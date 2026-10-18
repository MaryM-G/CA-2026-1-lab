#! /bin/bash


export LC_ALL=C

echo "Enter the path to the directory /log"
read path

if [ ! -d "$path" ]; then
   echo "Error: No such directory"
   exit 1
fi


size=$(df -h "$path" | awk 'NR==2 {print $2}')
percent_raw=$(df -h "$path" | awk 'NR==2 {print $5}')
percent=$(echo "$percent_raw" | tr -d '%')


echo "Directory: $path"
echo "Size: $size"
echo "Used: ${percent}% of limit"


threshold=90
M=5
backup_dir="/backup"


if [ "$percent" -gt "$threshold" ]; then
     echo "Threshold exceeded. Archiving and removing oldest files..."


     mkdir -p "$backup_dir"


     archive_name="backup_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"

 
     oldest_files=$(find "$path" -type f -not -path "$backup_dir/*" -printf '%T+ %p\n' | sort | head -$M | cut -d' ' -f2-)


     if [ -z "$oldest_files"]; then
         echo "No files to archive."
     else
         echo "Oldest files filtered:"
         echo "$oldest_files"


         tar -czf "$backup_dir/$archive_name" -P $oldest_files

         if [ $? -eq 0]; then
             echo "Succesfully archived to: $backup_dir/$archive_name"
        
             echo "$oldest_files | while IFS= read -r file; do
                 rm -f "$file"
                 echo "Removed from source: $file"
             done
         else
             echo "Error:Failed to create archive. Files were NOT removed."
         fi
     fi
fi
