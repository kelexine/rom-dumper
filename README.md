# Universal Android ROM Dumper

**Author:** [kelexine](https://github.com/kelexine)

A GitHub Actions workflow for extracting, processing, and uploading Android ROM files. Supports Android 11-16, multiple manufacturers, various archive formats, and maintains backward compatibility with legacy devices.

---

## ✨ Features

### Core Capabilities
- ✅ **Universal Archive Support**: ZIP, 7Z, TAR (all variants), RAR, GZIP, BZIP2, XZ, ZSTD, LZ4, Brotli
- ✅ **Multiple ROM Formats**: 
  - Payload.bin (A/B devices)
  - Super partition (Dynamic partitions)
  - Traditional IMG files
  - SDAT/DAT files (Android 5-9)
  - OZIP (OPPO/Realme)
- ✅ **Android Version Support**: Android 11, 12, 12L, 13, 14, 15, 16
- ✅ **Manufacturer Support**: Samsung, Xiaomi, OPPO, Vivo, Realme, OnePlus, Motorola, Nokia, ASUS, Google, Huawei, Honor, TECNO, Infinix, iTel, and more
- ✅ **Smart Extraction Modes**: Full, System only, Boot images only, Smart auto-select
- ✅ **Automatic File Splitting**: Handles files larger than GitHub's 2GB limit
- ✅ **Nested Archive Extraction**: Automatically processes archives within archives
- ✅ **Checksum Generation**: SHA256 checksums for file verification
- ✅ **Comprehensive Metadata**: Detailed extraction logs and file information

### Advanced Features
- 🔍 **Automatic ROM Structure Detection**: Intelligently identifies payload, super, traditional, or SDAT formats
- 🗜️ **Multi-Level Compression**: Configurable XZ compression (levels 0-9)
- 📦 **Smart File Management**: Automatically removes unnecessary files and compresses large images
- 🔄 **Resume Support**: Uses aria2c for robust downloads with auto-resume
- 🛡️ **Error Handling**: Graceful fallbacks and comprehensive error reporting
- 📊 **Detailed Logging**: Step-by-step extraction logs with collapsible groups

---

## 🚀 Quick Start

### 1. Fork/Clone Repository
```bash
git clone https://github.com/kelexine/rom-dumper.git
cd rom-dumper
```

### 2. Enable GitHub Actions
- Go to **Settings** → **Actions** → **General**
- Enable "Allow all actions and reusable workflows"

### 3. Run Workflow
- Navigate to **Actions** → **Universal ROM Dumper**
- Click **Run workflow**
- Fill in the required parameters:
  - **DOWNLOAD_URL**: Direct download link to ROM archive
  - **DEVICE_NAME**: Your device model
  - **MANUFACTURER**: Select from dropdown
  - **ANDROID_VERSION**: Select or use auto-detect
  - **ROM_TYPE**: Stock ROM, Custom ROM, OTA, or Firmware
  - **EXTRACT_MODE**: Choose extraction scope
  - **COMPRESSION_LEVEL**: 0-9 (default: 6)
  - **SPLIT_LARGE_FILES**: Enable for files >1.8GB

### 4. Download Results
- Results will be uploaded to **Releases** with the tag `dump-{run_id}`
- Download all files or individual partitions as needed

---

## Supported ROM Structures

### Payload.bin (A/B Devices)
Used by: Google Pixel, OnePlus, ASUS, Xiaomi (newer devices)
```
rom.zip
└── payload.bin
```
**Processing**: Extracted using payload-dumper-go → individual partition images

### Super Partition (Dynamic Partitions)
Used by: Most Android 10+ devices
```
rom.zip
└── super.img (or super.img.lz4/zst)
```
**Processing**: Decompressed → unpacked with lpunpack/imjtool → individual logical partitions

### Traditional Format
Used by: Older devices, MediaTek
```
rom.zip
├── system.img
├── vendor.img
├── boot.img
└── recovery.img
```
**Processing**: Direct extraction and optional compression

### SDAT Format (Android 5-9)
Used by: Older Xiaomi, Samsung
```
rom.zip
├── system.new.dat
├── system.transfer.list
└── system.patch.dat
```
**Processing**: Converted to .img using sdat2img

### OZIP Format
Used by: OPPO, Realme
```
rom.zip
└── firmware.ozip
```
**Processing**: Decryption attempted (may require manual intervention)

---

## 🎯 Extraction Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Full (All partitions)** | Extracts every partition image | Complete ROM backup, development |
| **System only** | Extracts system, system_ext | System modifications, theming |
| **Boot images only** | Extracts boot, recovery, vendor_boot | Custom recovery, kernel development |
| **Smart (Auto-select)** | Extracts important partitions only | General use, balanced output size |

Smart mode includes: `system`, `vendor`, `product`, `system_ext`, `boot`, `recovery`, `vbmeta`, `dtbo`, `super`

---

## 🔧 Advanced Usage

### Custom Compression Levels
```yaml
COMPRESSION_LEVEL: '9'  # Maximum compression (slower, smaller files)
COMPRESSION_LEVEL: '1'  # Fast compression (faster, larger files)
COMPRESSION_LEVEL: '6'  # Balanced (recommended)
```

### Handling Split Files
If files are split due to size limits:
```bash
# Reassemble on Linux/Mac
cat system_a.img.xz.part* > system_a.img.xz
xz -d system_a.img.xz

# Reassemble on Windows (PowerShell)
cmd /c copy /b system_a.img.xz.part* system_a.img.xz
```

### Manual Extraction (Local)
```bash
# Make script executable
chmod +x extract.sh

# Extract ROM archive
./extract.sh rom_archive.zip output_directory

# The script will:
# - Auto-install dependencies
# - Detect archive type
# - Extract nested archives
# - Provide detailed summary
```

---

## Manufacturer-Specific Notes

### Samsung
- Uses `.tar.md5` archives
- May include multiple CSC files
- AP file contains system partitions

### Xiaomi
- MIUI ROMs use `.tgz` format
- Fastboot ROMs may have sparse images
- Some devices use payload.bin (newer), others use traditional images

### OPPO/Realme
- `.ozip` format requires decryption
- Some ROMs are encrypted with device-specific keys
- Newer devices may use standard payload.bin

### Google Pixel
- Always uses payload.bin
- Includes both A and B slot images
- OTA files directly processable

### MediaTek Devices
- Often use traditional scatter-based ROMs
- May include `scatter.txt` file
- Super partition support on newer chipsets

---

## Output Structure

```
Release: DEVICE_NAME-MANUFACTURER-{run_id}
├── system_a.img.xz
├── vendor_a.img.xz
├── product_a.img.xz
├── system_ext_a.img.xz
├── boot.img.xz
├── recovery.img.xz
├── vbmeta.img.xz
├── dtbo.img.xz
├── METADATA.txt
└── SHA256SUMS.txt
```

### METADATA.txt Contents
- Device information
- ROM type and source
- Extraction timestamp
- Detected ROM structure
- Complete file listing with sizes

---

## 🐛 Troubleshooting

### Issue: "Download failed"
**Solutions:**
- Verify the download URL is direct (no redirects)
- Check if the server requires authentication
- Try using a different mirror

### Issue: "Extraction failed"
**Solutions:**
- Check if archive is corrupted
- Verify archive format is supported
- Review workflow logs for specific error

### Issue: "Super partition extraction failed"
**Solutions:**
- Image may be encrypted
- Check if simg2img conversion is needed
- Try manual extraction with lpunpack locally

### Issue: "Files missing in release"
**Solutions:**
- Check extraction mode selected
- Verify files weren't too large (>2GB)
- Enable file splitting option

### Issue: "OZIP decryption failed"
**Solutions:**
- OZIP requires manufacturer-specific keys
- Extract locally with OzipDecrypt tool
- Request decrypted version from source

---

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

1. **OZIP Decryption**: Implement automated decryption for OPPO/Realme devices
2. **Samsung TAR.MD5**: Enhanced support for Samsung's multi-part archives
3. **Scatter File Parsing**: Better support for MediaTek scatter-based ROMs
4. **UI Improvements**: Better release page formatting
5. **Error Recovery**: More robust handling of corrupted archives

### How to Contribute
```bash
# Fork the repository
# Create your feature branch
git checkout -b feature/amazing-feature

# Commit your changes
git commit -m "Add amazing feature"

# Push to branch
git push origin feature/amazing-feature

# Open a Pull Request
```

---

## Technical Details

### Partition Types

| Partition | Purpose | Critical |
|-----------|---------|----------|
| **system** | Core Android OS | ✅ Yes |
| **vendor** | Hardware-specific libraries | ✅ Yes |
| **product** | Additional apps/features | ⚠️ Optional |
| **system_ext** | Extended system components | ⚠️ Optional |
| **boot** | Kernel and ramdisk | ✅ Yes |
| **recovery** | Recovery mode | ⚠️ Optional |
| **vbmeta** | Verified boot metadata | ✅ Yes |
| **dtbo** | Device tree overlay | ⚠️ Device-specific |
| **super** | Container for logical partitions | ✅ Yes (A10+) |

### Supported Compression Formats

| Format | Extension | Tool | Speed | Ratio |
|--------|-----------|------|-------|-------|
| XZ | .xz | xz | Slow | Excellent |
| ZSTD | .zst | zstd | Fast | Good |
| LZ4 | .lz4 | lz4 | Very Fast | Fair |
| Brotli | .br | brotli | Medium | Very Good |
| GZIP | .gz | gzip | Fast | Good |

---

## ⚖️ License

This project is open-source and available under the MIT License.

---

## 🙏 Acknowledgments

- Android Open Source Project (AOSP)
- [payload-dumper-go](https://github.com/ssut/payload-dumper-go)
- [lpunpack](https://github.com/unix3dgforce/lpunpack)
- [imjtool](http://newandroidbook.com/tools/)
- [sdat2img](https://github.com/xpirt/sdat2img)

---

## Support

- **Issues**: [GitHub Issues](https://github.com/kelexine/rom-dumper/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kelexine/rom-dumper/discussions)
- **Author**: [kelexine](https://github.com/kelexine)

---

## 🔄 Version History

### v2.0.0 (Enhanced Release)
- ✅ Complete rewrite with modular architecture
- ✅ Support for Android 11-16
- ✅ Multi-manufacturer support
- ✅ Enhanced error handling and logging
- ✅ Automatic file splitting
- ✅ Smart extraction modes
- ✅ Comprehensive metadata generation
- ✅ Nested archive extraction
- ✅ Multiple compression formats

### v1.0.0 (Original Release)
- Basic ZIP extraction
- Super partition support
- Payload.bin extraction

---

**Made with ❤️ by [kelexine](https://github.com/kelexine)**

*Star ⭐ this repository if you find it useful!*