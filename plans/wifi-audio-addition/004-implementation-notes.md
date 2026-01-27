# Implementation Notes — Wi‑Fi + Audio

## Code map

- Wi‑Fi store: `Sources/Microverse/Network/WiFiStore.swift`
- Audio store: `Sources/Microverse/Audio/AudioDevicesStore.swift`
- Network UI: `Sources/Microverse/Views/NetworkTab.swift`
- Audio UI: `Sources/Microverse/Views/AudioTab.swift`
- System tab routing: `Sources/Microverse/Views/TabbedMainView.swift`
- Environment wiring: `Sources/Microverse/MenuBarApp.swift`
- Desktop widget wiring/modules: `Sources/Microverse/DesktopWidget.swift`, `Sources/Microverse/WidgetModules.swift`

## Architectural choices

### Shared stores

We treat Wi‑Fi + Audio stores as shared services:
- owned by `BatteryViewModel` so they can be injected into both the popover and Desktop Widget
- accessed via SwiftUI `EnvironmentObject`

### Start/stop safety

Both stores implement a simple **client ref-count** so multiple views can call `start()`/`stop()` without stepping on each other.

## Manual test checklist

### Wi‑Fi

- Wi‑Fi on + connected: strength bars show, percent non‑nil, details line stable.
- Wi‑Fi off: “Wi‑Fi off” state, no bogus RSSI.
- Disconnected: “Not connected” state.
- Switch networks: card updates within a few seconds.

### Audio

- Output device switching works (checkmark updates).
- Input device switching works.
- Output volume changes reflect in the system and UI stays in sync.
- For routes without volume control: slider hidden/disabled and we show the “unavailable” hint.

### Widget modules

- Add Wi‑Fi / Audio modules in Settings → Desktop Widget → Custom.
- Widget renders without clipping and values update.

## Known limitations

- Wi‑Fi SSID may be nil on some macOS setups due to privacy; we treat this as “Connected” if link metrics exist.
- Audio input level meter is not implemented yet (requires additional CoreAudio metering work).

