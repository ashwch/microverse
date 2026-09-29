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
- **Disk**: the expanded panel always shows startup-volume usage as a fourth System Health metric (with "N GB free" in the summary line). The compact pill and the center slot only add the disk metric once it needs attention (80% full and up), so the pill stays short in normal conditions.
- **Center slot (no physical notch only)**: on external displays or with the lid closed, DynamicNotchKit still reserves a notch-sized gap in the middle. Microverse fills it with Wi‑Fi signal, output volume, and (when enabled for the notch) weather, in the same status colors as the rest of the app. On a screen with a real notch that gap is the camera housing and the slot is never drawn.
- **Off**: disables notch UI

### Weather (optional)

When Weather is enabled (Settings → **Weather**) and “Show in Smart Notch” is on, Microverse can:

- Peek weather in the compact notch (rotation peeks or event-driven highlights). The peek is a cycle, not a single temperature:
  1. current conditions and temperature;
  2. up to three upcoming changes in the next six hours (rain, clearing, storm, fog, cooler, warmer) with their lead time, colored on the shared status scale;
  3. from 9 PM until 5 AM local, the coming daytime's high/low and a prep hint (cooler, warmer, rain, snow, storms). It says "tomorrow" before midnight and "today" after.
  Each slide holds 3 s and every slide is laid out up front, so the pill takes its widest slide's width from the first frame and nothing shifts. When nothing is changing there is only the current slide and the peek ends quickly. Logic: `Sources/Microverse/Weather/WeatherPeekPlanner.swift`, view: `Sources/Microverse/Weather/WeatherPeekView.swift`. The desktop widget's weather tile plays the same cycle.
- Pin temperature in the compact notch (replaces CPU or Memory)
- Show a small weather row in the expanded notch

### Interaction (optional)

- **Click notch to show details**: toggles expanded/compact Smart Notch view (Settings → **Smart Notch**)

## Launch intro

When the notch UI is enabled and “startup animation” is on (Settings → Alerts), launching plays a short sequence in the compact pill, in whichever layout the user has:

1. “microverse” types out letter by letter in mascot green, monospaced, with a blinking block cursor (an old-phone-keypad feel). In the **Split** layout the word crosses the notch: “micro” types in the left slot, then “verse” continues in the right slot; in **Left** the whole word types on the left;
2. it holds, then fades;
3. the startup glow runs around the empty notch;
4. the metrics fade in under the remaining light passes.

Logic: `Sources/Microverse/NotchIntro.swift` (`NotchIntroController` phases; the compact views show the typing pill while `showsText` and hide their metrics while `hidesMetrics`). Wired from `BatteryViewModel.handleAppLaunchCompleted`. Screenshot automation skips it.

## Notch Glow Alerts

Notch Glow Alerts render a glow + sweep + sparkles around the notch pill when key battery events occur. Every trigger is also published app-wide (`NotchGlowInNotchController`), and the desktop widget plays the same animation around its card (`DesktopWidgetGlow` in `Sources/Microverse/DesktopWidget.swift`), so the widget still glows with the lid closed or the notch UI off. The widget window carries a transparent margin for that ring.

### Rules (when it triggers)

Rules are split by “signal source”, but they share the same gating:
- `enableNotchAlerts` must be **ON**
- A notched display must be available (`isNotchAvailable`)

#### Battery rules

Implemented in `Sources/Microverse/BatteryViewModel.swift` (`checkAndTriggerAlerts()`):

- Triggers:
  - **Charger connected**: `isPluggedIn` flips `false -> true`
  - **Fully charged**: battery reaches `100%` while plugged in
  - **Low battery**: crossing below `20%` while on battery power (fires once until recovery > 20%)
  - **Critical battery**: `<= 10%` while on battery power (fires once until recovery > 10%)

#### Device rules (AirPods)

Implemented in `Sources/Microverse/BatteryViewModel.swift` (`checkAndTriggerAirPodsLowBatteryAlert(...)`):

- Requires:
  - AirPods rule enabled (Settings → **Alerts** → **Notch Glow Alerts** → Devices → “AirPods low battery”)
  - Bluetooth permission (for best-effort BLE scanning)
  - Default output is detected as AirPods
- Trigger:
  - **AirPods low battery**: crossing below the configured threshold (fires once until recovery above threshold)

#### Weather rules

Implemented in `Sources/Microverse/Weather/WeatherAlertEngine.swift`:

- Requires:
  - Weather enabled + a selected location
  - Weather Alerts enabled (Settings → **Alerts** → Weather Alerts)
  - Lead time + cooldown configuration
- Trigger:
  - A glow shortly before the next weather “upcoming change” event (based on lead time), with cooldown protection.
- Storage rule (Settings → **Alerts** → **Devices & storage** → “Low disk space”, on by default): orange glow when the startup volume crosses 90% full or under 10 GB free, red at 95% or under 5 GB, once per crossing. Polled every five minutes by `BatteryViewModel`, independent of any visible surface.

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

Settings → **Alerts** → **Notch Glow Alerts** → **Advanced** (Success/Warning/Critical/Info).

For AirPods:
- Settings → **Alerts** → **Notch Glow Alerts** → **Devices** → enable “AirPods low battery”
- (Optional) Use the built-in debug override buttons to force a low-battery state for a few seconds.

### Via debug argument

Microverse supports a CLI arg to show a glow shortly after launch:

- `--debug-notch-glow=success|warning|critical|info`

Example:

```bash
open -n /tmp/Microverse.app --args --debug-notch-glow=success
```

## Related docs

- `docs/WEATHER_LOCATIONS_AND_ALERTS.md` (how Weather alerts are scheduled)
- `docs/WIFI_AUDIO_FEATURES.md` (AirPods battery scanning + audio tiles)
