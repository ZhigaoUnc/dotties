# Coding Conventions

These conventions must be followed by any AI editing this codebase.

## General

- **Language**: QML (Qt Quick) with JavaScript expressions
- **No comments**: Do NOT add `//` or `/* */` comments unless the existing code style
  explicitly includes them (some files use doc-comment blocks). If you need to explain
  something, the code should be self-documenting.
- **Qt imports**: Use these standard imports:
  - `QtQuick`, `QtQuick.Effects`, `QtQuick.Shapes`
  - `Quickshell`, `Quickshell.Io`, `Quickshell.Wayland`
  - `Quickshell.Hyprland`, `Quickshell.I3`
  - `Quickshell.Services.Pipewire`, `Quickshell.Services.Mpris`
  - `Quickshell.Services.Notifications`, `Quickshell.Services.SystemTray`
- **No emoji**: Never use emoji in code or comments

## Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Files | PascalCase | `Mixer.qml`, `Devices.qml` |
| QML components | PascalCase | `IconChip`, `VFader` |
| IDs | camelCase | `nightlightFader`, `blDebounce` |
| Properties | camelCase | `nightlightPct`, `faderCount` |
| Functions | camelCase | `toggleNightlight()` |
| Signals | camelCase | `moved(real v)`, `committed(real v)` |
| Constants | camelCase | (no ALL_CAPS) |
| JS variables | camelCase | `var temp`, `var raw` |

## Singletons

- Use `pragma Singleton` at the top
- All properties accessed as `SingletonName.propertyName` (e.g. `Devices.nightlightPct`)
- Import singletons as `import "Singletons"` (relative path, not module)

## Component structure pattern

```qml
import QtQuick
import "Singletons"

Item {
    id: root

    // 1. Properties
    property real s: 1
    property real value: 0.5
    property bool focused: false

    // 2. Signals
    signal moved(real v)
    signal committed(real v)

    // 3. Readonly / computed properties
    readonly property point tickCenter: { ... }

    // 4. Child items (visual tree)
    Item { ... }
    Rectangle { ... }
    MouseArea { ... }
}
```

## VFader component usage

The `VFader` is a reusable vertical fader. Required interface:

| Property/Signal | Type | Description |
|-----------------|------|-------------|
| `s` | real | Scale factor |
| `icon` | string | Glyph name from GlyphIcon |
| `value` | real | 0.0 to 1.0 |
| `valueLabel` | string | Display text (e.g. `"42%"`, `"4500K"`) |
| `focused` | bool | Whether this fader has keyboard/hover focus |
| `moved(v)` | signal | Emitted during drag with 0..1 value |
| `committed(v)` | signal | Emitted on drag release with 0..1 value |
| `step(deltaPct)` | function | Programmatic nudge by ±percent |

## GlyphIcon usage

Self-contained vector icons. Available glyph names (see `GlyphIcon.qml:23-89`):

`sun`, `moon`, `cloud`, `droplet`, `check`, `arrow-up`, `speaker`,
`speaker-off`, `mic`, `mic-off`, `dnd`, `awake`, `monitor`, `lock`,
`music`, `play`, `pause`, `next`, `prev`, `bolt`, `wifi`, `bluetooth`,
`cog`, `clock`, `close`, `trash`, `shutdown`, `reboot`, `suspend`,
`mixer`, `sparkles`, `palette`, and more.

Usage:
```qml
GlyphIcon {
    width: 15 * root.s
    height: 15 * root.s
    name: "moon"
    color: Theme.vermLit
    stroke: 1.7
}
```

## Scaling

Every surface uses a scale factor `s` derived from `screen.height / 1080`.
All dimensions must be multiplied by `s`:
```qml
property real s: 1  // set by parent surface

width: 26 * root.s
height: 26 * root.s
radius: 8 * root.s
```

## External commands

Use `Quickshell.execDetached(args)` for fire-and-forget shell commands:
```qml
Quickshell.execDetached(["gammastep", "-PO", String(temp)]);
// or with shell features:
Quickshell.execDetached(["sh", "-c", "killall gammastep 2>/dev/null; gammastep -PO " + String(temp)]);
```

For reading command output, use `Process` + `StdioCollector`:
```qml
Process {
    command: ["ddcutil", "detect", "--brief"]
    running: false
    stdout: StdioCollector {
        onStreamFinished: { /* parse this.text */ }
    }
}
```

## Debounce pattern

For slider values that trigger external commands:

```qml
property real pendingValue: -1

Timer {
    id: debounceTimer
    interval: 160
    onTriggered: if (root.pendingValue >= 0) {
        Backend.setValue(root.pendingValue);
        root.pendingValue = -1;
    }
}

// On commit:
onCommitted: (v) => { root.pendingValue = v * 100; debounceTimer.restart(); }
```

## Theme colours

Always reference `Theme.*` for colours, never hardcode:
- `Theme.cream` — primary text
- `Theme.subtle` — secondary text
- `Theme.dim` — dim text
- `Theme.faint` — faintest text
- `Theme.vermLit` — accent (active/focused)
- `Theme.vermBurn` — accent dark
- `Theme.vermDim` / `Theme.vermDimDeep` — accent dim (inactive)
- `Theme.iconDim` — icon colour
- `Theme.cardTop` / `Theme.cardBot` — card gradient
- `Theme.border` / `Theme.frameBorder` — borders
- `Theme.frameBg` — frame background
- `Theme.hair` / `Theme.hairSoft` — ultra-thin dividers
- `Theme.sheen` — subtle highlight
- `Theme.threadBg` — VFader track background
