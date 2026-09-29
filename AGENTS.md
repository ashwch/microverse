# Microverse Agent Notes

This repo is a SwiftUI **menu bar** app with optional **notch UI** and **Sparkle** auto-updates.

## Quick orientation

- App entry: `Sources/Microverse/MenuBarApp.swift`
- Smart Notch UI: `Sources/Microverse/MicroverseNotchSystem.swift`
- Notch Glow Alerts: `Sources/Microverse/NotchGlowManager.swift`, `Sources/Microverse/NotchGlowInNotch.swift`
- Vendored DynamicNotchKit (patched): `Packages/DynamicNotchKit/`
- Website + Sparkle feed: `docs/` (deployed from `main` to the `microverse` Cloudflare Pages project)

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

- GitHub Actions `release.yml` builds app assets, creates a GitHub Release, generates a **signed** `appcast.xml`, and updates the Cloudflare Pages source files:
  - `docs/appcast.xml`
  - `docs/Microverse-vX.Y.Z.html`
- The Sparkle feed URL is `https://microverse.ashwch.com/appcast.xml`.
- Packaging invariants (both broke real releases, v0.9.0 and v0.9.1): the bundle must be ad-hoc code signed, and the zip must be created with `ditto -c -k --sequesterRsrc --keepParent`, never `zip -r`. CI verifies the extracted zip; keep that step. Details: `docs/SPARKLE_AUTO_UPDATE_SYSTEM.md` §5.4.

Docs:
- `docs/SPARKLE_AUTO_UPDATE_SYSTEM.md`
- `docs/DEPLOYMENT.md`

## When changing DynamicNotchKit

DynamicNotchKit is vendored under `Packages/DynamicNotchKit` because Microverse patches it with:

- a “decoration overlay” hook used for the glow (`setDecoration`), and
- a “compact center” slot (`setCompactCenter`, `hasPhysicalNotch`) that fills the reserved notch width on screens without a physical notch (external displays, closed lid). On a real notch that width is the camera housing and the slot is never rendered.

If you update/replace the vendored package, ensure both hooks are preserved or re-implemented. Also keep the package free of `@Entry` / `#Preview` macros (see `CLAUDE.md`).
