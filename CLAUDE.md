# Microverse (LLM / Agent Handoff)

If you’re an LLM/agent working in this repo, start here.

## What this project is

Microverse is a SwiftUI **menu bar** system monitor for macOS (Battery/CPU/Memory) with:

- Smart Notch UI (DynamicNotchKit)
- Notch Glow Alerts (battery event animations around the notch pill)
- Sparkle-based auto-updates driven by GitHub Releases + a signed appcast on GitHub Pages

## Key docs

- Notch + glow behavior: `docs/NOTCH_FEATURES.md`
- Sparkle + appcast pipeline: `docs/SPARKLE_AUTO_UPDATE_SYSTEM.md`
- Website (GitHub Pages from `main:/docs`): `docs/README.md`, `docs/DEPLOYMENT.md`
- Contributing standards: `CONTRIBUTING.md`

## Build & run

Use the Makefile:

- `make install-debug` (best for local iteration)
- `make install` (release-like behavior)
- `make app` / `make debug-app` to create `/tmp/Microverse.app`

Notes:
- Running the raw SwiftPM executable won’t behave like a bundled app (icons/framework rpaths). Prefer the Makefile bundle targets.

## Notch glow alignment (important)

The glow is rendered **inside DynamicNotchKit’s SwiftUI tree** via a vendored patch in `Packages/DynamicNotchKit`.

Rationale:
- DynamicNotchKit applies SwiftUI transforms (e.g. `.offset`) to its pill; those transforms **do not change layout**, so external “measure + overlay window” approaches drift.

If you touch notch/glow behavior:
- Prefer staying in-tree (decoration overlay).
- Treat external overlay windows as a fallback only (e.g. notch UI disabled).

## Release checklist (high level)

1. Merge to `main`
2. Ensure `Build and Release Microverse` workflow succeeds
3. Verify:
   - GitHub Release assets exist
   - `https://microverse.ashwch.com/appcast.xml` points to the latest zip and has `sparkle:edSignature`
   - `https://microverse.ashwch.com/Microverse-vX.Y.Z.html` exists

## Where to look in code

- Trigger rules: `Sources/Microverse/BatteryViewModel.swift` (`checkAndTriggerAlerts()`)
- Glow renderer: `Sources/Microverse/NotchGlowManager.swift` (`NotchGlowView`)
- In-notch routing: `Sources/Microverse/NotchGlowInNotch.swift`
- DynamicNotchKit patch points:
  - `Packages/DynamicNotchKit/Sources/DynamicNotchKit/DynamicNotch/DynamicNotch.swift`
  - `Packages/DynamicNotchKit/Sources/DynamicNotchKit/Views/NotchView.swift`
