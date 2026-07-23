# Mixer Module

**File**: `pill/Mixer.qml`

The mixer is a surface in the pill's hover panel that provides hardware controls:
brightness (DDC monitors + internal backlight), nightlight (gammastep), volume,
and microphone. It opens via the hover modules list when the user hovers the
"mixer" slot.

## Layout

```
┌──────────────────────────────────────────────┐
│ 調 MIXER        [spk] [mic] [DND] [醒] [☾]   │  ← header chips
├──────────────────────────────────────────────┤
│                                              │
│ [DDC%] [DDC%] [BL%] [☾ 4500K] [vol%] [mic] │  ← VFader columns
│                                              │
│           (device dropdown overlays)          │
└──────────────────────────────────────────────┘
```

### Header chips (right-aligned row)

| Chip | Glyph | Toggle | Description |
|------|-------|--------|-------------|
| Output device | `speaker` | `DevicePickerChip` | Selects `Pipewire.preferredDefaultAudioSink` |
| Input device | `mic` | `DevicePickerChip` | Selects `Pipewire.preferredDefaultAudioSource` |
| DND | `dnd` | `IconChip` | Toggles `Flags.dnd` |
| Keep Awake | `awake` | `IconChip` | Toggles `Flags.keepAwake` |
| **Night Light** | `moon` | `IconChip` | Toggles `Devices.toggleNightlight()` |

### Fader columns (left to right)

Each fader is a `VFader` (vertical filament fader) with a fill gradient and readout label.

| Position | ID | Icon | Control | Source |
|----------|----|------|---------|--------|
| 0..N-1 | `brFader` | `sun` | DDC monitor brightness | `Devices.ddcMonitors` (per-bus ddcutil) |
| N | `blLoader` | `sun` | Internal backlight | `Devices.backlightPct` (brightnessctl) |
| N+1 | `nightlightFader` | `moon` | Screen warmth | `Devices.nightlightPct` (gammastep) |
| N+2 | `volFader` | `speaker` | Master volume | `Pipewire.defaultAudioSink` |
| N+3 | `micFader` | `mic`/`mic-off` | Mic volume/mute | `Pipewire.defaultAudioSource` |

## Nightlight VFader specifics

Located at index `faderCount - 3`:

```qml
VFader {
    id: nightlightFader
    icon: "moon"
    value: Devices.nightlightPct / 100
    valueLabel: temp + "K"   // e.g. "4500K"
    onMoved: (v) => Devices.nightlightPct = Math.round(v * 100)
    onCommitted: (v) => { pendingNightlight = v * 100; nightlightDebounce.restart(); }
}
```

- **Value**: 0.0 (no warmth) to 1.0 (max warmth)
- **Label**: Temperature in Kelvin, computed as `6500 - nightlightPct * 30`
  - 0% → 6500K (neutral/daylight)
  - 100% → 3500K (max warmth)
- **Live updates**: `onMoved` updates the property immediately for UI feedback
- **Commit debounce**: `onCommitted` stores the value in `pendingNightlight` and
  restarts a 160ms `nightlightDebounce` timer. On timeout, calls
  `Devices.setNightlight(pendingNightlight)` which writes to gammastep and persists.

## Debounce timers

| Timer | Property | Calls | Interval | Purpose |
|-------|----------|-------|----------|---------|
| `nightlightDebounce` | `pendingNightlight` | `Devices.setNightlight()` | 160ms | Debounce gammastep writes |
| `blDebounce` | `pendingBacklight` | `Devices.setBacklight()` | 160ms | Debounce brightnessctl writes |

Each brightness Repeater item also has its own `brCommit` timer (160ms) debouncing
`Devices.setBrightness()` per DDC bus.

## Keyboard navigation

- Arrow keys move focus left/right across faders via `moveFocus(dir)`
- Scroll wheel nudges focused fader by 5% steps via `stepFocused(deltaPct)`
- `keyLatch` timer (250ms) gives keyboard priority over hover targeting
- `focusTickPoint` drives an AME (animated morph effect) bead that glides between faders

## Device dropdowns

`DeviceMenu` component (reused for output and input):
- Floats above faders, right-aligned under the header
- Shows matching nodes (sinks/sources), highlights current default
- Click selects, closes dropdown

## Dependencies

| Import | Usage |
|--------|-------|
| `Quickshell.Services.Pipewire` | Audio volume, sink/source selection |
| `Singletons/Devices.qml` | Nightlight + brightness control |
| `Singletons/Flags.qml` | DND, keep-awake state |
| `Singletons/Theme.qml` | Colours |
| `VFader.qml` | Reusable vertical fader component |
| `GlyphIcon.qml` | Vector icon glyphs |
| `DevicePickerChip` / `IconChip` | Inline header chip components |

## Adding a new fader

1. Add the `VFader` component in the `faderRow` Row (before or after existing faders)
2. Update the `faders` property array in `root` to include the new fader ID
3. Adjust `focused` index math in the new fader (`faderCount - N`)
4. Update `FaderTip` show conditions with the new hover index
5. Add any new debounce timer if needed for the backend write
