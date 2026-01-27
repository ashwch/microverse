# 001 - Context and Changes (v0.7.0 Weather)

## Goal

Produce a shared mental model of Microverse and the v0.7.0 Weather change set (what shipped, where it lives, and why key decisions were made).

## Dependencies

- Requires: None
- Blocks: 002, 003, 004, 005, 006, 007 (this file provides the “why/where” baseline)

## Scope

**In scope:**
- What Microverse is and how it’s structured (menu bar app + optional notch UI + Sparkle updates).
- What changed in v0.7.0 (Weather module + UI surfaces + docs/website).
- “Locked” decisions that future work must preserve (notch glow alignment + weather provider fallback).

**Out of scope:**
- Step-by-step build/run commands (see `002-build-run-smoke-test.md`).
- Detailed UX review checklists (see `003-feature-review-weather.md`).
- Deep code-quality/performance/security review (see `004-code-review-checklist.md`).
- Release mechanics and website publishing (see `005-release-and-website-playbook.md`).

## Checklist

- [ ] Read `CLAUDE.md` (repo orientation) and `AGENTS.md` (notch/glow and release constraints).
- [ ] Confirm repo state locally:
  - `git status -sb` is clean
  - `git tag --list` includes `v0.7.0` (or the intended release tag)
- [ ] Skim the Weather module “core” files and understand responsibilities:
  - `Sources/Microverse/Weather/WeatherStore.swift`
  - `Sources/Microverse/Weather/WeatherSettingsStore.swift`
  - `Sources/Microverse/Weather/DisplayOrchestrator.swift`
  - `Sources/Microverse/Weather/WeatherProviderFallback.swift`
  - `Sources/Microverse/Weather/WeatherKitProvider.swift`
  - `Sources/Microverse/Weather/OpenMeteoProvider.swift`
- [ ] Skim the Weather UI insertion points:
  - `Sources/Microverse/Views/WeatherTab.swift`
  - `Sources/Microverse/Views/WeatherSettingsSection.swift`
  - `Sources/Microverse/Views/TabbedMainView.swift`
- [ ] Skim the notch integration points and confirm the glow stays “in-tree”:
  - `Sources/Microverse/MicroverseNotchSystem.swift`
  - `Sources/Microverse/NotchGlowManager.swift`
  - `Sources/Microverse/NotchGlowInNotch.swift`
  - `Packages/DynamicNotchKit/` (vendored patch points)
- [ ] Confirm docs/site updates exist and have the expected assets:
  - `docs/` pages: `docs/index.md`, `docs/features.md`, `docs/download.md`
  - Screenshots: `docs/assets/images/` and `docs/screenshots/`

## Tests

- [x] Run `swift build -c debug` to ensure the code builds in a CLI context.
- [x] Run `swift build -c release` to ensure the release configuration builds.

## Completion Criteria

- [ ] You can explain (without opening the app) what the Weather feature does, where it lives, and why it was implemented with a fallback provider.
- [ ] You can identify the three primary UI surfaces Weather appears on (menu bar, notch, desktop widget).
- [ ] You can point to the exact code path that constructs the Weather provider(s).

## Notes

### What Microverse is

Microverse is a SwiftUI **menu bar** system monitor for macOS. It can show status in:

- Menu bar (LSUIElement app; no Dock icon)
- “Smart Notch” UI (DynamicNotchKit-based notch/pill UI)
- Desktop widget (“System Glance” surface)

Microverse also includes:

- **Notch Glow Alerts** (animated glows around the notch pill for certain events)
- **Sparkle auto-updates** driven by GitHub Releases + a signed appcast hosted on GitHub Pages (`main:/docs`)

Start with `CLAUDE.md` for the “where to look” map.

### What shipped in v0.7.0 (Weather)

Weather is a first-class module with:

- A Weather tab in the popover (`Sources/Microverse/Views/WeatherTab.swift`)
- A Weather settings section integrated into Settings (`Sources/Microverse/Views/WeatherSettingsSection.swift`)
- Multi-surface display:
  - Menu bar: optional temperature next to the Microverse icon
  - Smart Notch: compact “peeks” and pinned temperature mode; expanded notch shows richer weather info
  - Desktop widget: System Glance can swap in a weather view

### The key design decision: provider fallback

WeatherKit is the “best” data source when it works, but it can fail in unsigned/ad-hoc contexts (entitlements/signing). To avoid shipping a release where Weather silently doesn’t work, Microverse uses a provider chain:

- WeatherKit when available/authorized
- Open‑Meteo as a fallback

The fallback decision is intentionally **not** DEBUG-only; it keeps Weather functional in CI-built artifacts.

Provider construction happens in `Sources/Microverse/MenuBarApp.swift` (search for `makeWeatherProvider()`).

### Other notable v0.7.0 behaviors

- Smart Notch gained an optional “click-to-toggle expanded” behavior (popover-like auto-dismiss) driven by `BatteryViewModel.notchClickToToggleExpanded`.
- The “DisplayOrchestrator” controls compact notch rotation between system metrics vs weather peeks and considers both notch and widget enablement.

### Documentation + website updates

The v0.7.0 work updated privacy wording (Weather uses network requests), and added Weather screenshots to both repo README and the GitHub Pages site (`docs/`).
