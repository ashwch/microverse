# 005 - Release + Website Playbook

## Goal

Provide a repeatable, low-drama release process (build artifacts, GitHub Release, Sparkle appcast, website docs, screenshots) that someone new to the repo can execute.

## Dependencies

- Requires: 003, 004
- Blocks: 006

## Scope

**In scope:**
- Release triggers and version bumping expectations.
- What must be updated in the repo (docs, screenshots, privacy statements).
- How the Sparkle appcast and release notes are generated and published.

**Out of scope:**
- Codesigning/notarization beyond what the repo currently does (track as a separate project if desired).

## Checklist

- [ ] Pre-flight:
  - Ensure `main` contains the intended changes (merge via PR or direct push per repo norms)
  - Ensure commit messages are “conventional commit” style when possible (`feat:`, `fix:`) because the CI release workflow uses commit messages to decide version bumps
  - Confirm `docs/DEPLOYMENT.md` and `docs/SPARKLE_AUTO_UPDATE_SYSTEM.md` reflect current behavior
- [ ] Local readiness (recommended even when CI will build):
  - `make app` and launch `/tmp/Microverse.app` to ensure it’s not “CI only works”
  - Update `Info.plist` versions if they’re out of sync with the intended release (used by local Makefile bundles)
- [ ] Screenshots (update for new features):
  - Capture at least:
    - Popover Weather tab
    - Smart Notch compact weather
    - Smart Notch expanded weather
    - Desktop widget weather (System Glance)
  - Put files in both:
    - `docs/assets/images/` (website)
    - `docs/screenshots/` (repo/README)
  - Keep filenames stable when possible to avoid churn in docs pages
- [ ] Docs + website updates:
  - Update feature copy and privacy language as needed:
    - `README.md`
    - `docs/index.md`
    - `docs/features.md`
    - `docs/download.md`
    - `docs/NOTCH_FEATURES.md` (if notch behavior changed)
- [ ] Release execution (CI-driven):
  - Push to `main` (note: docs-only pushes are ignored by the release workflow)
  - Confirm GitHub Actions “Build and Release Microverse” workflow completes successfully
  - Confirm it created:
    - A new tag `vX.Y.Z`
    - A GitHub Release with `.dmg` and `.zip`
    - Updated `docs/appcast.xml`
    - A new `docs/Microverse-vX.Y.Z.html` release notes page
- [ ] Post-merge hygiene:
  - If the workflow created commits on `main` (e.g. appcast + release notes), ensure long-lived branches (e.g. `dev`) are synced

## Tests

- [ ] Run `make app` and open `/tmp/Microverse.app`.
- [ ] Sanity-check the generated website locally (optional): open `docs/index.md` via your preferred Markdown preview.

## Completion Criteria

- [ ] The release artifacts exist (zip/dmg), and the Sparkle appcast points to the newest zip with a valid signature.
- [ ] Website docs and screenshots reflect the release’s actual UI.
- [ ] A new maintainer could repeat the process using only this checklist + referenced docs.

## Notes

### How releases actually happen in this repo

Releases are primarily **CI-driven** by `.github/workflows/release.yml`:

- Runs on pushes to `main` (with `paths-ignore` for `docs/**` and various repo meta files).
- Determines the version bump from commit messages since the previous release/tag.
- Builds the app bundle and packages `.zip` and `.dmg`.
- Generates and signs the Sparkle appcast, and commits updates back into `docs/` on `main`.

See:

- `.github/workflows/release.yml`
- `docs/SPARKLE_AUTO_UPDATE_SYSTEM.md`
- `docs/DEPLOYMENT.md`

