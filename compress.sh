#!/bin/bash
# Advanced ROM Compression and Utilities Script
# Author: kelexine (https://github.com/kelexine)
# Purpose: Compress, split, and manage ROM images intelligently
# Usage: ./compress.sh [options]

set -eo pipefail

# Configuration
MAX_FILE_SIZE=$((1900 * 1024 * 1024))  # 1.9GB in bytes
DEFAULT_COMPRESSION_LEVEL=6
THREADS=$(nproc)
SPLIT_SIZE="1800M"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${MAGENTA}[STEP]${NC} $1"; }

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}Progress:${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percentage"
}

# Get human-readable file size
get_human_size() {
    local size=$1
    numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B"
}

# Detect optimal compression method based on file type
detect_optimal_compression() {
    local file="$1"
    local file_type=$(file -b "$file" | tr '[:upper:]' '[:lower:]')
    
    case "$file_type" in
        *"android sparse"*)
            echo "xz"  # Sparse images compress well with xz
            ;;
        *"ext4"*|*"ext3"*|*"ext2"*)
            echo "zstd"  # Filesystem images work well with zstd
            ;;
        *"compressed"*|*"gzip"*|*"bzip"*)
            echo "none"  # Already compressed
            ;;
        *)
            echo "xz"  # Default to xz for best compression
            ;;
    esac
}

# Convert sparse image to raw
convert_sparse_to_raw() {
    local input="$1"
    local output="${input%.img}_raw.img"
    
    if file "$input" | grep -q "Android sparse"; then
        log_info "Converting sparse image: $(basename "$input")"
        
        if command -v simg2img &>/dev/null; then
            simg2img "$input" "$output"
            rm -f "$input"
            mv "$output" "$input"
            log_success "Converted to raw image"
        else
            log_warning "simg2img not found, skipping sparse conversion"
        fi
    fi
}

# Compress file with optimal settings
compress_file() {
    local input="$1"
    local level="${2:-$DEFAULT_COMPRESSION_LEVEL}"
    local method="${3:-auto}"
    
    local input_size=$(stat -c%s "$input" 2>/dev/null || stat -f%z "$input" 2>/dev/null)
    local basename=$(basename "$input")
    
    log_step "Processing: $basename ($(get_human_size $input_size))"
    
    # Auto-detect compression method if needed
    if [ "$method" = "auto" ]; then
        method=$(detect_optimal_compression "$input")
    fi
    
    if [ "$method" = "none" ]; then
        log_info "File already compressed or not suitable for compression"
        return 0
    fi
    
    local output=""
    local compress_cmd=""
    local start_time=$(date +%s)
    
    case "$method" in
        xz)
            output="${input}.xz"
            compress_cmd="xz -${level} -T${THREADS} -vv"
            ;;
        zstd)
            output="${input}.zst"
            compress_cmd="zstd -${level} -T${THREADS} -v"
            ;;
        lz4)
            output="${input}.lz4"
            compress_cmd="lz4 -${level} -v"
            ;;
        gzip)
            output="${input}.gz"
            compress_cmd="pigz -${level} -p${THREADS} -v"
            [ ! -command -v pigz &>/dev/null ] && compress_cmd="gzip -${level} -v"
            ;;
        *)
            log_error "Unknown compression method: $method"
            return 1
            ;;
    esac
    
    log_info "Compressing with $method (level $level)..."
    
    # Perform compression
    if $compress_cmd "$input"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local output_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
        local ratio=$(echo "scale=2; ($input_size - $output_size) * 100 / $input_size" | bc)
        
        log_success "Compressed in ${duration}s"
        log_info "Original: $(get_human_size $input_size) → Compressed: $(get_human_size $output_size) (${ratio}% saved)"
        
        return 0
    else
        log_error "Compression failed"
        return 1
    fi
}

# Split large file
split_file() {
    local file="$1"
    local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    
    if [ "$file_size" -gt "$MAX_FILE_SIZE" ]; then
        log_warning "File too large ($(get_human_size $file_size)), splitting..."
        
        local basename=$(basename "$file")
        split -b "$SPLIT_SIZE" -d "$file" "${file}.part"
        
        local part_count=$(ls -1 "${file}.part"* 2>/dev/null | wc -l)
        
        if [ "$part_count" -gt 0 ]; then
            log_success "Split into $part_count parts"
            rm -f "$file"
            
            # Create reassembly script
            cat > "${file}.reassemble.sh" << 'EOF'
#!/bin/bash
# Reassembly script generated by kelexine's ROM tools
# Usage: ./filename.reassemble.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FILE_BASE="$(basename "$0" .reassemble.sh)"
OUTPUT="${FILE_BASE}"

echo "Reassembling: $FILE_BASE"

if ! ls "${FILE_BASE}.part"* 1>/dev/null 2>&1; then
    echo "Error: Part files not found!"
    exit 1
fi

cat "${FILE_BASE}.part"* > "$OUTPUT"

if [ $? -eq 0 ]; then
    echo "✓ Reassembled successfully: $OUTPUT"
    echo "  Size: $(du -h "$OUTPUT" | cut -f1)"
    
    read -p "Delete part files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "${FILE_BASE}.part"*
        echo "✓ Part files deleted"
    fi
else
    echo "✗ Reassembly failed!"
    exit 1
fi
EOF
            chmod +x "${file}.reassemble.sh"
            log_info "Created reassembly script: ${basename}.reassemble.sh"
        fi
    fi
}

# Clean up unnecessary files
cleanup_workspace() {
    log_step "Cleaning up workspace..."
    
    local cleanup_patterns=(
        "*.tar" "*.zip" "*.7z" "*.tgz"
        "*.list" "*.patch.dat" "*.new.dat"
        "*_raw.img"
        "scatter*.txt"
    )
    
    local removed_count=0
    
    for pattern in "${cleanup_patterns[@]}"; do
        while IFS= read -r file; do
            log_info "Removing: $(basename "$file")"
            rm -f "$file"
            ((removed_count++))
        done < <(find . -maxdepth 1 -type f -name "$pattern" 2>/dev/null)
    done
    
    # Remove empty directories
    find . -maxdepth 1 -type d -empty -delete 2>/dev/null
    
    log_success "Removed $removed_count unnecessary files"
}

# Generate checksums
generate_checksums() {
    log_step "Generating checksums..."
    
    local checksum_file="SHA256SUMS.txt"
    
    if command -v sha256sum &>/dev/null; then
        sha256sum *.img* *.xz* *.zst* *.lz4* *.part* 2>/dev/null > "$checksum_file" || true
    elif command -v shasum &>/dev/null; then
        shasum -a 256 *.img* *.xz* *.zst* *.lz4* *.part* 2>/dev/null > "$checksum_file" || true
    fi
    
    if [ -f "$checksum_file" ]; then
        log_success "Checksums saved to $checksum_file"
    fi
}

# Verify file integrity
verify_file() {
    local file="$1"
    
    log_info "Verifying: $(basename "$file")"
    
    case "${file,,}" in
        *.xz)
            xz -t "$file" && log_success "Integrity check passed" || log_error "Integrity check failed"
            ;;
        *.zst)
            zstd -t "$file" && log_success "Integrity check passed" || log_error "Integrity check failed"
            ;;
        *.lz4)
            lz4 -t "$file" && log_success "Integrity check passed" || log_error "Integrity check failed"
            ;;
        *.gz)
            gzip -t "$file" && log_success "Integrity check passed" || log_error "Integrity check failed"
            ;;
        *)
            log_warning "No integrity check available for this file type"
            ;;
    esac
}

# Main processing function
process_images() {
    local compression_level="${1:-$DEFAULT_COMPRESSION_LEVEL}"
    local compression_method="${2:-auto}"
    local skip_split="${3:-false}"
    
    echo "=================================================="
    echo "  ROM Compression Utility by kelexine"
    echo "  https://github.com/kelexine"
    echo "=================================================="
    echo
    
    log_info "Configuration:"
    log_info "  Compression level: $compression_level"
    log_info "  Compression method: $compression_method"
    log_info "  Max file size: $(get_human_size $MAX_FILE_SIZE)"
    log_info "  CPU threads: $THREADS"
    echo
    
    # Find all image files
    local images=($(find . -maxdepth 1 -type f -name "*.img" 2>/dev/null | sort))
    local total_images=${#images[@]}
    
    if [ "$total_images" -eq 0 ]; then
        log_error "No .img files found in current directory"
        exit 1
    fi
    
    log_info "Found $total_images image file(s)"
    echo
    
    local processed=0
    
    for img in "${images[@]}"; do
        ((processed++))
        
        echo "----------------------------------------"
        show_progress "$processed" "$total_images"
        echo
        
        # Convert sparse images
        convert_sparse_to_raw "$img"
        
        # Compress
        if compress_file "$img" "$compression_level" "$compression_method"; then
            compressed="${img}.${compression_method}"
            [ "$compression_method" = "auto" ] && compressed=$(ls "${img}".* 2>/dev/null | head -n1)
            
            # Split if needed
            if [ "$skip_split" != "true" ] && [ -f "$compressed" ]; then
                split_file "$compressed"
            fi
            
            # Verify compressed file
            [ -f "$compressed" ] && verify_file "$compressed"
        fi
        
        echo
    done
    
    echo "=========================================="
    echo
    
    # Cleanup
    cleanup_workspace
    
    # Generate checksums
    generate_checksums
    
    # Show summary
    echo
    log_success "Processing complete!"
    echo
    echo "=== Final Summary ==="
    echo "Processed images: $total_images"
    echo "Total size: $(du -sh . | cut -f1)"
    echo
    echo "=== Output Files ==="
    ls -lh *.xz* *.zst* *.lz4* *.part* 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo
}

# Parse command-line arguments
parse_args() {
    local compression_level="$DEFAULT_COMPRESSION_LEVEL"
    local compression_method="auto"
    local skip_split=false
    local verify_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--level)
                compression_level="$2"
                shift 2
                ;;
            -m|--method)
                compression_method="$2"
                shift 2
                ;;
            -s|--no-split)
                skip_split=true
                shift
                ;;
            -v|--verify)
                verify_only=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$verify_only" = true ]; then
        for file in *.xz *.zst *.lz4 *.gz; do
            [ -f "$file" ] && verify_file "$file"
        done
        exit 0
    fi
    
    process_images "$compression_level" "$compression_method" "$skip_split"
}

# Show help message
show_help() {
    cat << EOF
ROM Compression Utility by kelexine

Usage: $0 [OPTIONS]

Options:
    -l, --level LEVEL       Compression level (0-9, default: 6)
    -m, --method METHOD     Compression method (xz|zstd|lz4|gzip|auto)
    -s, --no-split          Don't split large files
    -v, --verify            Verify existing compressed files
    -h, --help              Show this help message

Examples:
    $0                      # Use default settings
    $0 -l 9 -m xz          # Maximum XZ compression
    $0 -l 1 -m zstd        # Fast ZSTD compression
    $0 --verify            # Verify all compressed files

Author: kelexine (https://github.com/kelexine)
EOF
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -eq 0 ]; then
        process_images
    else
        parse_args "$@"
    fi
fi