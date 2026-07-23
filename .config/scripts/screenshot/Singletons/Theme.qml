pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    readonly property color vermilion: "#ffffff"
    readonly property color white:     "#ffffff"
    readonly property color idle:      "#e0e0e0"
    readonly property color sep:       "#222222"

    readonly property color dim:        Qt.rgba(0, 0, 0, 0.75)
    readonly property color glassBg:    Qt.rgba(0, 0, 0, 0.95)
    readonly property color glassBorder: "#1a1a1a"
    readonly property color panelBg:    Qt.rgba(0, 0, 0, 0.98)
    readonly property color panelBorder: "#2a2a2a"

    readonly property color dimIcon: Qt.rgba(1, 1, 1, 0.4)
    readonly property color winFill: Qt.rgba(1, 1, 1, 0.1)
    readonly property color markerYellow: "#ffffff"
    readonly property color stepText: white

    readonly property var swatches: [
        "#ffffff", "#cccccc", "#999999", "#666666", "#333333", "#1a1a1a", "#000000"
    ]

    readonly property string monoFamily: pick(
        ["JetBrains Mono", "JetBrainsMono Nerd Font", "DejaVu Sans Mono", "Liberation Mono"],
        "monospace")
    readonly property string sansFamily: pick(
        ["Inter", "Inter Display", "Noto Sans", "DejaVu Sans", "Liberation Sans"],
        "sans-serif")

    /**
     * Returns the first installed family from prefs, or the generic fallback
     * when none are present. Lets screenshot ship without bundling fonts.
     */
    function pick(prefs, fallback) {
        var fams = Qt.fontFamilies();
        for (var i = 0; i < prefs.length; i++)
            if (fams.indexOf(prefs[i]) !== -1) return prefs[i];
        return fallback;
    }
}
