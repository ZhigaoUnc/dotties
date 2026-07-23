pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    property string listening: ""

    function handleKey(letter) {
        if (root.listening.length === 0)
            return false;
        if (letter >= "a" && letter <= "z") {
            switch (root.listening) {
                case "lock":     Flags.powerKeyLock = letter; break;
                case "logout":   Flags.powerKeyLogout = letter; break;
                case "suspend":  Flags.powerKeySuspend = letter; break;
                case "reboot":   Flags.powerKeyReboot = letter; break;
                case "shutdown": Flags.powerKeyShutdown = letter; break;
            }
            root.listening = "";
        }
        return true;
    }

    function cancelListening() {
        root.listening = "";
    }

    rows: [
        { item: lockRow, kind: "custom" },
        { item: logoutRow, kind: "custom" },
        { item: sleepRow, kind: "custom" },
        { item: restartRow, kind: "custom" },
        { item: shutdownRow, kind: "custom" }
    ]

    function kbActivate() {
        if (kbIndex < 0) return;
        activateRow(rows[kbIndex].item);
    }

    function activateRow(item) {
        if (item === lockRow) { root.listening = root.listening === "lock" ? "" : "lock"; return; }
        if (item === logoutRow) { root.listening = root.listening === "logout" ? "" : "logout"; return; }
        if (item === sleepRow) { root.listening = root.listening === "suspend" ? "" : "suspend"; return; }
        if (item === restartRow) { root.listening = root.listening === "reboot" ? "" : "reboot"; return; }
        if (item === shutdownRow) { root.listening = root.listening === "shutdown" ? "" : "shutdown"; return; }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "keyboard"
            title: "POWER KEYS"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: lockRow
            surface: root
            icon: "lock"
            name: "Lock"
            sub: root.listening === "lock" ? "Press a key..." : "Key: " + Flags.powerKeyLock.toUpperCase()
        }

        SettingsRow {
            id: logoutRow
            surface: root
            icon: "logout"
            name: "Logout"
            sub: root.listening === "logout" ? "Press a key..." : "Key: " + Flags.powerKeyLogout.toUpperCase()
        }

        SettingsRow {
            id: sleepRow
            surface: root
            icon: "suspend"
            name: "Sleep"
            sub: root.listening === "suspend" ? "Press a key..." : "Key: " + Flags.powerKeySuspend.toUpperCase()
        }

        SettingsRow {
            id: restartRow
            surface: root
            icon: "reboot"
            name: "Restart"
            sub: root.listening === "reboot" ? "Press a key..." : "Key: " + Flags.powerKeyReboot.toUpperCase()
        }

        SettingsRow {
            id: shutdownRow
            surface: root
            icon: "shutdown"
            name: "Shutdown"
            sub: root.listening === "shutdown" ? "Press a key..." : "Key: " + Flags.powerKeyShutdown.toUpperCase()
            last: true
        }
    }

    onActiveChanged: if (!active) root.listening = ""
}
