import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: pluginRoot

    // Popout dimensions
    popoutWidth: 400
    popoutHeight: 520

    // Right-click action on pill
    pillRightClickAction: () => {
        pluginRoot.scanFromClipboard();
        pluginRoot.triggerPopout();
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
                onClicked: pluginRoot.triggerPopout()
            }

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 4
                DankIcon {
                    name: "document_scanner"
                    size: Theme.iconSize
                    color: pluginRoot.isScanning ? Theme.primary : Theme.surfaceVariantText
                }
                StyledText {
                    text: "OCR"
                    visible: pluginRoot.isScanning
                    color: Theme.primary
                }
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutContent: Component {
        PopoutComponent {
            id: popout
            width: pluginRoot.popoutWidth
            headerText: "OCR Scanner"
            detailsText: pluginRoot.isScanning ? "Processing..." : "Ready to scan"
            showCloseButton: true

            onVisibleChanged: {
                if (!visible && !(pluginData.keepResults ?? true)) {
                    pluginRoot.resultText = "";
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                // Input Selection Cards
                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    // Clipboard Card
                    StyledRect {
                        id: clipCard
                        width: (parent.width - Theme.spacingM) / 2
                        height: 100
                        radius: Theme.cornerRadius
                        color: clipMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHigh
                        border.color: Theme.primary
                        border.width: clipMouse.containsMouse ? 2 : 0
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            DankIcon {
                                name: "content_paste"
                                size: 32
                                color: clipMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            StyledText {
                                text: "Clipboard"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: clipMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            id: clipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !pluginRoot.isScanning
                            onClicked: pluginRoot.scanFromClipboard()
                        }
                    }

                    // File Card
                    StyledRect {
                        id: fileCard
                        width: (parent.width - Theme.spacingM) / 2
                        height: 100
                        radius: Theme.cornerRadius
                        color: fileMouse.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                        border.color: Theme.secondary
                        border.width: fileMouse.containsMouse ? 2 : 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            DankIcon {
                                name: "image"
                                size: 32
                                color: fileMouse.containsMouse ? Theme.secondary : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            StyledText {
                                text: "Select File"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: fileMouse.containsMouse ? Theme.secondary : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            id: fileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !pluginRoot.isScanning
                            onClicked: pluginRoot.selectFileAndScan()
                        }
                    }
                }

                // Result Area with integrated actions
                StyledRect {
                    width: parent.width
                    height: 280
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerLow
                    border.color: pluginRoot.isScanning ? Theme.primary : Theme.outlineVariant
                    border.width: 1

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        contentWidth: width - (Theme.spacingM * 2)
                        contentHeight: resultArea.implicitHeight
                        clip: true

                        TextEdit {
                            id: resultArea
                            width: parent.width
                            text: pluginRoot.resultText
                            wrapMode: TextEdit.Wrap
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            selectByMouse: true
                            onTextChanged: pluginRoot.resultText = text
                            
                            Text {
                                text: "Extracted text will appear here..."
                                color: Theme.outlineVariant
                                visible: resultArea.text === ""
                                font: resultArea.font
                            }
                        }
                    }

                    // Floating Action Row
                    Row {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingXS
                        visible: pluginRoot.resultText !== ""

                        // Copy Button
                        StyledRect {
                            width: 36
                            height: 36
                            radius: 18
                            color: copyMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHighest
                            
                            DankIcon {
                                name: "content_copy"
                                size: Theme.iconSizeSmall
                                color: copyMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: copyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pluginRoot.copyToClipboard(pluginRoot.resultText)
                            }
                        }
                    }

                    // Scanning Overlay
                    Rectangle {
                        anchors.fill: parent
                        visible: pluginRoot.isScanning
                        color: Theme.withAlpha(Theme.surfaceContainerLow, 0.8)
                        radius: parent.radius

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM
                            BusyIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                running: pluginRoot.isScanning
                            }
                            StyledText {
                                text: "Analyzing Image..."
                                color: Theme.primary
                                font.weight: Font.Medium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // Action Bar
                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankButton {
                        text: "Save to File"
                        width: (parent.width - Theme.spacingM) / 2
                        iconName: "save"
                        backgroundColor: Theme.secondaryContainer
                        textColor: Theme.secondary
                        enabled: pluginRoot.resultText !== "" && !pluginRoot.isScanning
                        onClicked: pluginRoot.saveResultToFile()
                    }

                    DankButton {
                        text: "Clear Results"
                        width: (parent.width - Theme.spacingM) / 2
                        iconName: "delete_sweep"
                        backgroundColor: pluginRoot.resultText !== "" ? Theme.errorContainer : Theme.surfaceVariant
                        textColor: pluginRoot.resultText !== "" ? Theme.error : Theme.surfaceVariantText
                        enabled: pluginRoot.resultText !== "" && !pluginRoot.isScanning
                        onClicked: {
                            pluginRoot.resultText = "";
                        }
                    }
                }

                // Quick Tip
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingXS
                    opacity: 0.7
                    
                    DankIcon {
                        name: "info"
                        size: 14
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        text: "Right-click the bar icon for instant scan"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }
    }
}
