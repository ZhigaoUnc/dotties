//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.I3
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "Singletons"

/**
 * Washi pill top shell. Each monitor carries two layer-shell windows:
 *
 *  - `reserve` is a zero-content strip that only claims an exclusive zone the
 *    height of the rest pill, so tiled windows always sit below the pill even
 *    while it is expanded or a surface is open.
 *  - `overlay` is a full-screen transparent Overlay layer hosting the single
 *    morphing pill anchored at top-centre. The pill never moves windows and is
 *    never re-parented; it just grows in place, so every surface grows out of
 *    the rest pill instead of popping up as a separate panel.
 *
 * Input is routed by the window mask. While the pill is collapsed the mask is
 * the pill rect only, so the rest of the screen clicks through to windows.
 * While the pill is expanded (hovered/pinned) or a surface is open the mask is
 * cleared so the whole layer catches clicks. A backdrop press dismisses, and
 * keyboard focus is taken on demand so Escape closes the open surface.
 */
ShellRoot {
    id: root

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""

    property Toplevel activeToplevel: ToplevelManager.activeToplevel
    readonly property bool anyFullscreen: activeToplevel ? activeToplevel.fullscreen : false
    property bool carouselOpen: false

    function refresh() {
        I3.refreshMonitors();
        I3.refreshWorkspaces();
    }

    Component.onCompleted: {
        refresh();
        Devices.restore();
    }

    /**
     * After an update relaunches the shell, raise a one-shot toast naming what
     * landed, so the apply ends in a confirmation instead of a silent restart. The
     * updater drops the marker just before it restarts; the short delay lets the
     * notification server own the bus before we post to it, and the marker is
     * removed as it is read so the toast only ever fires once.
     */
    Timer {
        interval: 2500
        running: true
        onTriggered: updatedToast.running = true
    }
    Process {
        id: updatedToast
        command: ["sh", "-c",
            "m=\"${XDG_STATE_HOME:-$HOME/.local/state}/dingaling/updated\"; [ -f \"$m\" ] || exit 0; "
            + "b=$(cat \"$m\"); rm -f \"$m\"; "
            + "gdbus call --session --dest org.freedesktop.Notifications "
            + "--object-path /org/freedesktop/Notifications "
            + "--method org.freedesktop.Notifications.Notify "
            + "dingaling 0 '' 'dingaling updated' \"$b\" '[]' '{}' 5000 >/dev/null 2>&1"]
    }

    Process {
        id: colorPickerProc
        command: ["hyprpicker", "-f", "hex"]
        stdout: StdioCollector {
            onStreamFinished: {
                var hex = this.text.trim();
                if (/^#[0-9a-fA-F]{6}$/.test(hex)) {
                    var c = Qt.color(hex);
                    if (c.hslHue >= 0) {
                        Flags.paletteMode = "manual";
                        Flags.manualHue = Math.round(c.hslHue * 359);
                        Flags.manualSat = c.hslSaturation;
                    }
                }
            }
        }
    }

    Binding {
        target: Notifs
        property: "dnd"
        value: Flags.dnd
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "pill-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    /**
     * The Wayland IdleInhibitor above only pauses the compositor's own idle
     * (DPMS); hypridle runs its own timer and never sees it, so the lock still
     * fired with keep-awake on. A logind idle inhibitor is the wire hypridle
     * does respect, so hold one for as long as the flag is set.
     */
    Process {
        running: Flags.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=dingaling",
                  "--why=keep awake", "--mode=block", "sleep", "infinity"]
    }

    Process {
        id: lockProc
        command: [Quickshell.env("HOME") + "/.config/scripts/dingaling/lock"]
    }
    Process {
        id: screenOffProc
        command: ["scrollmsg", "output * power off"]
    }
    Process {
        id: screenOnProc
        command: ["scrollmsg", "output * power on"]
    }
    Process {
        id: suspendProc
        command: ["sh", "-c", "touch /tmp/suspend-fired && systemctl suspend"]
    }

    IdleMonitor {
        id: lockMon
        timeout: Flags.idleLockSec
        enabled: Flags.idleLockSec > 0 && !Flags.keepAwake
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                lockProc.running = true;
                armSuspend();
            } else {
                disarmSuspend();
            }
        }
    }

    IdleMonitor {
        id: screenMon
        timeout: Flags.idleScreenOffSec
        enabled: Flags.idleScreenOffSec > 0 && !Flags.keepAwake
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) screenOffProc.running = true;
            else screenOnProc.running = true;
        }
    }

    IdleMonitor {
        id: suspendFallbackMon
        timeout: Flags.idleSuspendSec
        enabled: Flags.idleLockSec <= 0 && Flags.idleSuspendSec > 0 && !Flags.keepAwake
        respectInhibitors: true
        onIsIdleChanged: {
            console.log("suspendFallback isIdle:", isIdle);
            if (isIdle) suspendProc.running = true;
        }
    }

    Timer {
        id: suspendChain
        repeat: false
        onTriggered: suspendProc.running = true
    }

    function armSuspend() {
        if (Flags.idleSuspendSec <= 0) return;
        var gap = Flags.idleSuspendSec - Flags.idleLockSec;
        if (gap > 0) {
            suspendChain.interval = gap * 1000;
            suspendChain.start();
        } else {
            suspendProc.running = true;
        }
    }

    function disarmSuspend() {
        suspendChain.stop();
    }

    Connections {
        target: Flags
        function onKeepAwakeChanged() {
            if (Flags.keepAwake) {
                disarmSuspend();
                screenOnProc.running = true;
            }
        }
    }

    /**
     * I3/Scroll events that can change what the pill renders (per-monitor
     * active workspace, window state, monitor hotplug).
     */
    readonly property var refreshEvents: ({
        workspace: true,
        window: true,
        output: true
    })

    Connections {
        target: I3
        function onRawEvent(event) {
            if (root.refreshEvents[event.type])
                root.refresh();
        }
    }

    function toggleSurface(mon, surface) {
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.carouselOpen = false;
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
        root.carouselOpen = false;
    }

    function toggleCarousel(mon) {
        if (root.carouselOpen && root.openMon === mon) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.carouselOpen = true;
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    IpcHandler {
        target: "pill"
        function mixer(mon: string): void { root.toggleSurface(mon, "mixer"); }
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
        function power(mon: string): void { root.toggleSurface(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function battery(mon: string): void { root.toggleSurface(mon, "battery"); }
        function settings(mon: string): void { root.toggleSurface(mon, "settings"); }
        function keybinds(mon: string): void { root.toggleSurface(mon, "keybinds"); }
        function recorder(mon: string): void { root.toggleSurface(mon, "recorder"); }
        function screenrec(mon: string): void { root.toggleSurface(mon, "recorder"); }
        function appmixer(mon: string): void { root.toggleSurface(mon, "appmixer"); }
        function record(mon: string): void { root.toggleSurface(mon, "recorder"); }

        /**
         * Quick-record keybind (SUPER+D): one button cycles the whole flow with no
         * surface. Recording → stop. Counting down → cancel. A chooser already up
         * on this monitor → dismiss. Otherwise open the standalone source chooser on
         * the focused monitor `mon`, so only that pill renders it.
         */
        function quickRecord(mon: string): void {
            if (ScreenRec.recording) {
                ScreenRec.stop();
            } else if (ScreenRec.counting) {
                ScreenRec.cancel();
            } else if (ScreenRec.quickChoosing) {
                ScreenRec.quickChoosing = false;
                ScreenRec.quickScreenChoosing = false;
            } else {
                ScreenRec.quickMon = mon;
                ScreenRec.quickScreenChoosing = false;
                ScreenRec.quickChoosing = true;
            }
        }
        function sysmon(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function system(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function wallpaper(mon: string): void {
            if (Flags.wallpaperPicker === "carousel")
                root.toggleCarousel(mon);
            else
                root.toggleSurface(mon, "wallpaper");
        }
        function media(mon: string): void {
            if (Mpris.players.values.length > 0)
                root.toggleSurface(mon, "media");
        }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { Flags.hidePill = !Flags.hidePill; }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserve
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * s
            readonly property real restHeight: 38 * s

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            implicitHeight: restHeight + topGap

            mask: emptyReserve
            Region { id: emptyReserve }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool modal: pill.authPending ? false : (surfaceOpen || pill.held || pill.quickChoosing)

            readonly property bool monFullscreen: root.anyFullscreen

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
                pill.pinned = false;
            }

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: ((surfaceOpen || pill.quickChoosing) && !pill.authPending) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: "pill"

            anchors { top: true; left: true; right: true; bottom: true }

            mask: monFullscreen && !pill.osdActive && !pill.toastActive ? hiddenRegion : (modal ? fullRegion : pillRegion)
            Region { id: hiddenRegion }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                x: pill.x + (pill.width - baseW) / 2
                y: pill.y
                width: baseW + pill.inputPadRight
                height: Math.max(pill.height, pill.targetH)
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    if (pill.quickChoosing) {
                        ScreenRec.quickChoosing = false;
                        ScreenRec.quickScreenChoosing = false;
                    } else if (overlay.surfaceOpen) {
                        var inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                            && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                        if (!inside)
                            root.close();
                        else if (mouse.y <= pillRegion.y + 40 * pill.s)
                            pill.surfaceBack();
                    } else {
                        pill.pinned = false;
                        root.peekMon = "";
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.surfaceOpen || pill.quickChoosing

                readonly property bool textFocused: {
                    try {
                        var fi = focusScope.activeFocusItem;
                        return fi !== null && fi !== undefined
                            && (fi instanceof TextInput || fi instanceof TextEdit);
                    } catch (e) {
                        return false;
                    }
                }

                HoverHandler {
                    onHoveredChanged: pill.hovered = hovered
                }
                Keys.onEscapePressed: {
                    if (focusScope.textFocused) { return; }
                    if (pill.quickChoosing) {
                        ScreenRec.quickChoosing = false;
                        ScreenRec.quickScreenChoosing = false;
                    } else if (!pill.linkBack() && !pill.keybindsBack()) {
                        root.close();
                    }
                }
                Keys.onUpPressed: (e) => {
                    if (focusScope.textFocused) { e.accepted = false; return; }
                    if (pill.keybindsOpen && !pill.keybindsListening) { pill.keybindsMove(-1); e.accepted = true; return; }
                    e.accepted = pill.mixerStep(1) || pill.recorderStep(5) || pill.settingsMove(-1);
                }
                Keys.onDownPressed: (e) => {
                    if (focusScope.textFocused) { e.accepted = false; return; }
                    if (pill.keybindsOpen && !pill.keybindsListening) { pill.keybindsMove(1); e.accepted = true; return; }
                    e.accepted = pill.mixerStep(-1) || pill.recorderStep(-5) || pill.settingsMove(1);
                }
                Keys.onLeftPressed: (e) => {
                    if (focusScope.textFocused) { e.accepted = false; return; }
                    if (pill.mixerOpen) { pill.mixerFocusMove(-1); e.accepted = true; }
                    else if (pill.wallpaperOpen) { pill.wallpaperMove(-1); e.accepted = true; }
                    else if (pill.powerOpen) { pill.powerMove(-1); e.accepted = true; }
                    else if (pill.recorderOpen) { e.accepted = pill.recorderStep(-5); }
                    else if (pill.settingsLike) { pill.settingsAdjust(-1); e.accepted = true; }
                }
                Keys.onRightPressed: (e) => {
                    if (focusScope.textFocused) { e.accepted = false; return; }
                    if (pill.mixerOpen) { pill.mixerFocusMove(1); e.accepted = true; }
                    else if (pill.wallpaperOpen) { pill.wallpaperMove(1); e.accepted = true; }
                    else if (pill.powerOpen) { pill.powerMove(1); e.accepted = true; }
                    else if (pill.recorderOpen) { e.accepted = pill.recorderStep(5); }
                    else if (pill.settingsLike) { pill.settingsAdjust(1); e.accepted = true; }
                }

                /**
                 * Return/Enter/Space: the wallpaper strip applies its focused
                 * thumb on every press; the power surface fires a safe tile on
                 * the first press and, for a destructive tile, holds the heat
                 * fill across autorepeat presses (drained on release). Autorepeat
                 * is swallowed for everything else so a held key never re-fires.
                 */
                Keys.onPressed: (e) => {
                    if (focusScope.textFocused) { e.accepted = false; return; }
                    // Easy motion: Esc cancels, letter keys jump
                    if (pill.easyMotionActive) {
                        if (e.key === Qt.Key_Escape) {
                            pill.cancelEasyMotion();
                            e.accepted = true;
                            return;
                        }
                        if (e.text.length === 1) {
                            var emCh = e.text.toLowerCase();
                            if (emCh >= "a" && emCh <= "z") {
                                var nav = pill.rowNavSurface();
                                if (nav) nav.easyMotionKey(emCh);
                                e.accepted = true;
                                return;
                            }
                        }
                    }
                    // Alt+J begins easy motion
                    if (pill.settingsLike && (e.modifiers & Qt.AltModifier) && e.key === Qt.Key_J) {
                        pill.beginEasyMotion();
                        e.accepted = true;
                        return;
                    }
                    if (pill.wallpaperOpen && !pill.wallpaperSearching
                        && e.text.length === 1 && e.text > " ") {
                        pill.wallpaperType(e.text);
                        e.accepted = true;
                        return;
                    }
                    if (pill.powerOpen && !e.isAutoRepeat && e.text.length === 1) {
                        var letter = e.text.toLowerCase();
                        if (letter >= "a" && letter <= "z" && pill.powerKeyAction(letter)) {
                            e.accepted = true;
                            return;
                        }
                    }
                    if (pill.powerkeysOpen && !e.isAutoRepeat && e.key === Qt.Key_Escape) {
                        pill.powerkeysCancelListening();
                        e.accepted = true;
                        return;
                    }
                    if (pill.powerkeysOpen && !e.isAutoRepeat && e.text.length === 1) {
                        var pkLetter = e.text.toLowerCase();
                        if (pkLetter >= "a" && pkLetter <= "z" && pill.powerkeysHandleKey(pkLetter)) {
                            e.accepted = true;
                            return;
                        }
                    }
                    if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space)
                        return;
                    if (pill.wallpaperOpen) {
                        if (!e.isAutoRepeat) {
                            if (e.modifiers & Qt.ControlModifier)
                                colorPickerProc.running = true;
                            else
                                pill.wallpaperActivate();
                        }
                        e.accepted = true;
                    } else if (pill.powerOpen) {
                        if (!e.isAutoRepeat) pill.powerPress();
                        e.accepted = true;
                    } else if (pill.settingsLike) {
                        if (!e.isAutoRepeat) pill.settingsActivate();
                        e.accepted = true;
                    } else if (pill.keybindsOpen && !pill.keybindsListening) {
                        if (!e.isAutoRepeat) pill.keybindsActivate();
                        e.accepted = true;
                    }
                }
                Keys.onReleased: (e) => {
                    if (focusScope.textFocused) { e.accepted = false; return; }
                    if (e.isAutoRepeat)
                        return;
                    if (pill.powerOpen && e.text.length === 1) {
                        var letter = e.text.toLowerCase();
                        if (letter >= "a" && letter <= "z") {
                            pill.powerKeyRelease(letter);
                            e.accepted = true;
                            return;
                        }
                    }
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                        && pill.powerOpen) {
                        pill.powerRelease();
                        e.accepted = true;
                    }
                }

                Pill {
                    id: pill
                    anchors.top: parent.top
                    anchors.topMargin: Flags.notchMode ? 0 : overlay.topGap
                    anchors.horizontalCenter: parent.horizontalCenter
                    s: overlay.s
                    screenName: overlay.modelData.name
                    barWindow: overlay
                    surface: overlay.surface
                    forcePinned: root.peekMon === overlay.modelData.name

                    opacity: overlay.monFullscreen && !pill.osdActive && !pill.toastActive ? 0 : (pill.hidden ? 0 : 1)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: pill.hidden ? 0 : Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                    transform: Translate {
                        y: overlay.monFullscreen && !pill.osdActive && !pill.toastActive ? -(pill.height + overlay.topGap) : 0
                        Behavior on y {
                            NumberAnimation {
                                duration: Motion.morph
                                easing.type: Motion.easeMorph
                                easing.bezierCurve: Motion.morphCurve
                            }
                        }
                    }

                    onRequestSurface: (name) => {
                        if (name === "wallpaper" && Flags.wallpaperPicker === "carousel")
                            root.toggleCarousel(overlay.modelData.name);
                        else
                            root.toggleSurface(overlay.modelData.name, name);
                    }
                    onRequestClose: root.close()
                }

            }

            onSurfaceOpenChanged: if (surfaceOpen) focusScope.forceActiveFocus()

            Connections {
                target: pill
                function onQuickChoosingChanged() {
                    if (pill.quickChoosing)
                        focusScope.forceActiveFocus();
                }
                function onWallpaperSearchingChanged() {
                    if (!pill.wallpaperSearching && overlay.surfaceOpen)
                        focusScope.forceActiveFocus();
                }
                function onKeybindsListeningChanged() {
                    if (!pill.keybindsListening && overlay.surfaceOpen)
                        focusScope.forceActiveFocus();
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        WallpaperCarousel {
            screen: modelData
            showing: Flags.wallpaperPicker === "carousel" && root.carouselOpen && root.openMon === modelData.name
            onDismissed: root.close()
            onPickColorRequested: colorPickerProc.running = true
        }
    }
}
