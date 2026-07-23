# Architecture

## Overview

This is the **dingaling** desktop configuration for **Quickshell** (Qt Quick / Wayland shell).
Five independent `ShellRoot` processes run as separate daemons, spawned by a session manager,
communicating indirectly via shared JSON files and system IPC.

```
quickshell/
├── pill/         # Primary settings/control surfaces (hover menu)
├── lock/         # Session lock screen + PAM auth + audio-reactive glow
├── launcher/     # Desktop entry launcher with fuzzy search
├── sidebar/      # Quick settings sidebar (audio, network, BT, display)
├── topbar/       # Per-monitor top bar (workspaces, clock, tray, MPRIS)
└── docs/         # This documentation
```

## Module communication

| Mechanism | Purpose |
|-----------|---------|
| `dingaling/flags.json` | Shared state (DND, keep-awake, UI prefs). Written by pill, read by all |
| `qs -c <module> ipc call <target> <method>` | Cross-module IPC via `dms ipc` |
| `IpcHandler` | In-process IPC per module (e.g. pill opens surfaces) |
| `FileView` + `watchChanges` | File-based reactive state (flags, events, cliphist) |

## Per-module summary

### Pill (`pill/shell.qml`)
The central "hover" panel. A floating, morphable pill anchored at top-centre on each
monitor. Collapsed by default (shows a small rest pill), expands on hover to reveal
a header row and surface content. Surfaces are loaded on demand via IPC.

- **Window model**: Two layer-shell windows per monitor:
  - `reserve` — zero-content strip claiming exclusive zone
  - `overlay` — fullscreen transparent overlay hosting the pill
- **Surface registry**: Maps string keys (`"mixer"`, `"recorder"`, etc.) to QML components
- **15 singletons**: Theme, Flags, Devices, Notifs, Cliphist, Walls, Battery, ScreenRec,
  Sysmon, Dyn, Weather, Events, Workspacerules, Cava, Motion

### Sidebar (`sidebar/shell.qml`)
Per-monitor top-right panel (372px wide). Two tabs: Quick Settings + Notifications.
Uses static Theme (no dynamic palette).

### Topbar (`topbar/shell.qml`)
Per-monitor top edge bar (34px tall). Left: logo + workspaces. Center: clock.
Right: MPRIS + minimized windows + tray + sidebar toggle + power.

### Launcher (`launcher/shell.qml`)
Desktop entry launcher popup (540px wide). Desktop entry + keybind search.
Usage tracking persisted to JSON state file.

### Lock (`lock/shell.qml`)
Full-screen lock screen with PAM auth, per-monitor blurred wallpaper,
audio-reactive glow visualization, 3-attempt lockout, exponential backoff.

## Key patterns

- **Scaling**: Every surface uses `s` derived from `screen.height / 1080`
- **Icons**: Self-contained vector glyphs (`GlyphIcon`) with baked SVG path data
- **Colour tokens**: `Theme.qml` singleton, either dynamic (matugen) or static fallback
- **Pixel-snapped**: Dark-on-black aesthetic with `vermLit` (teal/green accent)
