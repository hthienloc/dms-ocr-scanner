import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "ocrScanner"

    property var availableLangs: []
    property var selectedLangs: []

    // Sync with pluginData
    function loadSettings() {
        let val = pluginData.ocrLanguage || "eng+vie";
        selectedLangs = val.split("+").filter(s => s !== "");
    }

    function toggleLang(lang) {
        let list = selectedLangs.slice();
        let index = list.indexOf(lang);
        if (index >= 0) {
            list.splice(index, 1);
        } else {
            list.push(lang);
        }
        
        // Save to persistent storage
        let newVal = list.join("+");
        pluginService.savePluginData(root.pluginId, "ocrLanguage", newVal);
        
        // Update local state to trigger UI
        selectedLangs = list;
    }

    Component.onCompleted: {
        loadSettings();
        Proc.runCommand(
            "list-langs",
            ["tesseract", "--list-langs"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    var lines = stdout.split("\n");
                    var langs = [];
                    for (var i = 1; i < lines.length; i++) {
                        var l = lines[i].trim();
                        if (l !== "" && l !== "osd") langs.push(l);
                    }
                    availableLangs = langs.sort();
                }
            },
            0
        );
    }

    StyledText {
        width: parent.width
        text: "OCR Engine Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    StyledRect {
        width: parent.width
        height: settingsColumn.implicitHeight + (Theme.spacingM * 2)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: settingsColumn
            width: parent.width - (Theme.spacingM * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM

            StyledText {
                text: "Select Recognition Languages"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Flow {
                id: langFlow
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.availableLangs
                    delegate: Rectangle {
                        width: (langFlow.width - 12) / 3
                        height: 40
                        radius: Theme.cornerRadius
                        color: root.selectedLangs.indexOf(modelData) >= 0 ? Theme.primary : Theme.surfaceContainerHigh                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            DankIcon {
                                name: root.selectedLangs.indexOf(modelData) >= 0 ? "check_circle" : "radio_button_unchecked"
                                size: 14
                                color: root.selectedLangs.indexOf(modelData) >= 0 ? Theme.onPrimary : Theme.surfaceVariantText
                            }
                            StyledText {
                                text: modelData.toUpperCase()
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: root.selectedLangs.indexOf(modelData) >= 0 ? Font.Bold : Font.Normal
                                color: root.selectedLangs.indexOf(modelData) >= 0 ? Theme.onPrimary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleLang(modelData)
                        }
                    }
                }
            }

            StyledRect { width: parent.width; height: 1; color: Theme.outlineVariant }

            Column {
                width: parent.width
                spacing: 4
                ToggleSetting {
                    settingKey: "autoCopy"
                    label: "Auto-copy to Clipboard"
                    defaultValue: true
                }
                ToggleSetting {
                    settingKey: "keepResults"
                    label: "Keep results when closed"
                    defaultValue: true
                }
            }
        }
    }
}
