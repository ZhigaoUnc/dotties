pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "Singletons"

/**
 * 相 APPEARANCE sub-surface: the clock format and seconds, the Japanese-glyph
 * toggle that gates every surface header, the palette mode (static flame, dynamic
 * per-wallpaper, or a manually chosen hue), the UI scale and a reduce-motion
 * switch. Reached from the settings index and morphs back to it on an empty click
 * or the back chevron.
 *
 * Manual palette mode reveals a rainbow hue strip and a dark/light choice; moving
 * either rebuilds the rice colour set from that hue through wallcolors.py --hue
 * and reloads Hyprland and the terminal, debounced so a drag does not spawn a
 * build per pixel.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: Math.min(content.implicitHeight, 700 * s)

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"
    property string satArg: String(Flags.manualSat)
    property string editKey: ""
    property string editHex: ""

    readonly property color accentColor: Qt.hsla(Flags.manualHue / 360, Flags.manualSat, Flags.manualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: {
        var c = accentColor;
        function h(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    function applyManual() {
        hueArg = String(Math.round(Flags.manualHue));
        modeArg = Flags.manualDark ? "dark" : "light";
        satArg = String(Flags.manualSat);
        applyTimer.restart();
    }

    function applyMode(v) {
        Flags.paletteMode = v;
        if (v === "manual")
            applyManual();
        else if (v === "dynamic")
            dynamicProc.running = true;
        else if (v === "static")
            staticProc.running = true;
    }

    Timer {
        id: applyTimer
        interval: 260
        repeat: false
        onTriggered: paletteProc.running = true
    }

    Process {
        id: paletteProc
        command: ["sh", "-c",
            "bash \"$HOME/.config/scripts/dingaling/wallcolors.sh\" --hue \"$1\" \"$2\" \"$3\"",
            "sh", root.hueArg, root.modeArg, root.satArg]
    }

    Process {
        id: dynamicProc
        command: ["sh", "-c",
            "bash \"$HOME/.config/scripts/dingaling/wallcolors.sh\""]
    }

    Process {
        id: staticProc
        command: ["sh", "-c", "bash \"$HOME/.config/scripts/dingaling/wallcolors.sh\" --static"]
    }

    Process {
        id: overrideSetProc
        command: editKey.length > 0
            ? ["bash", "/home/unc/.config/scripts/dingaling/override.sh", "set", editKey, editHex]
            : ["true"]
    }

    Process {
        id: overrideRemoveProc
        command: editKey.length > 0
            ? ["bash", "/home/unc/.config/scripts/dingaling/override.sh", "remove", editKey]
            : ["true"]
    }

    Process {
        id: pushProc
        command: ["sh", "-c", "bash \"$HOME/.config/scripts/dingaling/pushcolors.sh\""]
    }

    Process {
        id: pullProc
        command: ["sh", "-c", "rm -f \"$HOME/.cache/dingaling/overrides.json\"; bash \"$HOME/.config/scripts/dingaling/wallcolors.sh\""]
    }

    Connections {
        target: Flags
        function onManualHueChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
        function onManualSatChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
    }

    rows: [
        { item: timeRow, kind: "seg", vals: [false, true], get: function () { return Flags.time12h; }, set: function (v) { Flags.time12h = v; } },
        { item: secRow, kind: "toggle", get: function () { return Flags.clockSeconds; }, set: function (v) { Flags.clockSeconds = v; } },
        { item: glyphRow, kind: "toggle", get: function () { return Flags.showGlyphs; }, set: function (v) { Flags.showGlyphs = v; } },
        { item: clockIconRow, kind: "toggle", get: function () { return Flags.showClockIcon; }, set: function (v) { Flags.showClockIcon = v; } },
        { item: vizRow, kind: "toggle", get: function () { return Flags.musicViz; }, set: function (v) { Flags.musicViz = v; } },
        { item: paletteRow, kind: "seg", vals: ["static", "dynamic", "manual"], get: function () { return Flags.paletteMode; }, set: function (v) { root.applyMode(v); } },
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: sizingRow, kind: "nav", surface: "sizing" },
        { item: hoverStateRow, kind: "nav", surface: "hoverstate" },
        { item: wallpaperPickerRow, kind: "seg", vals: ["filmstrip", "carousel"], get: function () { return Flags.wallpaperPicker; }, set: function (v) { Flags.wallpaperPicker = v; } },
        { item: motionRow, kind: "toggle", get: function () { return Flags.reduceMotion; }, set: function (v) { Flags.reduceMotion = v; } },
        { item: fontRow, kind: "nav", surface: "fontpicker" }
    ]

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: content.implicitHeight

        Column {
            id: content
            width: parent.width
            spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "相"
            title: "APPEARANCE"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: timeRow
            surface: root
            name: "Time format"
            icon: "clock"

            SettingsSeg {
                s: root.s
                options: [{ label: "24H", value: false }, { label: "12H", value: true }]
                value: Flags.time12h
                onPicked: (v) => Flags.time12h = v
            }
        }

        SettingsRow {
            id: secRow
            surface: root
            name: "Clock seconds"
            icon: "stopwatch"

            LinkToggle {
                s: root.s
                on: Flags.clockSeconds
                onToggled: Flags.clockSeconds = !Flags.clockSeconds
            }
        }

        SettingsRow {
            id: glyphRow
            surface: root
            name: "Kanji"
            icon: "language"

            LinkToggle {
                s: root.s
                on: Flags.showGlyphs
                onToggled: Flags.showGlyphs = !Flags.showGlyphs
            }
        }

        SettingsRow {
            id: clockIconRow
            surface: root
            name: "Clock icon"
            icon: "clock"

            LinkToggle {
                s: root.s
                on: Flags.showClockIcon
                onToggled: Flags.showClockIcon = !Flags.showClockIcon
            }
        }

        SettingsRow {
            id: vizRow
            surface: root
            name: "Music visualizer"
            icon: "music"

            LinkToggle {
                s: root.s
                on: Flags.musicViz
                onToggled: Flags.musicViz = !Flags.musicViz
            }
        }

        SettingsRow {
            id: paletteRow
            surface: root
            name: "Palette"
            icon: "palette"

            SettingsSeg {
                s: root.s
                options: [{ label: "Static", value: "static" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: Flags.paletteMode
                onPicked: (v) => root.applyMode(v)
            }
        }

        /**
         * Manual hue editor, folded shut unless the palette is on Manual. Holds a
         * rainbow strip with a draggable thumb, then a single line pairing a live
         * accent swatch and its hex caption with the dark/light choice, and a hex
         * input that drives both hue and saturation. The strip is mouse-driven and
         * stays out of the keyboard row registry.
         */
        Item {
            id: manualSection
            width: parent.width
            height: Flags.paletteMode === "manual" ? manualCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                Item {
                    width: parent.width
                    height: 14 * root.s

                    Rectangle {
                        id: hueStrip
                        anchors.fill: parent
                        radius: 7 * root.s
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                            GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                        }

                        Rectangle {
                            id: hueThumb
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Flags.manualHue / 359) * (hueStrip.width - width)
                            color: root.accentColor
                            border.width: 2.5 * root.s
                            border.color: Theme.cream
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setHue(mx) {
                                if (Flags.manualSat < 0.05)
                                    Flags.manualSat = 0.5;
                                Flags.manualHue = Math.round(Math.max(0, Math.min(1, mx / hueStrip.width)) * 359);
                            }
                            onPressed: (mouse) => setHue(mouse.x)
                            onPositionChanged: (mouse) => setHue(mouse.x)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(34 * root.s, toneSeg.implicitHeight)

                    Rectangle {
                        id: accentSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.accentColor
                        border.width: 1
                        border.color: Theme.border
                    }

                    Column {
                        anchors.left: accentSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.right: toneSeg.left
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3 * root.s

                        Text {
                            text: "Accent hue"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.currentHex + " · " + (Flags.manualDark ? "dark" : "light")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    SettingsSeg {
                        id: toneSeg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                        value: Flags.manualDark
                        onPicked: (v) => { Flags.manualDark = v; root.applyManual(); }
                    }
                }

                Item {
                    width: parent.width
                    height: 30 * root.s

                    Text {
                        id: hexHint
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: hexField
                        anchors.left: hexHint.right
                        anchors.leftMargin: 6 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: root.currentHex
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        maximumLength: 7

                        onActiveFocusChanged: if (!activeFocus) text = "";

                        function commit() {
                            var raw = text.trim();
                            var clean = raw.charAt(0) === "#" ? raw.slice(1) : raw;
                            if (/^[0-9a-fA-F]{6}$/.test(clean)) {
                                var c = Qt.color("#" + clean);
                                if (c.hslHue >= 0) {
                                    Flags.manualHue = Math.round(c.hslHue * 359);
                                    Flags.manualSat = c.hslSaturation;
                                } else {
                                    Flags.manualSat = 0;
                                }
                                root.applyManual();
                            }
                            text = "";
                            focus = false;
                        }

                        onAccepted: commit()
                        onEditingFinished: commit()
                    }

                    Rectangle {
                        anchors.left: hexField.left
                        anchors.right: hexField.right
                        anchors.top: hexField.bottom
                        anchors.topMargin: 3 * root.s
                        height: 1
                        color: Theme.faint
                        opacity: hexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

        Item {
            width: parent.width
            property bool overrideCollapsed: true
            height: Flags.paletteMode === "static" ? 0 : (overrideCollapsed ? 34 * root.s : paletteGrid.implicitHeight + 24 * root.s)
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: paletteGrid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 12 * root.s
                spacing: 6 * root.s

                Item {
                    width: parent.width
                    height: 22 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Colour overrides"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 4 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.parent.overrideCollapsed ? "▸" : "▾"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.parent.parent.overrideCollapsed = !parent.parent.parent.overrideCollapsed
                    }
                }

                Repeater {
                    model: [
                        { key: "surface", jsonKey: "surface", label: "Surface" },
                        { key: "primary", jsonKey: "primary", label: "Primary" },
                        { key: "primaryContainer", jsonKey: "primary_container", label: "Primary container" },
                        { key: "cream", jsonKey: "cream", label: "Cream" },
                        { key: "subtle", jsonKey: "subtle", label: "Subtle" },
                        { key: "dim", jsonKey: "dim", label: "Dim" },
                        { key: "faint", jsonKey: "faint", label: "Faint" },
                        { key: "surfaceContainerHigh", jsonKey: "surface_container_high", label: "Surface high" },
                        { key: "outlineVariant", jsonKey: "outline_variant", label: "Outline var." },
                        { key: "bright", jsonKey: "bright", label: "Bright" },
                        { key: "iconDim", jsonKey: "icon_dim", label: "Icon dim" }
                    ]

                    delegate: Item {
                        required property var modelData
                        width: parent.width
                        height: 22 * root.s

                        Rectangle {
                            id: swatch
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16 * root.s; height: 16 * root.s; radius: 3 * root.s
                            border.width: 1; border.color: Theme.border
                            color: {
                                var v = Dyn[modelData.key];
                                return v ? Qt.color(v) : "#888888";
                            }
                        }

                        Text {
                            anchors.left: swatch.right
                            anchors.leftMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 4 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: Dyn[modelData.key] || ""
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.features: { "tnum": 1 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                editKey = modelData.jsonKey;
                                editField.text = Dyn[modelData.key] || "";
                                editField.focus = true;
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 22 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: editField
                        anchors.left: parent.left; anchors.leftMargin: 14 * root.s
                        anchors.right: resetBtn.left; anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null; padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.features: { "tnum": 1 }
                        maximumLength: 7
                        selectByMouse: true
                        selectionColor: Theme.verm

                        onEditingFinished: commit()
                        onAccepted: commit()

                        function commit() {
                            var raw = text.trim();
                            var clean = raw.charAt(0) === "#" ? raw.slice(1) : raw;
                            if (/^[0-9a-fA-F]{6}$/.test(clean)) {
                                editHex = "#" + clean;
                                overrideSetProc.running = true;
                            }
                            editKey = "";
                            text = "";
                            focus = false;
                        }
                    }

                    Rectangle {
                        anchors.left: editField.left
                        anchors.right: editField.right
                        anchors.top: editField.bottom; anchors.topMargin: 2 * root.s
                        height: 1; color: Theme.faint; opacity: editField.activeFocus ? 0.7 : 0.18
                    }

                    Text {
                        id: resetBtn
                        anchors.right: parent.right; anchors.rightMargin: 4 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "reset"
                        color: Theme.verm
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                overrideRemoveProc.running = true;
                                editKey = "";
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: Flags.paletteMode === "static" ? 0 : 28 * root.s
            clip: true
            visible: height > 0
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Row {
                anchors.centerIn: parent
                spacing: 10 * root.s

                Rectangle {
                    width: pullText.implicitWidth + 24 * root.s
                    height: 26 * root.s
                    radius: 6 * root.s
                    color: Qt.alpha(Theme.verm, 0.12)
                    border.width: 1; border.color: Qt.alpha(Theme.verm, 0.25)

                    Text {
                        id: pullText
                        anchors.centerIn: parent
                        text: "Pull from wallpaper"
                        color: Theme.verm
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pullProc.running = true;
                        }
                    }
                }

                Rectangle {
                    width: pushText.implicitWidth + 24 * root.s
                    height: 26 * root.s
                    radius: 6 * root.s
                    color: Qt.alpha(Theme.verm, 0.12)
                    border.width: 1; border.color: Qt.alpha(Theme.verm, 0.25)

                    Text {
                        id: pushText
                        anchors.centerIn: parent
                        text: "Push to apps"
                        color: Theme.verm
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pushProc.running = true
                    }
                }
            }
        }

        SettingsRow {
            id: scaleRow
            surface: root
            name: "UI scale"
            icon: "scaling"

            SettingsSeg {
                s: root.s
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Flags.uiScale
                onPicked: (v) => Flags.uiScale = v
            }
        }

        SettingsRow {
            id: sizingRow
            surface: root
            name: "Sizing"
            icon: "scaling"
            sub: "Hover, OSD, panels"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === sizingRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: hoverStateRow
            surface: root
            name: "Hover state"
            icon: "pointer"
            sub: "Modules, order, visibility"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === hoverStateRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: wallpaperPickerRow
            surface: root
            name: "Wallpaper picker"
            icon: "image"

            SettingsSeg {
                s: root.s
                options: [{ label: "Filmstrip", value: "filmstrip" }, { label: "Carousel", value: "carousel" }]
                value: Flags.wallpaperPicker
                onPicked: (v) => Flags.wallpaperPicker = v
            }
        }

        SettingsRow {
            id: motionRow
            surface: root
            name: "Reduce motion"
            icon: "waves"

            LinkToggle {
                s: root.s
                on: Flags.reduceMotion
                onToggled: Flags.reduceMotion = !Flags.reduceMotion
            }
        }

        SettingsRow {
            id: fontRow
            surface: root
            name: "Font"
            icon: "type"
            sub: Flags.uiFont.length > 0 ? Flags.uiFont : "Inter"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === fontRow ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }
        }
    }

    WheelScroller {
        s: root.s
        flick: flick
    }
}
