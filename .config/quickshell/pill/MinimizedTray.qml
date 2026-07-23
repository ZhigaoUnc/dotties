pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import "Singletons"

Row {
    id: root

    property real s: 1
    property string screenName: ""
    spacing: 8 * s

    function restoreWorkspace() {
        var ms = I3.monitors.values;
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName && ms[i].activeWorkspace)
                return ms[i].activeWorkspace.num;
        return I3.focusedWorkspace ? I3.focusedWorkspace.num : 1;
    }

    readonly property var items: {
        var out = [];
        var tl = ToplevelManager.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            if (t && t.minimized)
                out.push(t);
        }
        return out;
    }
    readonly property int count: items.length

    function iconFor(t) {
        var cls = t.appId ? t.appId : "";
        if (!cls)
            return "";
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === cls.toLowerCase() && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
        }
        return Quickshell.iconPath(cls, "application-x-executable");
    }

    Repeater {
        model: root.items

        delegate: Item {
            id: chip
            required property var modelData
            width: 18 * root.s
            height: 18 * root.s

            readonly property string iconSrc: root.iconFor(chip.modelData)

            Image {
                anchors.fill: parent
                sourceSize.width: Math.round(36 * root.s)
                sourceSize.height: Math.round(36 * root.s)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                source: chip.iconSrc
                opacity: area.containsMouse ? 1 : 0.78
                Behavior on opacity { NumberAnimation { duration: 110 } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -3 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var ws = root.restoreWorkspace();
                    I3.dispatch('move window to workspace number ' + ws + '; workspace ' + ws);
                }
            }
        }
    }
}
