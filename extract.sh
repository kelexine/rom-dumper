#!/bin/bash

# Create directory for extracted files
extract_dir="rom"
mkdir -p "$extract_dir"

# Function to attempt extraction with specific tool
attempt_extract() {
  local archive="$1"
  local tool="$2"

  if [ -f "$archive" ]; then
    echo "Attempting to extract '$archive' with '$tool'..."
    if $tool "$archive" -C "$extract_dir" >/dev/null 2>&1; then
      echo "Extracted successfully!"
      return 0
    else
      echo "Failed to extract with '$tool'."
    fi
  fi
  return 1
}

# Supported archive extensions
archive_extensions=("zip" "tar.gz" "tar" "tar.xz" "7z")

# Try extracting based on file extension
for extension in "${archive_extensions[@]}"; do
  archive=*.$extension
  attempt_extract "$archive" "unzip" && break
  attempt_extract "$archive" "tar" && break
  attempt_extract "$archive" "7z" && break
done

# Install p7zip if no extraction succeeded
if [ $? -eq 1 ]; then
  echo "No built-in tools found. Installing p7zip..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y p7zip
  elif command -v yum &>/dev/null; then
    sudo yum install -y p7zip
  else
    echo "Error: Unsupported package manager." >&2
    exit 1
  fi

  # Retry extraction with p7zip for all archives
  for archive in *.{zip,tar.gz,tar.xz,7z}; do
    attempt_extract "$archive" "7z"
  done
fi

echo "Extraction complete. Files are in the '$extract_dir' directory."
