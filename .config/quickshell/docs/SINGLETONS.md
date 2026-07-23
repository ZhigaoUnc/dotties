# Singletons Reference (Pill module)

All live in `pill/Singletons/`. Declared with `pragma Singleton` and imported
as `import "Singletons"` — usable without instantiation.

---

## `Theme.qml` — Colour tokens

Provides named colour properties derived from either `Dyn` (dynamic matugen palette)
or static fallback values. All surfaces reference `Theme.*` for colours.

Key properties (all `readonly property color`):

| Property | Dynamic source | Static fallback |
|----------|---------------|-----------------|
| `onGlow` | `Dyn.primary` | `#ffffff` |
| `verm` | `darker(Dyn.primary, 1.18)` | `#222222` |
| `vermLit` | `Dyn.primary` | `#333333` |
| `vermDeep` | `Dyn.primaryContainer` | `#111111` |
| `cream` | `Dyn.cream` | `#ffffff` |
| `cardTop` | `Dyn.surfaceContainerHigh` | `#000000` |
| `cardBot` | `Dyn.surfaceContainerLow` | `#000000` |
| `border` | `Dyn.outlineVariant` | `#1a1a1a` |
| `subtle` | `Dyn.subtle` | `#888888` |
| `faint` | `Dyn.faint` | `#555555` |
| `iconDim` | `Dyn.iconDim` | `#888888` |
| `hair` | `alpha(cream, 0.08)` |
| `vermDim` | `darker(Dyn.primary, 1.5)` |
| `vermDimDeep` | `darker(Dyn.primary, 2.2)` |
| `vermBurn` | `darker(Dyn.primaryContainer, 1.1)` |
| `threadBg` | `alpha(cream, 0.08)` |
| `frameBg` | `alpha(cream, 0.04)` |
| `frameBorder` | `alpha(cream, 0.08)` |

Also:
- `font` — from `Flags.uiFont` or `"Inter"`
- `fontJp` — `"Zen Kaku Gothic New"`

---

## `Flags.qml` — Persisted user preferences

Watched JSON file at `$XDG_STATE_HOME/dingaling/flags.json`. All properties
are `alias` to a `JsonAdapter` for automatic read/write.

Key toggles:

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `dnd` | bool | false | Do Not Disturb |
| `keepAwake` | bool | false | Block sleep/screen-off |
| `time12h` | bool | false | 12h clock format |
| `clockSeconds` | bool | false | Show seconds |
| `showGlyphs` | bool | true | Show Japanese glyphs in headers |
| `paletteMode` | string | `"static"` | `"static"` or `"dynamic"` |
| `uiFont` | string | `""` | Override UI font |
| `reduceMotion` | bool | false | Reduced animations |
| `pillOpacity` | real | 1.0 | Pill background opacity |
| `pillBlur` | bool | false | Background blur |

---

## `Devices.qml` — Hardware control

Controls screen nightlight (gammastep) and external-monitor brightness (ddcutil).

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `nightlightPct` | int | 0 | Nightlight slider, 0-100, maps to 6500K-3500K |
| `nightlightEnabled` | bool | false | Whether nightlight gamma is active |
| `ddcMonitors` | array | `[]` | DDC-capable monitors: `[{bus, label}]` |
| `backlightPresent` | bool | false | Internal backlight found under /sys/class/backlight |
| `backlightPct` | int | 75 | Internal backlight level 0-100 |

### Functions

| Function | Description |
|----------|-------------|
| `restore()` | Load persisted nightlight percent and apply if > 0 |
| `toggleNightlight()` | Toggle nightlight on (apply gamma) / off (kill gammastep) |
| `setNightlight(pct)` | Set nightlight percent, saves and applies |
| `applyNightlight(pct)` | Run `gammastep -PO <temp>` (6500K - pct*30) |
| `saveNightlight(pct)` | Persist to state file |
| `detect()` | Start DDC and backlight detection processes |
| `setBrightness(bus, pct)` | Set monitor brightness via `ddcutil setvcp 10` |
| `setBacklight(pct)` | Set internal backlight via `brightnessctl` |
| `parseBrightness(text)` | Parse `ddcutil getvcp --brief` output |

### State file

`$XDG_STATE_HOME/dingaling/gammastep-value` — stores the nightlight percent as plain text.

### Nightlight mapping

```
Slider 0%  → gammastep -PO 6500K (no effect, daylight)
Slider 50% → gammastep -PO 5000K (mild warmth)
Slider 100% → gammastep -PO 3500K (max warmth, candlelight)
```

Uses `gammastep` (tool for Wayland gamma control via `wlr-gamma-control` protocol).

---

## `Notifs.qml` — Notifications

Tracks notifications via `NotificationServer`. Key features:
- Coalescing (same-app notifications grouped)
- History buffer (last 50)
- Urgency-based expiry
- Groups by app name
- DND-aware

---

## `Cliphist.qml` — Clipboard history

Bridges to `cliphist` tool. Properties:
- `items` — clipboard history entries
- `search(query)` — filter history

Uses `wl-paste` watcher and generates thumbnails for image content.

---

## `Dyn.qml` — Dynamic matugen palette

Watches `$XDG_CACHE_HOME/dingaling/matugen.json` and exposes palette colours:
`bg1`, `bg2`, `fg1`, `fg2`, `accent`, `accentLit`, `primary`, `primaryContainer`,
`surface`, `surfaceContainerHigh/Low`, `outlineVariant`, and more.

---

## `ScreenRec.qml` — Screen recording

Backend for `gpu-screen-recorder`. Builds argv from Flags, starts/stops capture,
polls recording state. Uses `slurp` for region/window selection.

---

## `Sysmon.qml` — System monitor

Polls CPU, GPU, memory, network, disk on three cadences via `setInterval`.
Consumed by `SysmonSurface.qml` (270° arc dials + data cells).

---

## `Weather.qml` — Weather

Open-Meteo API. Auto-location via ip-api or geocoding. Icons from Font Awesome.
Properties: `current`, `hourly`, `daily`.

---

## `Events.qml` — Calendar events

Local JSON persistence (`events.json`). Monotonic IDs. Functions: `add()`, `remove()`, `list()`.

---

## `Battery.qml` — Power

Laptop battery state from UPower. Properties: `percent`, `charging`, `timeToEmpty`, `timeToFull`.

---

## `Walls.qml` — Wallpaper manager

Tracks wallpaper files, applies via Hyprland or other backend.

---

## `Workspacerules.qml` — Workspace overrides

Custom workspace naming and per-monitor range overrides for I3 workspaces.

---

## `Motion.qml` — Animation durations

Reduced-motion-aware timing values:
- `standard` — default animation duration
- `fast` — quick animation
- `slow` — slow animation

Honours `Flags.reduceMotion`.

---

## `Cava.qml` — Audio visualiser

MPRIS playback tracking with 1.5s hold timer. Used by lock screen glow field.
