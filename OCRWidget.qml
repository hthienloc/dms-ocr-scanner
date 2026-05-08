import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Popout dimensions
    popoutWidth: 400
    popoutHeight: 520

    // Right-click action on pill
    pillRightClickAction: () => {
        root.scanFromClipboard();
        root.triggerPopout();
    }

    property string resultText: ""
    property bool isScanning: false

    function scanFromClipboard() {
        if (isScanning) return;
        isScanning = true;
        
        const tempImage = "/tmp/dms_ocr_input.png";
        const getClipCmd = "wl-paste -t image/png > " + tempImage + " || xclip -selection clipboard -t image/png -o > " + tempImage;
        
        Proc.runCommand(
            "get-clipboard-image",
            ["sh", "-c", getClipCmd],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    runTesseract(tempImage);
                } else {
                    isScanning = false;
                    ToastService.showError("No image found in clipboard!");
                }
            },
            0
        );
    }

    function selectFileAndScan() {
        if (isScanning) return;
        
        Proc.runCommand(
            "select-file",
            ["kdialog", "--getopenfilename", ":", "Images (*.png *.jpg *.jpeg *.webp *.bmp)"],
            (stdout, exitCode) => {
                const filePath = stdout.trim();
                if (exitCode === 0 && filePath !== "") {
                    isScanning = true;
                    runTesseract(filePath);
                }
            },
            0
        );
    }

    function runTesseract(imagePath) {
        const lang = pluginData.ocrLanguage || "eng+vie";
        const tesseractCmd = "tesseract '" + imagePath + "' - -l " + lang;

        Proc.runCommand(
            "run-tesseract",
            ["sh", "-c", tesseractCmd],
            (stdout, exitCode) => {
                isScanning = false;
                if (exitCode === 0) {
                    const result = stdout.trim();
                    if (result === "") {
                        ToastService.showInfo("No text detected.");
                    } else {
                        resultText = result;
                        ToastService.showInfo("Scan complete!");
                        if (pluginData.autoCopy ?? true) {
                            copyToClipboard(result);
                        }
                    }
                } else {
                    ToastService.showError("Tesseract failed. Is it installed?");
                }
            },
            0
        );
    }

    function copyToClipboard(text) {
        if (!text) return;
        Proc.runCommand(
            "clipboard-copy",
            ["sh", "-c", "echo -n \"" + text.replace(/"/g, "\\\"") + "\" | wl-copy || echo -n \"" + text.replace(/"/g, "\\\"") + "\" | xclip -selection clipboard"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    ToastService.showInfo("Copied to clipboard!");
                }},
            0
        );
    }

    function saveResultToFile() {
        if (resultText === "") return;
        
        Proc.runCommand(
            "save-file-dialog",
            ["kdialog", "--getsavefilename", ":", "Text Files (*.txt)"],
            (stdout, exitCode) => {
                const filePath = stdout.trim();
                if (exitCode === 0 && filePath !== "") {
                    let finalPath = filePath;
                    if (!finalPath.toLowerCase().endsWith(".txt")) finalPath += ".txt";
                    
                    Proc.runCommand(
                        "write-file",
                        ["sh", "-c", "echo -n \"" + resultText.replace(/"/g, "\\\"") + "\" > \"" + finalPath + "\""],
                        (out, code) => {
                            if (code === 0) ToastService.showInfo("Saved to " + finalPath);
                            else ToastService.showError("Failed to save file.");
                        },
                        0
                    );
                }
            },
            0
        );
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
            }

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 4
                DankIcon {
                    name: "document_scanner"
                    size: Theme.iconSizeMedium
                    color: root.isScanning ? Theme.primary : Theme.surfaceVariantText
                }
                StyledText {
                    text: "OCR"
                    visible: root.isScanning
                    color: Theme.primary
                }
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "OCR Scanner"
            detailsText: root.isScanning ? "Processing..." : "Ready to scan"
            showCloseButton: false

            onVisibleChanged: {
                if (!visible && !(pluginData.keepResults ?? true)) {
                    root.resultText = "";
                }
            }

            Column {
                width: parent.width
                spacing: 12

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    DankButton {
                        text: "From Clipboard"
                        width: (pluginData.keepResults ?? true) ? (parent.width - Theme.spacingS) / 2 : parent.width
                        iconName: "content_paste"
                        backgroundColor: Theme.primary
                        enabled: !root.isScanning
                        onClicked: root.scanFromClipboard()
                    }
                    DankButton {
                        text: "From File"
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "image"
                        backgroundColor: Theme.secondary
                        enabled: !root.isScanning
                        visible: pluginData.keepResults ?? true
                        onClicked: root.selectFileAndScan()
                    }
                }

                StyledRect {
                    width: parent.width
                    height: 250
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        contentWidth: width
                        contentHeight: resultArea.implicitHeight
                        clip: true

                        TextEdit {
                            id: resultArea
                            width: parent.width
                            text: root.resultText
                            wrapMode: TextEdit.Wrap
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            selectByMouse: true
                            onTextChanged: root.resultText = text
                            
                            // Placeholder
                            Text {
                                text: "Result will appear here..."
                                color: Theme.outlineVariant
                                visible: resultArea.text === ""
                                font: resultArea.font
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        text: "Copy Result"
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "content_copy"
                        backgroundColor: Theme.secondary
                        enabled: root.resultText !== ""
                        onClicked: root.copyToClipboard(root.resultText)
                    }

                    DankButton {
                        text: "Save to File"
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "save"
                        backgroundColor: Theme.primary
                        enabled: root.resultText !== ""
                        onClicked: root.saveResultToFile()
                    }
                }

                DankButton {
                    text: "Clear"
                    width: parent.width
                    iconName: "delete"
                    backgroundColor: root.resultText !== "" ? Theme.errorContainer : Theme.surfaceVariant
                    textColor: root.resultText !== "" ? Theme.error : Theme.surfaceVariantText
                    enabled: root.resultText !== ""
                    onClicked: {
                        root.resultText = "";
                        ToastService.showInfo("Cleared.");
                    }
                }

                StyledText {
                    text: "Hint: Right-click the bar icon to instantly OCR from clipboard."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
