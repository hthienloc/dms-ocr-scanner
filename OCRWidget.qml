import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.Modals.FileBrowser

PluginComponent {
    id: pluginRoot

    popoutWidth: 800
    popoutHeight: 600

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
        fileBrowserModal.open();
    }

    function scanFromUrl(url) {
        if (!url || isScanning) return;
        
        let path = "";
        if (url.startsWith("file://")) {
            path = url.substring(7);
            sourceImage = path;
            imageTrigger++;
            isScanning = true;
            runTesseract(path);
        } else if (url.startsWith("http://") || url.startsWith("https://")) {
            const tempFile = "/tmp/dms_ocr_dl_" + Date.now();
            Proc.runCommand("download-image", ["curl", "-L", url, "-o", tempFile], (stdout, exitCode) => {
                if (exitCode === 0) {
                    sourceImage = tempFile;
                    imageTrigger++;
                    isScanning = true;
                    runTesseract(tempFile);
                } else {
                    ToastService.showError("Failed to download image from URL.");
                }
            });
        } else {
            if (url.startsWith("/")) {
                sourceImage = url;
                imageTrigger++;
                isScanning = true;
                runTesseract(url);
            } else {
                ToastService.showError("Invalid image source.");
            }
        }
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
                    if (stdout && stdout.includes("Invalid")) {
                        ToastService.showError("Invalid or unsupported image format.");
                    } else if (stdout && stdout.includes("read")) {
                        ToastService.showError("Could not read the file. Make sure it's a valid image.");
                    } else {
                        ToastService.showError("Tesseract failed. Is it installed?");
                    }
                }
            },
            0
        );
    }

    function copyToClipboard(text) {
        if (!text) return;
        DMSService.sendRequest("clipboard.copy", { "text": text }, function(response) {
            if (!response.error) {
                ToastService.showInfo("Copied to clipboard!");
            }
        });
    }

    function saveResultToFile() {
        if (!resultText) return;
        saveBrowserModal.open();
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: horizontalRow.implicitWidth
            implicitHeight: 24
            anchors.verticalCenter: parent.verticalCenter

            property bool draggingOver: false

            Row {
                id: horizontalRow
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                scale: draggingOver ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                DankIcon {
                    name: "document_scanner"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (pluginRoot.isScanning ? Theme.primary : Theme.surfaceVariantText)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "OCR"
                    font.pixelSize: Theme.fontSizeSmall
                    color: pluginRoot.isScanning ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (pluginData.showTextInPill ?? true) && pluginRoot.isScanning
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    let urls = [];
                    if (drop.hasUrls) {
                        urls = drop.urls.map(url => url.toString());
                    } else if (drop.hasText) {
                        urls = [drop.text];
                    }
                    pluginRoot.triggerPopout();
                    if (urls.length > 0) {
                        urls.forEach(url => pluginRoot.scanFromUrl(url));
                    }
                }
            }
        }
    }

    FileBrowserModal {
        id: fileBrowserModal
        browserTitle: "Select Image to Scan"
        browserIcon: "image"
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        onFileSelected: path => {
            pluginRoot.isScanning = true;
            pluginRoot.sourceImage = path;
            pluginRoot.imageTrigger++;
            pluginRoot.runTesseract(path);
            close();
        }
    }

    FileBrowserModal {
        id: saveBrowserModal
        browserTitle: "Save OCR Result"
        browserIcon: "save"
        saveMode: true
        defaultFileName: "ocr_result.txt"
        fileExtensions: ["*.txt"]
        onFileSelected: filePath => {
            Proc.runCommand(
                "write-file",
                ["sh", "-c", "echo \"" + resultText.replace(/"/g, "\\\"") + "\" > '" + filePath + "'"],
                (stdout, exitCode) => {
                    if (exitCode === 0) ToastService.showInfo("Saved successfully!");
                },
                0
            );
            close();
        }
    }

    verticalBarPill: horizontalBarPill

    popoutContent: Component {
        PopoutComponent {
            id: popout
            width: parent ? parent.width : 0
            headerText: "OCR Scanner"
            detailsText: pluginRoot.isScanning ? "Processing..." : "Ready to scan"
            showCloseButton: true
            focus: true

            property var parentPopout: null

            Component.onDestruction: {
                if (!(pluginData.keepResults ?? true)) {
                    resultText = "";
                    sourceImage = "";
                }
            }

            DankFlickable {
                width: parent.width
                height: Math.min(contentHeight, pluginRoot.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingM - ((pluginData.showTip ?? true) ? 40 : 0))
                contentHeight: contentColumn.implicitHeight
                contentWidth: width
                clip: true

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingXS
                        visible: (pluginData.showTip ?? true)
                        DankIcon { name: "lightbulb"; size: 14; color: Theme.surfaceVariantText }
                        StyledText { text: "Tip: Drop image onto pill icon to scan quickly"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingM

                            StyledRect {
                                width: parent.width
                                height: 380
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

                                DankButton {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingS
                                    width: 32
                                    height: 32
                                    iconName: "delete"
                                    onClicked: {
                                        pluginRoot.sourceImage = ""
                                        pluginRoot.resultText = ""
                                    }
                                    enabled: (pluginRoot.sourceImage !== "" || pluginRoot.resultText !== "") && !pluginRoot.isScanning
                                    backgroundColor: Theme.errorContainer
                                    textColor: Theme.error
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankButton {
                                    text: "Scan Clipboard"
                                    width: (parent.width - Theme.spacingS) / 2
                                    iconName: "content_paste"
                                    onClicked: pluginRoot.scanFromClipboard()
                                    enabled: !pluginRoot.isScanning
                                    backgroundColor: Theme.primaryContainer
                                    textColor: Theme.primary
                                }

                                DankButton {
                                    text: "Select File"
                                    width: (parent.width - Theme.spacingS) / 2
                                    iconName: "image"
                                    onClicked: pluginRoot.selectFileAndScan()
                                    enabled: !pluginRoot.isScanning
                                    backgroundColor: Theme.surfaceContainerHighest
                                    textColor: Theme.surfaceText
                                }
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingM

                            StyledRect {
                                width: parent.width
                                height: 380
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

                                DankButton {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingS
                                    width: 32
                                    height: 32
                                    iconName: "delete"
                                    onClicked: pluginRoot.resultText = ""
                                    enabled: pluginRoot.resultText !== "" && !pluginRoot.isScanning
                                    backgroundColor: Theme.errorContainer
                                    textColor: Theme.error
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankButton {
                                    text: "Copy Text"
                                    width: (parent.width - Theme.spacingS) / 2
                                    iconName: "content_copy"
                                    onClicked: pluginRoot.copyToClipboard(pluginRoot.resultText)
                                    enabled: pluginRoot.resultText !== "" && !pluginRoot.isScanning
                                    backgroundColor: Theme.primaryContainer
                                    textColor: Theme.primary
                                }

                                DankButton {
                                    text: "Save Text"
                                    width: (parent.width - Theme.spacingS) / 2
                                    iconName: "save"
                                    onClicked: pluginRoot.saveResultToFile()
                                    enabled: pluginRoot.resultText !== "" && !pluginRoot.isScanning
                                    backgroundColor: Theme.surfaceContainerHighest
                                    textColor: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
