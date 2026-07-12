#!/bin/bash

# set human-readable password

PASSWORD="portfolio2026"

echo "Starting vkwakweni portfolio site encryption..."

# find every .html file in the build directory and encrypt it

find build -name "*.html" | while read -r file; do
    echo "Encrypting: $file"
    npx staticrypt "$file" -p "$PASSWORD" -o "$file" --short
done

echo "All HTML pages successfully encrypted!"
