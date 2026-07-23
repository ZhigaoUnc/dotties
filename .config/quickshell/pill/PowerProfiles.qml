pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import "Singletons"

SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    rows: [
        { item: acRow, kind: "seg", vals: [0, 1, 2], get: function () { return Flags.acProfile; }, set: function (v) { Flags.acProfile = v; } },
        { item: batteryRow, kind: "seg", vals: [0, 1, 2], get: function () { return Flags.batteryProfile; }, set: function (v) { Flags.batteryProfile = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "電"
            title: "POWER PROFILES"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: acRow
            surface: root
            name: "On AC"
            icon: "bolt"
            sub: "Profile when plugged in"

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Eco", value: 0 },
                    { label: "Bal", value: 1 },
                    { label: "Perf", value: 2 }
                ]
                value: Flags.acProfile
                onPicked: (v) => Flags.acProfile = v
            }
        }

        SettingsRow {
            id: batteryRow
            surface: root
            name: "On Battery"
            icon: "leaf"
            sub: "Profile when unplugged"
            last: true

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Eco", value: 0 },
                    { label: "Bal", value: 1 },
                    { label: "Perf", value: 2 }
                ]
                value: Flags.batteryProfile
                onPicked: (v) => Flags.batteryProfile = v
            }
        }
    }
}
