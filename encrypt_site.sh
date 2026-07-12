#!/bin/bash

# set human-readable password

PASSWORD="portfolio2026"

echo "Starting vkwakweni portfolio site encryption..."

# find every .html file in the build directory and encrypt it

find ./build -name "*.html" | while read -r file; do
    echo "Encrypting: $file"
    npx staticrypt "$file" -p "$PASSWORD" -o "$file" --short -d "$(dirname "$file")"
    mv "${file%.html}_encrypted.html" "$file" 2>/dev/null
done

echo "All HTML pages successfully encrypted!"
