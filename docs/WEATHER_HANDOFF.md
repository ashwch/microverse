# Microverse Weather Module — Export Handoff v3

Last updated: **2026-01-16**  
App: **Microverse** (macOS 13+, Swift 6, SwiftUI + AppKit menu bar app, SwiftPM, optional notch UI via vendored DynamicNotchKit, Sparkle auto-updates)

Audience: Principal iOS engineer + principal macOS engineer (**you**)  
Owner: (**I**) am implementing the Microverse Weather module and I want your guidance, coding help, and creative help.

---

## Why you’re reading this

I’ve added a Weather module to Microverse and I’m trying to ship it as:

- **Calm + deferential** (fits Microverse’s system-metrics design language).
- **Power-safe** (menu bar + notch can’t be a space heater).
- **Notch-stable** (no DynamicNotchKit drift/jitter).

You don’t have access to the repo, so this document is intended to be self-contained: what exists, how it works, known risks, and what I want from you.

---

## Product surface summary (what users can do)

### Settings → Weather

Users can configure:

- Enable Weather (manual location only; no CoreLocation permission in v1)
- Units (°C/°F) + refresh interval
- Show in: Smart Notch / Desktop Widget / Menu bar
- **Weather highlights** (event-driven takeover; default ON; conservative)
- **Occasional temperature peek** (cadence; default OFF; opt-in)
  - Peek interval options: **10s, 20s, 30s, 1m, 2m, 5m, 10m, 15m** (default **15m**)
- **Pinned temperature in compact notch** (opt-in): always-visible compact weather replacing **CPU** or **Memory**
- Animated icons: Off / Subtle / Full
- “Animate in compact notch” (opt-in; micro-motion only)

### Popover (Weather tab)

Weather tab shows:

- **Now**: condition glyph + temperature + last updated state
- **Up Next**: a single “next significant change” message (relative time updates in-view)
- **Hourly**: next ~12 hours (SF Symbols; no animations here)
- **Attribution**: WeatherKit attribution link, and Open‑Meteo terms link when fallback is used

### Smart Notch (DynamicNotchKit)

- Compact notch can show weather via peeks/highlights (or pinned mode).
- Expanded notch includes a small weather row and triggers refresh on expand.
- Optional interaction: click notch to toggle expanded/compact, with sane dismissal (no global click monitors).

### Desktop widget (System Glance)

- During peek/highlight windows, the CPU column swaps to weather (glyph + temp).

---

## Architecture overview (mental model)

I kept this as a small set of “boring” single-responsibility pieces:

1) **`WeatherSettingsStore`** (typed, UserDefaults-backed)
- Owns all weather settings.
- Provides immutable `WeatherSettingsSnapshot` so services can read settings safely.
- Stores `weatherLocation` as a validated `WeatherLocation` (coordinate range checks on decode; failable init for programmatic creation).

2) **`WeatherStore`** (`@MainActor`, single source of truth)
- Publishes `current`, `hourly`, `nextEvent`, `fetchState`, `lastUpdated`, `lastProvider`.
- Has disk cache (“stale but present”).
- Has a periodic refresh loop + debounced triggers (tab open, notch expand, wake, orchestrator peek).
- Has in-flight fetch dedupe **keyed by location id**.

3) **`WeatherProvider` protocol**
- Preferred provider: **WeatherKit**.
- Fallback provider: WeatherKit → Open‑Meteo (when WeatherKit isn’t authorized / available).

4) **`WeatherEventDetector`**
- Computes one conservative “next change” event from the payload (precip start/stop, major bucket shift, temp swing).
- Avoids jitter via hysteresis/persistence/stickiness (details below).

5) **`DisplayOrchestrator`** (compact surfaces scheduler)
- Chooses whether compact notch/widget show `.systemMetrics` vs `.weather`.
- Enforces min dwell + cooldown.
- Priority: battery critical always wins (never hide critical system signals).
- Triggers on-demand refresh when a peek begins (rate limited).

**How often does compact notch switch to weather?**

- If **Pinned temperature** is enabled: weather is always visible in compact notch (no swapping).
- Otherwise, compact notch switches to weather in three cases:
  - **Immediate peek** when Weather becomes “ready” (enabled + location set).
  - **Rotation peeks** when “Occasional temperature peek” is enabled: one peek every `weatherRotationInterval` (default **15m**).
  - **Event highlights** when “Weather highlights” is enabled: when `nextEvent` is within the **90m lead window**, it can re-highlight at most once per **cooldown** (default **15m**) until the event passes.
- Each peek shows weather for at least `minDwell` (default **8s**); event highlights use `eventBoostDuration` (default **12s**).

6) **`WeatherAnimationBudget`**
- Centralized “should animate?” policy producing `WeatherRenderMode` by surface.
- Gated by: visibility, Reduce Motion, Low Power Mode, thermal state.

7) **`MicroverseWeatherGlyph`**
- If renderMode `.off`: SF Symbol fallback.
- If animating: Canvas scene driven by low-FPS `TimelineView(.periodic)`.

---

## Key constraints (non-negotiable)

### Notch alignment contract

Microverse’s notch visuals must render **inside DynamicNotchKit’s SwiftUI tree**.

DynamicNotchKit’s compact pill uses transforms/offsets that don’t participate in layout, so “external overlay windows” drift.

### Performance budget

Menu bar apps get judged harshly. My target posture:

- Compact notch: “watch complication” (static by default; micro-motion only when explicitly enabled)
- Expanded notch + Weather tab: allowed to be delightful, but FPS capped and fully gated

---

## Provider details (WeatherKit + Open‑Meteo fallback)

### WeatherKit (release)

- Uses native WeatherKit framework.
- Expected dev workflow: WeatherKit works reliably in properly signed, entitlement-correct builds (typically Xcode-managed signing).
- Known failure mode: `WeatherDaemon.WDSJWT…` authorization failures in unsigned/ad-hoc bundles; Microverse treats that as `setupRequired` and falls back.

### Open‑Meteo (fallback)

- Used when WeatherKit isn’t available or isn’t authorized (including many unsigned/ad-hoc builds).
- Note: Open‑Meteo’s free API is non-commercial; review their terms before shipping commercially.

**Bug fixed (2026-01-14):** hourly forecast was empty in Open‑Meteo fallback because their `hourly.time` values are local times without offsets (e.g. `2026-01-14T05:00`), and `ISO8601DateFormatter(.withInternetDateTime)` rejects those strings. I added a timezone-aware local parse fallback using the selected location’s timezone.

**Improvement (2026-01-14):** Open‑Meteo hourly now requests `is_day` and populates `HourlyForecastPoint.isDaylight` so hourly icons are day/night-correct without the 6–18 heuristic.

**Bug fixed (2026-01-14):** the compact peek scheduler could behave like it was “ignoring” the rotation interval because cancelled sleep tasks were falling through and recomputing immediately. Cancellation is now treated as “stop” (no immediate recompute) in both the notch orchestrator scheduler and WeatherStore debounce paths.

---

## “Up Next” detection (how I avoid noisy UX)

The detector emits **one** event within a horizon (currently 6 hours):

- precip start / stop (prefers minutely series when available)
- major condition bucket shift (precip/fog/thunder only)
- meaningful temp swing (threshold within window + trend confirmation)

Stability rules:

- **Hysteresis**: start threshold > stop threshold
- **Persistence**: require consecutive samples
- **Stickiness**: don’t replace previous unless new score is materially better
- Model stores `startTime` as an absolute `Date` and UI computes “in 25m” in a per-minute TimelineView (so the store doesn’t republish every minute).

---

## Compact notch behavior (how swapping avoids pill jitter)

DynamicNotchKit compact pill can “bump” if trailing width changes. My approach:

- A **stable-width slot** that only grows (measure via a preference key) and is clamped to a max.
- Inside it: crossfade + tiny vertical slide between system metrics view and weather view.
- Hidden weather branch is “paused” via `WeatherRenderMode` (so TimelineView isn’t ticking invisibly).

### Debugging peeks (the “is my interval respected?” question)

In DEBUG builds, Settings → Weather shows a compact debug line under “Preview in notch”:

- `reason=... lastSwitch=... switches(w:… s:…) lastWeather=... until=... nextRotation=... cooldown=... rotationEvery=... highlights=...`

How I use this:

- If `reason=event_boost` and `highlights=on`, highlights can show weather independent of the peek interval (bounded by cooldown).
- If `nextRotation` constantly resets or never counts down, that indicates a scheduling/Task cancellation bug (the 2026‑01‑14 fix above).

Pinned mode:

- Split layout: `[battery] | [metric + weather]` (weather replaces CPU or Memory)
- Left layout: unified chip becomes `battery · metric · weather`

---

## Animation system (power-safe “premium”)

### Central policy (`WeatherAnimationBudget`)

Surfaces:

- `compactNotch` → off by default; subtle 2–3 FPS only if user opts in
- `expandedNotch` → 8–12 FPS (mode dependent)
- `popoverWeatherTab` → 10–12 FPS (mode dependent)
- `desktopWidget` → 4–6 FPS (only when weather is swapped in; clamped off in Low Power / thermal serious/critical)

Gates:

- Reduce Motion → off
- Low Power Mode / thermal serious/critical → clamp aggressively (always-on surfaces off)

### Glyph implementation (`MicroverseWeatherGlyph`)

- `.off` uses SF Symbols.
- Otherwise draws a tiny Canvas scene with deterministic motion (no RNG in draw loop; minimal allocations).

---

## Iconography (current concern)

Users (and I) still find the compact condition icons hard to differentiate.

What I did so far:

- Updated SF Symbol mapping to prefer distinct silhouettes at tiny sizes:
  - Thunder: `cloud.bolt.fill` (instead of `cloud.bolt.rain.fill`)
  - Cloudy: `cloud.fill` (strong silhouette; avoids “sun + cloud” confusion at 10–12pt)
  - Clear (night): `moon.fill` (the stars version was too detailed at 10pt)
- Switched notch + widget weather icons to **hierarchical** rendering (monochrome was too subtle).
- Tweaked Canvas fog glyph to include a cloud cap + bands (reads better).

What I still need from you:

- Should I continue with SF Symbols + hierarchical as “static baseline”, or switch to custom vector assets for crisp differentiation at 12px?
- If SF Symbols: which exact symbols would you pick for fog/wind/thunder/rain/snow when rendered at 10–12pt?

### Debug tool for icon QA (DEBUG-only)

I added an **Icon gallery** sheet (Settings → Weather → “TEST WEATHER” → “Icon gallery”) that renders:

- SF Symbols vs Microverse Canvas glyphs
- compact notch size / widget size / popover size
- day/night variants
- 1×/2× preview scaling

This is meant to make icon review systematic, not vibe-based.

---

## Debug + QA harness (how I test quickly)

CLI flags:

- `--debug-weather-scenario=<scenario>` (deterministic store payload)
- `--debug-open-popover`, `--debug-open-settings`, `--debug-open-weather`
- `--debug-weather-demo` (temporarily enables notch+widget, previews weather, expands notch, then quits)
- `--debug-weather-fetch` (one-shot fetch + exits)
- `--debug-weather-help`

In-app (DEBUG): Settings → Weather has “TEST WEATHER” buttons:

- scenario buttons (Clear / Rain / Clearing / Thunder / Temp drop)
- “Run demo”
- “Icon gallery”

Scenarios:

- `clear`, `rainIn25m`, `clearingIn20m`, `thunderIn2h`, `tempDropIn2h`

---

## Compliance / product risks I’m tracking

1) **WeatherKit attribution**: currently shown in Weather tab only; other surfaces rely on “one-click route to Weather tab”. I want you to sanity check whether that’s defensible.
2) **WeatherKit call economics**: default refresh interval must be conservative; on-demand refresh is rate limited.
3) **Notch focus stealing**: click-to-toggle expand currently activates + keys the notch panel to get reliable click-away dismissal (no global monitors). I need your UX instincts here.
4) **Energy regressions**: hidden animations/timers are the classic menu bar footgun. I’m gating via renderMode and central budget, but I want extra guardrail ideas.
5) **Day/night correctness in hourly strip**: WeatherKit and DEBUG Open‑Meteo now both provide an `isDaylight`/`is_day` signal and I plumb it into the hourly UI. Only deterministic DEBUG scenarios still fall back to a coarse 6–18 heuristic.

---

## What I want from you (please answer bluntly)

### 1) WeatherKit dev + release workflow

- Should I treat WeatherKit as “Xcode-signed builds only” and keep the DEBUG fallback forever?
- For Sparkle + SwiftPM menu bar apps: what signing/provisioning workflow actually holds up for a team?

### 2) Iconography and differentiation (highest priority feedback)

- SF Symbols vs custom vectors: what would you do for 12px notch glyphs?
- If SF Symbols: pick a concrete mapping for these buckets: clear/cloudy/rain/snow/fog/thunder/wind.
- Any experience with `.hierarchical` vs `.palette` at tiny sizes in dark glass UI?

### 3) “Premium but calm” animation art direction

- What motion language reads as “deferential” (amplitude, period, easing)?
- Would you ever use CAEmitterLayer here, or stay Canvas-only for consistency across surfaces?

### 4) Notch interaction + dismissal

- Is activating + keying the notch panel acceptable UX, or should I keep it non-activating and rely on a local monitor?
- If you’ve done popover-like panels in sandboxed apps: what dismissal pattern didn’t become a maintenance hazard?

### 5) Performance guardrails

- What automated checks or debug instrumentation would you add to catch “hidden-but-running” regressions?
- Any practical tricks to keep SwiftUI invalidation storms under control in always-on UI (notch/widget)?

### 6) Anything else you’re worried about

I’m explicitly asking: what would you red-flag here before this goes to real users?
