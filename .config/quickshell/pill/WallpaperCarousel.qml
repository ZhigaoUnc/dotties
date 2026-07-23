pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import "Singletons"

PanelWindow {
    id: wallpaper

    required property var modelData

    signal dismissed()
    signal pickColorRequested()

    property alias showing: wallpaper.visible
    property bool ready: false
    property var enriched: []
    property var filtered: []
    property string query: ""
    property int selected: 0
    property real continuousPos: 0
    property real smoothPos: 0
    property string currentWall: ""
    property int thumbVersion: 0
    property bool _skipInitialAnim: true
    property bool searching: false

    Behavior on smoothPos {
        NumberAnimation { duration: _skipInitialAnim ? 0 : Motion.shapeshift; easing.type: Easing.OutExpo }
    }
    onContinuousPosChanged: smoothPos = continuousPos

    property real cardW: Math.min(screen ? screen.width * 0.46 : 680, 860)
    property real cardH: Math.round(cardW / 1.6)
    property real angleStep: 38

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallpaper-carousel"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function wrapIdx(idx) {
        if (filtered.length === 0) return 0
        var wrapped = idx % filtered.length
        if (wrapped < 0) wrapped += filtered.length
        return wrapped
    }

    function cyclicDist(idx, pos) {
        var len = filtered.length
        if (len === 0) return idx
        var raw = idx - pos
        var wrapped = ((raw % len) + len) % len
        if (wrapped > len / 2) return wrapped - len
        return wrapped
    }

    function move(dir) {
        if (filtered.length === 0) return
        if (searching) {
            selected = Math.max(0, Math.min(filtered.length - 1, selected + dir))
            continuousPos = selected
        } else {
            selected = wrapIdx(selected + dir)
            continuousPos += dir
        }
    }

    function jumpTo(idx) {
        var len = filtered.length
        if (len === 0) { selected = 0; continuousPos = 0; return }
        selected = idx
        if (searching) {
            continuousPos = idx
        } else {
            var cycle = Math.round((smoothPos - idx) / len)
            continuousPos = idx + cycle * len
        }
    }

    onShowingChanged: {
        if (showing) {
            query            = ""
            selected         = 0
            continuousPos    = 0
            smoothPos        = 0
            keyInput.text    = ""
            _skipInitialAnim = true
            searching        = false
            ready            = false
            buildEnriched()
            currentWall      = Walls.current
            finishInit()
        } else {
            ready     = false
            searching = false
        }
    }

    function finishInit() {
        ready = true
        selectCurrentWall()
        Qt.callLater(() => { _skipInitialAnim = false })
        Qt.callLater(() => { keyInput.forceActiveFocus() })
    }

    function buildEnriched() {
        var entries = Walls.entries
        var result = []
        for (var i = 0; i < entries.length; i++) {
            var lower = entries[i].name.toLowerCase()
            result.push({
                name: entries[i].name,
                path: entries[i].path,
                thumb: entries[i].thumb,
                isVideo: lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv"),
                isGif: lower.endsWith(".gif")
            })
        }
        enriched = result
        filtered = result.slice()
        thumbVersion++
    }

    Connections {
        target: Walls
        function onEntriesChanged() {
            if (showing) {
                buildEnriched()
                selectCurrentWall()
            }
        }
        function onCurrentChanged() {
            currentWall = Walls.current
            if (showing && filtered.length > 0)
                selectCurrentWall()
        }
    }

    function filterWalls(preserve) {
        var prevName = preserve && selected < filtered.length ? filtered[selected].name : ""
        var result   = enriched.slice()
        if (query !== "") {
            var q = query.toLowerCase()
            result = result.filter(function(w) { return w.name.toLowerCase().includes(q) })
            result.sort(function(a, b) {
                var ai = a.name.toLowerCase().indexOf(q)
                var bi = b.name.toLowerCase().indexOf(q)
                if (ai !== bi) return ai - bi
                return a.name.length - b.name.length
            })
        }
        var snap = _skipInitialAnim
        _skipInitialAnim = true
        filtered = result
        if (prevName) {
            for (var i = 0; i < result.length; i++) {
                if (result[i].name === prevName) {
                    selected = i
                    continuousPos = i
                    smoothPos = i
                    _skipInitialAnim = snap
                    return
                }
            }
        }
        selected = 0
        continuousPos = 0
        smoothPos = 0
        _skipInitialAnim = snap
    }

    function selectCurrentWall() {
        if (filtered.length === 0) return
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].path === currentWall) { selected = i; continuousPos = i; return }
        }
    }

    function applyWallpaper(wall) {
        if (!wall) return
        Walls.apply(wall.path)
        currentWall = wall.path
    }

    function prettyName(name) {
        var dot = name.lastIndexOf(".")
        var n   = dot > 0 ? name.substring(0, dot) : name
        return n.replace(/[-_]/g, " ")
    }

    function pickRandom() {
        if (filtered.length < 2) return
        var idx = selected
        while (idx === selected)
            idx = Math.floor(Math.random() * filtered.length)
        jumpTo(idx)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: wallpaper.dismissed()
    }

    TextInput {
        id: keyInput
        visible: false
        color: Theme.cream
        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
        selectByMouse: true
        readOnly: !searching

        onTextChanged: {
            query = text.toLowerCase()
            filterWalls()
        }

        function exitSearch(apply) {
            if (apply && filtered.length > 0) applyWallpaper(filtered[selected])
            keyInput.text = ""
            query = ""
            searching = false
            selectCurrentWall()
        }

        Keys.onPressed: function(event) {
            if (searching) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    exitSearch(true)
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    exitSearch(false)
                    event.accepted = true
                } else if (event.key === Qt.Key_Left) {
                    move(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    move(1)
                    event.accepted = true
                }
            } else {
                if (event.key === Qt.Key_Slash) {
                    text = ""
                    query = ""
                    searching = true
                    event.accepted = true
                } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                    move(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                    move(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Home) {
                    jumpTo(0)
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    jumpTo(Math.max(0, filtered.length - 1))
                    event.accepted = true
                } else if (event.key === Qt.Key_PageUp) {
                    for (var pi = 0; pi < 5; pi++) move(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageDown) {
                    for (var pi = 0; pi < 5; pi++) move(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & Qt.ControlModifier)
                        pickColorRequested()
                    else if (filtered.length > 0)
                        applyWallpaper(filtered[selected])
                    event.accepted = true
                } else if (event.key === Qt.Key_R) {
                    pickRandom()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    if (query !== "") {
                        keyInput.text = ""
                        query = ""
                        filterWalls()
                    } else {
                        wallpaper.dismissed()
                    }
                    event.accepted = true
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: ready ? 1 : 0
        scale:   ready ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Motion.shapeshift; easing.type: Easing.OutBack }
        }

        Item {
            id: sceneRoot
            anchors.centerIn: parent
            width:  parent.width
            height: cardH
            clip:   true

            function slotX(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return sceneRoot.width / 2 - cardW / 2 + Math.sin(rad) * (cardW * 0.82)
            }

            function slotAngle(offset) {
                return offset * angleStep
            }

            function slotScale(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return Math.max(0.35, 0.5 + 0.5 * Math.cos(rad))
            }

            function slotOpacity(offset) {
                var dist = Math.abs(offset)
                if (dist < 0.5)  return 1.0
                if (dist < 1.5)  return 1.0  - (dist - 0.5) * 0.25
                if (dist < 2.5)  return 0.75 - (dist - 1.5) * 0.30
                if (dist < 3.0)  return 0.45 * (3.0 - dist) / 0.5
                return 0.0
            }

            function slotRadius(absOff) {
                return 14
            }

            function slotBright(absOff) {
                return Math.max(0.22, 1.0 - absOff * 0.2)
            }

            function slotSat(absOff) {
                return Math.max(0.4, 1.0 - absOff * 0.15)
            }

            Repeater {
                model: filtered

                Item {
                    id: slotItem
                    required property int index
                    required property var modelData

                    property real offset:    searching ? index - smoothPos : wallpaper.cyclicDist(index, smoothPos)
                    property real absOffset: Math.abs(offset)
                    property bool isCenter:  index === selected
                    property bool _committing: trashHeat.hold >= trashHeat.tapThreshold
                    property real _commitProgress: Math.max(0, (trashHeat.hold - trashHeat.tapThreshold) / (1 - trashHeat.tapThreshold))

                    width:  cardW
                    height: cardH
                    x:      sceneRoot.slotX(offset)
                    y:      0
                    scale:  sceneRoot.slotScale(offset)
                    opacity: sceneRoot.slotOpacity(offset)
                    visible: absOffset < 3.0
                    z:      isCenter ? 999 : Math.round((1.0 - Math.min(absOffset, 2.0) / 2.0) * 100)

                    transform: Rotation {
                        origin.x: cardW / 2
                        origin.y: cardH / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: sceneRoot.slotAngle(slotItem.offset)
                    }

                    ClippingRectangle {
                        id: cardBg
                        anchors.fill: parent
                        radius: sceneRoot.slotRadius(absOffset)
                        color:  Theme.tileBg
                        clip:   true

                        property bool isGif:   slotItem.isCenter && modelData.isGif
                        property bool isVideo: slotItem.isCenter && modelData.isVideo

                        Image {
                            anchors.fill: parent
                            source: slotItem.isCenter && !cardBg.isGif && !cardBg.isVideo
                                ? "file://" + modelData.thumb
                                : (!slotItem.isCenter ? "file://" + modelData.thumb : "")
                            onStatusChanged: {
                                if (status === Image.Error && slotItem.isCenter)
                                    source = "file://" + modelData.path
                            }
                            fillMode: slotItem.isCenter ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            sourceSize.width: slotItem.isCenter ? 1920 : 400
                            asynchronous: true
                            cache: true
                            visible: !cardBg.isGif && !cardBg.isVideo
                        }

                        Loader {
                            anchors.fill: parent
                            active: cardBg.isGif
                            sourceComponent: AnimatedImage {
                                anchors.fill: parent
                                source: "file://" + slotItem.modelData.path
                                fillMode: Image.PreserveAspectFit
                                playing: true
                                asynchronous: true
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: cardBg.isVideo
                            sourceComponent: Item {
                                anchors.fill: parent
                                MediaPlayer {
                                    id: slotVid
                                    source: "file://" + slotItem.modelData.path
                                    loops: MediaPlayer.Infinite
                                    audioOutput: AudioOutput { muted: true }
                                    videoOutput: slotVidOut
                                    Component.onCompleted: play()
                                }
                                VideoOutput {
                                    id: slotVidOut
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectFit
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 1)
                            opacity: 1 - sceneRoot.slotBright(slotItem.absOffset)
                            Behavior on opacity { NumberAnimation { duration: Motion.standard } }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: cardBg.height * slotItem._commitProgress
                            visible: slotItem._committing
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.alpha(Theme.vermBurn, 0.66) }
                                GradientStop { position: 0.74; color: Qt.alpha(Theme.vermLit, 0.30) }
                                GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 2
                                opacity: Math.min(1, slotItem._commitProgress * 3)
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                                    GradientStop { position: 0.5; color: Theme.flameGlow }
                                    GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                                }
                            }
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            saturation: sceneRoot.slotSat(slotItem.absOffset) - 1
                            shadowEnabled: slotItem.isCenter
                            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
                            shadowBlur: 0.7
                            shadowVerticalOffset: 4
                        }
                    }

                    HeatHold {
                        id: trashHeat
                        tapThreshold: 0.25
                        duration: Motion.heat * 1.4
                        enabled: slotItem.isCenter
                        onConfirmed: {
                            if (slotItem.isCenter)
                                Walls.trash(slotItem.modelData.path)
                        }
                        onTapped: {
                            if (slotItem.isCenter)
                                applyWallpaper(slotItem.modelData)
                        }
                    }

                    Item {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 56
                        visible: slotItem.isCenter
                        opacity: slotItem.isCenter ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                            }
                        }

                        Row {
                            anchors { left: parent.left; bottom: parent.bottom }
                            anchors { leftMargin: 18; bottomMargin: 14 }
                            spacing: 10

                            Text {
                                text:  prettyName(slotItem.modelData.name)
                                color: "#fff"
                                font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                                Text {
                                    visible: slotItem.modelData.path === currentWall
                                    text:    "●"
                                    color:   Theme.vermLit
                                    font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: slotItem.isCenter
                        cursorShape: slotItem.isCenter ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onPressed: {
                            if (slotItem.isCenter)
                                trashHeat.press()
                        }
                        onReleased: {
                            if (slotItem.isCenter)
                                trashHeat.release()
                        }
                        onExited: trashHeat.cancel()
                        onClicked: {
                            if (!slotItem.isCenter) {
                                jumpTo(slotItem.index)
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                z: -999
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0)
                        move(-1)
                    else
                        move(1)
                }
            }
        }

        Rectangle {
            id: emptyCard
            anchors.centerIn: sceneRoot
            width:  cardW
            height: cardH
            radius: 10
            color:  Qt.rgba(0, 0, 0, 0.85)
            border.width: 1
            border.color: Theme.border
            visible: ready && filtered.length === 0
            opacity: visible ? 1 : 0
            scale:   visible ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: Motion.shapeshift;   easing.type: Easing.OutBack } }
            Behavior on radius  { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
            Behavior on color   { ColorAnimation  { duration: Motion.shapeshift } }

            Column {
                anchors.centerIn: parent
                spacing: 18

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  enriched.length === 0 ? "Scanning wallpapers" : "No results"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: query !== ""
                    text:    "\"" + query + "\""
                    color:   Qt.rgba(1, 1, 1, 0.2)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                }
            }
        }

        Rectangle {
            id: searchBar
            anchors {
                top:              sceneRoot.bottom
                topMargin:        24
                horizontalCenter: parent.horizontalCenter
            }
            width:  200
            height: 34
            radius: 6
            color:  Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
            border.color: searching ? Qt.rgba(Theme.flameGlow.r, Theme.flameGlow.g, Theme.flameGlow.b, 0.3) : Qt.rgba(1, 1, 1, 0.05)
            opacity: ready ? 1 : 0
            scale:   ready ? 1 : 0.95

            Behavior on border.color { ColorAnimation  { duration: Motion.fast } }
            Behavior on radius       { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
            Behavior on scale        { NumberAnimation { duration: Motion.shapeshift;   easing.type: Easing.OutBack } }

            Row {
                anchors.fill: parent
                anchors.leftMargin:  11
                anchors.rightMargin: 11
                spacing: 8

                Text {
                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyInput.text || (searching ? "" : "/ search")
                    color: keyInput.text ? Theme.cream : Qt.rgba(1, 1, 1, 0.25)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    elide: Text.ElideRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:    "×"
                    color:   clrMa.containsMouse ? Theme.cream : Qt.rgba(1, 1, 1, 0.3)
                    font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                    visible: keyInput.text.length > 0
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    MouseArea {
                        id: clrMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { keyInput.text = ""; keyInput.forceActiveFocus() }
                    }
                }
            }

            MouseArea {
                id: searchMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    if (!searching) { searching = true; keyInput.text = ""; query = "" }
                    keyInput.forceActiveFocus()
                }
            }
        }
    }
}
