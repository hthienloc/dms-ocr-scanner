# OCR Scanner

Extract text from images using Tesseract OCR.

<img src="screenshot.png" width="400" alt="Screenshot">

## Install


**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
dms://plugin/install/ocrScanner
```

Or manually:
```bash
git clone https://github.com/hthienloc/dms-ocr-scanner ~/.config/DankMaterialShell/plugins/ocrScanner
```

## Features

- **Clipboard scan** - One click to extract text from clipboard image
- **Multi-language** - English, Vietnamese, and 100+ other languages
- **Auto-copy** - Extracted text automatically copied to clipboard
- **Save to file** - Export as .txt

## Usage

| Action | Result |
|--------|--------|
| Left click | Open scanner |
| Right click | Scan from clipboard |

## Requirements

| Package | Installation |
|---------|--------------|
| `tesseract` | `sudo dnf install tesseract` / `sudo pacman -S tesseract` |
| `tesseract-data-*` | Language packs (e.g., `tesseract-langpack-eng`) |

## License

GPL-3.0(https://github.com/hthienloc/dms-common) to be installed in the plugins directory.
