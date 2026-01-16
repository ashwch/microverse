# Notch Features (Smart Notch + Notch Glow)

Microverse includes optional notch-specific UI for MacBooks with a built-in camera housing (“the notch”).

## Requirements

- **macOS 13.0+**
- Built-in display with a notch (Microverse checks `NSScreen.safeAreaInsets` + `auxiliaryTopLeftArea/right`)

## Smart Notch

Smart Notch displays Microverse system stats around the notch using DynamicNotchKit.

### Layout modes

Configured in Settings → **Smart Notch**:

- **Left**: all metrics on the left side
- **Split**: battery on the left, CPU + Memory on the right
- **Off**: disables notch UI

### Weather (optional)

When Weather is enabled (Settings → **Weather**) and “Show in Smart Notch” is on, Microverse can:

- Peek temperature in the compact notch (rotation peeks or event-driven highlights)
- Pin temperature in the compact notch (replaces CPU or Memory)
- Show a small weather row in the expanded notch

### Interaction (optional)

- **Click notch to show details**: toggles expanded/compact Smart Notch view (Settings → **Smart Notch**)

## Notch Glow Alerts

Notch Glow Alerts render a glow + sweep + sparkles around the notch pill when key battery events occur.

### Rules (when it triggers)

Implemented in `Sources/Microverse/BatteryViewModel.swift` (`checkAndTriggerAlerts()`):

- `enableNotchAlerts` must be **ON**
- A notched display must be available (`isNotchAvailable`)
- Triggers:
  - **Charger connected**: `isPluggedIn` flips `false -> true`
  - **Fully charged**: battery reaches `100%` while plugged in
  - **Low battery**: crossing below `20%` while on battery power (fires once until recovery > 20%)
  - **Critical battery**: `<= 10%` while on battery power (fires once until recovery > 10%)

### Motion + timing

Implemented in `Sources/Microverse/NotchGlowManager.swift`:

- **Success (charging / full)**: `pingPong` motion (anticlockwise then clockwise) and slower timing for “charger connected”
- **Warning / Critical / Info**: looping sweep

### Startup animation (optional)

If enabled, Microverse plays a short 1-time-per-run startup animation:

- RGB-ish sequence (red/green/blue), shuffled order per run
- Mixed motion styles for a “boot” feel

Controlled by:

- Settings → **Notch Glow Alerts** → **Startup Animation**
- `enableNotchStartupAnimation` in `BatteryViewModel`

## How we keep the glow aligned

The glow is rendered **inside DynamicNotchKit’s SwiftUI tree** (as a decoration overlay), so it shares:

- the exact pill geometry
- compact-only horizontal offset (`.offset(x:)`)
- hover/expand transitions

This avoids the classic “hardware notch vs software pill” mismatch that happens with separate overlay windows.

## Testing

### From Settings

Settings → **Notch Glow Alerts** → **Test Alerts** (Success/Warning/Critical/Info).

### Via debug argument

Microverse supports a CLI arg to show a glow shortly after launch:

- `--debug-notch-glow=success|warning|critical|info`

Example:

```bash
open -n /tmp/Microverse.app --args --debug-notch-glow=success
```
