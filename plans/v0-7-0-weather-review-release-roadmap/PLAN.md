# Microverse v0.7.0 (Weather) — Review, Release, Roadmap - Master Plan

## Purpose

- Provide a single, versioned checklist for **final code review**, **feature review**, **release**, and **website/docs** work.
- Capture the v0.7.0 Weather design + implementation decisions so future contributors don’t regress release viability.
- Reduce “tribal knowledge”: someone new to this repo should be able to ship a high-quality release by following these files.

## How to Use

1. Start with `CLAUDE.md` for repo orientation.
   - Also see `docs/WEATHER_LOCATIONS_AND_ALERTS.md` for a simple mental model of Weather internals (multi-location, current location, alerts).
2. Work through the tasks in this directory in order (or follow dependencies when they differ).
3. Treat checkboxes as the source of truth: check items as you complete them (`- [x]`).
4. When a task file is fully complete, check that task in the **Task Index**.
5. For future releases, copy this directory to a new slug (e.g. `plans/v0-7-1-.../`) and update `001-context-and-changes.md`. Keep old plans for history.

## Decisions (Locked)

- **Notch glow alignment:** keep the glow rendered *inside* DynamicNotchKit’s SwiftUI tree via the vendored “decoration overlay” hook (`Packages/DynamicNotchKit/...`). External overlay-window approaches drift due to SwiftUI transforms.
- **Weather provider robustness:** Weather must remain functional in release artifacts even when WeatherKit signing/entitlements are unavailable; keep the “primary provider + network fallback” pattern.
- **Website hosting:** GitHub Pages serves from `main:/docs` (not `gh-pages`). Docs-only pushes may not trigger releases because the release workflow ignores `docs/**`.
- **Build discipline:** Prefer the Makefile bundle targets (`make install-debug`, `make install`, etc.). Running the raw SwiftPM executable is not equivalent to the bundled app (rpaths/resources).

## Task Index

- [ ] 001 - Context and Changes (`001-context-and-changes.md`)
- [x] 002 - Build, Run, Smoke Test (`002-build-run-smoke-test.md`)
- [ ] 003 - Feature Review: Weather (`003-feature-review-weather.md`)
- [ ] 004 - Code Review Checklist (`004-code-review-checklist.md`)
- [ ] 005 - Release + Website Playbook (`005-release-and-website-playbook.md`)
- [ ] 006 - Post-release Verification (`006-post-release-verification.md`)
- [ ] 007 - Next Additions Roadmap (`007-next-additions-roadmap.md`)

## Completion

- [ ] All tasks in the index are checked.
- [ ] All tests listed in task files pass (or are explicitly N/A with justification).
- [ ] A new maintainer can reproduce the review + release by following these files + referenced repo docs.
