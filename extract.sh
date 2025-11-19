#!/bin/bash
# Universal ROM Extract Script
# Author: kelexine (https://github.com/kelexine)
# Supports: Android 11-16, Multiple archive formats, Nested archives
# Usage: ./extract.sh [archive_file] [output_dir]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EXTRACT_DIR="${2:-extracted}"
MAX_NESTED_DEPTH=3
CURRENT_DEPTH=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check and install dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    local deps=(
        "7z:p7zip-full"
        "unzip:unzip"
        "tar:tar"
        "bzip2:bzip2"
        "xz:xz-utils"
        "zstd:zstd"
        "lz4:lz4"
        "brotli:brotli"
    )
    
    for dep_pair in "${deps[@]}"; do
        IFS=':' read -r cmd pkg <<< "$dep_pair"
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$pkg")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        log_info "Installing missing dependencies..."
        
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y "${missing_deps[@]}"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "${missing_deps[@]}"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm "${missing_deps[@]}"
        elif command -v apk &>/dev/null; then
            sudo apk add "${missing_deps[@]}"
        else
            log_error "Unsupported package manager. Please install manually: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    log_success "All dependencies satisfied"
}

# Detect archive type
detect_archive_type() {
    local file="$1"
    
    # Check by magic bytes
    local magic=$(xxd -p -l 8 "$file" 2>/dev/null | tr -d '\n')
    
    case "$magic" in
        504b0304*|504b0506*|504b0708*)
            echo "zip"
            ;;
        377abcaf271c*)
            echo "7z"
            ;;
        1f8b08*)
            echo "gzip"
            ;;
        425a68*)
            echo "bzip2"
            ;;
        fd377a585a00*)
            echo "xz"
            ;;
        28b52ffd*)
            echo "zstd"
            ;;
        04224d18*)
            echo "lz4"
            ;;
        *)
            # Fallback to extension
            case "${file,,}" in
                *.zip) echo "zip" ;;
                *.7z) echo "7z" ;;
                *.tar.gz|*.tgz) echo "tar.gz" ;;
                *.tar.bz2|*.tbz|*.tbz2) echo "tar.bz2" ;;
                *.tar.xz|*.txz) echo "tar.xz" ;;
                *.tar.zst) echo "tar.zst" ;;
                *.tar) echo "tar" ;;
                *.gz) echo "gzip" ;;
                *.bz2) echo "bzip2" ;;
                *.xz) echo "xz" ;;
                *.zst) echo "zstd" ;;
                *.lz4) echo "lz4" ;;
                *.br) echo "brotli" ;;
                *.rar) echo "rar" ;;
                *.ozip) echo "ozip" ;;
                *) echo "unknown" ;;
            esac
            ;;
    esac
}

# Extract archive based on type
extract_archive() {
    local archive="$1"
    local output="$2"
    local type="$3"
    
    [ -z "$type" ] && type=$(detect_archive_type "$archive")
    
    log_info "Extracting: $archive (type: $type)"
    
    mkdir -p "$output"
    
    case "$type" in
        zip)
            if unzip -qt "$archive" &>/dev/null; then
                unzip -q -o "$archive" -d "$output" 2>/dev/null || \
                7z x "$archive" -o"$output" -y >/dev/null
            else
                log_warning "Corrupt ZIP, trying 7z..."
                7z x "$archive" -o"$output" -y >/dev/null
            fi
            ;;
        7z)
            7z x "$archive" -o"$output" -y >/dev/null
            ;;
        tar)
            tar -xf "$archive" -C "$output"
            ;;
        tar.gz)
            tar -xzf "$archive" -C "$output"
            ;;
        tar.bz2)
            tar -xjf "$archive" -C "$output"
            ;;
        tar.xz)
            tar -xJf "$archive" -C "$output"
            ;;
        tar.zst)
            tar --zstd -xf "$archive" -C "$output"
            ;;
        gzip)
            gunzip -c "$archive" > "$output/$(basename "${archive%.gz}")"
            ;;
        bzip2)
            bunzip2 -c "$archive" > "$output/$(basename "${archive%.bz2}")"
            ;;
        xz)
            unxz -c "$archive" > "$output/$(basename "${archive%.xz}")"
            ;;
        zstd)
            zstd -d "$archive" -o "$output/$(basename "${archive%.zst}")"
            ;;
        lz4)
            lz4 -d "$archive" "$output/$(basename "${archive%.lz4}")"
            ;;
        brotli)
            brotli -d "$archive" -o "$output/$(basename "${archive%.br}")"
            ;;
        rar)
            7z x "$archive" -o"$output" -y >/dev/null
            ;;
        ozip)
            log_warning "OZIP format detected - may require decryption"
            log_info "Attempting extraction with 7z..."
            7z x "$archive" -o"$output" -y >/dev/null || \
            log_error "OZIP extraction failed. Manual decryption may be required."
            ;;
        unknown)
            log_warning "Unknown format, attempting universal extraction with 7z..."
            if ! 7z x "$archive" -o"$output" -y >/dev/null 2>&1; then
                log_error "Failed to extract: $archive"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported archive type: $type"
            return 1
            ;;
    esac
    
    log_success "Extracted: $archive"
    return 0
}

# Recursively extract nested archives
extract_nested() {
    local dir="$1"
    local depth="${2:-0}"
    
    if [ "$depth" -ge "$MAX_NESTED_DEPTH" ]; then
        log_warning "Max nesting depth ($MAX_NESTED_DEPTH) reached, stopping recursive extraction"
        return
    fi
    
    log_info "Scanning for nested archives (depth: $depth)..."
    
    local archive_patterns=(
        "*.zip" "*.7z" "*.tar" "*.tar.gz" "*.tgz" 
        "*.tar.bz2" "*.tbz" "*.tar.xz" "*.txz"
        "*.tar.zst" "*.rar" "*.gz" "*.bz2" 
        "*.xz" "*.zst" "*.lz4" "*.br" "*.ozip"
    )
    
    local found_archive=false
    
    for pattern in "${archive_patterns[@]}"; do
        while IFS= read -r -d '' archive; do
            found_archive=true
            local nested_dir="${archive%.${archive##*.}}_extracted"
            
            if extract_archive "$archive" "$nested_dir" ""; then
                # Remove the archive after successful extraction
                rm -f "$archive"
                # Recursively check the extracted directory
                extract_nested "$nested_dir" $((depth + 1))
            fi
        done < <(find "$dir" -maxdepth 1 -type f -iname "$pattern" -print0 2>/dev/null)
    done
    
    if [ "$found_archive" = false ] && [ "$depth" -eq 0 ]; then
        log_info "No nested archives found"
    fi
}

# Main extraction workflow
main() {
    local input="${1:-}"
    
    echo "=================================================="
    echo "  Universal ROM Extract Script by kelexine"
    echo "  https://github.com/kelexine"
    echo "=================================================="
    echo
    
    if [ -z "$input" ]; then
        log_error "Usage: $0 <archive_file> [output_dir]"
        exit 1
    fi
    
    if [ ! -f "$input" ]; then
        log_error "File not found: $input"
        exit 1
    fi
    
    check_dependencies
    
    echo
    log_info "Starting extraction process..."
    log_info "Input: $input"
    log_info "Output: $EXTRACT_DIR"
    echo
    
    # Initial extraction
    if extract_archive "$input" "$EXTRACT_DIR" ""; then
        # Look for nested archives
        extract_nested "$EXTRACT_DIR" 0
        
        echo
        log_success "Extraction complete!"
        log_info "Output directory: $EXTRACT_DIR"
        
        # Show summary
        echo
        echo "=== Extraction Summary ==="
        echo "Total files extracted: $(find "$EXTRACT_DIR" -type f | wc -l)"
        echo "Total size: $(du -sh "$EXTRACT_DIR" | cut -f1)"
        echo
        echo "=== Image files found ==="
        find "$EXTRACT_DIR" -type f -name "*.img" -o -name "*.bin" | while read -r file; do
            echo "  - $(basename "$file") ($(du -h "$file" | cut -f1))"
        done
        echo
        
    else
        log_error "Extraction failed"
        exit 1
    fi
}

# Handle script arguments
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi