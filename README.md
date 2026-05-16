# OCR Scanner

Extract text from images using Tesseract OCR.

<img src="screenshot.png" width="400" alt="Screenshot">

## Install


**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
dms plugins install ocrScanner
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

GPL-3.0

## Roadmap / TODO

- [ ] **Native Region Capture**: Add a "Screen Capture" mode using `grim`/`slurp` (Wayland) or `maim` (X11) to scan portions of the screen directly.
- [ ] **On-device Translation**: Integrate a lightweight translation service (or API) to translate extracted text instantly.
- [ ] **Persistent History**: Implement a local database to store previous scans, including timestamps and source image references.
- [ ] **Batch Processing**: Support selecting multiple images for sequential OCR with a merged text output.
- [ ] **Advanced Tesseract Options**: Expose Page Segmentation Method (PSM) and OCR Engine Mode (OEM) settings in the UI for specialized documents.
