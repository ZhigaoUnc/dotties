pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/setDeco.js" as SetDeco
import "Singletons"

/**
 * 飾 LOOK sub-surface: edits the window-decoration knobs that live in
 * decoration.lua and writes each change straight back to its source so the choice
 * survives a restart. Window gaps, rounding and border size, the two opacity
 * fields and the blur block all rewrite the Lua and reload Hyprland so the change
 * lands at once. Blur fields are rewritten scoped to the `blur` block, since
 * `enabled` is shared with the sibling `shadow` block. The border colours are
 * sourced from the palette pipeline and never touched here. Reached from the
 * settings index; morphs back on the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: Math.min(innerCol.implicitHeight, 700 * s)

    Component.onCompleted: {
        var labels = [];
        var container = innerCol.children[1];
        if (!container) return;
        for (var gi = 0; gi < container.children.length; gi++) {
            var c = container.children[gi];
            if (c.title !== undefined && c.body !== undefined) {
                for (var ri = 0; ri < c.body.children.length; ri++) {
                    var row = c.body.children[ri];
                    if (row.label !== undefined)
                        labels.push(row.label);
                }
            }
        }
        var list = [];
        for (var i = 0; i < labels.length; i++) {
            var frow = findFieldRow(labels[i]);
            if (frow) list.push({ item: frow });
        }
        rows = list;
    }

    function kbMove(dir) {
        if (rows.length === 0) return;
        var start = kbIndex < 0 ? (dir > 0 ? -1 : rows.length) : kbIndex;
        var next = start;
        var attempts = 0;
        while (attempts < rows.length) {
            next += dir;
            if (next < 0) next = rows.length - 1;
            else if (next >= rows.length) next = 0;
            var frow = rows[next].item;
            if (frow.collapsed) { attempts++; continue; }
            kbIndex = next;
            focusRowItem = frow;
            return;
        }
    }

    function kbAdjust(dir) {
        if (rows.length === 0 || kbIndex < 0) return;
        var frow = rows[kbIndex].item;
        var ctrl = frow.ctrlItem;
        if (!ctrl) return;
        if (frow.controlKind === "scrub" && typeof ctrl.bump === "function") {
            ctrl.bump(dir);
        } else if (frow.controlKind === "toggle" && typeof ctrl.onToggled === "function") {
            ctrl.onToggled();
        } else if (frow.controlKind === "seg" && typeof ctrl.picked === "function") {
            var opts = ctrl.options;
            if (opts && opts.length > 0) {
                var ci = 0;
                for (var i = 0; i < opts.length; i++) {
                    if (opts[i].value === ctrl.value) { ci = i; break; }
                }
                ctrl.picked(opts[(ci + dir + opts.length) % opts.length].value);
            }
        }
    }

    function kbActivate() {
        if (rows.length === 0 || kbIndex < 0) return;
        var frow = rows[kbIndex].item;
        var ctrl = frow.ctrlItem;
        if (ctrl && frow.controlKind === "toggle" && typeof ctrl.onToggled === "function")
            ctrl.onToggled();
    }

    readonly property string decoPath: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"
    readonly property string pillBlurRule: 'hl.layer_rule({ name = "pill-blur", match = { namespace = "pill" }, blur = true, ignore_alpha = 0.5 })\n'

    property int gapsIn: 6
    property int gapsOut: 12
    property int rounding: 12
    property int roundingPower: 4
    property int borderSize: 2
    property bool resizeOnBorder: true
    property string layout: "dwindle"
    property bool blurOn: true
    property int blurSize: 8
    property int blurPasses: 3
    property real blurVibrancy: 0.17
    property real blurNoise: 0.01
    property bool shadowOn: true
    property int shadowRange: 12
    property int shadowRenderPower: 3
    property real activeOpacity: 1.0
    property real inactiveOpacity: 1.0

    property string searchHighlightLabel: ""
    property real searchHighlightAlpha: 0

    function openGroupFor(label) {
        var container = innerCol.children[1];
        if (!container) return;
        for (var i = 0; i < container.children.length; i++) {
            var c = container.children[i];
            if (c.title !== undefined && c.body !== undefined) {
                for (var k = 0; k < c.body.children.length; k++) {
                    if (c.body.children[k].label === label) {
                        c.open = true;
                        return;
                    }
                }
            }
        }
    }

    function scrollToLabel(label) {
        var container = innerCol.children[1];
        if (!container) return;
        for (var i = 0; i < container.children.length; i++) {
            var c = container.children[i];
            if (c.title !== undefined && c.body !== undefined) {
                for (var k = 0; k < c.body.children.length; k++) {
                    var row = c.body.children[k];
                    if (row.label === label) {
                        var yPos = row.mapToItem(innerCol, 0, 0).y;
                        var viewH = content.height;
                        var targetY = yPos - viewH / 2 + row.height / 2;
                        targetY = Math.max(0, Math.min(content.contentHeight - viewH, targetY));
                        content.contentY = targetY;
                        return;
                    }
                }
            }
        }
    }

    function findFieldRow(label) {
        var container = innerCol.children[1];
        if (!container) return null;
        for (var i = 0; i < container.children.length; i++) {
            var c = container.children[i];
            if (c.title !== undefined && c.body !== undefined) {
                for (var k = 0; k < c.body.children.length; k++) {
                    if (c.body.children[k].label === label)
                        return c.body.children[k];
                }
            }
        }
        return null;
    }

    Timer {
        id: searchHighlightTimer
        interval: 2000
        onTriggered: {
            searchHighlightAlpha = 0;
            searchHighlightLabel = "";
        }
    }

    Behavior on searchHighlightAlpha { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    readonly property var layoutOptions: [
        { label: "Dwindle", value: "dwindle" },
        { label: "Master", value: "master" }
    ]

    property string decoText: ""

    /** Per-field values captured on each open; the ScrubValue undo glyphs revert to these. */
    property var base: ({})

    onActiveChanged: {
        if (active) {
            decoFile.reload();
            seed();
            if (Flags.searchFocusTarget.length > 0) {
                searchHighlightLabel = Flags.searchFocusTarget;
                searchHighlightAlpha = 1;
                openGroupFor(Flags.searchFocusTarget);
                scrollToLabel(Flags.searchFocusTarget);
                root.focusRowItem = findFieldRow(Flags.searchFocusTarget);
                Flags.searchFocusTarget = "";
                searchHighlightTimer.restart();
            }
        } else {
            focusRowItem = null;
            kbIndex = -1;
            searchHighlightLabel = "";
            searchHighlightAlpha = 0;
        }
    }

    /**
     * Seeds every control from the live decoration.lua. Numbers fall back to the
     * shipped defaults when a field is missing so a partially hand-edited config
     * never leaves a control blank. Blur fields read from the `blur` block so a
     * field name shared with the `shadow` block resolves correctly.
     */
    function seed() {
        root.decoText = decoFile.text();
        var t = root.decoText;

        var gi = parseInt(SetDeco.getField(t, "gaps_in"), 10);
        root.gapsIn = isNaN(gi) ? 6 : gi;
        var go = parseInt(SetDeco.getField(t, "gaps_out"), 10);
        root.gapsOut = isNaN(go) ? 12 : go;
        var rd = parseInt(SetDeco.getField(t, "rounding"), 10);
        root.rounding = isNaN(rd) ? 12 : rd;
        var rp = parseInt(SetDeco.getField(t, "rounding_power"), 10);
        root.roundingPower = isNaN(rp) ? 4 : rp;
        var bs = parseInt(SetDeco.getField(t, "border_size"), 10);
        root.borderSize = isNaN(bs) ? 2 : bs;
        root.resizeOnBorder = SetDeco.getField(t, "resize_on_border") === "true";
        var lo = SetDeco.getField(t, "layout");
        root.layout = lo.length > 0 ? lo : "dwindle";

        root.blurOn = SetDeco.getBlockField(t, "blur", "enabled") === "true";
        var bz = parseInt(SetDeco.getBlockField(t, "blur", "size"), 10);
        root.blurSize = isNaN(bz) ? 8 : bz;
        var bp = parseInt(SetDeco.getBlockField(t, "blur", "passes"), 10);
        root.blurPasses = isNaN(bp) ? 3 : bp;
        var vb = parseFloat(SetDeco.getBlockField(t, "blur", "vibrancy"));
        root.blurVibrancy = isNaN(vb) ? 0.17 : vb;
        var nz = parseFloat(SetDeco.getBlockField(t, "blur", "noise"));
        root.blurNoise = isNaN(nz) ? 0.01 : nz;

        root.shadowOn = SetDeco.getBlockField(t, "shadow", "enabled") === "true";
        var sr = parseInt(SetDeco.getBlockField(t, "shadow", "range"), 10);
        root.shadowRange = isNaN(sr) ? 12 : sr;
        var sp = parseInt(SetDeco.getBlockField(t, "shadow", "render_power"), 10);
        root.shadowRenderPower = isNaN(sp) ? 3 : sp;

        var ao = parseFloat(SetDeco.getField(t, "active_opacity"));
        root.activeOpacity = isNaN(ao) ? 1.0 : ao;
        var io = parseFloat(SetDeco.getField(t, "inactive_opacity"));
        root.inactiveOpacity = isNaN(io) ? 1.0 : io;

        Flags.pillBlur = SetDeco.hasNamedRule(t, "pill-blur");

        root.base = {
            gapsIn: root.gapsIn,
            gapsOut: root.gapsOut,
            rounding: root.rounding,
            roundingPower: root.roundingPower,
            borderSize: root.borderSize,
            blurSize: root.blurSize,
            blurPasses: root.blurPasses,
            blurVibrancy: root.blurVibrancy,
            blurNoise: root.blurNoise,
            shadowRange: root.shadowRange,
            shadowRenderPower: root.shadowRenderPower,
            activeOpacity: root.activeOpacity,
            inactiveOpacity: root.inactiveOpacity,
            pillOpacity: Flags.pillOpacity
        };
    }

    /**
     * Rewrites one top-level decoration.lua field to `literal` (already formatted
     * by the caller) and reloads Hyprland so the change takes effect at once.
     */
    function writeDeco(name, literal) {
        var res = SetDeco.setField(root.decoText, name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Same as writeDeco, but for the two opacity fields. A plain reload re-reads
     * the file yet only animates windows on their next focus change, so a window
     * that was inactive when the value changed keeps its stale alpha. Pushing the
     * value through hl.config hits Hyprland's REFRESH_WINDOW_STATES path, which
     * recomputes every existing window's active/inactive alpha at once. Sends both
     * fields so lowering one then restoring the other never leaves a window stuck,
     * and the push fires even when the value lands back on 1.0.
     */
    function writeOpacity(name, literal) {
        writeDeco(name, literal);
        opacityRefresh.command = ["hyprctl", "eval",
            "hl.config({ decoration = { active_opacity = " + root.activeOpacity.toFixed(2)
            + ", inactive_opacity = " + root.inactiveOpacity.toFixed(2) + " } })"];
        opacityRefresh.running = true;
    }

    /**
     * Rewrites one field inside the `blur` block to `literal` and reloads
     * Hyprland. Scoping to the block keeps `enabled` from hitting the sibling
     * `shadow` block's `enabled` first.
     */
    function writeBlur(name, literal) {
        var res = SetDeco.setBlockField(root.decoText, "blur", name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Rewrites one field inside the `shadow` block to `literal` and reloads
     * Hyprland. Scoped to the block so `enabled` lands on shadow, not the sibling
     * `blur` block.
     */
    function writeShadow(name, literal) {
        var res = SetDeco.setBlockField(root.decoText, "shadow", name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Adds or removes the pill-blur layer_rule in decoration.lua and reloads
     * Hyprland so the frosted-glass effect behind the pill turns on or off at
     * once. The rule lives in the Lua source (the live config parser rejects a
     * runtime `layerrule` keyword), so it has to be written, not pushed.
     */
    function applyPillBlur(on) {
        var t = root.decoText;
        var res;
        if (on) {
            if (SetDeco.hasNamedRule(t, "pill-blur"))
                return;
            res = SetDeco.addNamedRule(t, root.pillBlurRule);
        } else {
            res = SetDeco.removeNamedRule(t, "pill-blur");
        }
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    FileView {
        id: decoFile
        path: root.decoPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: decoWriter
        path: root.decoPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.4; hyprctl reload"]
    }

    Process {
        id: opacityRefresh
        command: []
    }

    component GroupLabel: Text {
        topPadding: 16 * root.s
        bottomPadding: 6 * root.s
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * root.s
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * root.s
    }

    /**
     * Collapsible settings group: a tappable header (the group label plus a
     * chevron) over a body of rows that animates between zero and its content
     * height, so a long tab shows only the group headers until one is opened.
     * `open` is the initial state; tapping the header toggles it.
     */
    component Group: Column {
        id: grp
        property string title: ""
        property bool open: false
        default property alias rows: body.data

        width: parent ? parent.width : 0
        spacing: 0

        Item {
            width: parent.width
            height: gl.implicitHeight

            GroupLabel { id: gl; text: grp.title }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: gl.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                name: "chevron-down"
                color: Theme.faint
                stroke: 2.0
                rotation: grp.open ? 0 : -90
                Behavior on rotation { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: grp.open = !grp.open
            }
        }

        Item {
            width: parent.width
            height: grp.open ? body.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

            Column {
                id: body
                width: parent.width
            }
        }
    }

    /**
     * One settings line. At rest it is a single label + control row; hovering the
     * row folds its grey caption open below the label so a long tab stays compact
     * by default. `collapsed` drops the whole row to zero height with the same
     * height animation, used by the blur and shadow rows that depend on a toggle.
     * The label and control are pinned to the top line so only the caption space
     * grows; nothing above it shifts.
     */
    component FieldRow: Item {
        id: frow
        property string label: ""
        property string caption: ""
        property string easyMotionLabel: ""
        property bool collapsed: false
        property string controlKind: ""
        property var ctrlItem: null
        default property alias control: ctrl.data

        readonly property bool focused: root.focusRowItem === frow
        readonly property bool expanded: !frow.collapsed && (fhover.hovered || frow.focused)
        readonly property real rowH: 30 * root.s
        readonly property real capH: 14 * root.s

        width: parent ? parent.width : 0
        height: frow.collapsed ? 0 : (frow.rowH + (frow.expanded ? frow.capH : 0))
        clip: true
        Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

        Component.onCompleted: {
            if (ctrl.data.length > 0) {
                ctrlItem = ctrl.data[0];
                if (controlKind === "" && ctrlItem) {
                    if (typeof ctrlItem.bump === "function") controlKind = "scrub";
                    else if (typeof ctrlItem.onToggled === "function") controlKind = "toggle";
                    else if (typeof ctrlItem.picked === "function") controlKind = "seg";
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3 * root.s
            anchors.bottomMargin: 3 * root.s
            radius: 9 * root.s
            visible: frow.focused || (root.searchHighlightLabel === frow.label && root.searchHighlightAlpha > 0)
            color: frow.focused ? Theme.frameBg : Qt.alpha(Theme.vermLit, root.searchHighlightAlpha * 0.2)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        HoverHandler {
            id: fhover
            onHoveredChanged: if (root.reportRowHover) root.reportRowHover(frow, hovered)
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 2 * root.s
            anchors.top: parent.top
            anchors.topMargin: 8 * root.s
            visible: frow.easyMotionLabel.length > 0
            text: frow.easyMotionLabel
            color: Theme.vermLit
            font.bold: true
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        Text {
            id: labelT
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 8 * root.s
            text: frow.label
            color: frow.focused || (root.searchHighlightLabel === frow.label && root.searchHighlightAlpha > 0) ? Theme.vermLit : Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.Medium
        }

        Text {
            anchors.left: parent.left
            anchors.top: labelT.bottom
            anchors.topMargin: 2 * root.s
            visible: frow.expanded && frow.caption.length > 0
            text: frow.caption
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.Medium
        }

        Item {
            id: ctrl
            anchors.right: parent.right
            anchors.verticalCenter: labelT.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Flickable {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: innerCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: innerCol
            width: parent.width
            spacing: 0

            SettingsHeader {
            s: root.s
            glyph: "飾"
            title: "LOOK"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            Group { title: "Window"; open: true

            FieldRow {
                label: "Gaps inner"
                caption: "Space between tiled windows"
                ScrubValue {
                    s: root.s
                    value: root.gapsIn
                    openValue: root.base.gapsIn
                    from: 0; to: 40; step: 1; unit: "px"
                    onEdited: v => {
                        root.gapsIn = v;
                        root.writeDeco("gaps_in", String(v));
                    }
                }
            }

            FieldRow {
                label: "Gaps outer"
                caption: "Space to the screen edge"
                ScrubValue {
                    s: root.s
                    value: root.gapsOut
                    openValue: root.base.gapsOut
                    from: 0; to: 60; step: 1; unit: "px"
                    onEdited: v => {
                        root.gapsOut = v;
                        root.writeDeco("gaps_out", String(v));
                    }
                }
            }

            FieldRow {
                label: "Rounding"
                caption: "Corner radius in pixels"
                ScrubValue {
                    s: root.s
                    value: root.rounding
                    openValue: root.base.rounding
                    from: 0; to: 30; step: 1; unit: "px"
                    onEdited: v => {
                        root.rounding = v;
                        root.writeDeco("rounding", String(v));
                    }
                }
            }

            FieldRow {
                label: "Rounding power"
                caption: "Higher bends corners to a squircle"
                ScrubValue {
                    s: root.s
                    value: root.roundingPower
                    openValue: root.base.roundingPower
                    from: 1; to: 10; step: 1
                    onEdited: v => {
                        root.roundingPower = v;
                        root.writeDeco("rounding_power", String(v));
                    }
                }
            }

            FieldRow {
                label: "Border size"
                caption: "Window outline thickness"
                ScrubValue {
                    s: root.s
                    value: root.borderSize
                    openValue: root.base.borderSize
                    from: 0; to: 8; step: 1; unit: "px"
                    onEdited: v => {
                        root.borderSize = v;
                        root.writeDeco("border_size", String(v));
                    }
                }
            }

            FieldRow {
                label: "Resize on border"
                caption: "Drag a window edge to resize"
                LinkToggle {
                    s: root.s
                    on: root.resizeOnBorder
                    onToggled: {
                        root.resizeOnBorder = !root.resizeOnBorder;
                        root.writeDeco("resize_on_border", root.resizeOnBorder ? "true" : "false");
                    }
                }
            }

            FieldRow {
                label: "Layout"
                caption: "Tiling layout for new windows"
                SettingsSeg {
                    s: root.s
                    options: root.layoutOptions
                    value: root.layout
                    onPicked: v => {
                        root.layout = v;
                        root.writeDeco("layout", "\"" + v + "\"");
                    }
                }
            }

            }

            Group { title: "Shadow"

            FieldRow {
                label: "Enabled"
                caption: "Drop shadow under windows"
                LinkToggle {
                    s: root.s
                    on: root.shadowOn
                    onToggled: {
                        root.shadowOn = !root.shadowOn;
                        root.writeShadow("enabled", root.shadowOn ? "true" : "false");
                    }
                }
            }

            FieldRow {
                label: "Range"
                caption: "How far the shadow spreads"
                collapsed: !root.shadowOn
                ScrubValue {
                    s: root.s
                    value: root.shadowRange
                    openValue: root.base.shadowRange
                    from: 0; to: 50; step: 1; unit: "px"
                    onEdited: v => {
                        root.shadowRange = v;
                        root.writeShadow("range", String(v));
                    }
                }
            }

            FieldRow {
                label: "Render power"
                caption: "Shadow falloff sharpness"
                collapsed: !root.shadowOn
                ScrubValue {
                    s: root.s
                    value: root.shadowRenderPower
                    openValue: root.base.shadowRenderPower
                    from: 1; to: 4; step: 1
                    onEdited: v => {
                        root.shadowRenderPower = v;
                        root.writeShadow("render_power", String(v));
                    }
                }
            }

            }

            Group { title: "Blur"

            FieldRow {
                label: "Enabled"
                caption: "Blur behind transparent windows"
                LinkToggle {
                    s: root.s
                    on: root.blurOn
                    onToggled: {
                        root.blurOn = !root.blurOn;
                        root.writeBlur("enabled", root.blurOn ? "true" : "false");
                    }
                }
            }

            FieldRow {
                label: "Strength"
                caption: "Blur radius"
                collapsed: !root.blurOn
                ScrubValue {
                    s: root.s
                    value: root.blurSize
                    openValue: root.base.blurSize
                    from: 1; to: 20; step: 1; unit: "px"
                    onEdited: v => {
                        root.blurSize = v;
                        root.writeBlur("size", String(v));
                    }
                }
            }

            FieldRow {
                label: "Passes"
                caption: "More passes, smoother blur"
                collapsed: !root.blurOn
                ScrubValue {
                    s: root.s
                    value: root.blurPasses
                    openValue: root.base.blurPasses
                    from: 1; to: 5; step: 1
                    onEdited: v => {
                        root.blurPasses = v;
                        root.writeBlur("passes", String(v));
                    }
                }
            }

            FieldRow {
                label: "Vibrancy"
                caption: "Color saturation behind the blur"
                collapsed: !root.blurOn
                ScrubValue {
                    s: root.s
                    value: root.blurVibrancy
                    openValue: root.base.blurVibrancy
                    from: 0; to: 1; step: 0.01; decimals: 2
                    onEdited: v => {
                        root.blurVibrancy = v;
                        root.writeBlur("vibrancy", v.toFixed(2));
                    }
                }
            }

            FieldRow {
                label: "Noise"
                caption: "Grain mixed into the blur"
                collapsed: !root.blurOn
                ScrubValue {
                    s: root.s
                    value: root.blurNoise
                    openValue: root.base.blurNoise
                    from: 0; to: 0.2; step: 0.01; decimals: 2
                    onEdited: v => {
                        root.blurNoise = v;
                        root.writeBlur("noise", v.toFixed(2));
                    }
                }
            }

            }

            Group { title: "Opacity"

            FieldRow {
                label: "Active window"
                caption: "Focused window transparency"
                ScrubValue {
                    s: root.s
                    value: root.activeOpacity
                    openValue: root.base.activeOpacity
                    from: 0.5; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => {
                        root.activeOpacity = v;
                        root.writeOpacity("active_opacity", v.toFixed(2));
                    }
                }
            }

            FieldRow {
                label: "Inactive window"
                caption: "Unfocused window transparency"
                ScrubValue {
                    s: root.s
                    value: root.inactiveOpacity
                    openValue: root.base.inactiveOpacity
                    from: 0.5; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => {
                        root.inactiveOpacity = v;
                        root.writeOpacity("inactive_opacity", v.toFixed(2));
                    }
                }
            }

            }

            Group { title: "Pill"

            FieldRow {
                label: "Pill opacity"
                caption: "How see-through the pill sits"
                ScrubValue {
                    s: root.s
                    value: Flags.pillOpacity
                    openValue: root.base.pillOpacity
                    from: 0.55; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => Flags.pillOpacity = v
                }
            }

            FieldRow {
                label: "Pill blur"
                caption: "Frosts what is behind the pill. Needs opacity below 100%."
                LinkToggle {
                    s: root.s
                    on: Flags.pillBlur
                    onToggled: {
                        Flags.pillBlur = !Flags.pillBlur;
                        root.applyPillBlur(Flags.pillBlur);
                    }
                }
            }

            FieldRow {
                label: "Notch mode"
                caption: "Flush black notch at the screen edge"
                LinkToggle {
                    s: root.s
                    on: Flags.notchMode
                    onToggled: Flags.notchMode = !Flags.notchMode
                }
            }

            FieldRow {
                label: "Round battery"
                caption: "Outline around the whole pill body"
                LinkToggle {
                    s: root.s
                    on: Flags.batteryOutline
                    onToggled: Flags.batteryOutline = !Flags.batteryOutline
                }
            }

            FieldRow {
                label: "Line thickness"
                caption: "Stroke width of the battery outline"
                ScrubValue {
                    s: root.s
                    value: Flags.batteryLineThickness
                    openValue: 4
                    from: 1; to: 12; step: 1; decimals: 0
                    onEdited: v => Flags.batteryLineThickness = v
                }
            }

            FieldRow {
                label: "Battery in OSD"
                caption: "Outline visible during workspace flash"
                LinkToggle {
                    s: root.s
                    on: Flags.osdBatteryOutline
                    onToggled: Flags.osdBatteryOutline = !Flags.osdBatteryOutline
                }
            }

            FieldRow {
                label: "Auto-hide pill"
                caption: "Hide the rest pill. Hover the area to reveal."
                LinkToggle {
                    s: root.s
                    on: Flags.hidePill
                    onToggled: Flags.hidePill = !Flags.hidePill
                }
            }

            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
}
