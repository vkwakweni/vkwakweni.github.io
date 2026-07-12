#!/bin/bash

# set human-readbale password

PASSWORD="portfolio2026"

echo "Starting vkwakweni portfolio site encryption..."

# find every .html file in the build directory and encrypt it

find build -name "*.html" | while read -r file; directory
    echo "Encrypting: $file"
    staticrypt "$file" "$PASSWORD" -o "$file"
done

echo "All HTML pages successfull encrypted!"