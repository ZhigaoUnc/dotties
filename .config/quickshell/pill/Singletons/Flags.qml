pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Shared session flags persisted to a small JSON file and watched for external
 * change, so every dingaling daemon (pill, sidebar) reads and writes the same
 * Do-Not-Disturb and Keep-Awake state live without a second notification server
 * or idle inhibitor. Toggling in one surface updates the others on the next file
 * event, and the state survives a daemon restart.
 */
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias time12h: adapter.time12h
    property alias clockSeconds: adapter.clockSeconds
    property alias showGlyphs: adapter.showGlyphs
    property alias paletteMode: adapter.paletteMode
    property alias uiScale: adapter.uiScale
    property alias reduceMotion: adapter.reduceMotion
    property alias manualHue: adapter.manualHue
    property alias manualDark: adapter.manualDark
    property alias manualSat: adapter.manualSat
    property alias uiFont: adapter.uiFont
    property alias pillOpacity: adapter.pillOpacity
    property alias pillBlur: adapter.pillBlur
    property alias recordCountdown: adapter.recordCountdown
    property alias recordDir: adapter.recordDir
    property alias recordFps: adapter.recordFps
    property alias recordQuality: adapter.recordQuality
    property alias recordCursor: adapter.recordCursor
    property alias recordMic: adapter.recordMic
    property alias recordDesktop: adapter.recordDesktop
    property alias recordClearedBefore: adapter.recordClearedBefore
    property alias acProfile: adapter.acProfile
    property alias batteryProfile: adapter.batteryProfile
    property alias idleLockSec: adapter.idleLockSec
    property alias idleScreenOffSec: adapter.idleScreenOffSec
    property alias idleSuspendSec: adapter.idleSuspendSec
    property alias idleLockBeforeSleep: adapter.idleLockBeforeSleep
    property alias weatherCity: adapter.weatherCity
    property alias musicViz: adapter.musicViz
    property alias showClockIcon: adapter.showClockIcon
    property alias hoverScale: adapter.hoverScale
    property alias osdScale: adapter.osdScale
    property alias surfaceScale: adapter.surfaceScale
    property alias hoverModules: adapter.hoverModules
    property alias notchMode: adapter.notchMode
    property alias batteryOutline: adapter.batteryOutline
    property alias osdBatteryOutline: adapter.osdBatteryOutline
    property alias batteryLineThickness: adapter.batteryLineThickness
    property alias powerKeyLock: adapter.powerKeyLock
    property alias powerKeyLogout: adapter.powerKeyLogout
    property alias powerKeySuspend: adapter.powerKeySuspend
    property alias powerKeyReboot: adapter.powerKeyReboot
    property alias powerKeyShutdown: adapter.powerKeyShutdown
    property alias wallpaperPicker: adapter.wallpaperPicker
    property alias hidePill: adapter.hidePill

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/dingaling/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property bool time12h: false
            property bool clockSeconds: false
            property bool showGlyphs: true
            property string paletteMode: "static"
            property real uiScale: 1.0
            property bool reduceMotion: false
            property int manualHue: 30
            property bool manualDark: true
            property real manualSat: 0.5
            property string uiFont: ""
            property real pillOpacity: 1.0
            property bool pillBlur: false
            property int recordCountdown: 5
            property string recordDir: ""
            property int recordFps: 60
            property string recordQuality: "high"
            property bool recordCursor: true
            property bool recordMic: true
            property bool recordDesktop: true
            property real recordClearedBefore: 0
            property int idleLockSec: 10
            property int idleScreenOffSec: 15
            property int idleSuspendSec: 18
            property bool idleLockBeforeSleep: false
            property string weatherCity: ""
            property int acProfile: 1
            property int batteryProfile: 0
            property bool musicViz: true
            property bool showClockIcon: true
            property real hoverScale: 1.1
            property real osdScale: 1.3
            property real surfaceScale: 1.3
            property string hoverModules: "[\"workspaces\",\"clock\",\"weather\",\"minimized\",\"tray\",\"dnd\",\"network\",\"battery\",\"inbox\",\"mixer\",\"sysmon\",\"recorder\",\"wallpaper\",\"settings\",\"power\"]"
            property bool notchMode: false
            property bool batteryOutline: false
            property bool osdBatteryOutline: false
            property real batteryLineThickness: 4
            property string powerKeyLock: "l"
            property string powerKeyLogout: "o"
            property string powerKeySuspend: "s"
            property string powerKeyReboot: "r"
            property string powerKeyShutdown: "d"
            property string wallpaperPicker: "filmstrip"
            property bool hidePill: false
        }
    }

    property string searchFocusTarget: ""
}
