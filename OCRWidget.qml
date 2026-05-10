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
    popoutWidth: 800
    popoutHeight: 520

    // Right-click action on pill
    pillRightClickAction: () => {
        const showPopout = pluginData.showPopoutOnRightClick ?? true;
        if (showPopout) pluginRoot.triggerPopout();
        pluginRoot.scanFromClipboard();
    }

    property string resultText: ""
    property bool isScanning: false
    property string sourceImage: ""
    property int imageTrigger: 0

    function scanFromClipboard() {
        if (isScanning) return;
        
        const tempImage = "/tmp/dms_ocr_input.png";
        const getClipCmd = "wl-paste -t image/png > " + tempImage + " || xclip -selection clipboard -t image/png -o > " + tempImage;
        
        Proc.runCommand(
            "get-clipboard-image",
            ["sh", "-c", getClipCmd],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    isScanning = true;
                    runTesseract(tempImage);
                } else {
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
                    sourceImage = filePath;
                    imageTrigger++;
                    runTesseract(filePath);
                }
            },
            0
        );
    }

    function runTesseract(imagePath) {
        if (imagePath.includes("/tmp/dms_ocr_input.png")) {
            sourceImage = imagePath;
            imageTrigger++;
        }
        
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
                }
            },
            0
        );
    }

    function saveResultToFile() {
        if (!resultText) return;
        Proc.runCommand(
            "save-file",
            ["kdialog", "--getsavefilename", ":", "*.txt"],
            (stdout, exitCode) => {
                const filePath = stdout.trim();
                if (exitCode === 0 && filePath !== "") {
                    Proc.runCommand(
                        "write-file",
                        ["sh", "-c", "echo \"" + resultText.replace(/"/g, "\\\"") + "\" > '" + filePath + "'"],
                        (stdout, exitCode) => {
                            if (exitCode === 0) ToastService.showInfo("Saved successfully!");
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
            implicitWidth: pillRow.implicitWidth + Theme.spacingM
            implicitHeight: 32

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                
                DankIcon {
                    name: "document_scanner"
                    size: Theme.iconSizeSmall
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
        Item {
            implicitWidth: pluginRoot.popoutWidth
            implicitHeight: popout.implicitHeight

            PopoutComponent {
                id: popout
                width: parent.width
                headerText: "OCR Scanner"
                detailsText: pluginRoot.isScanning ? "Processing..." : "Ready to scan"
                showCloseButton: true

                DankFlickable {
                    width: parent.width
                    height: Math.min(contentHeight, pluginRoot.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingM)
                    contentHeight: contentColumn.implicitHeight
                    contentWidth: width
                    clip: true

                    Column {
                        id: contentColumn
                        width: parent.width
                        spacing: Theme.spacingM

                        // Header Row: Selection Buttons (Compact)
                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            
                            DankButton {
                                text: "Scan Clipboard"
                                width: (parent.width - Theme.spacingM) / 2
                                iconName: "content_paste"
                                onClicked: pluginRoot.scanFromClipboard()
                                enabled: !pluginRoot.isScanning
                                backgroundColor: Theme.primaryContainer
                                textColor: Theme.primary
                            }
                            
                            DankButton {
                                text: "Select Image File"
                                width: (parent.width - Theme.spacingM) / 2
                                iconName: "image"
                                onClicked: pluginRoot.selectFileAndScan()
                                enabled: !pluginRoot.isScanning
                                backgroundColor: Theme.secondaryContainer
                                textColor: Theme.secondary
                            }
                        }

                        // Comparison Area (Side-by-Side)
                        Row {
                            width: parent.width
                            height: 380
                            spacing: Theme.spacingM
                            
                            // Left: Image Panel (Reference)
                            StyledRect {
                                width: (parent.width - Theme.spacingM) / 2
                                height: parent.height
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: Theme.outlineVariant
                                border.width: 1
                                clip: true
                                
                                Image {
                                    id: sourceImg
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    source: pluginRoot.sourceImage ? "file://" + pluginRoot.sourceImage + "?t=" + pluginRoot.imageTrigger : ""
                                    
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "No image scanned yet"
                                        color: Theme.outlineVariant
                                        visible: sourceImg.status !== Image.Ready && !pluginRoot.isScanning
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                }
                            }
                            
                            // Right: Text Panel (Editor)
                            StyledRect {
                                width: (parent.width - Theme.spacingM) / 2
                                height: parent.height
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: pluginRoot.isScanning ? Theme.primary : Theme.outlineVariant
                                border.width: 1
                                
                                DankFlickable {
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
                                            text: "Text will appear here..."
                                            color: Theme.outlineVariant
                                            visible: resultArea.text === ""
                                            font: resultArea.font
                                        }
                                    }
                                }

                                // Floating Action Row for results
                                Row {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingXS
                                    visible: pluginRoot.resultText !== ""

                                    StyledRect {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: copyMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHighest
                                        
                                        DankIcon {
                                            name: "content_copy"
                                            size: 16
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
                            }
                        }

                        // Bottom Action Bar
                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankButton {
                                text: "Save Results"
                                width: (parent.width - Theme.spacingM) / 2
                                iconName: "save"
                                backgroundColor: Theme.surfaceContainerHighest
                                textColor: Theme.surfaceText
                                enabled: pluginRoot.resultText !== "" && !pluginRoot.isScanning
                                onClicked: pluginRoot.saveResultToFile()
                            }

                            DankButton {
                                text: "Clear All"
                                width: (parent.width - Theme.spacingM) / 2
                                iconName: "delete_sweep"
                                backgroundColor: Theme.errorContainer
                                textColor: Theme.error
                                enabled: (pluginRoot.resultText !== "" || pluginRoot.sourceImage !== "") && !pluginRoot.isScanning
                                onClicked: {
                                    pluginRoot.resultText = "";
                                    pluginRoot.sourceImage = "";
                                }
                            }
                        }
                    }
            }
        }

            // Global Scanning Overlay
            Rectangle {
                anchors.fill: parent
                z: 100
                visible: opacity > 0
                opacity: pluginRoot.isScanning ? 1 : 0
                color: Theme.withAlpha(Theme.surfaceContainer, 0.9)
                radius: Theme.cornerRadius

                Behavior on opacity {
                    NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingL
                    
                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: pluginRoot.isScanning
                        implicitWidth: 64
                        implicitHeight: 64
                    }
                    
                    StyledText {
                        text: "Analyzing Image..."
                        color: Theme.primary
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    StyledText {
                        text: "Please wait a moment"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                        opacity: 0.8
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
