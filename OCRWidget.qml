import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.Modals.FileBrowser
import "./dms-common"

PluginComponent {
    id: pluginRoot

    popoutWidth: 800
    property int maxPopoutHeight: (pluginData.showHints ?? true) ? 660 : 600
    property int currentContentHeight: 400
    popoutHeight: Math.min(currentContentHeight, maxPopoutHeight)

    pillRightClickAction: () => {
        const showPopout = pluginData.showPopoutOnRightClick ?? true;
        if (showPopout) pluginRoot.triggerPopout();
        pluginRoot.scanFromClipboard();
    }

    property string resultText: ""
    property bool isScanning: false
    property bool isSaving: false
    property bool isAutoScanning: false
    property string sourceImage: ""
    property int imageTrigger: 0
    property int lastScanTime: 0

    // History & Tabs
    property string activeTab: "scanner" // "scanner" or "history"
    property var history: []
    readonly property string historyPath: Quickshell.env("HOME") + "/.config/DankMaterialShell/plugins/ocrScanner"
    readonly property string historyFile: historyPath + "/history.json"

    function loadHistory() {
        Proc.runCommand(
            "load-history",
            ["python3", "-c", "import os, sys; f=sys.argv[1]; print(open(f).read() if os.path.exists(f) else '[]')", historyFile],
            (stdout, exitCode) => {
                try {
                    const data = JSON.parse(stdout);
                    history = Array.isArray(data) ? data : [];
                    pluginRoot.history = history;
                } catch (e) {
                    history = [];
                    pluginRoot.history = [];
                }
            },
            0
        );
    }

    function saveHistory() {
        const data = JSON.stringify(history);
        Proc.runCommand(
            "save-history",
            ["python3", "-c", "import os, sys; open(sys.argv[1], 'w').write(sys.argv[2])", historyFile, data],
            (stdout, exitCode) => {
                if (exitCode !== 0) {
                    ToastService.showError("Failed to save history database. Code: " + exitCode);
                }
            },
            0
        );
    }

    function getRawPath(path) {
        if (!path) return "";
        let clean = path.toString();
        // Strip query string (e.g. ?t=123)
        const qIdx = clean.indexOf('?');
        if (qIdx !== -1) clean = clean.substring(0, qIdx);
        
        if (clean.startsWith("file://")) return clean.substring(7);
        if (clean.startsWith("file: ")) return clean.substring(6);
        return clean;
    }

    function addToHistory() {
        if (!resultText || !sourceImage) {
            ToastService.showError("Nothing to save to history");
            return;
        }

        const rawSource = getRawPath(sourceImage);
        const timestamp = Date.now();
        const ext = rawSource.split('.').pop() || "png";
        const newImageName = "ocr_" + timestamp + "." + ext;
        const newImagePath = historyPath + "/images/" + newImageName;
        
        Proc.runCommand(
            "copy-history-image",
            ["python3", "-c", "import os, shutil, sys; os.makedirs(os.path.dirname(sys.argv[2]), exist_ok=True); shutil.copy2(sys.argv[1], sys.argv[2])", rawSource, newImagePath],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    const entry = {
                        id: timestamp,
                        timestamp: timestamp,
                        text: resultText,
                        image: newImagePath
                    };
                    const updatedHistory = [entry, ...history].slice(0, 50);
                    history = updatedHistory;
                    pluginRoot.history = updatedHistory;
                    saveHistory();
                    ToastService.showInfo("Saved to history");
                } else {
                    ToastService.showError("Failed to save image. Code: " + exitCode);
                }
            },
            0
        );
    }

    function deleteFromHistory(index) {
        const item = history[index];
        if (item && item.image) {
            Proc.runCommand("delete-history-image", ["rm", "-f", item.image], null, 0);
        }
        const newHistory = [...history];
        newHistory.splice(index, 1);
        pluginRoot.history = newHistory;
        saveHistory();
    }

    function clearHistory() {
        Proc.runCommand("clear-history-images", ["sh", "-c", "rm -rf \"$1/images\" && mkdir -p \"$1/images\"", "sh", historyPath], (stdout, exitCode) => {
            if (exitCode !== 0) {
                ToastService.showError("Failed to clear history images");
            }
        }, 0);
        pluginRoot.history = [];
        saveHistory();
    }

    onPluginServiceChanged: {
        if (pluginService) {
            loadHistory();
        }
    }

    Component.onCompleted: {
        if (pluginService) {
            loadHistory();
        }
    }

    function scanFromClipboard() {
        if (isScanning || isAutoScanning) return;
        
        const now = Date.now();
        if (now - lastScanTime < 2000) return;
        lastScanTime = now;

        const tempImage = "/tmp/dms_ocr_input.png";
        const getClipCmd = "wl-paste -t image/png > " + tempImage + " 2>/dev/null";

        Proc.runCommand(
            "get-clipboard-image",
            ["sh", "-c", getClipCmd],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    const checkCmd = "file --mime-type -b " + tempImage + " | grep -q image && echo HAS_IMAGE";
                    Proc.runCommand(
                        "check-image-type",
                        ["sh", "-c", checkCmd],
                        (checkOut, checkCode) => {
                            if (checkCode === 0 && checkOut.trim() === "HAS_IMAGE") {
                                isScanning = true;
                                isAutoScanning = true;
                                runTesseract(tempImage, true);
                            } else {
                                ToastService.showError("No image found in clipboard!");
                            }
                        },
                        0
                    );
                } else {
                    ToastService.showError("No image found in clipboard!");
                }
            },
            0
        );
    }

    function scanFromScreenshot() {
        isScanning = true;
        const tempPath = "/tmp/dms_ocr_screenshot.png";

        Proc.runCommand(
            "screenshot-ocr",
            ["dms", "screenshot", "region", "--no-confirm", "--no-notify", "--dir", "/tmp", "--filename", "dms_ocr_screenshot.png"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    sourceImage = tempPath;
                    imageTrigger++;
                    runTesseract(tempPath);
                    pluginRoot.triggerPopout();
                } else {
                    isScanning = false;
                    ToastService.showError("Failed to take screenshot or selection cancelled.");
                }
            },
            0
        );
    }

    function selectFileAndScan() {
        pluginRoot.closePopout();
        fileBrowserModal.open();
    }

    function scanFromUrl(url) {
        if (!url || isScanning) return;
        
        const convertSvgToPng = function(inputPath, callback) {
            const outputPath = "/tmp/dms_ocr_svg_" + Date.now() + ".png";
            Proc.runCommand(
                "svg-convert",
                ["rsvg-convert", "-w", "2000", "-h", "2000", "-f", "png", "-o", outputPath, inputPath],
                (stdout, exitCode) => {
                    if (exitCode === 0) {
                        callback(outputPath);
                    } else {
                        Proc.runCommand(
                            "svg-convert-fallback",
                            ["convert", "-background", "white", "-alpha", "remove", inputPath, outputPath],
                            (stdout2, exitCode2) => {
                                if (exitCode2 === 0) {
                                    callback(outputPath);
                                } else {
                                    callback(null);
                                }
                            },
                            0
                        );
                    }
                },
                0
            );
        };

        const processImage = function(path) {
            if (path.toLowerCase().endsWith(".svg")) {
                convertSvgToPng(path, function(convertedPath) {
                    if (convertedPath) {
                        sourceImage = convertedPath;
                        imageTrigger++;
                        isScanning = true;
                        runTesseract(convertedPath);
                    } else {
                        ToastService.showError("Failed to convert SVG to PNG. Install rsvg-convert or imagemagick.");
                    }
                });
            } else {
                sourceImage = path;
                imageTrigger++;
                isScanning = true;
                runTesseract(path);
            }
        };

        if (url.startsWith("file://")) {
            processImage(url.substring(7));
        } else if (url.startsWith("http://") || url.startsWith("https://")) {
            const tempFile = "/tmp/dms_ocr_dl_" + Date.now();
            Proc.runCommand("download-image", ["curl", "-L", url, "-o", tempFile], (stdout, exitCode) => {
                if (exitCode === 0) {
                    processImage(tempFile);
                } else {
                    ToastService.showError("Failed to download image from URL.");
                }
            });
        } else if (url.startsWith("/")) {
            processImage(url);
        } else {
            ToastService.showError("Invalid image source.");
        }
    }

    function runTesseract(imagePath, skipAutoCopy) {
        if (imagePath.includes("/tmp/dms_ocr_input.png")) {
            sourceImage = imagePath;
            imageTrigger++;
        }

        const lang = pluginService.loadPluginSetting(root.pluginId, "ocrLanguage", "eng");
        const tesseractCmd = "tesseract '" + imagePath + "' - -l " + lang;

        Proc.runCommand(
            "run-tesseract",
            ["sh", "-c", tesseractCmd],
            (stdout, exitCode) => {
                isScanning = false;
                isAutoScanning = false;
                if (exitCode === 0) {
                    const result = stdout.trim();
                    if (result === "") {
                        ToastService.showInfo("No text detected.");
                    } else {
                        resultText = result;
                        ToastService.showInfo("Scan complete!");
                        if (!skipAutoCopy && (pluginData.autoCopy ?? true)) {
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
        isSaving = true;
        pluginRoot.closePopout();
        saveBrowserModal.open();
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: horizontalRow.implicitWidth
            implicitHeight: Theme.iconSize
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

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        pluginRoot.scanFromScreenshot();
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
        onDialogClosed: {
            pluginRoot.triggerPopout();
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
            isSaving = true;
            let cleanPath = pluginRoot.getRawPath(filePath);
            
            Proc.runCommand(
                "write-file",
                ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", resultText, cleanPath],
                (stdout, exitCode) => {
                    isSaving = false;
                    if (exitCode === 0) {
                        ToastService.showInfo("Saved successfully!");
                    } else {
                        ToastService.showError("Failed to save: " + exitCode);
                    }
                },
                0
            );
            close();
        }
        onDialogClosed: isSaving = false
    }

    verticalBarPill: horizontalBarPill

    popoutContent: Component {
        PopoutComponent {
            id: popout
            width: parent ? parent.width : 0
            headerText: pluginRoot.activeTab === "history" ? I18n.tr("OCR History") : I18n.tr("OCR Scanner")
            detailsText: pluginRoot.activeTab === "history" ? (pluginRoot.history.length + " items") : (pluginRoot.isScanning ? I18n.tr("Processing...") : I18n.tr("Ready to scan"))
            showCloseButton: true
            focus: true

            onImplicitHeightChanged: pluginRoot.currentContentHeight = implicitHeight

            property var parentPopout: null

            Component.onDestruction: {
                if (!pluginRoot.isSaving && pluginRoot.pluginData && !(pluginRoot.pluginData.keepResults ?? true)) {
                    resultText = "";
                    sourceImage = "";
                }
                pluginRoot.activeTab = "scanner";
            }

            headerActions: Component {
                Row {
                    spacing: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter

                    // History Toggle Button
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: historyBtnArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: pluginRoot.activeTab === "history" ? "arrow_back" : "history"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: historyBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pluginRoot.activeTab = (pluginRoot.activeTab === "history" ? "scanner" : "history")
                        }
                    }
                }
            }

            readonly property int maxAllowedViewHeight: pluginRoot.maxPopoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingM

            // History View
            DankFlickable {
                id: historyView
                width: parent.width
                visible: pluginRoot.activeTab === "history"
                height: visible ? Math.min(historyCol.implicitHeight + Theme.spacingM, maxAllowedViewHeight) : 0
                implicitHeight: height
                contentHeight: historyCol.implicitHeight + Theme.spacingM
                contentWidth: width
                clip: true
                interactive: visible

                Column {
                    id: historyCol
                    width: parent.width
                    spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Clear All History")
                            width: parent.width
                            backgroundColor: Theme.errorContainer
                            textColor: Theme.error
                            iconName: "delete_sweep"
                            onClicked: pluginRoot.clearHistory()
                            visible: pluginRoot.history.length > 0
                        }

                        StyledText {
                            text: I18n.tr("No history items yet")
                            color: Theme.outlineVariant
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: pluginRoot.history.length === 0
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        Repeater {
                            model: pluginRoot.history
                            delegate: StyledRect {
                                width: parent.width
                                height: 120
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: Theme.outlineVariant
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingM

                                    // Image thumbnail
                                    StyledRect {
                                        width: 100
                                        height: parent.height - (Theme.spacingS * 2)
                                        radius: Theme.cornerRadiusSmall
                                        color: Theme.surfaceContainerHigh
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: "file://" + modelData.image
                                            fillMode: Image.PreserveAspectCrop
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                pluginRoot.sourceImage = modelData.image;
                                                pluginRoot.resultText = modelData.text;
                                                pluginRoot.imageTrigger++;
                                                pluginRoot.activeTab = "scanner";
                                            }
                                        }
                                    }

                                    // Text preview
                                    Column {
                                        width: parent.width - 160
                                        height: parent.height - (Theme.spacingS * 2)
                                        spacing: 4

                                        StyledText {
                                            text: new Date(modelData.timestamp).toLocaleString()
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: modelData.text
                                            width: parent.width
                                            height: parent.height - 20
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            maximumLineCount: 3
                                        }
                                    }

                                    // Action buttons
                                    Column {
                                        width: 32
                                        spacing: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankActionButton {
                                            iconName: "content_copy"
                                            iconSize: 16
                                            onClicked: pluginRoot.copyToClipboard(modelData.text)
                                            tooltipText: I18n.tr("Copy Text")
                                        }

                                        DankActionButton {
                                            iconName: "delete"
                                            iconSize: 16
                                            iconColor: Theme.error
                                            onClicked: pluginRoot.deleteFromHistory(index)
                                            tooltipText: I18n.tr("Delete Entry")
                                        }
                                    }
                                }
                            }
                }
            }

            // Scanner View
            DankFlickable {
                id: scannerView
                width: parent.width
                visible: pluginRoot.activeTab === "scanner"
                height: visible ? Math.min(contentColumn.implicitHeight, maxAllowedViewHeight) : 0
                implicitHeight: height
                contentHeight: contentColumn.implicitHeight
                contentWidth: width
                clip: true
                interactive: visible

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: Theme.spacingM

                    HintSection {
                        showHints: (pluginData.showHints ?? true)
                        width: parent.width

                        HintItem {
                            icon: "file_download"
                            text: I18n.tr("Drop an image or URL onto the pill icon to scan it instantly")
                        }
                        HintItem {
                            icon: "mouse"
                            text: I18n.tr("Right-click to scan clipboard, Middle-click to scan screenshot")
                        }
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
                                        text: I18n.tr("No image scanned yet")
                                        color: Theme.outlineVariant
                                        visible: sourceImg.status !== Image.Ready && !pluginRoot.isScanning
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                }

                                Row {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankActionButton {
                                        buttonSize: 32
                                        iconName: "bookmark_add"
                                        onClicked: pluginRoot.addToHistory()
                                        enabled: pluginRoot.sourceImage !== "" && !pluginRoot.isScanning
                                        backgroundColor: Theme.surfaceContainerHighest
                                        iconColor: Theme.surfaceText
                                        tooltipText: I18n.tr("Save to History")
                                    }

                                    DankActionButton {
                                        buttonSize: 32
                                        iconName: "delete"
                                        onClicked: {
                                            pluginRoot.sourceImage = ""
                                            pluginRoot.resultText = ""
                                        }
                                        enabled: (pluginRoot.sourceImage !== "" || pluginRoot.resultText !== "") && !pluginRoot.isScanning
                                        backgroundColor: Theme.errorContainer
                                        iconColor: Theme.error
                                        tooltipText: I18n.tr("Clear (No history)")
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankButton {
                                    text: I18n.tr("Scan Clipboard")
                                    width: (parent.width - Theme.spacingS) / 2
                                    iconName: "content_paste"
                                    onClicked: pluginRoot.scanFromClipboard()
                                    enabled: !pluginRoot.isScanning
                                    backgroundColor: Theme.primaryContainer
                                    textColor: Theme.primary
                                }

                                DankButton {
                                    text: I18n.tr("Select File")
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
                                            text: I18n.tr("Text will appear here...")
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
                                    text: I18n.tr("Copy Text")
                                    width: (parent.width - Theme.spacingS) / 2
                                    iconName: "content_copy"
                                    onClicked: pluginRoot.copyToClipboard(pluginRoot.resultText)
                                    enabled: pluginRoot.resultText !== "" && !pluginRoot.isScanning
                                    backgroundColor: Theme.primaryContainer
                                    textColor: Theme.primary
                                }

                                DankButton {
                                    text: I18n.tr("Save Text")
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
}

