pragma ComponentBehavior: Bound

import QtQuick

/**
 * Shared base for the morphing settings surfaces: the category index and each
 * sub-surface. Carries the keyboard-navigable row registry and the glowing
 * row-soul seam, and morphs back to the parent index when empty space is clicked
 * on a sub-surface. The deriving surface sets `rows`, optionally `backSurface`,
 * and lays out its own content column (header, section labels, SettingsRow lines).
 *
 * Each `rows` entry pairs a row item with its control kind and the backing getter
 * and setter: `seg` steps a segmented choice, `toggle` flips a boolean, `nav`
 * morphs to another surface. The host routes arrow keys through `kbMove`,
 * `kbAdjust` and `kbActivate`; hover and clicks route through `reportRowHover`
 * and `activateRow`, keeping `kbIndex` and the seam in sync.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    property string backSurface: ""
    signal requestSurface(string name)

    property Item focusRowItem: null
    property int kbIndex: -1
    property var rows: []

    function reportRowHover(item, hovered) {
        if (hovered) {
            focusRowItem = item;
            kbIndex = rowIndexOf(item);
        }
    }
    onActiveChanged: if (!active) {
        focusRowItem = null;
        kbIndex = -1;
        cancelEasyMotion();
    }

    function rowIndexOf(item) {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].item === item)
                return i;
        return -1;
    }

    function kbMove(dir) {
        if (rows.length === 0)
            return;
        kbIndex = Math.max(0, Math.min(rows.length - 1, (kbIndex < 0 ? 0 : kbIndex + dir)));
        focusRowItem = rows[kbIndex].item;
    }

    function kbAdjust(dir) {
        if (rows.length === 0)
            return;
        if (kbIndex < 0) {
            kbIndex = 0;
            focusRowItem = rows[0].item;
        }
        var r = rows[kbIndex];
        if (r.kind === "seg") {
            var i = r.vals.indexOf(r.get());
            r.set(r.vals[Math.max(0, Math.min(r.vals.length - 1, (i < 0 ? 0 : i) + dir))]);
        } else if (r.kind === "toggle") {
            r.set(dir > 0);
        }
    }

    function kbActivate() {
        if (rows.length === 0 || kbIndex < 0)
            return;
        var r = rows[kbIndex];
        if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
    }

    /**
     * A click anywhere on a row drives its control: toggles flip, nav rows open
     * their surface, and segmented rows step to the next value (wrapping). The
     * control's own hit areas stay on top, so clicking a specific segment still
     * picks it directly.
     */
    function activateRow(item) {
        var idx = rowIndexOf(item);
        if (idx < 0)
            return;
        kbIndex = idx;
        focusRowItem = item;
        var r = rows[idx];
        if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
        else if (r.kind === "seg") {
            var i = r.vals.indexOf(r.get());
            r.set(r.vals[((i < 0 ? 0 : i) + 1) % r.vals.length]);
        }
    }

    // --- Easy motion jump navigation ---
    property bool easyMotionActive: false
    property var easyMotionRows: []
    property string easyMotionBuffer: ""

    function beginEasyMotion() {
        var keys = ["a","s","d","f","g","h","j","k","l","q","w","e","r","t","y","u","i","o","p","z","x","c","v","b","n","m"];
        var visible = [];
        for (var i = 0; i < rows.length; i++) {
            var ri = rows[i].item;
            if (ri && ri.visible !== false && !ri.collapsed)
                visible.push({ row: rows[i], index: i });
        }
        if (visible.length === 0 || visible.length > keys.length)
            return;
        for (var vi = 0; vi < visible.length; vi++) {
            visible[vi].label = keys[vi];
            visible[vi].row.item.easyMotionLabel = keys[vi];
        }
        easyMotionRows = visible;
        easyMotionActive = true;
        easyMotionBuffer = "";
    }

    function easyMotionKey(text) {
        if (!easyMotionActive)
            return false;
        for (var i = 0; i < easyMotionRows.length; i++) {
            if (easyMotionRows[i].label === text) {
                kbIndex = easyMotionRows[i].index;
                focusRowItem = rows[kbIndex].item;
                cancelEasyMotion();
                return true;
            }
        }
        cancelEasyMotion();
        return false;
    }

    function cancelEasyMotion() {
        easyMotionActive = false;
        for (var i = 0; i < easyMotionRows.length; i++)
            easyMotionRows[i].row.item.easyMotionLabel = "";
        easyMotionRows = [];
        easyMotionBuffer = "";
    }

    readonly property bool rowFocused: focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void root.focusRowItem;
        if (!focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * root.s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint
}
