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
- [x] Smoke test the UI (popover + Settings):
  - Microverse icon appears in the menu bar
  - Clicking the icon opens the popover
  - Tabs render (System / Weather / Alerts)
  - Settings renders (System + Weather + Alerts sections)
- [x] Smoke test the new System tabs (popover → System):
  - System → Network:
    - [ ] Wi‑Fi card shows “Wi‑Fi off” when Wi‑Fi is off *(skipped here; turning off Wi‑Fi can disconnect remote sessions)*
    - [ ] Wi‑Fi card shows “Not connected” when disconnected *(skipped here; disconnecting can break remote sessions)*
    - [x] Wi‑Fi card shows bars + percent when connected (SSID may be redacted; “Connected” is OK)
    - [x] Throughput card shows non-negative values and updates over time
  - System → Audio:
    - [x] Output devices list renders
    - [ ] Selecting a device switches the system default output *(requires an actually-selectable non-default output device, e.g. AirPods/BT/HDMI)*
    - [x] Input devices list renders and selecting a device switches the system default input
    - [x] Volume slider + mute toggle are present and enabled for the default route
    - [ ] Volume/mute disable state verified on a route that doesn’t support it *(requires such a route present)*
- [x] Smoke test Custom widget modules (Settings → Desktop Widget → Custom):
  - [x] Enable Desktop Widget and set style to Custom
  - [x] Ensure the module list includes: Wi‑Fi, Audio Output, Audio Input
  - [x] Confirm the widget window renders without clipping (values should update live)
- [x] Run a minimal Weather debug fetch (prints a single-line result and quits):
  - `open -n /tmp/Microverse.app --args --debug-weather-fetch`
  - If you need help / scenario names:
    - `open -n /tmp/Microverse.app --args --debug-weather-help`
- [x] Run deterministic notch + widget Weather demo (debug build; auto-quits):
  - `make debug-app`
  - `open -n /tmp/Microverse.app --args --debug-weather-demo`
- [x] (Optional) Trigger a notch glow preview (debug build; does not auto-quit):
  - `open -n /tmp/Microverse.app --args --debug-notch-glow=success`
- [x] Build a release-like bundle and launch it:
  - `make app`
  - `open -n /tmp/Microverse.app`

## Tests

- [x] Run `swift build -c debug` (fast build sanity).
- [x] Run `swift build -c release` (release configuration build sanity).
- [x] Run `make debug-app` (ensures app-bundle packaging + rpaths + Sparkle framework embedding work).
- [x] Run `--debug-weather-demo` (exercises notch + widget surfaces deterministically; debug builds only).

## Completion Criteria

- [x] You can reproduce a launchable `/tmp/Microverse.app` from a clean checkout using only `make debug-app` / `make app`.
- [x] The menu bar icon and popover appear, and no obvious runtime crashes occur on startup.
- [x] `--debug-weather-fetch` prints `WEATHER_OK ...` or a clear failure state and then exits.

## Notes

### Why the Makefile matters

Microverse is a menu bar app that depends on correct bundle structure (Info.plist, resources, Sparkle framework embedding/rpaths). Running the raw SwiftPM executable (`swift run`) is often **not equivalent** and can produce misleading behavior.

### Common “it didn’t launch” causes

- An old instance is still running (especially after `make install-debug`).
- The app launched but has no Dock icon (expected for LSUIElement menu bar apps).
- The popover is off-screen due to multi-monitor/menu bar layout (try toggling the icon, or move to the primary display).

### Remote-session safety (Wi‑Fi toggles)

If you’re working over SSH / a remote desktop / an agent session, avoid:

- turning Wi‑Fi off
- disconnecting from the current network

Those steps are useful for validating UI states, but they can also disconnect your session. In those environments,
verify the “connected” UI state + throughput updates instead, and do the “off/disconnected” checks locally later.
