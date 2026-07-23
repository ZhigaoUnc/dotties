pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight
    rows: []

    readonly property var allModules: [
        { id: "workspaces", name: "Workspaces", icon: "grid" },
        { id: "clock", name: "Clock", icon: "clock" },
        { id: "weather", name: "Weather", icon: "cloud" },
        { id: "minimized", name: "Minimized windows", icon: "collapse" },
        { id: "tray", name: "System tray", icon: "chevron-up" },
        { id: "dnd", name: "Do not disturb", icon: "bell-off" },
        { id: "network", name: "Network", icon: "wifi" },
        { id: "battery", name: "Battery", icon: "battery" },
        { id: "inbox", name: "Notifications", icon: "inbox" },
        { id: "mixer", name: "Audio mixer", icon: "mixer" },
        { id: "sysmon", name: "System monitor", icon: "monitor" },
        { id: "recorder", name: "Screen recorder", icon: "video" },
        { id: "wallpaper", name: "Wallpaper", icon: "image" },
        { id: "settings", name: "Settings", icon: "cog" },
        { id: "power", name: "Power", icon: "shutdown" }
    ]

    readonly property var enabledList: {
        var raw = Flags.hoverModules;
        if (!raw || raw.length < 2) return [];
        try { return JSON.parse(raw); } catch(e) { return []; }
    }

    readonly property var displayList: {
        var enabled = enabledList;
        var enabledSet = {};
        for (var i = 0; i < enabled.length; i++)
            enabledSet[enabled[i]] = true;
        var out = [];
        for (var k = 0; k < allModules.length; k++) {
            var m = allModules[k];
            var ei = enabled.indexOf(m.id);
            out.push({
                id: m.id, name: m.name, icon: m.icon,
                on: ei >= 0
            });
        }
        return out;
    }

    function saveList(list) {
        Flags.hoverModules = JSON.stringify(list);
    }

    function toggle(id) {
        var list = enabledList.slice();
        var idx = list.indexOf(id);
        if (idx >= 0) list.splice(idx, 1);
        else list.push(id);
        saveList(list);
    }

    function moveUp(id) {
        var list = enabledList.slice();
        var idx = list.indexOf(id);
        if (idx <= 0) return;
        var tmp = list[idx - 1];
        list[idx - 1] = list[idx];
        list[idx] = tmp;
        saveList(list);
    }

    function moveDown(id) {
        var list = enabledList.slice();
        var idx = list.indexOf(id);
        if (idx < 0 || idx >= list.length - 1) return;
        var tmp = list[idx + 1];
        list[idx + 1] = list[idx];
        list[idx] = tmp;
        saveList(list);
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "触"
            title: "HOVER STATE"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        Repeater {
            model: root.displayList

            delegate: Item {
                id: modRow
                required property var modelData
                width: parent.width
                height: 40 * root.s

                readonly property bool isEnabled: modelData.on
                readonly property int idx: root.enabledList.indexOf(modelData.id)

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2 * root.s
                    anchors.bottomMargin: 2 * root.s
                    anchors.leftMargin: 12 * root.s
                    anchors.rightMargin: 12 * root.s
                    radius: 9 * root.s
                    color: modRowRow.containsMouse ? Theme.frameBg : "transparent"
                }

                HoverHandler { id: modRowRow }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 18 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10 * root.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16 * root.s
                        height: 16 * root.s
                        name: modelData.icon
                        color: isEnabled ? Theme.subtle : Theme.faint
                        stroke: 1.7
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: isEnabled ? Theme.cream : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s

                    MouseArea {
                        id: upBtn
                        width: 20 * root.s
                        height: 20 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: isEnabled && idx > 0
                        cursorShape: Qt.PointingHandCursor

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 12 * root.s
                            height: 12 * root.s
                            name: "chevron-up"
                            color: upBtn.enabled ? (upBtn.containsMouse ? Theme.cream : Theme.iconDim) : Theme.faint
                            stroke: 2.2
                        }

                        onClicked: root.moveUp(modelData.id)
                    }

                    MouseArea {
                        id: downBtn
                        width: 20 * root.s
                        height: 20 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: isEnabled && idx >= 0 && idx < root.enabledList.length - 1
                        cursorShape: Qt.PointingHandCursor

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 12 * root.s
                            height: 12 * root.s
                            name: "chevron-down"
                            color: downBtn.enabled ? (downBtn.containsMouse ? Theme.cream : Theme.iconDim) : Theme.faint
                            stroke: 2.2
                        }

                        onClicked: root.moveDown(modelData.id)
                    }

                    Item {
                        width: 34 * root.s
                        height: 20 * root.s

                        Rectangle {
                            anchors.fill: parent
                            radius: 10 * root.s
                            color: isEnabled ? Qt.alpha(Theme.vermLit, 0.3) : Theme.tileBg
                            border.width: 1
                            border.color: isEnabled ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: isEnabled ? undefined : parent.left
                                anchors.right: isEnabled ? parent.right : undefined
                                anchors.leftMargin: isEnabled ? undefined : 2 * root.s
                                anchors.rightMargin: isEnabled ? 2 * root.s : undefined
                                width: 14 * root.s
                                height: 14 * root.s
                                radius: width / 2
                                color: isEnabled ? Theme.vermLit : Theme.faint
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggle(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 12 * root.s }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Drag up/down arrows to reorder · Toggle to show/hide"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
        }
    }
}
