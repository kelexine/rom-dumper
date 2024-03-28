#!/bin/bash

# Create directory for extracted files
extract_dir="rom"
mkdir -p "$extract_dir"

# Function to attempt extraction with 7z
attempt_extract() {
 local archive="$1"

 if [ -f "$archive" ]; then
    echo "Attempting to extract '$archive' with 7z..."
    if 7z x "$archive" -o"$extract_dir" >/dev/null 2>&1; then
      echo "Extracted successfully!"
      return 0
    else
      echo "Failed to extract with 7z."
    fi
 fi
 return 1
}

# Install p7zip-full if not already installed
if ! command -v 7z &>/dev/null; then
 echo "7z not found. Installing p7zip-full..."
 if command -v apt &>/dev/null; then
    sudo apt update
    sudo apt install -y p7zip-full
 elif command -v dnf &>/dev/null; then
    sudo dnf install -y p7zip*
 elif command -v pacman &>/dev/null; then
    sudo pacman -S p7zip
 else
    echo "Error: Unsupported package manager." >&2
    exit 1
 fi
fi

# Attempt extraction for all archives in the current directory
for archive in *; do
 attempt_extract "$archive"
done

echo "Extraction complete. Files are in the '$extract_dir' directory."
