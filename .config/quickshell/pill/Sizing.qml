pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        { item: hoverRow, kind: "custom" },
        { item: osdRow, kind: "custom" },
        { item: surfaceRow, kind: "custom" }
    ]

    function kbActivate() {
        if (kbIndex < 0) return;
        if (rows[kbIndex].item === hoverRow) hoverField.focus = true;
        else if (rows[kbIndex].item === osdRow) osdField.focus = true;
        else if (rows[kbIndex].item === surfaceRow) surfaceField.focus = true;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "寸"
            title: "SIZING"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: hoverRow
            surface: root
            name: "Hover"
            icon: "pointer"
            sub: "Hover / pinned state"

            Item {
                width: 56 * root.s
                height: 32 * root.s

                TextField {
                    id: hoverField
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    padding: 6 * root.s
                    text: Flags.hoverScale.toFixed(1)
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    selectByMouse: true
                    selectionColor: Theme.verm
                    validator: DoubleValidator { bottom: 0.5; top: 3.0; decimals: 1; notation: DoubleValidator.StandardNotation }

                    background: Rectangle {
                        radius: 6 * root.s
                        color: Theme.tileBg
                        border.width: 1
                        border.color: hoverField.activeFocus ? Theme.vermLit : Theme.border
                    }

                    function apply() {
                        var v = parseFloat(text);
                        if (!isNaN(v) && v >= 0.5 && v <= 3.0)
                            Flags.hoverScale = Math.round(v * 10) / 10;
                        text = Flags.hoverScale.toFixed(1);
                    }

                    onAccepted: { apply(); focus = false; }
                    onEditingFinished: apply()
                }
            }
        }

        SettingsRow {
            id: osdRow
            surface: root
            name: "OSD"
            icon: "notification"
            sub: "Volume, brightness, track"

            Item {
                width: 56 * root.s
                height: 32 * root.s

                TextField {
                    id: osdField
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
padding: 6 * root.s
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    selectByMouse: true
                    selectionColor: Theme.verm
                    validator: DoubleValidator { bottom: 0.5; top: 3.0; decimals: 1; notation: DoubleValidator.StandardNotation }

                    background: Rectangle {
                        radius: 6 * root.s
                        color: Theme.tileBg
                        border.width: 1
                        border.color: osdField.activeFocus ? Theme.vermLit : Theme.border
                    }

                    function apply() {
                        var v = parseFloat(text);
                        if (!isNaN(v) && v >= 0.5 && v <= 3.0)
                            Flags.osdScale = Math.round(v * 10) / 10;
                        text = Flags.osdScale.toFixed(1);
                    }

                    onAccepted: { apply(); focus = false; }
                    onEditingFinished: apply()
                }
            }
        }

        SettingsRow {
            id: surfaceRow
            surface: root
            name: "Surfaces"
            icon: "app-window"
            sub: "Popups, menus, submenus"
            last: true

            Item {
                width: 56 * root.s
                height: 32 * root.s

                TextField {
                    id: surfaceField
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    padding: 6 * root.s
                    text: Flags.surfaceScale.toFixed(1)
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    selectByMouse: true
                    selectionColor: Theme.verm
                    validator: DoubleValidator { bottom: 0.5; top: 3.0; decimals: 1; notation: DoubleValidator.StandardNotation }

                    background: Rectangle {
                        radius: 6 * root.s
                        color: Theme.tileBg
                        border.width: 1
                        border.color: surfaceField.activeFocus ? Theme.vermLit : Theme.border
                    }

                    function apply() {
                        var v = parseFloat(text);
                        if (!isNaN(v) && v >= 0.5 && v <= 3.0)
                            Flags.surfaceScale = Math.round(v * 10) / 10;
                        text = Flags.surfaceScale.toFixed(1);
                    }

                    onAccepted: { apply(); focus = false; }
                    onEditingFinished: apply()
                }
            }
        }
    }
}
