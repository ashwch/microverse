# 002 - Build, Run, Smoke Test

## Goal

Reliably compile, install, and launch Microverse (debug and release-like) and run a minimal smoke test without “it works on my machine” ambiguity.

## Dependencies

- Requires: 001
- Blocks: 003, 004, 005 (you can’t review/release what you can’t run)

## Scope

**In scope:**
- Build requirements and the canonical build/run commands.
- How to kill existing Microverse processes before launching.
- A repeatable smoke-test script (manual QA steps + debug flags).

**Out of scope:**
- Deep feature verification (see `003-feature-review-weather.md`).
- Performance profiling and security review (see `004-code-review-checklist.md`).

## Checklist

- [ ] Confirm your environment:
  - macOS 13+
  - Xcode 16+ / Swift 6
- [x] Kill any running Microverse instances (to avoid confusing “old build still running” issues):
  - Preferred: quit from the menu bar icon
  - Or via Terminal:
    - `pkill -x Microverse || true`
    - `killall Microverse || true`
- [x] Build a debug bundle and launch it:
  - `make debug-app`
  - `open -n /tmp/Microverse.app`
- [ ] (Optional but recommended) Install debug build into `/Applications` and launch:
  - `make install-debug`
- [ ] Smoke test the UI:
  - Microverse icon appears in the menu bar
  - Clicking the icon opens the popover
  - Tabs render (including Weather)
  - Settings render (including Weather settings section)
- [x] Run a minimal Weather debug fetch (prints a single-line result and quits):
  - `open -n /tmp/Microverse.app --args --debug-weather-fetch`
  - If you need help / scenario names:
    - `open -n /tmp/Microverse.app --args --debug-weather-help`
- [x] Build a release-like bundle and launch it:
  - `make app`
  - `open -n /tmp/Microverse.app`

## Tests

- [x] Run `swift build -c debug` (fast build sanity).
- [x] Run `swift build -c release` (release configuration build sanity).
- [x] Run `make debug-app` (ensures app-bundle packaging + rpaths + Sparkle framework embedding work).

## Completion Criteria

- [ ] You can reproduce a launchable `/tmp/Microverse.app` from a clean checkout using only `make debug-app` / `make app`.
- [ ] The menu bar icon and popover appear, and no obvious runtime crashes occur on startup.
- [x] `--debug-weather-fetch` prints `WEATHER_OK ...` or a clear failure state and then exits.

## Notes

### Why the Makefile matters

Microverse is a menu bar app that depends on correct bundle structure (Info.plist, resources, Sparkle framework embedding/rpaths). Running the raw SwiftPM executable (`swift run`) is often **not equivalent** and can produce misleading behavior.

### Common “it didn’t launch” causes

- An old instance is still running (especially after `make install-debug`).
- The app launched but has no Dock icon (expected for LSUIElement menu bar apps).
- The popover is off-screen due to multi-monitor/menu bar layout (try toggling the icon, or move to the primary display).
