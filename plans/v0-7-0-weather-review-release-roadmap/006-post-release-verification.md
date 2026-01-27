# 006 - Post-release Verification

## Goal

Verify the release is real, usable, and updatable (assets exist, website is updated, Sparkle appcast is valid, and the app can discover the update).

## Dependencies

- Requires: 005
- Blocks: None

## Scope

**In scope:**
- Git tag and release artifacts verification.
- Appcast correctness verification (version, URLs, signatures).
- Website docs presence (release notes page + screenshots).
- Optional: live update check from the previous version to the new one.

**Out of scope:**
- Long-term monitoring and telemetry (Microverse does not include analytics).

## Checklist

- [ ] Confirm the tag exists locally:
  - `git tag --list | rg '^v\\d+\\.\\d+\\.\\d+$'`
- [ ] Confirm appcast was updated:
  - `git diff --name-only HEAD~1..HEAD` should include `docs/appcast.xml` on the CI-generated commit
  - Open `docs/appcast.xml` and verify the newest `<item>` points to the latest zip and includes `sparkle:edSignature`
- [ ] Confirm release notes page exists in `docs/`:
  - `docs/Microverse-vX.Y.Z.html` exists for the released version
- [ ] Confirm website docs reference the new screenshots and feature copy (no broken image links):
  - `docs/index.md`
  - `docs/features.md`
  - `docs/download.md`
- [ ] Optional: Sparkle update flow sanity check (manual):
  - Install the previous release
  - Run Microverse and trigger “Check for Updates…”
  - Confirm the new version is offered and downloads successfully

## Tests

- [ ] Local verification: run `rg -n \"sparkle:edSignature\" docs/appcast.xml` and ensure at least one match exists.
- [ ] Local verification: open the built app and confirm `SUFeedURL` is set to `https://microverse.ashwch.com/appcast.xml` in the bundle Info.plist.

## Completion Criteria

- [ ] The appcast contains a valid, signed entry for the newest version.
- [ ] The repo’s website docs match the shipped UI and do not contain broken references.
- [ ] (If performed) The Sparkle update check successfully finds the release.

## Notes

If anything fails here, resist the urge to “hot fix by hand-editing appcast.xml” unless you fully understand Sparkle signing. Prefer re-running the CI release workflow or fixing the release pipeline.

