pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Widgets
import "Singletons"

/**
 * The pill body. One element carries every state. Width/height driven by `state`
 * (rest, hover/pinned, mixer, calendar) with a no-overshoot easing so surfaces
 * grow out of the pill in place. Surfaces are stacked absolutely and cross-fade.
 *
 * Hover comes from a passive HoverHandler, pin from a passive TapHandler, so
 * neither swallows pointer events from the surfaces stacked above: workspace
 * dots, the clock target, tray icons and the mixer faders get their own clicks
 * and drags.
 */
Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var barWindow
    property string surface: ""

    property bool hovered: false
    property bool pinned: false
    property bool forcePinned: false

    readonly property bool held: pinned || forcePinned
    readonly property bool mixerOpen: surface === "mixer"
    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool launcherOpen: surface === "launcher"
    readonly property bool clipboardOpen: surface === "clipboard"
    readonly property bool wallpaperOpen: surface === "wallpaper"
    readonly property bool powerOpen: surface === "power"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool linkOpen: surface === "link"
    readonly property bool batteryOpen: surface === "battery"
    readonly property bool settingsOpen: surface === "settings"
    readonly property bool keybindsOpen: surface === "keybinds"
    readonly property bool recorderOpen: surface === "recorder"
    readonly property bool sysmonOpen: surface === "sysmon"
    readonly property bool appearanceOpen: surface === "appearance"
    readonly property bool updatesOpen: surface === "updates"
    readonly property bool displayOpen: surface === "display"
    readonly property bool inputOpen: surface === "input"
    readonly property bool lookOpen: surface === "look"
    readonly property bool idlelockOpen: surface === "idlelock"
    readonly property bool animationOpen: surface === "animation"
    readonly property bool fontpickerOpen: surface === "fontpicker"
    readonly property bool sizingOpen: surface === "sizing"
    readonly property bool hoverstateOpen: surface === "hoverstate"
    readonly property bool powerprofilesOpen: surface === "powerprofiles"
    readonly property bool powerkeysOpen: surface === "powerkeys"
    readonly property bool scrollOpen: surface === "scroll"
    readonly property bool appmixerOpen: surface === "appmixer"
    readonly property bool settingsLike: settingsOpen || appearanceOpen || updatesOpen || powerprofilesOpen || powerkeysOpen
        || displayOpen || inputOpen || lookOpen || idlelockOpen || animationOpen
        || fontpickerOpen || sizingOpen || hoverstateOpen || scrollOpen
    readonly property bool hasMedia: Mpris.players.values.length > 0

    /**
     * Subview the link surface should land on when next opened. The wifi glance
     * sets "wifi" to drill straight to the network list; the inbox glance and
     * toast set "main". Reset once the surface closes so IPC opens land on main.
     */
    property string linkInitialView: "main"

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null
    readonly property real wifiLevel: (wifiActive && wifiActive.signalStrength) || 0
    readonly property bool surfaceOpen: surface.length > 0

    readonly property var hoverModList: {
        var raw = Flags.hoverModules;
        if (!raw || raw.length < 2) return ["workspaces","clock","weather","minimized","tray","dnd","network","battery","inbox","mixer","sysmon","recorder","wallpaper","settings","power"];
        try { var list = JSON.parse(raw); return list.length > 0 ? list : ["workspaces","clock","weather","minimized","tray","dnd","network","battery","inbox","mixer","sysmon","recorder","wallpaper","settings","power"]; }
        catch(e) { return ["workspaces","clock","weather","minimized","tray","dnd","network","battery","inbox","mixer","sysmon","recorder","wallpaper","settings","power"]; }
    }

    readonly property bool hoverStatusVisible: pill.hoverModList.indexOf("weather") >= 0 || pill.hoverModList.indexOf("minimized") >= 0 || pill.hoverModList.indexOf("tray") >= 0 || pill.hoverModList.indexOf("dnd") >= 0 || pill.hoverModList.indexOf("network") >= 0 || pill.hoverModList.indexOf("battery") >= 0 || pill.hoverModList.indexOf("inbox") >= 0 || pill.hoverModList.indexOf("mixer") >= 0 || pill.hoverModList.indexOf("sysmon") >= 0 || pill.hoverModList.indexOf("recorder") >= 0 || pill.hoverModList.indexOf("wallpaper") >= 0 || pill.hoverModList.indexOf("settings") >= 0 || pill.hoverModList.indexOf("power") >= 0
    readonly property bool hidden: Flags.hidePill && mode === "rest"
    property bool hoverLatch: false
    readonly property bool expanded: surfaceOpen || held || hoverLatch

    /**
     * True while the open surface is waiting on an external auth dialog (the
     * updater's pkexec password prompt). The shell drops its modal grab for this
     * so the polkit window underneath is clickable and typeable, instead of the
     * backdrop swallowing the reach for it and dismissing the whole pill.
     */
    readonly property bool authPending: updatesOpen && updates.applying
    readonly property bool toastActive: Notifs.popups.length > 0
    readonly property bool osdActive: osd.flashing

    /**
     * Quick-record overlays belong only to the focused monitor the keybind
     * targeted, so a single chooser and a single countdown toast appear. The
     * standalone chooser is suppressed while the morphing recorder surface owns the
     * pill; the countdown toast yields to the surface too (the surface shows its
     * own in-bar countdown there).
     */
    readonly property bool quickHere: ScreenRec.quickMon === screenName
    readonly property bool quickChoosing: quickHere && ScreenRec.quickChoosing && !surfaceOpen
    readonly property bool quickCounting: quickHere && ScreenRec.counting && !recorderOpen

    readonly property real restW: 160 * s
    readonly property real restH: 38 * s
    readonly property real hoverScale: Flags.hoverScale
    readonly property real hoverPad: 20 * s * hoverScale
    readonly property real hoverW: hoverRow.implicitWidth * hoverScale + 2 * hoverPad
    readonly property real hoverH: 58 * s * hoverScale
    readonly property real mixerW: 93 * Math.max(4, mixer.faderCount) * s * Flags.surfaceScale
    readonly property real mixerH: 280 * s
    readonly property real calendarW: (calendar.implicitWidth > 0 ? calendar.implicitWidth : 282 * s) + 36 * s
    readonly property real calendarH: calendar.implicitHeight + 32 * s
    readonly property real launcherW: 360 * s
    readonly property real launcherH: 332 * s
    readonly property real clipboardW: 360 * s
    readonly property real clipboardH: 332 * s
    readonly property real wallpaperW: 720 * s
    readonly property real wallpaperH: 172 * s
    readonly property real powerW: 330 * s * Flags.surfaceScale
    readonly property real powerH: 150 * s * Flags.surfaceScale
    readonly property real mediaW: 390 * s
    readonly property real mediaH: 150 * s
    readonly property real batteryW: 316 * s
    readonly property real settingsW: 392 * s * Flags.surfaceScale
    readonly property real keybindsW: 460 * s * Flags.surfaceScale
    readonly property real recorderW: 500 * s
    readonly property real sysmonW: 560 * s
    readonly property real appearanceW: 392 * s * Flags.surfaceScale
    readonly property real updatesW: 360 * s * Flags.surfaceScale
    readonly property real displayW: 392 * s * Flags.surfaceScale
    readonly property real inputW: 392 * s * Flags.surfaceScale
    readonly property real lookW: 392 * s * Flags.surfaceScale
    readonly property real idlelockW: 392 * s * Flags.surfaceScale
    readonly property real animationW: 392 * s * Flags.surfaceScale
    readonly property real fontpickerW: 360 * s * Flags.surfaceScale
    readonly property real sizingW: 392 * s * Flags.surfaceScale
    readonly property real hoverstateW: 392 * s * Flags.surfaceScale
    readonly property real powerprofilesW: 392 * s * Flags.surfaceScale
    readonly property real powerkeysW: 392 * s * Flags.surfaceScale
    readonly property real scrollW: 392 * s * Flags.surfaceScale
    readonly property real appmixerW: 560 * s * Flags.surfaceScale
    readonly property real toastW: 342 * s * Flags.surfaceScale
    readonly property real quickChooseW: 344 * s
    readonly property real quickChooseH: 76 * s
    readonly property real quickCountW: 150 * s
    readonly property real quickCountH: 64 * s
    readonly property real restCorner: 18 * s
    readonly property real openCorner: 22 * s

    /**
     * Single source of truth for every morphing surface, keyed by its `surface`
     * string. Each entry owns the surface's target size (a thunk so the geometry
     * it reads registers as a live dep of targetSize) and the surface item Ame
     * anchors to while it is open (null = Ame falls back to the pill's own hover
     * or wake anchor). `mode`, `targetSize` and `ameSurface` all derive from this,
     * so adding a surface is one entry here plus its child item — no parallel
     * ternary chains to keep in lockstep.
     */
    readonly property var surfaces: ({
        calendar:  { size: () => Qt.size(calendarW, calendarH), ame: calendar },
        launcher:  { size: () => Qt.size(launcherW, launcherH), ame: launcher },
        clipboard: { size: () => Qt.size(clipboardW, clipboardH), ame: clip },
        wallpaper: { size: () => Qt.size(wallpaperW, wallpaperH), ame: null },
        power:     { size: () => Qt.size(powerW, powerH), ame: power },
        media:     { size: () => Qt.size(mediaW, mediaH), ame: media },
        mixer:     { size: () => Qt.size(mixerW, mixerH), ame: mixer },
        link:      { size: () => Qt.size(link.desiredW, link.implicitHeight + 26 * s), ame: link },
        battery:   { size: () => Qt.size(batteryW, battery.implicitHeight + 26 * s), ame: battery },
        settings:  { size: () => Qt.size(settingsW, settings.implicitHeight + 29 * s), ame: settings },
        keybinds:  { size: () => Qt.size(keybindsW, keybinds.implicitHeight + 29 * s), ame: keybinds },
        recorder:  { size: () => Qt.size(recorderW, recorder.implicitHeight + 33 * s), ame: recorder },
        sysmon:    { size: () => Qt.size(sysmonW, sysmon.implicitHeight + 33 * s), ame: sysmon },
        appearance: { size: () => Qt.size(appearanceW, appearance.implicitHeight + 29 * s), ame: appearance },
        updates:    { size: () => Qt.size(updatesW, updates.implicitHeight + 29 * s), ame: updates },
        display:    { size: () => Qt.size(displayW, display.implicitHeight + 29 * s), ame: display },
        input:      { size: () => Qt.size(inputW, input.implicitHeight + 29 * s), ame: input },
        look:       { size: () => Qt.size(lookW, look.implicitHeight + 29 * s), ame: look },
        idlelock:   { size: () => Qt.size(idlelockW, idlelock.implicitHeight + 29 * s), ame: idlelock },
        animation:  { size: () => Qt.size(animationW, animation.implicitHeight + 29 * s), ame: animation },
        fontpicker: { size: () => Qt.size(fontpickerW, fontpicker.implicitHeight + 29 * s), ame: fontpicker },
        sizing:     { size: () => Qt.size(sizingW, sizing.implicitHeight + 29 * s), ame: sizing },
        hoverstate: { size: () => Qt.size(hoverstateW, hoverstate.implicitHeight + 29 * s), ame: hoverstate },
        powerprofiles: { size: () => Qt.size(powerprofilesW, powerprofiles.implicitHeight + 29 * s), ame: powerprofiles },
        powerkeys:     { size: () => Qt.size(powerkeysW, powerkeys.implicitHeight + 29 * s), ame: powerkeys },
        scroll:     { size: () => Qt.size(scrollW, scroll.implicitHeight + 29 * s), ame: scroll },
        appmixer:   { size: () => Qt.size(appmixerW, appmixer.implicitHeight + 26 * s), ame: appmixer }
    })

    readonly property string mode: surfaceOpen && surfaces[surface] !== undefined ? surface
        : (quickChoosing ? "quickChoose"
        : (quickCounting ? "quickCount"
        : (osdActive && !held ? "osd"
        : (toastActive && !held ? "toast"
        : (expanded ? "hover" : "rest")))))

    readonly property bool workspaceOsdActive: osdActive && osd.kind === "workspace"

    signal requestSurface(string name)
    signal requestClose()

    /**
     * Forward an arrow-key nudge to the open mixer's targeted fader. Returns true
     * when the mixer is open and a fader consumed the step.
     */
    function mixerStep(deltaPct) {
        return pill.mixerOpen ? mixer.stepFocused(deltaPct) : false;
    }

    /**
     * Move the open mixer's keyboard focus across the fader row; `dir` is +1
     * (right) or -1 (left). No-op unless the mixer is open.
     */
    function mixerFocusMove(dir) {
        if (pill.mixerOpen)
            mixer.moveFocus(dir);
    }

    function appmixerStep(deltaPct) {
        return pill.appmixerOpen ? appmixer.stepFocused(deltaPct) : false;
    }

    function appmixerFocusMove(dir) {
        if (pill.appmixerOpen)
            appmixer.moveFocus(dir);
    }

    /**
     * Forward an arrow-key nudge to the open recorder's focused audio fader.
     * Returns true when the recorder is open and a revealed fader consumed it.
     */
    function recorderStep(deltaPct) {
        return pill.recorderOpen ? recorder.stepFocused(deltaPct) : false;
    }

    /**
     * Resolve which settings-family surface owns keyboard row navigation right
     * now: the category index or one of its morphing sub-surfaces. Returns null
     * when none of them is open.
     */
    function rowNavSurface() {
        if (pill.settingsOpen)
            return settings;
        if (pill.appearanceOpen)
            return appearance;
        if (pill.powerprofilesOpen)
            return powerprofiles;
        if (pill.powerkeysOpen)
            return powerkeys;
        if (pill.scrollOpen)
            return scroll;
        if (pill.displayOpen)
            return display;
        if (pill.inputOpen)
            return input;
        if (pill.animationOpen)
            return animation;
        if (pill.updatesOpen)
            return updates;
        if (pill.idlelockOpen)
            return idlelock;
        if (pill.fontpickerOpen)
            return fontpicker;
        if (pill.sizingOpen)
            return sizing;
        if (pill.hoverstateOpen)
            return hoverstate;
        if (pill.lookOpen)
            return look;
        return null;
    }

    /**
     * Move the focused settings row by `dir` (+1 down, -1 up), carrying the soul
     * seam. Returns true when a settings-family surface is open and consumed it.
     */
    function settingsMove(dir) {
        var nav = pill.rowNavSurface();
        if (!nav)
            return false;
        nav.kbMove(dir);
        return true;
    }

    /**
     * Step the focused settings row's control: a segmented choice cycles by
     * `dir`, a toggle is set on (dir > 0) or off. Returns true when consumed.
     */
    function settingsAdjust(dir) {
        var nav = pill.rowNavSurface();
        if (!nav)
            return false;
        nav.kbAdjust(dir);
        return true;
    }

    /**
     * Activate the focused settings row: a toggle flips, a nav row opens its
     * sub-surface. Returns true when a settings-family surface is open.
     */
    function settingsActivate() {
        var nav = pill.rowNavSurface();
        if (!nav)
            return false;
        nav.kbActivate();
        return true;
    }

    readonly property bool easyMotionActive: {
        var nav = pill.rowNavSurface();
        return nav ? nav.easyMotionActive : false;
    }

    function beginEasyMotion() {
        var nav = pill.rowNavSurface();
        if (nav) nav.beginEasyMotion();
    }

    function cancelEasyMotion() {
        var nav = pill.rowNavSurface();
        if (nav) nav.cancelEasyMotion();
    }

    /**
     * Slide the open keybinds list's focused row by `dir` (+1 down, -1 up),
     * carrying the soul seam. No-op unless the keybinds surface is open.
     */
    function keybindsMove(dir) {
        if (pill.keybindsOpen)
            keybinds.move(dir);
    }

    /**
     * Enter on the open keybinds surface: arm chord capture on the focused row.
     * No-op unless the keybinds surface is open.
     */
    function keybindsActivate() {
        if (pill.keybindsOpen)
            keybinds.activate();
    }

    readonly property bool keybindsListening: pill.keybindsOpen && keybinds.listening

    /**
     * A tile was picked in the standalone quick-record chooser. Screen with several
     * monitors flips to the inline sub-choice; otherwise each source kicks off its
     * resolver (which counts down once the target is ready) and the chooser closes.
     */
    function quickChooseSource(kind) {
        if (kind === "screen") {
            if (ScreenRec.monitors.length > 1) {
                ScreenRec.quickScreenChoosing = true;
                return;
            }
            ScreenRec.prepareScreen(pill.screenName);
        } else if (kind === "window") {
            ScreenRec.prepareWindow();
        }
        ScreenRec.quickChoosing = false;
        ScreenRec.quickScreenChoosing = false;
    }

    function quickPickMonitor(name) {
        ScreenRec.quickChoosing = false;
        ScreenRec.quickScreenChoosing = false;
        ScreenRec.prepareScreen(name);
    }

    /**
     * Pop the open link surface one subview back. Returns true when the step was
     * consumed, false when the surface is already at its root (or not open) and
     * Escape should close the surface instead.
     */
    function linkBack() {
        return pill.linkOpen ? link.back() : false;
    }

    /**
     * Step the open surface back one level when its header bar is clicked: a
     * settings sub-surface returns to the index, the font picker to appearance,
     * a keybinds form to its list, and any other surface dismisses to the hover
     * pill. Empty space in the body never triggers this.
     */
    function surfaceBack() {
        if (pill.keybindsOpen) {
            if (keybinds.formOpen)
                keybinds.closeForm();
            else
                pill.requestSurface("scroll");
            return;
        }
        var nav = pill.rowNavSurface();
        if (nav) {
            var bs = nav.backSurface;
            if (bs) pill.requestSurface(bs);
            else pill.requestClose();
            return;
        }
        pill.requestClose();
    }

    /**
     * Pop the open keybinds editor form back to the bind list. Returns true when a
     * form was open and dismissed, false otherwise so Escape closes the surface.
     */
    function keybindsBack() {
        if (pill.keybindsOpen && keybinds.formOpen) {
            keybinds.closeForm();
            return true;
        }
        return false;
    }

    /**
     * Slide the open wallpaper strip's focus by `dir` thumbs; +1 is right (older)
     * and -1 is left (newer). No-op unless the wallpaper surface is open.
     */
    function wallpaperMove(dir) {
        if (pill.wallpaperOpen)
            wall.move(dir);
    }

    /**
     * Apply the wallpaper strip's focused thumb through wallpaper.sh. The
     * surface stays open so the pick can be iterated. No-op unless the
     * wallpaper surface is open.
     */
    function wallpaperActivate() {
        if (pill.wallpaperOpen)
            wall.activate();
    }

    readonly property bool wallpaperSearching: pill.wallpaperOpen && wall.searching

    /**
     * Route the first printable keystroke over the open wallpaper strip into a
     * DuckDuckGo search seeded with that character. No-op unless the wallpaper
     * surface is open.
     */
    function wallpaperType(ch) {
        if (pill.wallpaperOpen)
            wall.startSearch(ch);
    }

    /**
     * Slide the open power surface's keyboard focus by `dir` tiles; +1 is right
     * and -1 is left. No-op unless the power surface is open.
     */
    function powerMove(dir) {
        if (pill.powerOpen)
            power.move(dir);
    }

    /**
     * Enter pressed on the open power surface's focused tile: fires a safe tile
     * at once, latches a destructive tile's heat hold. Returns true when a tile
     * consumed the key. No-op (false) unless the power surface is open.
     */
    function powerPress() {
        return pill.powerOpen ? power.pressFocused() : false;
    }

    /**
     * Enter released on the open power surface: drains an unfinished destructive
     * hold so a key let go before the fill completes never confirms.
     */
    function powerRelease() {
        if (pill.powerOpen)
            power.releaseFocused();
    }

    function powerKeyAction(letter) {
        return pill.powerOpen ? power.keyAction(letter) : false;
    }

    function powerKeyRelease(letter) {
        if (pill.powerOpen)
            power.keyRelease(letter);
    }

    function powerkeysHandleKey(letter) {
        return pill.powerkeysOpen ? powerkeys.handleKey(letter) : false;
    }

    function powerkeysCancelListening() {
        if (pill.powerkeysOpen)
            powerkeys.cancelListening();
    }

    onSurfaceOpenChanged: if (surfaceOpen) {
        pinned = false;
        if (quickHere && ScreenRec.quickChoosing) {
            ScreenRec.quickChoosing = false;
            ScreenRec.quickScreenChoosing = false;
        }
    }

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string timeFormat: (Flags.time12h ? "h:mm" : "HH:mm")
            + (Flags.clockSeconds ? ":ss" : "")
            + (Flags.time12h ? " AP" : "")
        readonly property string hhmm: Qt.formatTime(now, timeFormat)
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: Flags.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    property real morphRadius: (mode === "rest" || mode === "hover") ? restCorner
        : (mode === "osd" && osd.kind === "workspace" ? restCorner : openCorner)

    /**
     * Target geometry for the non-surface morph modes. Surface sizes come from
     * the `surfaces` descriptor; these three are the pill's own modes that have no
     * surface item. Thunks so the properties they read register as live deps of
     * targetSize.
     */
    readonly property var modeSize: ({
        osd:   () => Qt.size(osd.desiredW, osd.desiredH),
        toast: () => Qt.size(toastW, toastLoader.item ? toastLoader.item.implicitHeight + 24 * s : restH),
        hover: () => Qt.size(hoverW, hoverH),
        quickChoose: () => Qt.size(quickChooseW, quickChooseH),
        quickCount:  () => Qt.size(quickCountW, quickCountH)
    })

    readonly property size targetSize: {
        const sf = surfaces[mode];
        if (sf)
            return sf.size();
        const f = modeSize[mode];
        return f ? f() : Qt.size(Math.max(restW, restRow.implicitWidth + 36 * s), restH);
    }
    readonly property real targetW: targetSize.width
    readonly property real targetH: targetSize.height

    width: targetW
    height: targetH

    /**
     * How settled the pill is into its target geometry: 0 while the morph is far
     * away, 1 once it arrives. Content opacities key off this, not their own
     * timers, so a surface fades in as the pill reaches full size, never over a
     * half-grown pill.
     */
    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(width - targetW), Math.abs(height - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }

    /**
     * Gate the soul bead until the hover morph has arrived and its icons exist.
     * Fire it earlier and the bead aims at anchors that aren't laid out yet.
     * Latched so small width changes inside hover (workspace dot growing, tray
     * icons appearing) don't flicker the bead off.
     */
    property bool hoverSoulGate: false
    readonly property bool hoverArrived: mode === "hover" && morphCloseness > 0.55
    onHoverArrivedChanged: if (hoverArrived) hoverSoulGate = true
    onModeChanged: if (mode !== "hover") {
        hoverSoulGate = false;
        soulTarget = "";
        soulWsIndex = -1;
    }
    onHoverSoulGateChanged: if (hoverSoulGate) kanjiFlashAnim.restart()

    property string soulTarget: ""
    property int soulWsIndex: -1

    property real kanjiFlash: 0

    SequentialAnimation {
        id: kanjiFlashAnim
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 1; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 0; duration: 320; easing.type: Easing.OutCubic }
    }

    Behavior on width { NumberAnimation { duration: pill.hidden ? 0 : Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on height { NumberAnimation { duration: pill.hidden ? 0 : Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on morphRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    Rectangle {
        id: bud
        readonly property bool shown: pill.mode === "hover" && pill.hasMedia
        property real budR: (budArea.containsMouse ? 15 : 12) * pill.s
        width: budR * 2
        height: budR * 2
        radius: budR
        x: pill.width - budR
        anchors.verticalCenter: parent.verticalCenter
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.pillOpacity) }
        }
        Behavior on budR { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard } }

        Canvas {
            id: budBead
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 3 * pill.s
            width: 18 * pill.s
            height: 18 * pill.s
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const R = (budArea.containsMouse ? 5.2 : 4) * pill.s;
                const hg = ctx.createRadialGradient(c - R * 0.32, c - R * 0.38, 0, c, c, R);
                hg.addColorStop(0, Theme.flameInk);
                hg.addColorStop(0.55, Theme.vermLit);
                hg.addColorStop(0.92, Theme.verm);
                hg.addColorStop(1, Theme.flameEmber);
                ctx.beginPath();
                ctx.arc(c, c, R, 0, 7);
                ctx.fillStyle = hg;
                ctx.fill();
                ctx.beginPath();
                ctx.ellipse(c - R * 0.62, c - R * 0.66, R * 0.6, R * 0.36);
                ctx.fillStyle = "rgba(255,246,240,0.6)";
                ctx.fill();
            }
        }

        MouseArea {
            id: budArea
            anchors.fill: parent
            enabled: bud.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("media")
            onContainsMouseChanged: budBead.requestPaint()
        }
    }

    ClippingRectangle {
        id: bodyShadow
        anchors.fill: body
        radius: body.radius
        topLeftRadius: body.topLeftRadius
        topRightRadius: body.topRightRadius
        bottomLeftRadius: body.bottomLeftRadius
        bottomRightRadius: body.bottomRightRadius
        color: "black"
        z: -1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * pill.s
        }
    }

    ClippingRectangle {
        id: body
        anchors.fill: parent
        radius: pill.morphRadius
        topLeftRadius: Flags.notchMode ? 0 : pill.morphRadius
        topRightRadius: Flags.notchMode ? 0 : pill.morphRadius
        color: "transparent"
        Behavior on radius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
        Behavior on topLeftRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
        Behavior on topRightRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.pillOpacity) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.pillOpacity) }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: body.radius * 0.6
            anchors.rightMargin: body.radius * 0.6
            height: 1
            color: Theme.sheen
        }

        readonly property color batColor: {
            if (Battery.pct <= 20) return "#ff4444";
            if (Battery.pct <= 50) return Theme.verm;
            return Battery.charging ? Theme.vermLit : Theme.verm;
        }

        Rectangle {
            id: batteryLine
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: body.radius * 0.35
            width: (parent.width - 2 * body.radius * 0.35) * (Battery.present ? Battery.frac : 0)
            height: Flags.batteryLineThickness * pill.s
            visible: Battery.present && pill.mode === "rest" && !Flags.notchMode && !Flags.batteryOutline
            color: body.batColor
            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            Behavior on radius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
            Behavior on topLeftRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
            Behavior on topRightRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
        }

        Canvas {
            id: notchBat
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            smooth: true

            readonly property bool show: Battery.present && (pill.mode === "rest" || (pill.workspaceOsdActive && Flags.osdBatteryOutline)) && Flags.notchMode
            onShowChanged: requestPaint()

            Connections {
                target: Battery
                function onFracChanged() { notchBat.requestPaint() }
                function onChargingChanged() { notchBat.requestPaint() }
                function onPctChanged() { notchBat.requestPaint() }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (!show) return;

                const w = width, h = height, r = body.radius;
                const leftV = h - r, botArc = Math.PI * r / 2, botH = w - 2 * r;
                const total = 2 * leftV + 2 * botArc + botH;
                let draw = Battery.frac * total;
                if (draw < 1) return;

                const sw = Flags.batteryLineThickness * pill.s;
                ctx.strokeStyle = body.batColor;
                ctx.lineWidth = sw;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                ctx.beginPath();
                ctx.moveTo(0, 0);

                if (draw <= leftV) {
                    ctx.lineTo(0, draw);
                    ctx.stroke();
                    return;
                }
                ctx.lineTo(0, h - r);
                draw -= leftV;

                if (draw <= botArc) {
                    const a = draw / r;
                    ctx.arc(r, h - r, r, Math.PI, Math.PI - a, true);
                    ctx.stroke();
                    return;
                }
                ctx.arc(r, h - r, r, Math.PI, Math.PI / 2, true);
                draw -= botArc;

                if (draw <= botH) {
                    ctx.lineTo(r + draw, h);
                    ctx.stroke();
                    return;
                }
                ctx.lineTo(w - r, h);
                draw -= botH;

                if (draw <= botArc) {
                    const a = draw / r;
                    ctx.arc(w - r, h - r, r, Math.PI / 2, Math.PI / 2 - a, true);
                    ctx.stroke();
                    return;
                }
                ctx.arc(w - r, h - r, r, Math.PI / 2, 0, true);
                draw -= botArc;

                ctx.lineTo(w, draw);
                ctx.stroke();
            }
        }

        Canvas {
            id: outlineBat
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            smooth: true

            readonly property bool show: Battery.present && (pill.mode === "rest" || (pill.workspaceOsdActive && Flags.osdBatteryOutline)) && !Flags.notchMode && Flags.batteryOutline
            onShowChanged: requestPaint()

            Connections {
                target: Battery
                function onFracChanged() { outlineBat.requestPaint() }
                function onChargingChanged() { outlineBat.requestPaint() }
                function onPctChanged() { outlineBat.requestPaint() }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (!show) return;

                const w = width, h = height, r = body.radius;
                if (r <= 0 || w <= 0 || h <= 0) return;

                const hw = w / 2;
                const segTopL = Math.max(0, hw - r);
                const segArc = Math.PI * r / 2;
                const segLeft = Math.max(0, h - 2 * r);
                const segBot = Math.max(0, w - 2 * r);
                const segRight = Math.max(0, h - 2 * r);
                const segTopR = Math.max(0, hw - r);

                const total = segTopL + segArc + segLeft + segArc + segBot + segArc + segRight + segArc + segTopR;
                let draw = Battery.frac * total;
                if (draw < 1) return;

                const sw = Flags.batteryLineThickness * pill.s;
                ctx.strokeStyle = body.batColor;
                ctx.lineWidth = sw;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                ctx.beginPath();
                ctx.moveTo(hw, 0);

                if (draw <= segTopL) {
                    ctx.lineTo(hw - draw, 0);
                    ctx.stroke();
                    return;
                }
                ctx.lineTo(r, 0);
                draw -= segTopL;

                if (draw <= segArc) {
                    const a = draw / r;
                    ctx.arc(r, r, r, 3 * Math.PI / 2, 3 * Math.PI / 2 - a, true);
                    ctx.stroke();
                    return;
                }
                ctx.arc(r, r, r, 3 * Math.PI / 2, Math.PI, true);
                draw -= segArc;

                if (draw <= segLeft) {
                    ctx.lineTo(0, r + draw);
                    ctx.stroke();
                    return;
                }
                ctx.lineTo(0, h - r);
                draw -= segLeft;

                if (draw <= segArc) {
                    const a = draw / r;
                    ctx.arc(r, h - r, r, Math.PI, Math.PI - a, true);
                    ctx.stroke();
                    return;
                }
                ctx.arc(r, h - r, r, Math.PI, Math.PI / 2, true);
                draw -= segArc;

                if (draw <= segBot) {
                    ctx.lineTo(r + draw, h);
                    ctx.stroke();
                    return;
                }
                ctx.lineTo(w - r, h);
                draw -= segBot;

                if (draw <= segArc) {
                    const a = draw / r;
                    ctx.arc(w - r, h - r, r, Math.PI / 2, Math.PI / 2 - a, true);
                    ctx.stroke();
                    return;
                }
                ctx.arc(w - r, h - r, r, Math.PI / 2, 0, true);
                draw -= segArc;

                if (draw <= segRight) {
                    ctx.lineTo(w, h - r - draw);
                    ctx.stroke();
                    return;
                }
                ctx.lineTo(w, r);
                draw -= segRight;

                if (draw <= segArc) {
                    const a = draw / r;
                    ctx.arc(w - r, r, r, 0, -a, true);
                    ctx.stroke();
                    return;
                }
                ctx.arc(w - r, r, r, 0, -Math.PI / 2, true);
                draw -= segArc;

                if (draw < segTopR) {
                    ctx.lineTo(w - r - draw, 0);
                } else {
                    ctx.closePath();
                }
                ctx.stroke();
            }
        }
    }

    /**
     * Rest anchor for Ame: the 時 kanji centre. The idle outline condenses into
     * the bead here before it moves.
     */
    readonly property point wakePoint: {
        void pill.width;
        void pill.height;
        return restKanji.mapToItem(pill, restKanji.width / 2, restKanji.height / 2);
    }

    /**
     * Bead target while hovered. soulTarget is a sticky key written by the hover
     * sources: the bead parks on the last focused dot or icon and glides to the
     * next, so crossing a gap between targets doesn't snap it back to the active
     * workspace. Pill geometry is voided so the anchor follows the hover morph,
     * the point stays live.
     */
    readonly property point soulPoint: {
        void pill.width;
        void pill.height;
        const drop = 12 * pill.s;
        if (soulTarget === "wifi")
            return wifiIcon.mapToItem(pill, wifiIcon.width / 2, wifiIcon.height + drop * 0.55);
        if (soulTarget === "battery")
            return batteryIcon.mapToItem(pill, batteryIcon.width / 2, batteryIcon.height + drop * 0.55);
        if (soulTarget === "inbox")
            return inboxIcon.mapToItem(pill, inboxIcon.width / 2, inboxIcon.height + drop * 0.55);
        if (soulTarget === "mixer")
            return mixerIcon.mapToItem(pill, mixerIcon.width / 2, mixerIcon.height + drop * 0.55);
        if (soulTarget === "power")
            return powerIcon.mapToItem(pill, powerIcon.width / 2, powerIcon.height + drop * 0.55);
        if (soulTarget === "settings")
            return settingsIcon.mapToItem(pill, settingsIcon.width / 2, settingsIcon.height + drop * 0.55);
        if (soulTarget === "recorder")
            return recorderIcon.mapToItem(pill, recorderIcon.width / 2, recorderIcon.height + drop * 0.55);
        if (soulTarget === "sysmon")
            return sysmonIcon.mapToItem(pill, sysmonIcon.width / 2, sysmonIcon.height + drop * 0.55);
        if (soulTarget === "ws" && soulWsIndex >= 0) {
            void ws.activeName;
            void ws.width;
            const p = ws.mapToItem(pill, ws.slotCenterX(soulWsIndex), ws.height / 2);
            return Qt.point(p.x, p.y + drop);
        }
        return ws.mapToItem(pill, ws.activeDotPoint.x, ws.activeDotPoint.y + drop);
    }

    /**
     * Which open surface owns Ame's anchor. Each surface exports its own
     * `ameForm`/`amePoint`; the pill picks the open surface's `ame` from the
     * descriptor and maps it. Null = nothing open (or a surface with no anchor,
     * e.g. wallpaper), so Ame falls back to the pill's own hover/wake anchor.
     */
    readonly property var ameSurface: (surfaceOpen && surfaces[surface] !== undefined)
        ? surfaces[surface].ame : null

    Ame {
        id: ame
        anchors.fill: parent
        s: pill.s
        heat: pill.powerOpen ? power.holdProgress : 0
        wake: pill.wakePoint
        wickDir: pill.powerOpen ? 1 : -1
        form: pill.ameSurface ? pill.ameSurface.ameForm
            : (pill.mode === "hover" && pill.hoverSoulGate ? "soul" : "off")
        point: pill.ameSurface
            ? Qt.point(pill.ameSurface.x + pill.ameSurface.amePoint.x,
                       pill.ameSurface.y + pill.ameSurface.amePoint.y)
            : (pill.mode === "hover" ? pill.soulPoint : pill.wakePoint)
    }

    /**
     * Extra input width past the pill's right edge while the media bud sticks
     * out there, so the window mask covers the bud's outer half. pill.hovered is
     * fed by a window-level HoverHandler in shell.qml: pointer events only exist
     * inside the input mask, so "window hovered" means "pointer over the pill (or
     * bud)". That sidesteps the per-item hover flicker the child MouseAreas and
     * the centred width morph would otherwise cause.
     */
    readonly property real inputPadRight: bud.shown ? bud.budR + 2 * s : 0

    onHoveredChanged: {
        if (hovered) {
            hoverLatch = true;
            graceTimer.stop();
        } else {
            graceTimer.restart();
        }
    }

    Timer {
        id: graceTimer
        interval: 300
        onTriggered: {
            if (pill.morphCloseness < 0.95) {
                graceTimer.restart();
                return;
            }
            pill.hoverLatch = false;
        }
    }

    TapHandler {
        enabled: !pill.surfaceOpen
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.pinned = !pill.pinned
    }

    Item {
        id: rest
        anchors.fill: parent
        clip: true
        opacity: (pill.expanded || pill.mode === "toast" || pill.mode === "osd" || pill.mode === "quickChoose" || pill.mode === "quickCount") ? 0 : Math.pow(pill.morphCloseness, 1.5)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: pill.mode === "rest" ? Motion.fast : 260 } }

        Row {
            id: restRow
            anchors.centerIn: parent
            spacing: 9 * pill.s
            Item {
                id: restKanji
                anchors.verticalCenter: parent.verticalCenter
                width: kanjiFill.implicitWidth
                height: kanjiFill.implicitHeight
                visible: Flags.showClockIcon || restKanji.barsOn

                /** Audio leaving the speakers flips the clock glyph over to the live waveform. */
                readonly property bool barsOn: Flags.musicViz && Cava.active

                Text {
                    anchors.fill: parent
                    opacity: (Flags.showGlyphs && !restKanji.barsOn && Flags.showClockIcon) ? 1 : 0
                    text: kanjiFill.text
                    color: "transparent"
                    font: kanjiFill.font
                    style: Text.Outline
                    styleColor: Qt.alpha(Theme.vermLit,
                        Math.min(1, (pill.mode === "rest" || !pill.hoverSoulGate ? 0.5 : 0) + pill.kanjiFlash))
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                Text {
                    id: kanjiFill
                    opacity: (Flags.showGlyphs && !restKanji.barsOn && Flags.showClockIcon) ? 1 : 0
                    text: "時"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 15 * pill.s
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    opacity: (!Flags.showGlyphs && !restKanji.barsOn && Flags.showClockIcon) ? 1 : 0
                    width: 17 * pill.s
                    height: 17 * pill.s
                    name: "clock"
                    color: Theme.cream
                    stroke: 1.7
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                MusicBars {
                    id: musicBars
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: kanjiFill.baseline
                    s: pill.s
                    opacity: restKanji.barsOn ? 1 : 0
                    scale: restKanji.barsOn ? 1 : 0.7
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.hhmm
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        clip: true
        opacity: pill.mode === "hover" ? Math.pow(pill.morphCloseness, 1.2) : 0
        visible: true
        Behavior on opacity { NumberAnimation { duration: pill.mode === "hover" ? Motion.fast : 40 } }

        readonly property bool live: pill.mode === "hover"

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 20 * pill.s
            scale: pill.hoverScale
            transformOrigin: Item.Center

            Workspaces {
                id: ws
                visible: pill.hoverModList.indexOf("workspaces") >= 0
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                screenName: pill.screenName
                s: pill.s
                gap: 8 * pill.s
                enabled: hover.live
                onHoverIndexChanged: if (hoverIndex >= 0) {
                    pill.soulTarget = "ws";
                    pill.soulWsIndex = hoverIndex;
                }
            }

            Rectangle {
                visible: pill.hoverModList.indexOf("workspaces") >= 0 && (pill.hoverModList.indexOf("clock") >= 0 || pill.hoverStatusVisible)
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Item {
                visible: pill.hoverModList.indexOf("clock") >= 0
                anchors.verticalCenter: parent.verticalCenter
                width: hoverClock.implicitWidth
                height: hoverClock.implicitHeight

                Column {
                    id: hoverClock
                    anchors.centerIn: parent
                    spacing: 2 * pill.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.hhmm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 18 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.date
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11 * pill.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6 * pill.s
                    }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: hoverClock.implicitWidth + 22 * pill.s
                    height: hoverClock.implicitHeight + 10 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                visible: pill.hoverModList.indexOf("clock") >= 0 && pill.hoverStatusVisible
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Row {
                id: statusRow
                visible: pill.hoverStatusVisible
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * pill.s

                Row {
                    id: weatherGlance
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Weather.ready && pill.hoverModList.indexOf("weather") >= 0
                    spacing: 5 * pill.s

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        enabled: hover.live
                    }
                    TapHandler {
                        enabled: hover.live
                        onTapped: pill.requestSurface("calendar")
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16 * pill.s
                        height: 16 * pill.s
                        name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
                        color: Theme.subtle
                        stroke: 1.8
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.tempNow + "°"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 12.5 * pill.s
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }

                MinimizedTray {
                    id: minimized
                    anchors.verticalCenter: parent.verticalCenter
        s: pill.s
        screenName: pill.screenName
                    enabled: hover.live
                    visible: count > 0 && pill.hoverModList.indexOf("minimized") >= 0
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: minimized.count > 0 && pill.hoverModList.indexOf("minimized") >= 0 && pill.hoverModList.indexOf("tray") >= 0
                    width: 1
                    height: 14 * pill.s
                    color: Theme.hair
                    opacity: 0.7
                }

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                    visible: pill.hoverModList.indexOf("tray") >= 0
                }

                Item {
                    id: dndIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.dnd && pill.hoverModList.indexOf("dnd") >= 0
                    width: 16 * pill.s
                    height: 16 * pill.s

                    Shape {
                        id: dndShape

                        width: 16
                        height: 16
                        scale: pill.s
                        transformOrigin: Item.TopLeft
                        x: dndShape.boundingRect.width > 0
                           ? dndIcon.width / 2 - (dndShape.boundingRect.x + dndShape.boundingRect.width / 2) * pill.s
                           : (dndIcon.width - 16 * pill.s) / 2
                        y: dndShape.boundingRect.height > 0
                           ? dndIcon.height / 2 - (dndShape.boundingRect.y + dndShape.boundingRect.height / 2) * pill.s
                           : (dndIcon.height - 16 * pill.s) / 2
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Theme.vermLit
                            strokeWidth: 1.5
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 5.2; startY: 12.2
                            PathLine { x: 12.2; y: 12.2 }
                            PathLine { x: 12.2; y: 7.2 }
                            PathCubic {
                                control1X: 12.2; control1Y: 5.4
                                control2X: 11.2; control2Y: 4.0
                                x: 9.5; y: 3.5
                            }
                        }
                        ShapePath {
                            strokeColor: Theme.vermLit
                            strokeWidth: 1.5
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 6.8; startY: 13.6
                            PathLine { x: 9.2; y: 13.6 }
                        }
                        ShapePath {
                            strokeColor: Theme.vermLit
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 3.2; startY: 2.8
                            PathLine { x: 13.0; y: 13.4 }
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (pill.hoverModList.indexOf("network") >= 0 && pill.wifiDev !== null && pill.wifiOn) || (pill.hoverModList.indexOf("battery") >= 0 && Battery.present)
                    spacing: 12 * pill.s

                    Item {
                        id: wifiIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pill.hoverModList.indexOf("network") >= 0 && pill.wifiDev !== null && pill.wifiOn
                        width: 17 * pill.s
                        height: 17 * pill.s

                        WifiGlyph {
                            anchors.centerIn: parent
                            s: pill.s
                            level: pill.wifiLevel
                            on: pill.wifiOn
                        }

                        MouseArea {
                            id: wifiArea
                            anchors.fill: parent
                            anchors.margins: -6 * pill.s
                            hoverEnabled: true
                            enabled: hover.live
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pill.linkInitialView = "wifi";
                                pill.requestSurface("link");
                            }
                            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "wifi"
                        }
                    }

                    Item {
                        id: batteryIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pill.hoverModList.indexOf("battery") >= 0 && Battery.present
                        width: battPct.implicitWidth
                        height: 17 * pill.s

                        Text {
                            id: battPct
                            anchors.centerIn: parent
                            text: Battery.pct + "%"
                            color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                            font.family: Theme.font
                            font.pixelSize: 13 * pill.s
                            font.weight: Battery.charging ? Font.DemiBold : Font.Medium
                            font.features: { "tnum": 1 }
                        }

                        MouseArea {
                            id: batteryArea
                            anchors.fill: parent
                            anchors.margins: -6 * pill.s
                            hoverEnabled: true
                            enabled: hover.live
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pill.requestSurface("battery")
                            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "battery"
                        }
                    }
                }

                Item {
                    id: inboxIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModList.indexOf("inbox") >= 0
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "inbox"
                        color: inboxArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    Rectangle {
                        visible: Notifs.unread > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2 * pill.s
                        anchors.rightMargin: -2 * pill.s
                        width: 5 * pill.s
                        height: 5 * pill.s
                        radius: width / 2
                        color: Theme.flameGlow
                    }

                    MouseArea {
                        id: inboxArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pill.linkInitialView = "main";
                            pill.requestSurface("link");
                        }
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "inbox"
                    }
                }

                Item {
                    id: mixerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModList.indexOf("mixer") >= 0
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "mixer"
                        color: mixerArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: mixerArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("mixer")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "mixer"
                    }
                }

                Item {
                    id: sysmonIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModList.indexOf("sysmon") >= 0
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "monitor"
                        color: sysmonArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: sysmonArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("sysmon")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sysmon"
                    }
                }

                Item {
                    id: recorderIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModList.indexOf("recorder") >= 0
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        visible: !ScreenRec.recording
                        name: "video"
                        color: recorderArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: ScreenRec.recording
                        width: 12 * pill.s
                        height: 12 * pill.s
                        radius: width / 2
                        color: Theme.verm
                        SequentialAnimation on opacity {
                            running: ScreenRec.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                        }
                    }

                    MouseArea {
                        id: recorderArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (e) => {
                            if (e.button === Qt.RightButton) {
                                if (ScreenRec.recording)
                                    ScreenRec.stop();
                                return;
                            }
                            pill.requestSurface("recorder");
                        }
                        onDoubleClicked: (e) => {
                            if (e.button === Qt.LeftButton && ScreenRec.recording)
                                ScreenRec.stop();
                        }
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "recorder"
                    }
                }

                Item {
                    id: wallpaperIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModList.indexOf("wallpaper") >= 0
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "image"
                        color: wallpaperArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: wallpaperArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("wallpaper")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "wallpaper"
                    }
                }

                Item {
                    id: settingsIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModList.indexOf("settings") >= 0
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "cog"
                        color: settingsArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.6
                    }

                    MouseArea {
                        id: settingsArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("settings")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "settings"
                    }
                }

                Item {
                    id: powerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.hoverModList.indexOf("power") >= 0
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "shutdown"
                        color: powerArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("power")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "power"
                    }
                }
            }
        }
    }

    Mixer {
        id: mixer
        s: pill.s * Flags.surfaceScale
        open: pill.mixerOpen
        morphCloseness: pill.morphCloseness
    }

    AppMixerSurface {
        id: appmixer
        s: pill.s * Flags.surfaceScale
        open: pill.appmixerOpen
        morphCloseness: pill.morphCloseness
    }

    Calendar {
        id: calendar
        s: pill.s * Flags.surfaceScale
        open: pill.calendarOpen
        morphCloseness: pill.morphCloseness
    }

    Launcher {
        id: launcher
        s: pill.s
        open: pill.launcherOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Clipboard {
        id: clip
        s: pill.s
        open: pill.clipboardOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Wallpaper {
        id: wall
        s: pill.s
        open: pill.wallpaperOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Power {
        id: power
        s: pill.s * Flags.surfaceScale
        open: pill.powerOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Media {
        id: media
        s: pill.s
        open: pill.mediaOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Link {
        id: link
        s: pill.s * Flags.surfaceScale
        open: pill.linkOpen
        initialView: pill.linkInitialView
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    onLinkOpenChanged: if (!linkOpen) linkInitialView = "main"

    BatterySurface {
        id: battery
        s: pill.s
        open: pill.batteryOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Settings {
        id: settings
        s: pill.s * Flags.surfaceScale
        open: pill.settingsOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Keybinds {
        id: keybinds
        s: pill.s * Flags.surfaceScale
        open: pill.keybindsOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Recorder {
        id: recorder
        s: pill.s * Flags.surfaceScale
        screenName: pill.screenName
        open: pill.recorderOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    SysmonSurface {
        id: sysmon
        s: pill.s * Flags.surfaceScale
        open: pill.sysmonOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Appearance {
        id: appearance
        s: pill.s * Flags.surfaceScale
        open: pill.appearanceOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Updates {
        id: updates
        s: pill.s * Flags.surfaceScale
        open: pill.updatesOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Display {
        id: display
        s: pill.s * Flags.surfaceScale
        open: pill.displayOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Input {
        id: input
        s: pill.s * Flags.surfaceScale
        open: pill.inputOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Look {
        id: look
        s: pill.s * Flags.surfaceScale
        open: pill.lookOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    IdleLock {
        id: idlelock
        s: pill.s * Flags.surfaceScale
        open: pill.idlelockOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    AnimationSurface {
        id: animation
        s: pill.s * Flags.surfaceScale
        open: pill.animationOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    FontPicker {
        id: fontpicker
        s: pill.s * Flags.surfaceScale
        open: pill.fontpickerOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Sizing {
        id: sizing
        s: pill.s * Flags.surfaceScale
        open: pill.sizingOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    HoverState {
        id: hoverstate
        s: pill.s * Flags.surfaceScale
        open: pill.hoverstateOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    PowerProfiles {
        id: powerprofiles
        s: pill.s * Flags.surfaceScale
        open: pill.powerprofilesOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    PowerKeys {
        id: powerkeys
        s: pill.s * Flags.surfaceScale
        open: pill.powerkeysOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Scroll {
        id: scroll
        s: pill.s * Flags.surfaceScale
        open: pill.scrollOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
        onRequestSurface: (name) => pill.requestSurface(name)
    }

    Osd {
        id: osd
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 18 * pill.s
        anchors.rightMargin: 18 * pill.s
        anchors.bottomMargin: 12 * pill.s
        s: pill.s * osd.osdScale
        screenName: pill.screenName
        suppressed: pill.expanded
        expanded: pill.expanded
        enabled: pill.mode === "osd"
        opacity: pill.mode === "osd" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
    }

    Loader {
        id: toastLoader
        active: pill.toastActive
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 16 * pill.s
        anchors.rightMargin: 16 * pill.s
        anchors.bottomMargin: 12 * pill.s
        enabled: pill.mode === "toast"
        opacity: pill.mode === "toast" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        sourceComponent: Item {
            implicitHeight: toastContent.implicitHeight

            Toast {
                id: toastContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                s: pill.s * osd.osdScale
                live: pill.mode === "toast"
                notif: Notifs.popups.length > 0 ? Notifs.popups[Notifs.popups.length - 1] : null
                onOpenCenter: {
                    pill.linkInitialView = "main";
                    pill.requestSurface("link");
                }
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: Notifs.popups.length > 1
                text: "+" + (Notifs.popups.length - 1)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9 * pill.s
                font.weight: Font.DemiBold
            }
        }
    }

    /**
     * Standalone quick-record source chooser. Driven by the SUPER+D keybind with
     * no recorder surface open: it grows the pill on the focused monitor only
     * (mode "quickChoose") and offers the same Screen and Window / Region picks as
     * the surface. Screen with one monitor resolves at once; several monitors flip
     * to the inline sub-choice. A pick fires ScreenRec.prepareScreen / prepareWindow
     * → targetReady → the central countdown, then closes.
     */
    Item {
        id: quickChooser
        anchors.fill: parent
        anchors.margins: 6 * pill.s
        enabled: pill.mode === "quickChoose"
        opacity: pill.mode === "quickChoose" ? Math.pow(pill.morphCloseness, 1.3) : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        Row {
            id: quickSources
            anchors.fill: parent
            visible: !ScreenRec.quickScreenChoosing
            spacing: 6 * pill.s

            Repeater {
                model: [
                    { kind: "screen", label: "Screen", glyph: "monitor" },
                    { kind: "window", label: "Window / Region", glyph: "video" }
                ]

                Rectangle {
                    id: qSrcTile
                    required property var modelData
                    width: (quickSources.width - 6 * pill.s) / 2
                    height: parent.height
                    radius: 11 * pill.s
                    color: qSrcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                    border.width: 1
                    border.color: qSrcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8 * pill.s

                        GlyphIcon {
                            width: 16 * pill.s
                            height: 16 * pill.s
                            name: qSrcTile.modelData.glyph
                            color: qSrcArea.containsMouse ? Theme.vermLit : Theme.iconDim
                            stroke: 1.7
                        }
                        Text {
                            height: 16 * pill.s
                            verticalAlignment: Text.AlignVCenter
                            text: qSrcTile.modelData.label
                            color: qSrcArea.containsMouse ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                        font.pixelSize: 8.5 * pill.s
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: qSrcArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.quickChooseSource(qSrcTile.modelData.kind)
                    }
                }
            }
        }

        ListView {
            id: quickScreens
            anchors.fill: parent
            anchors.rightMargin: 22 * pill.s
            visible: ScreenRec.quickScreenChoosing
            orientation: ListView.Horizontal
            spacing: 6 * pill.s
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ScreenRec.monitors

            delegate: Rectangle {
                id: qMonTile
                required property var modelData
                width: 152 * pill.s
                height: quickScreens.height
                radius: 11 * pill.s
                color: qMonArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                border.width: 1
                border.color: qMonArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 2 * pill.s

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qMonTile.modelData.name
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * pill.s
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qMonTile.modelData.w + " × " + qMonTile.modelData.h
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9.5 * pill.s
                        font.features: { "tnum": 1 }
                    }
                }

                MouseArea {
                    id: qMonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.quickPickMonitor(qMonTile.modelData.name)
                }
            }
        }

        WheelScroller {
            flick: quickScreens
            s: pill.s
            anchors.fill: quickScreens
            visible: ScreenRec.quickScreenChoosing
        }

        GlyphIcon {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 5 * pill.s
            visible: ScreenRec.quickScreenChoosing
            width: 12 * pill.s
            height: 12 * pill.s
            name: "chevron-left"
            color: qBackArea.containsMouse ? Theme.cream : Theme.faint
            stroke: 2

            MouseArea {
                id: qBackArea
                anchors.fill: parent
                anchors.margins: -7 * pill.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ScreenRec.quickScreenChoosing = false
            }
        }
    }

    /**
     * Standalone pre-roll countdown toast. Shown at the pill top on the focused
     * monitor when the central countdown runs and the recorder surface is closed
     * (mode "quickCount"): a big flame-glow numeral over a small "GET READY" label.
     * Tapping cancels. The surface's own in-bar countdown covers the surface case.
     */
    Item {
        id: quickCount
        anchors.fill: parent
        enabled: pill.mode === "quickCount"
        opacity: pill.mode === "quickCount" ? Math.pow(pill.morphCloseness, 1.3) : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1 * pill.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ScreenRec.countdown
                color: Theme.flameGlow
                font.family: Theme.font
                font.pixelSize: 28 * pill.s
                font.weight: Font.ExtraBold
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GET READY"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 8.5 * pill.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * pill.s
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ScreenRec.cancel()
        }
    }

}
