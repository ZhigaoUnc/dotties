import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Singletons"

PillSurface {
    id: root

    mTop: 13
    mLeft: 14
    mRight: 14
    mBottom: 12

    implicitHeight: Math.min(Math.max(160 * root.s, 24 * root.s + 10 * root.s + root.appStreams.length * 46 * root.s + 12 * root.s), 380 * root.s)

    readonly property var sink: Pipewire.defaultAudioSink

    readonly property var appStreams: {
        void Pipewire.nodes.values;
        var out = [];
        var all = Pipewire.nodes.values;
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.audio && n.isStream)
                out.push(n);
        }
        out.sort((a, b) => root.appLabel(a).localeCompare(root.appLabel(b)));
        return out;
    }

    function appLabel(node) {
        if (!node) return "";
        return node.properties["application.name"]
            || node.properties["media.name"]
            || node.properties["node.name"]
            || node.name
            || "Unknown";
    }

    function appMedia(node) {
        if (!node) return "";
        var app = node.properties["application.name"];
        var media = node.properties["media.name"];
        if (media && media !== app)
            return media;
        return "";
    }

    function volPct(v) {
        return Math.round(Math.max(0, Math.min(1.5, v || 0)) * 100) + "%";
    }

    property int focusIndex: -1

    readonly property var faders: {
        void streamList.contentItem;
        var out = [];
        for (var i = 0; i < streamList.count; i++) {
            var item = streamList.itemAtIndex(i);
            if (item && item.fader)
                out.push(item.fader);
        }
        return out;
    }

    readonly property bool surfaceHovered: hoverTracker.hovered

    readonly property int hoverIndex: surfaceHovered && faders.length > 0
        && hoverTracker.point.position.y >= divider.y + divider.height
        ? Math.max(0, Math.min(faders.length - 1,
            Math.floor((hoverTracker.point.position.y - (divider.y + divider.height + 10 * root.s)) / (46 * root.s))))
        : -1

    onHoverIndexChanged: if (hoverIndex >= 0 && !keyLatch.running) focusIndex = hoverIndex

    HoverHandler { id: hoverTracker }

    Timer {
        id: keyLatch
        interval: Motion.standard
    }

    onActiveChanged: {
        focusIndex = active && appStreams.length > 0 ? 0 : -1;
    }

    function stepFocused(deltaPct) {
        if (focusIndex < 0 || focusIndex >= faders.length) return false;
        faders[focusIndex].step(deltaPct);
        keyLatch.restart();
        return true;
    }

    function moveFocus(dir) {
        if (faders.length === 0) return;
        focusIndex = focusIndex < 0 ? (dir > 0 ? 0 : faders.length - 1)
                                    : (focusIndex + dir + faders.length) % faders.length;
        keyLatch.restart();
    }

    Item {
        id: header
        z: 5
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                text: "音"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "APP VOLUMES"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Text {
        id: emptyMsg
        anchors.top: divider.bottom
        anchors.topMargin: 30 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        text: "No application streams detected.\nPlay some audio and try again."
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10 * root.s
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: root.appStreams.length === 0
    }

    ListView {
        id: streamList
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        flickableDirection: Flickable.VerticalFlick
        visible: root.appStreams.length > 0

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4 * root.s
        }

        model: root.appStreams

        delegate: Item {
            id: streamRow
            required property var modelData
            required property int index
            readonly property var fader: rowFader
            width: parent.width
            height: 46 * root.s

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8 * root.s
                anchors.rightMargin: 8 * root.s
                height: 36 * root.s
                radius: 9 * root.s
                color: rowHover.hovered ? Theme.frameBg : "transparent"
            }

            HoverHandler { id: rowHover }

            GlyphIcon {
                id: streamIcon
                anchors.left: parent.left
                anchors.leftMargin: 14 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 18 * root.s
                height: 18 * root.s
                name: modelData.audio.muted ? "speaker-off" : "speaker"
                color: modelData.audio.muted ? Theme.faint : Theme.subtle
                stroke: 1.7
            }

            Item {
                id: labelCol
                anchors.left: streamIcon.right
                anchors.leftMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 110 * root.s
                height: 30 * root.s

                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: root.appLabel(modelData)
                    color: modelData.audio.muted ? Theme.dim : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: {
                        var sub = root.appMedia(modelData);
                        if (sub) return sub;
                        return modelData.audio.muted ? "MUTED" : root.volPct(modelData.audio.volume);
                    }
                    color: modelData.audio.muted ? Theme.vermBurn : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8 * root.s
                    font.weight: modelData.audio.muted ? Font.Bold : Font.Medium
                    elide: Text.ElideRight
                }
            }

            HFader {
                id: rowFader
                anchors.left: labelCol.right
                anchors.leftMargin: 6 * root.s
                anchors.right: muteBtn.left
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                maxValue: 1.5
                value: modelData.audio.volume
                on: !modelData.audio.muted
                focused: root.focusIndex === index
                onMoved: (v) => {
                    if (modelData.audio.muted)
                        modelData.audio.muted = false;
                    modelData.audio.volume = v;
                }
                onCommitted: (v) => {
                    if (modelData.audio.muted)
                        modelData.audio.muted = false;
                    modelData.audio.volume = v;
                }
                onFocusRequested: root.focusIndex = index
            }

            Rectangle {
                id: muteBtn
                anchors.right: parent.right
                anchors.rightMargin: 14 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * root.s
                height: 26 * root.s
                radius: 8 * root.s
                color: muteArea.containsMouse ? Theme.frameBg : "transparent"
                border.width: 1
                border.color: modelData.audio.muted ? Theme.vermBurn : Theme.border

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 14 * root.s
                    height: 14 * root.s
                    name: modelData.audio.muted ? "mic-off" : "speaker"
                    color: modelData.audio.muted ? Theme.vermBurn : Theme.iconDim
                    stroke: 1.7
                }

                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.audio.muted = !modelData.audio.muted
                }
            }
        }
    }

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0 && root.stepFocused(notches * 5))
                acc -= notches;
            event.accepted = true;
        }
    }

    PwObjectTracker {
        objects: root.appStreams.filter(Boolean)
    }
}
