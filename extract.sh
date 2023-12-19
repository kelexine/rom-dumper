#!/bin/bash

# Create a directory for extracting files
extract_dir="rom"
mkdir -p "$extract_dir"

# Function to install required tools
install_tools() {
  if command -v unzip &>/dev/null; then
    archive_tool="unzip"
  elif command -v tar &>/dev/null; then
    archive_tool="tar"
  else
    echo "Error: Could not find suitable archive extraction tool (zip or tar)." >&2
    exit 1
  fi

  if ! command -v 7z &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      echo "Installing p7zip..."
      sudo apt-get update
      sudo apt-get install -y p7zip
    elif command -v yum &>/dev/null; then
      echo "Installing p7zip..."
      sudo yum install -y p7zip
    else
      echo "Error: Unsupported package manager." >&2
      exit 1
    fi
  fi
}

# Install required tools
install_tools

# Extract files from archives
for archive in *.{zip,tar.gz,tar,xz,7z}; do
  if [ -f "$archive" ]; then
    echo "Extracting $archive..."
    case "$archive" in
      *.zip) $archive_tool "$archive" -d "$extract_dir" ;;
      *.tar.gz | *.tar) $archive_tool -xf "$archive" -C "$extract_dir" ;;
      *.tar.xz) $archive_tool -xJf "$archive" -C "$extract_dir" ;;
      *.7z) 7z x "$archive" -o"$extract_dir" ;;
      *) echo "Unsupported archive format: $archive" ;;
    esac
  fi
done

echo "Extraction complete. Files are in the '$extract_dir' directory."
