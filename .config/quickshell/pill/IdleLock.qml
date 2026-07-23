pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import "Singletons"

SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    rows: [
        { item: lockRow, kind: "custom" },
        { item: screenRow, kind: "custom" },
        { item: suspendRow, kind: "custom" }
    ]

    function kbActivate() {
        if (kbIndex < 0) return;
        if (rows[kbIndex].item === lockRow) lockField.focus = true;
        else if (rows[kbIndex].item === screenRow) screenField.focus = true;
        else if (rows[kbIndex].item === suspendRow) suspendField.focus = true;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "錠"
            title: "IDLE / LOCK"
            showBack: true
        }

        SettingsRow {
            id: lockRow
            surface: root
            icon: "lock"
            name: "Auto-lock"


            TextField {
                id: lockField
                width: 72 * root.s
                height: 28 * root.s
                horizontalAlignment: TextInput.AlignRight
                verticalAlignment: TextInput.AlignVCenter
                padding: 6 * root.s
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                selectByMouse: true
                selectionColor: Theme.verm
                text: String(Flags.idleLockSec)
                validator: IntValidator { bottom: 0; top: 86400 }

                background: Rectangle {
                    radius: 6 * root.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: lockField.activeFocus ? Theme.vermLit : Theme.border
                }

                function apply() {
                    var v = parseInt(text);
                    if (!isNaN(v) && v >= 0) Flags.idleLockSec = v;
                    else text = String(Flags.idleLockSec);
                }
                onAccepted: { apply(); focus = false; }
                onEditingFinished: apply()
            }
        }

        SettingsRow {
            id: screenRow
            surface: root
            icon: "monitor"
            name: "Screen off"


            TextField {
                id: screenField
                width: 72 * root.s
                height: 28 * root.s
                horizontalAlignment: TextInput.AlignRight
                verticalAlignment: TextInput.AlignVCenter
                padding: 6 * root.s
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                selectByMouse: true
                selectionColor: Theme.verm
                text: String(Flags.idleScreenOffSec)
                validator: IntValidator { bottom: 0; top: 86400 }

                background: Rectangle {
                    radius: 6 * root.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: screenField.activeFocus ? Theme.vermLit : Theme.border
                }

                function apply() {
                    var v = parseInt(text);
                    if (!isNaN(v) && v >= 0) Flags.idleScreenOffSec = v;
                    else text = String(Flags.idleScreenOffSec);
                }
                onAccepted: { apply(); focus = false; }
                onEditingFinished: apply()
            }
        }

        SettingsRow {
            id: suspendRow
            surface: root
            icon: "suspend"
            name: "Suspend"
            last: true

            TextField {
                id: suspendField
                width: 72 * root.s
                height: 28 * root.s
                horizontalAlignment: TextInput.AlignRight
                verticalAlignment: TextInput.AlignVCenter
                padding: 6 * root.s
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                selectByMouse: true
                selectionColor: Theme.verm
                text: String(Flags.idleSuspendSec)
                validator: IntValidator { bottom: 0; top: 86400 }

                background: Rectangle {
                    radius: 6 * root.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: suspendField.activeFocus ? Theme.vermLit : Theme.border
                }

                function apply() {
                    var v = parseInt(text);
                    if (!isNaN(v) && v >= 0) Flags.idleSuspendSec = v;
                    else text = String(Flags.idleSuspendSec);
                }
                onAccepted: { apply(); focus = false; }
                onEditingFinished: apply()
            }
        }

        Item {
            width: 1
            height: 10 * root.s
        }

        Text {
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            width: parent.width
            text: "These timeouts can be prevented by using the keep-awake toggle in the mixer."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Item {
            width: 1
            height: 8 * root.s
        }
    }
}
