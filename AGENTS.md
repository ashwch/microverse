# Microverse Agent Notes

This repo is a SwiftUI **menu bar** app with optional **notch UI** and **Sparkle** auto-updates.

## Quick orientation

- App entry: `Sources/Microverse/MenuBarApp.swift`
- Smart Notch UI: `Sources/Microverse/MicroverseNotchSystem.swift`
- Notch Glow Alerts: `Sources/Microverse/NotchGlowManager.swift`, `Sources/Microverse/NotchGlowInNotch.swift`
- Vendored DynamicNotchKit (patched): `Packages/DynamicNotchKit/`
- Website + Sparkle feed (GitHub Pages): `docs/` (served from `main:/docs`)

## Build & run (local)

- Requirements: **macOS 13+**, **Xcode 16+ / Swift 6**
- Use the Makefile (preferred):
  - `make install-debug` (build bundle → install to `/Applications` → run)
  - `make install` (release bundle → install → run)
  - `make app` / `make debug-app` (creates `/tmp/Microverse.app`)

## Notch Glow (design contract)

We render the glow **inside DynamicNotchKit’s SwiftUI tree** (not by manually positioning a separate window).

Reason: DynamicNotchKit’s compact pill uses SwiftUI transforms (e.g. `.offset(x:)`) that **don’t participate in layout**. External overlays tend to drift.

See `docs/NOTCH_FEATURES.md` for trigger rules + motion details.

## Releases / Sparkle

- GitHub Actions `release.yml` builds app assets, creates a GitHub Release, generates a **signed** `appcast.xml`, and updates:
  - `docs/appcast.xml`
  - `docs/Microverse-vX.Y.Z.html`
- The Sparkle feed URL is `https://microverse.ashwch.com/appcast.xml`.

Docs:
- `docs/SPARKLE_AUTO_UPDATE_SYSTEM.md`
- `docs/DEPLOYMENT.md`

## When changing DynamicNotchKit

DynamicNotchKit is vendored under `Packages/DynamicNotchKit` because Microverse patches it with a “decoration overlay” hook used for the glow.

If you update/replace the vendored package, ensure the glow decoration hook is preserved or re-implemented.
