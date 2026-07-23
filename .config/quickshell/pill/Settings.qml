pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * 設 SETTINGS index: a short list of categories grouped into Shell and Control.
 * Each row carries its kanji, name and caption, and morphs the pill into that
 * category's sub-surface. Arrow keys move the focused row with the glowing seam
 * and Return opens it. A search field at the top filters rows live by surface
 * name, caption, or token label, picks the best-matching display name, and
 * supports keyboard navigation that skips non-matching rows.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    property string searchQuery: ""

    onActiveChanged: if (active) field.forceActiveFocus()

    readonly property var appearanceTokens: [{label:"time format", displayName:"Time format"},{label:"clock seconds", displayName:"Clock seconds"},{label:"kanji", displayName:"Kanji"},{label:"clock icon", displayName:"Clock icon"},{label:"music visualizer", displayName:"Music visualizer"},{label:"palette", displayName:"Palette"},{label:"ui scale", displayName:"UI scale"},{label:"sizing", target:"sizing", displayName:"Sizing"},{label:"hover state", target:"hoverstate", displayName:"Hover state"},{label:"wallpaper picker", displayName:"Wallpaper picker"},{label:"reduce motion", displayName:"Reduce motion"},{label:"font", target:"fontpicker", displayName:"Font"}]
    readonly property var lookTokens: [{label:"gaps", displayName:"Gaps inner"},{label:"rounding", displayName:"Rounding", fieldLabel:"Rounding"},{label:"border", displayName:"Border size", fieldLabel:"Border size"},{label:"layout", displayName:"Layout", fieldLabel:"Layout"},{label:"shadow", displayName:"Shadow", fieldLabel:"Enabled"},{label:"blur", displayName:"Blur"},{label:"strength", displayName:"Blur strength", fieldLabel:"Strength"},{label:"passes", displayName:"Blur passes", fieldLabel:"Passes"},{label:"vibrancy", displayName:"Blur vibrancy", fieldLabel:"Vibrancy"},{label:"noise", displayName:"Blur noise", fieldLabel:"Noise"},{label:"opacity", displayName:"Window opacity"},{label:"active window", displayName:"Active window", fieldLabel:"Active window"},{label:"inactive window", displayName:"Inactive window", fieldLabel:"Inactive window"},{label:"pill opacity", displayName:"Pill opacity", fieldLabel:"Pill opacity"},{label:"pill blur", displayName:"Pill blur", fieldLabel:"Pill blur"},{label:"notch mode", displayName:"Notch mode", fieldLabel:"Notch mode"},{label:"battery", displayName:"Battery outline", fieldLabel:"Round battery"},{label:"auto-hide", displayName:"Auto-hide pill", fieldLabel:"Auto-hide pill"}]
    readonly property var scrollTokens: [{label:"display", target:"display", displayName:"Display"},{label:"input", target:"input", displayName:"Input"},{label:"animation", target:"animation", displayName:"Animation"},{label:"keybinds", target:"keybinds", displayName:"Keybinds"}]
    readonly property var idleTokens: [{label:"auto-lock", displayName:"Auto-lock"},{label:"screen off", displayName:"Screen off"},{label:"suspend", displayName:"Suspend"}]
    readonly property var powerProfileTokens: [{label:"on ac", displayName:"On AC"},{label:"on battery", displayName:"On Battery"},{label:"ac", displayName:"AC profile"},{label:"battery", displayName:"Battery profile"}]
    readonly property var powerKeysTokens: [{label:"lock", displayName:"Lock"},{label:"logout", displayName:"Logout"},{label:"sleep", displayName:"Sleep"},{label:"restart", displayName:"Restart"},{label:"shutdown", displayName:"Shutdown"}]
    readonly property var updatesTokens: [{label:"version", displayName:"Version"},{label:"check for updates", displayName:"Check for updates"},{label:"update", displayName:"Update"}]

    readonly property var allRows: [
        { id: "appearance", name: "Appearance", sub: "Clock, glyphs, accent palette", group: "Shell", tokens: appearanceTokens },
        { id: "look", name: "Look", sub: "Gaps, rounding, blur, opacity", group: "Shell", tokens: lookTokens },
        { id: "scroll", name: "Scroll", sub: "Display, input, animation, keybinds", group: "Shell", tokens: scrollTokens },
        { id: "idlelock", name: "Idle / Lock", sub: "Auto-lock, screen off, suspend", group: "Control", tokens: idleTokens },
        { id: "powerprofiles", name: "Power Profiles", sub: "Auto-switch on AC / battery", group: "Control", tokens: powerProfileTokens },
        { id: "powerkeys", name: "Power Keys", sub: "Shortcut letters for power actions", group: "Control", tokens: powerKeysTokens },
        { id: "updates", name: "Updates", sub: "Version and check for updates", group: "Control", tokens: updatesTokens }
    ]

    rows: [
        { item: appearanceRow, kind: "nav", surface: "appearance" },
        { item: lookRow, kind: "nav", surface: "look" },
        { item: scrollRow, kind: "nav", surface: "scroll" },
        { item: idleRow, kind: "nav", surface: "idlelock" },
        { item: powerProfileRow, kind: "nav", surface: "powerprofiles" },
        { item: powerKeysRow, kind: "nav", surface: "powerkeys" },
        { item: updatesRow, kind: "nav", surface: "updates" }
    ]

    // ── Search helpers (read searchQuery directly — QML tracks the dependency) ──

    /**
     * Returns true if every word in the query matches somewhere: surface name,
     * sub caption, or a token label (AND logic, multi-word).
     */
    function matchesQuery(name, sub, tokens) {
        if (searchQuery.length === 0) return true;
        var words = searchQuery.toLowerCase().split(/\s+/).filter(function(w) { return w.length > 0; });
        var nameL = name.toLowerCase();
        var subL = sub.toLowerCase();
        for (var wi = 0; wi < words.length; wi++) {
            var w = words[wi];
            if (nameL.indexOf(w) >= 0 || subL.indexOf(w) >= 0) continue;
            var found = false;
            if (tokens) {
                for (var ti = 0; ti < tokens.length && !found; ti++) {
                    if (tokens[ti].label.toLowerCase().indexOf(w) >= 0)
                        found = true;
                }
            }
            if (!found) return false;
        }
        return true;
    }

    /** Whether any row in a group array matches the query. */
    function groupVisible(rows) {
        if (searchQuery.length === 0) return true;
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i];
            if (matchesQuery(r.name, r.sub, r.tokens)) return true;
        }
        return false;
    }

    /**
     * Returns the best display name for a surface given the current query.
     * Falls back to defaultName when there is no query or no token match.
     */
    function searchName(surfaceId, defaultName) {
        if (searchQuery.length === 0) return defaultName;
        var q = searchQuery.toLowerCase();
        var words = q.split(/\s+/).filter(function(w) { return w.length > 0; });
        for (var i = 0; i < allRows.length; i++) {
            if (allRows[i].id !== surfaceId) continue;
            var tokens = allRows[i].tokens;
            if (!tokens) return defaultName;

            // Find the best-matching token by tier
            var bestTier = 0;
            var bestDisplay = null;
            for (var wi = 0; wi < words.length; wi++) {
                for (var ti = 0; ti < tokens.length; ti++) {
                    var t = tokens[ti];
                    var tl = t.label.toLowerCase();
                    if (tl === words[wi] && 3 > bestTier) { bestTier = 3; bestDisplay = t.displayName; }
                    else if (tl.indexOf(words[wi]) === 0 && 2 > bestTier) { bestTier = 2; bestDisplay = t.displayName; }
                    else if (tl.indexOf(words[wi]) >= 0 && 1 > bestTier) { bestTier = 1; bestDisplay = t.displayName; }
                }
                if (allRows[i].name.toLowerCase() === words[wi] && 6 > bestTier) { bestTier = 6; bestDisplay = allRows[i].name; }
                else if (allRows[i].name.toLowerCase().indexOf(words[wi]) === 0 && 5 > bestTier) { bestTier = 5; bestDisplay = allRows[i].name; }
            }
            return bestDisplay || defaultName;
        }
        return defaultName;
    }

    /**
     * Finds the best-matching token's fieldLabel for a surface.
     * Returns { target: string, fieldLabel: string }.
     */
    function _bestToken(surfaceId) {
        if (searchQuery.length === 0) return { target: "", fieldLabel: "" };
        var q = searchQuery.toLowerCase();
        var words = q.split(/\s+/).filter(function(w) { return w.length > 0; });
        for (var i = 0; i < allRows.length; i++) {
            if (allRows[i].id !== surfaceId) continue;
            var tokens = allRows[i].tokens;
            if (!tokens) return {};
            var best = { target: "", fieldLabel: "", tier: 0 };
            for (var wi = 0; wi < words.length; wi++) {
                for (var ti = 0; ti < tokens.length; ti++) {
                    var t = tokens[ti];
                    var tl = t.label.toLowerCase();
                    var s = tl === words[wi] ? 3 : (tl.indexOf(words[wi]) === 0 ? 2 : (tl.indexOf(words[wi]) >= 0 ? 1 : 0));
                    if (s > best.tier) {
                        best = { target: t.target || "", fieldLabel: t.fieldLabel || "", tier: s };
                    }
                }
            }
            return best;
        }
        return {};
    }

    // ── Row activation ──────────────────────────────────────────────────────

    function _doActivate(surfaceId) {
        var bt = _bestToken(surfaceId);
        if (bt.target.length > 0) {
            Flags.searchFocusTarget = "";
            root.requestSurface(bt.target);
        } else {
            Flags.searchFocusTarget = bt.fieldLabel;
            root.requestSurface(surfaceId);
        }
    }

    function activateRow(item) {
        var idx = rowIndexOf(item);
        if (idx < 0) return;
        kbIndex = idx;
        focusRowItem = item;
        var r = rows[idx];
        _doActivate(r.surface);
    }

    function kbActivate() {
        if (kbIndex < 0) return;
        var r = rows[kbIndex];
        if (r.kind === "toggle") {
            r.set(!r.get());
        } else if (r.kind === "nav") {
            _doActivate(r.surface);
        }
    }

    /** Override kbMove to skip rows not matching the search query. */
    function kbMove(dir) {
        if (rows.length === 0) return;
        var start = kbIndex < 0 ? (dir > 0 ? -1 : rows.length) : kbIndex;
        var next = start;
        var attempts = 0;
        while (attempts < rows.length) {
            next += dir;
            if (next < 0) next = rows.length - 1;
            else if (next >= rows.length) next = 0;
            if (searchQuery.length === 0) {
                kbIndex = next;
                focusRowItem = rows[next].item;
                return;
            }
            var r = rows[next];
            var rowData = null;
            for (var i = 0; i < allRows.length; i++) {
                if (allRows[i].id === r.surface) { rowData = allRows[i]; break; }
            }
            if (rowData && matchesQuery(rowData.name, rowData.sub, rowData.tokens)) {
                kbIndex = next;
                focusRowItem = rows[next].item;
                return;
            }
            attempts++;
        }
    }

    // ── UI ──────────────────────────────────────────────────────────────────

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "設"
            title: "SETTINGS"
        }

        // ── Search field ────────────────────────────────────────────────────

        Item {
            width: parent.width
            height: 30 * root.s

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2 * root.s
                anchors.bottomMargin: 2 * root.s
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                radius: 8 * root.s
                color: field.activeFocus ? Theme.frameBg : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            TextField {
                id: field
                anchors.fill: parent
                anchors.topMargin: 2 * root.s
                anchors.bottomMargin: 2 * root.s
                anchors.leftMargin: 16 * root.s
                anchors.rightMargin: 12 * root.s
                background: null
                padding: 0
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                placeholderText: "Search settings…"
                placeholderTextColor: Theme.faint
                selectByMouse: true
                selectionColor: Theme.verm
                cursorDelegate: Item {}
                onTextChanged: root.searchQuery = text
                Keys.onEscapePressed: {
                    text = "";
                    root.searchQuery = "";
                    focus = false;
                }
                Keys.onUpPressed: root.kbMove(-1)
                Keys.onDownPressed: root.kbMove(1)
                Keys.onReturnPressed: {
                    if (root.kbIndex < 0) root.kbMove(1);
                    root.kbActivate();
                }
                Keys.onPressed: function(e) {
                    if (e.modifiers & Qt.ControlModifier) {
                        switch (e.key) {
                        case Qt.Key_J:
                        case Qt.Key_Down:
                            root.kbMove(1);
                            e.accepted = true;
                            break;
                        case Qt.Key_K:
                        case Qt.Key_Up:
                            root.kbMove(-1);
                            e.accepted = true;
                            break;
                        case Qt.Key_L:
                        case Qt.Key_Right:
                            if (root.kbIndex < 0) root.kbMove(1);
                            root.kbActivate();
                            e.accepted = true;
                            break;
                        }
                    }
                }
            }
        }

        // ── No results indicator ────────────────────────────────────────────

        Item {
            width: parent.width
            height: root.searchQuery.length > 0 && !root.groupVisible(root.shellRows) && !root.groupVisible(root.controlRows) ? 60 * root.s : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: "No matching settings"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }
        }

        // ── Shell group ─────────────────────────────────────────────────────

        Text {
            topPadding: 16 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Shell"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
            visible: root.searchQuery.length === 0 && root.groupVisible(root.shellRows)
        }

        SettingsRow {
            id: appearanceRow
            surface: root
            captionOnFocus: true
            icon: "sparkles"
            name: root.searchName("appearance", "Appearance")
            sub: "Clock, glyphs, accent palette"
            visible: root.matchesQuery(name, sub, root.appearanceTokens)

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appearanceRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: lookRow
            surface: root
            captionOnFocus: true
            icon: "app-window"
            name: root.searchName("look", "Look")
            sub: "Gaps, rounding, blur, opacity"
            visible: root.matchesQuery(name, sub, root.lookTokens)

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === lookRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: scrollRow
            surface: root
            captionOnFocus: true
            icon: "cog"
            name: root.searchName("scroll", "Scroll")
            sub: "Display, input, animation, keybinds"
            visible: root.matchesQuery(name, sub, root.scrollTokens)

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === scrollRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        // ── Control group ───────────────────────────────────────────────────

        Text {
            topPadding: 16 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Control"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
            visible: root.searchQuery.length === 0 && root.groupVisible(root.controlRows)
        }

        SettingsRow {
            id: idleRow
            surface: root
            captionOnFocus: true
            icon: "lock"
            name: root.searchName("idlelock", "Idle / Lock")
            sub: "Auto-lock, screen off, suspend"
            visible: root.matchesQuery(name, sub, root.idleTokens)

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === idleRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: powerProfileRow
            surface: root
            captionOnFocus: true
            icon: "bolt"
            name: root.searchName("powerprofiles", "Power Profiles")
            sub: "Auto-switch on AC / battery"
            visible: root.matchesQuery(name, sub, root.powerProfileTokens)

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === powerProfileRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: powerKeysRow
            surface: root
            captionOnFocus: true
            icon: "keyboard"
            name: root.searchName("powerkeys", "Power Keys")
            sub: "Shortcut letters for power actions"
            visible: root.matchesQuery(name, sub, root.powerKeysTokens)

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === powerKeysRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: updatesRow
            surface: root
            captionOnFocus: true
            icon: "download"
            name: root.searchName("updates", "Updates")
            sub: "Version and check for updates"
            last: true
            visible: root.matchesQuery(name, sub, root.updatesTokens)

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === updatesRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }
    }
}
