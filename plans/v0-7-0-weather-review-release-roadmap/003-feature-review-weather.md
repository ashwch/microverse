# 003 - Feature Review: Weather

## Goal

Validate the Weather feature end-to-end (UX, correctness, polish, accessibility, offline behavior) across all Microverse surfaces.

## Dependencies

- Requires: 002
- Blocks: 005 (don’t ship without feature review)

## Scope

**In scope:**
- Weather settings (enable/disable, units, refresh, location search, **optional current location**).
- Weather UI surfaces: popover Weather tab, menu bar temperature, compact notch peeks/pinned, expanded notch detail, desktop widget swap.
- Provider fallback behavior (WeatherKit → Open‑Meteo).
- Error handling and stale-cache behavior.
- Optional Weather Alerts (notch glow scheduling).

**Out of scope:**
- Refactoring and performance tuning beyond obvious UX-impacting problems (see `004-code-review-checklist.md` for deeper review).

## Checklist

- [ ] Validate defaults (fresh install / cleared prefs):
  - Weather defaults to **off** (`WeatherSettingsStore.weatherEnabled == false`)
  - Default “show in …” toggles exist but have no effect until Weather is enabled
- [ ] Enable Weather in Settings and confirm the Weather tab transitions:
  - “Weather is off.” → “No location set.” → actual forecast cards
- [ ] Set a location via search:
  - Search a city name in Settings → Weather → Location (uses geocoding, not device GPS)
  - Select a result and confirm the display name is reasonable and persists across relaunch
- [ ] (Optional) Validate Current Location:
  - Enable “Current location” in Settings → Weather
  - Verify the macOS permission prompt (Allow / Don’t Allow)
  - If allowed:
    - Weather shows “Current Location” quickly (neutral name), then resolves a city/region name later
    - Location updates are *coarse* (no jitter; doesn’t spam updates on tiny movement)
  - If denied/restricted:
    - UI shows a clear error state and a System Settings path to fix it
- [ ] Verify popover Weather tab behavior:
  - Current temperature renders with a stable layout (monospaced digits, no jank while loading)
  - Manual refresh button updates state correctly
  - “Updated …” relative time increments without heavy CPU usage
  - Attribution card switches depending on provider used
- [ ] Verify menu bar temperature (when enabled):
  - Toggle “Show in Menu Bar” and confirm temperature appears next to the icon
  - Confirm truncation/spacing in narrow menu bars (small screens, many icons)
- [ ] Verify Smart Notch weather (when notch is enabled/available):
  - Toggle “Show in Smart Notch”
  - Use “Show now” preview to force a weather peek
  - Toggle “Pinned temperature” and confirm it replaces the selected compact metric (CPU or Memory)
  - Toggle “Occasional temperature peek” and confirm it rotates at the configured interval without being distracting
- [ ] Verify expanded notch Weather polish:
  - Expand the notch and confirm the weather row appears only when Weather is enabled and “Show in Smart Notch” is enabled
  - Confirm it doesn’t regress notch glow alignment (glow stays in-pill)
- [ ] Verify desktop widget Weather swap (when widget is enabled):
  - Toggle “Show in Desktop Widget”
  - Confirm the System Glance widget can display Weather (and returns to system metrics when disabled)
- [ ] (Optional) Verify Weather Alerts (notch glow):
  - Enable Settings → Alerts → Notch Glow Alerts
  - Enable Settings → Alerts → Weather Alerts
  - Choose rules + lead time + cooldown and confirm the “Next” event is shown
  - Confirm alerts do not spam (cooldown respected; toggles disable immediately)
- [ ] Validate offline / failure behavior:
  - Temporarily disable network or block the provider
  - Confirm the UI shows “stale cached” or a clear error and does not spin forever
  - Confirm Weather does not crash the app when fetch fails
- [ ] Accessibility / motion:
  - With “Reduce Motion” enabled, confirm animated icons degrade appropriately
  - Confirm text contrast and font sizes are readable in the popover cards

## Tests

- [ ] Manual QA: run the Weather debug demo to exercise notch+widget surfaces:
  - `make debug-app`
  - `open -n /tmp/Microverse.app --args --debug-weather-demo`
- [ ] Manual QA: force-open the Weather tab on launch:
  - `open -n /tmp/Microverse.app --args --debug-open-weather`

## Completion Criteria

- [ ] Weather can be enabled, configured, and disabled without leaving stale UI artifacts in the menu bar, notch, or widget.
- [ ] At least one successful fetch is observed (WeatherKit or Open‑Meteo), and attribution reflects the provider actually used.
- [ ] Failure states are understandable and non-destructive (no crashes, no infinite spinners).

## Notes

### What “location” means in v0.8.0

Weather supports two location modes:

- **Manual location** (default): chosen via Settings search (geocoding); no device GPS permission needed.
- **Current location** (optional): uses CoreLocation **When In Use** with *coarse accuracy* (good enough for weather).

### Debug surfaces (intentional)

The Weather module includes deterministic debug tools (scenarios + a demo runner) to make regression testing fast and repeatable.

### Where the knobs live

- Settings defaults and persistence: `Sources/Microverse/Weather/WeatherSettingsStore.swift`
- Popover UI: `Sources/Microverse/Views/WeatherTab.swift`
- Settings UI: `Sources/Microverse/Views/WeatherSettingsSection.swift`
- Notch scheduling/switching: `Sources/Microverse/Weather/DisplayOrchestrator.swift`
