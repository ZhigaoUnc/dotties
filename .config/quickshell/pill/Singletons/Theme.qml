pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"

    readonly property color onGlow: dyn ? Dyn.primary : "#ffffff"

    readonly property color verm:     dyn ? Qt.darker(Dyn.primary, 1.18) : "#ffffff"
    readonly property color vermLit:  dyn ? Dyn.primary : "#ffffff"
    readonly property color vermDeep: dyn ? Dyn.primaryContainer : "#000000"
    readonly property color cream:    dyn ? Dyn.cream : "#d4d4d4"
    readonly property color bright:   dyn ? Dyn.bright : "#ffffff"
    readonly property color dim:      dyn ? Dyn.dim : "#aaaaaa"
    readonly property color cardTop:  dyn ? Dyn.surfaceContainerHigh : "#111111"
    readonly property color cardBot:  dyn ? Dyn.surfaceContainerLow : "#0a0a0a"
    readonly property color border:   dyn ? Dyn.outlineVariant : "#333333"
    readonly property color shadow:     Qt.rgba(0, 0, 0, 0.55)
    readonly property color tileBg:   dyn ? Dyn.surface : "#000000"
    readonly property color subtle:   dyn ? Dyn.subtle : "#bbbbbb"
    readonly property color faint:    dyn ? Qt.lighter(Qt.color(Dyn.faint), 2.2) : "#bbbbbb"
    readonly property color iconDim:  dyn ? Dyn.iconDim : "#888888"
    readonly property color hair:     Qt.alpha(cream, 0.06)
    readonly property color hairSoft: Qt.alpha(cream, 0.03)
    readonly property color sheen:    Qt.alpha(cream, 0.02)
    readonly property color vermDim:   dyn ? Qt.darker(Dyn.primary, 1.5) : "#aaaaaa"
    readonly property color vermDimDeep: dyn ? Qt.darker(Dyn.primary, 2.2) : "#666666"
    readonly property color vermBurn:  dyn ? Qt.darker(Dyn.primaryContainer, 1.1) : "#444444"
    readonly property color tickRest:  dyn ? Dyn.tickRest : "#888888"
    readonly property color threadBg:  Qt.alpha(cream, 0.08)
    readonly property color flameCore: dyn ? Qt.lighter(onGlow, 1.03) : "#ffffff"
    readonly property color flameGlow: dyn ? onGlow : "#ffffff"

    readonly property string flameInk:   dyn ? Dyn.primary : "#ffffff"
    readonly property string flameEmber: dyn ? Dyn.primaryContainer : "#333333"
    readonly property string flameBurn:  dyn ? Dyn.primaryContainer : "#222222"
    readonly property string flameTip:   dyn ? Dyn.onPrimaryContainer : "#ffffff"
    readonly property color todayWarm: dyn ? onGlow : "#ffffff"
    readonly property color ghost:     dyn ? Dyn.surfaceContainerHighest : "#222222"
    readonly property color frameBg:      Qt.alpha(cream, 0.04)
    readonly property color frameBorder:  Qt.alpha(cream, 0.08)
    readonly property color creamMenu:     Qt.alpha(cream, 0.85)
    readonly property real shadowOpacity: 0.5
    readonly property var fontFamilies: Qt.fontFamilies()
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Inter"
    readonly property string fontJp: "Zen Kaku Gothic New"

    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
