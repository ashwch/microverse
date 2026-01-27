# Weather — Locations, Current Location, and Alerts

Microverse’s Weather feature is designed for **glances**, not “full weather app” depth:
- current temperature
- an “up next” change
- optional compact-surface peeks (Smart Notch + Desktop Widget)

This document explains the **why** behind the Weather architecture, how multi-location + current location work, and how notch glow weather alerts are scheduled.

---

## First principles (why the system is shaped this way)

- **Weather must work in real release artifacts**  
  WeatherKit is great when authorized, but it can fail in ad-hoc / CI / signing-mismatch contexts. Microverse uses a provider chain:
  - WeatherKit when available
  - Open‑Meteo fallback when WeatherKit isn’t available

- **No hot polling**  
  Weather refreshes on a user-configurable interval (default 30 minutes) and uses debounced refresh triggers while settings are changing.

- **Current location is opt-in and coarse**  
  If enabled, Microverse requests **When In Use** and uses kilometer accuracy. Weather doesn’t need GPS precision.

- **Multi-location should not become a background sync engine**  
  We only refresh many locations automatically when that information is actively used on a compact surface (pinned + cycling).

- **Alerts must not spam**  
  Weather alerts are opt-in, cooldown-protected, and driven by existing state (`WeatherStore.nextEvent`) rather than background polling loops.

---

## What shows up where (UX surfaces)

- **Popover → Weather tab**
  - Current temperature + fetch status (“Live / Stale / Error”)
  - “Up next” event and a small hourly strip
  - Location list when multiple locations (or current location) are configured
  - Attribution that matches the provider actually used

- **Menu bar (optional)**
  - Temperature next to the icon when enabled

- **Smart Notch (optional)**
  - Compact “peeks” and pinned temperature modes
  - Expanded notch shows a richer weather row

- **Desktop Widget (optional)**
  - System Glance can swap in weather based on `DisplayOrchestrator` scheduling rules

- **Notch glow alerts (optional)**
  - A subtle glow shortly before an upcoming event (lead time), with cooldown protection

---

## Data flow (visual)

```text
WeatherSettingsStore  (UserDefaults, selected location(s), current-location toggle)
  ├─ WeatherCurrentLocationController  (CoreLocation; coarse updates)
  └─ WeatherPlacemarkNameFormatter     (CLPlacemark → display name)

WeatherStore          (selected location only)
  ├─ WeatherProviderFallback (WeatherKit → Open‑Meteo)
  ├─ WeatherDiskCache        (per-location cache)
  └─ WeatherEventDetector    (“Up next” event)

WeatherLocationsStore (summaries for multiple saved locations)
  └─ WeatherDiskCache (cache of summaries)

WeatherAlertEngine    (schedules notch glow for next event)
  └─ NotchGlowManager (renders in-notch glow; see NOTCH_FEATURES.md)
```

---

## Code map (where to look)

Core:
- Settings + persistence: `Sources/Microverse/Weather/WeatherSettingsStore.swift`
- Selected-location store: `Sources/Microverse/Weather/WeatherStore.swift`
- Multi-location summaries: `Sources/Microverse/Weather/WeatherLocationsStore.swift`
- Current location plumbing: `Sources/Microverse/Weather/WeatherCurrentLocationController.swift`
- Placemark naming: `Sources/Microverse/Weather/WeatherPlacemarkNameFormatter.swift`

Provider chain:
- Provider protocol: `Sources/Microverse/Weather/WeatherProvider.swift`
- Fallback implementation: `Sources/Microverse/Weather/WeatherProviderFallback.swift`
- WeatherKit provider: `Sources/Microverse/Weather/WeatherKitProvider.swift`
- Open‑Meteo provider: `Sources/Microverse/Weather/OpenMeteoProvider.swift`

Events + alerts:
- “Up next” logic: `Sources/Microverse/Weather/WeatherEventDetector.swift`
- Alert scheduling: `Sources/Microverse/Weather/WeatherAlertEngine.swift`

UI:
- Popover weather UI: `Sources/Microverse/Views/WeatherTab.swift`
- Settings UI: `Sources/Microverse/Views/WeatherSettingsSection.swift`
- Alerts settings UI: `Sources/Microverse/Views/WeatherAlertsSection.swift`

App wiring:
- Provider construction + store wiring: `Sources/Microverse/MenuBarApp.swift` (search `makeWeatherProvider()`)

---

## Permissions (current location)

Current location weather requires:
- Info.plist string: `NSLocationWhenInUseUsageDescription`
- Sandbox entitlement: `com.apple.security.personal-information.location`

Microverse only requests location permission when the user enables “Current location”.

---

## How to test (commands + checklist)

### Build + run (bundled)

```bash
make debug-app
open -n /tmp/Microverse.app
```

### One-shot fetch (prints and quits)

```bash
open -n /tmp/Microverse.app --args --debug-weather-fetch
```

### Deterministic demo runner (exercises notch + widget)

```bash
open -n /tmp/Microverse.app --args --debug-weather-demo
```

### Manual QA checklist

Locations:
- Enable Weather → set a manual location via search → relaunch → confirm it persisted
- Add a second location → confirm the location list appears and selection works

Current location:
- Enable “Current location” → verify permission flow (notDetermined → allow/deny)
- If denied, UI should show a clear message + System Settings CTA
- If allowed, Weather should show “Current Location” quickly, then resolve a city name later

Alerts:
- Enable Notch Glow Alerts (and ensure a notched Mac is available)
- Enable Weather Alerts → pick rules + lead time + cooldown
- Confirm “Next” reflects the current `WeatherStore.nextEvent`

Failure behavior:
- Temporarily disconnect network → Weather should show “stale cached” (if cache exists) or a clear error, not a spinner forever

---

## Extending the feature safely (how to change things without regrets)

### Add a new “Up next” event kind

1. Teach `WeatherEventDetector` how to detect it.
2. Decide how it should render in compact surfaces (glyph + copy).
3. If it should trigger alerts, map it in:
   - `WeatherSettingsStore` (add a toggle + key)
   - `WeatherAlertsSection` (UI toggle)
   - `WeatherAlertEngine.shouldAlert(for:)` (rule gating)

### Change alert timing behavior

Weather alerts are intentionally conservative:
- lead time: “warn me before it starts”
- cooldown: “don’t repeat within X”

If you change scheduling, ensure:
- tasks are canceled on input changes (to prevent “stale alerts”)
- cooldown is always enforced
- nothing runs while Weather is disabled

### Change multi-location refresh behavior

`WeatherLocationsStore` runs periodic refresh only when multi-location is actively visible/valuable.
If you broaden that condition, validate energy impact (avoid “background sync” behavior).

