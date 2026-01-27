# 004 - Code Review Checklist (UX, Performance, Security, Maintainability)

## Goal

Perform a thorough, pedantic code review that catches UX regressions, energy/performance issues, privacy/security mistakes, and “future maintainer” hazards.

## Dependencies

- Requires: 001, 002
- Blocks: 005 (don’t ship without code review)

## Scope

**In scope:**
- Swift concurrency correctness (`@MainActor`, tasks, cancellation, debouncing).
- Energy efficiency (avoid hot loops, minimize timers, coalesce work).
- UI correctness and SwiftUI best practices.
- Network hygiene (timeouts, caching, error handling, attribution compliance).
- Privacy posture (no surprise data collection/logging).
- Release robustness (avoid entitlements/signing surprises).

**Out of scope:**
- Major architectural rewrites (file issues/notes and schedule them post-release unless correctness requires immediate changes).

## Checklist

- [ ] Swift concurrency + cancellation:
  - Long-lived tasks are cancellable and canceled on teardown
  - UI updates occur on the main actor
  - Debounced persistence avoids UserDefaults spam (verify sliders, typing)
- [ ] Energy/performance:
  - No aggressive timers running while UI is hidden
  - Background refresh intervals are conservative and user-configurable (Weather refresh default is 30m)
  - Notch rotations/peeks have sensible dwell/cooldown and don’t cause animation thrash
- [ ] UI correctness:
  - Popover layouts don’t jump while loading (stable widths, monospaced digits where needed)
  - Empty/error states are deliberate and styled consistently
  - Controls have clear labels/helps and don’t require guessing
- [ ] Network + caching:
  - Fetch failures are surfaced as “stale cached” or a clear error
  - Providers don’t retry aggressively
  - Attribution UI matches the provider actually used (`WeatherTab` uses `weather.lastProvider`)
- [ ] Privacy + security:
  - No location or network payloads are logged at info-level in production
  - No analytics/tracking
  - Location permission is requested **only** when “Current location” Weather is enabled
  - Bluetooth scanning is **opt-in** and only used for AirPods battery features (no connecting / no paired-device enumeration)
  - Info.plist usage strings exist both locally (`Info.plist`) and in CI packaging (`.github/workflows/release.yml`)
- [ ] Release robustness / entitlements:
  - Weather remains functional in ad-hoc and CI builds (fallback provider is not DEBUG-only)
  - Notch glow remains “in-tree” inside DynamicNotchKit (no overlay-window drift regressions)
  - Sparkle update feed URL and behaviors remain correct
  - Release workflow ignores plans/checklists (avoid accidental “patch releases” from plan edits)
- [ ] “Future maintainer” clarity:
  - Public APIs have obvious ownership boundaries (Store vs View vs Provider)
  - Naming communicates intent (e.g. `DisplayOrchestrator` isn’t doing unrelated work)
  - Debug hooks are isolated and don’t leak into release behavior except when explicitly intended

## Tests

- [ ] Run `swift build -c debug` and `swift build -c release`.
- [ ] Manual QA: `make debug-app` and run through `003-feature-review-weather.md`.
- [ ] Manual QA (debug): `open -n /tmp/Microverse.app --args --debug-weather-demo`
- [ ] Manual QA (debug): `open -n /tmp/Microverse.app --args --debug-notch-glow=success`
- [ ] Manual QA: toggle notch modes + Weather toggles repeatedly and ensure there’s no growth in CPU usage over ~2–3 minutes.

## Completion Criteria

- [ ] No high-severity issues remain unaddressed (crashes, data leaks, major UX regressions, runaway CPU).
- [ ] Medium/low severity findings are written down (as issues or TODOs) with clear follow-ups.
- [ ] The review yields a concrete “ship/no-ship” conclusion with reasons.

## Notes

### High-quality macOS UX reference points (what to aim for)

Microverse competes (in UX expectations) with tools like iStat Menus / Stats / MenuMeters:

- Minimal distraction, fast glanceability
- Good defaults; advanced knobs discoverable but not overwhelming
- Clear privacy posture; predictable network behavior

### Apple docs worth re-reading before shipping

- Human Interface Guidelines (macOS): https://developer.apple.com/design/human-interface-guidelines/
- Energy efficiency / responsiveness: https://developer.apple.com/documentation/xcode/energy-efficiency
- App Sandbox + entitlements: https://developer.apple.com/documentation/security/app_sandbox
- Accessibility (SwiftUI): https://developer.apple.com/documentation/accessibility
