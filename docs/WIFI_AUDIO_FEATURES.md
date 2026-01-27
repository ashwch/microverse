# Wi‑Fi + Audio (and AirPods Battery) — Features & Architecture

Microverse is a **glanceable** system monitor. Wi‑Fi and Audio are two of the most frequently “why is this weird?” signals on macOS, and they fit Microverse’s philosophy well: low-noise status you can read in a second.

This document explains **why** these features exist, **where** they show up, and **how** they’re implemented so future changes stay consistent.

---

## First principles (why we built it this way)

- **Glanceable over exhaustive**  
  We prefer a small set of stable, high-signal fields (status, bars, percent, device name, volume) over power-user dumps.

- **Safe by default**  
  We avoid collecting or displaying sensitive info unless it’s already part of the system’s obvious UI. For Wi‑Fi, that means:
  - we don’t scan for networks
  - SSID is “nice to have” and often redacted on modern macOS anyway

- **Energy-aware**  
  Polling only runs while a UI surface is actually observing the store. Multiple surfaces share the same store so we don’t multiply timers.

- **Respect system routing**  
  Audio changes the **system default** input/output device (like Control Center), rather than inventing a separate routing layer.

---

## Where it shows up (UX surfaces)

### Popover

- **System → Network**
  - Wi‑Fi status (off / disconnected / connected)
  - Strength bars + percent
  - Optional “details” line (RSSI / noise / Tx rate)
  - Aggregate throughput + totals

- **System → Audio**
  - Output devices list (switch default output)
  - Output volume slider + mute toggle (only if supported by the route)
  - Input devices list (switch default input)
  - “Open Sound Settings” button for anything beyond the 90%

### Smart Notch

- Expanded notch shows a **Wi‑Fi tile** and an **Audio tile** (glanceable; no scrolling).
- AirPods battery can subtly tint the Audio tile when “AirPods low battery” alerts are enabled.

### Desktop Widget (Custom)

Custom widget modules:
- **Wi‑Fi** (strength + quality)
- **Audio Output** (device + volume/mute)
- **Audio Input** (device)

---

## Data flow (visual)

```text
BatteryViewModel (shared ownership)
  ├─ WiFiStore              (CoreWLAN, polled)
  ├─ AudioDevicesStore      (CoreAudio, polled + listeners)
  └─ AirPodsBatteryStore    (CoreBluetooth, brief periodic scans; opt-in)

Popover tabs / Smart Notch / Desktop Widget
  └─ read via SwiftUI EnvironmentObject
```

Why `BatteryViewModel` owns these stores:
- The popover, notch, and widget can all be on-screen during the same run.
- Sharing stores avoids duplicated polling and keeps state consistent across surfaces.

---

## Code map (where to look)

### Stores
- Wi‑Fi: `Sources/Microverse/Network/WiFiStore.swift`
- Network throughput: `Sources/Microverse/Network/NetworkStore.swift`
- Audio devices + routing: `Sources/Microverse/Audio/AudioDevicesStore.swift`
- AirPods battery (BLE): `Sources/Microverse/Audio/AirPodsBatteryStore.swift`

### UI surfaces
- Popover network: `Sources/Microverse/Views/NetworkTab.swift`
- Popover audio: `Sources/Microverse/Views/AudioTab.swift`
- Smart Notch tiles: `Sources/Microverse/MicroverseNotchSystem.swift`
- Widget modules: `Sources/Microverse/WidgetModules.swift`, `Sources/Microverse/DesktopWidget.swift`

### Wiring
- Environment injection: `Sources/Microverse/MenuBarApp.swift`
- Shared store ownership: `Sources/Microverse/BatteryViewModel.swift`

---

## Permissions (what we ask the user for)

Microverse is sandboxed, so some features require explicit user permission + entitlement.

### Bluetooth (AirPods battery)

- Info.plist string: `NSBluetoothAlwaysUsageDescription`
- Entitlement: `com.apple.security.device.bluetooth`

**Important:** AirPods battery scanning is opt-in and only runs when the user enables AirPods-related alerting/UI.

### Location (not required for Wi‑Fi strength)

Wi‑Fi strength does **not** request location.  
However, Microverse also supports *Current location weather*, which uses:
- Info.plist string: `NSLocationWhenInUseUsageDescription`
- Entitlement: `com.apple.security.personal-information.location`

---

## How to test (commands + checklist)

### Build + run (bundled)

```bash
make debug-app
open -n /tmp/Microverse.app
```

### Jump to the relevant UI quickly (debug builds)

```bash
# Open directly to System → Network
open -n /tmp/Microverse.app --args --debug-open-system-network

# Open directly to System → Audio
open -n /tmp/Microverse.app --args --debug-open-system-audio
```

### Manual QA checklist

Wi‑Fi:
- Turn Wi‑Fi off → card shows “Wi‑Fi off”
- Disconnect from network → shows “Not connected”
- Connect to network → shows bars + percent (SSID may be “Connected” if redacted)
- Switch networks → updates within a few seconds

Audio:
- Switch default output and confirm the checkmark moves
- Switch default input and confirm the checkmark moves
- Test a route that doesn’t support volume (slider should disable / show “unavailable” text)
- “Open Sound Settings” deep link works (or falls back to System Settings)

AirPods battery (optional):
- Enable Settings → Alerts → “AirPods low battery”
- If Bluetooth permission is denied, UI should show a clear state (not a crash)

Widget modules:
- Settings → Desktop Widget → Custom → add Wi‑Fi / Audio modules
- Confirm widget renders without clipping and values update

---

## Extending the feature safely (how to change things without regrets)

### Adjust polling cadence

All stores take explicit intervals:
- `WiFiStore.start(interval:)`
- `AudioDevicesStore.start(interval:)`
- `AirPodsBatteryStore.start(scanInterval:scanDuration:)`

Keep intervals conservative and only tighten if you have a concrete UX need.

### Add a new widget module

1. Add a new `case` in `Sources/Microverse/WidgetModules.swift`
2. Update widget rendering in `Sources/Microverse/DesktopWidget.swift`
3. If the module needs a new sampler/store, prefer putting it on `BatteryViewModel` and injecting it as an environment object (so popover + notch + widget share it).

### Add device-specific icon logic

Device icons are intentionally heuristic:
- AirPods models are detected by name (`AudioDevicesStore.detectAirPodsModel`)
- Some common headphones are mapped for nicer visuals (e.g. Sony WH‑1000XM*)

When adding new mappings:
- keep it optional (“nice icon” not “business logic”)
- don’t rely on it for correctness (names can vary)
