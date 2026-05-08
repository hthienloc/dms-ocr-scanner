# OCR Scanner Plugin

A dedicated OCR (Optical Character Recognition) plugin for [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell). Extract text from images in your clipboard or files instantly using the powerful Tesseract engine.

<img src="screenshot.png" width="400" alt="Screenshot">

## Features

- **From Clipboard**: Instantly extract text from an image in your clipboard. Perfect for quick captures from the web or other apps.
- **From File**: Select an image file from your system to extract text.
- **Instant Access**: Right-click the bar icon to instantly OCR from the clipboard and open the results.
- **Dynamic Language Discovery**: Automatically detects all Tesseract languages installed on your system.
- **Multi-language Support**: Select multiple languages simultaneously (e.g., English + Vietnamese) for mixed-content recognition.
- **Auto-copy**: Automatically copy the extracted text back to your clipboard after scanning.
- **Save to File**: Export the extracted text as a `.txt` file.
- **Editable Result**: Refine the extracted text directly in the popout before copying or saving.
- **Persistence Settings**: Choose whether to keep the results after closing the popout.

## Prerequisites

This plugin requires the following system tools:

- `tesseract`: The core OCR engine.
- `tesseract-langpack-*` (Fedora) or `tesseract-data-*` (Arch): Language data files for your desired languages.
- `wl-clipboard` (Wayland) or `xclip` (X11): For clipboard image handling.
- `kdialog` (for file selection and saving dialogs).

### Installation (Fedora)

```bash
sudo dnf install tesseract tesseract-langpack-eng tesseract-langpack-vie wl-clipboard kdialog
```

### Installation (Arch Linux)

```bash
sudo pacman -S tesseract tesseract-data-eng tesseract-data-vie wl-clipboard xclip kdialog
```

## Installation

1. Create a directory for the plugin:
   ```bash
   mkdir -p ~/.config/DankMaterialShell/plugins/ocrScanner
   ```
2. Copy all `.qml` and `plugin.json` files to that directory.
3. Reload DMS or scan for plugins in DMS Settings.

## License

GPL-3.0 - See [LICENSE](LICENSE)
