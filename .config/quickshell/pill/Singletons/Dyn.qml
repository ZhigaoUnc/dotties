pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string surface: adapter.surface
    readonly property string surfaceContainer: adapter.surface_container
    readonly property string surfaceContainerLow: adapter.surface_container_low
    readonly property string surfaceContainerHigh: adapter.surface_container_high
    readonly property string surfaceContainerHighest: adapter.surface_container_highest
    readonly property string primary: adapter.primary
    readonly property string primaryContainer: adapter.primary_container
    readonly property string onPrimaryContainer: adapter.on_primary_container
    readonly property string outline: adapter.outline
    readonly property string outlineVariant: adapter.outline_variant
    readonly property string cream: adapter.cream
    readonly property string bright: adapter.bright
    readonly property string subtle: adapter.subtle
    readonly property string dim: adapter.dim
    readonly property string faint: adapter.faint
    readonly property string iconDim: adapter.icon_dim
    readonly property string tickRest: adapter.tick_rest

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dingaling/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string surface: "#000000"
            property string surface_container: "#0a0a0a"
            property string surface_container_low: "#050505"
            property string surface_container_high: "#141414"
            property string surface_container_highest: "#1e1e1e"
            property string primary: "#ffffff"
            property string primary_container: "#2a2a2a"
            property string on_primary_container: "#ffffff"
            property string outline: "#555555"
            property string outline_variant: "#2a2a2a"
            property string cream: "#d4d4d4"
            property string bright: "#ffffff"
            property string subtle: "#999999"
            property string dim: "#777777"
            property string faint: "#444444"
            property string icon_dim: "#777777"
            property string tick_rest: "#888888"
        }
    }
}
