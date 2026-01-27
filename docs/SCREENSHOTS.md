# Screenshots & Website Images

Microverse ships with a small set of screenshots used in two places:

1. **Website (GitHub Pages)**: `docs/assets/images/`
2. **Repo README**: `docs/screenshots/`

Keeping filenames stable avoids churn in docs pages and prevents broken links.

---

## First principles

- **Representative > perfect**: screenshots should match shipped UI, but don’t need to showcase every edge case.
- **Stable filenames**: prefer replacing existing files over inventing new names.
- **High signal**: capture the smallest surface that tells the story (popover card vs full desktop).
- **No private data**: use generic locations/devices where possible.

---

## Build a capture-ready app

Use the bundled app (not `swift run`):

```bash
make debug-app
open -n /tmp/Microverse.app
```

Useful debug helpers:

```bash
# Open popover (and optionally the Weather tab) on launch
open -n /tmp/Microverse.app --args --debug-open-popover
open -n /tmp/Microverse.app --args --debug-open-weather

# Open specific popover tabs/sections (handy for capturing new features)
open -n /tmp/Microverse.app --args --debug-open-alerts
open -n /tmp/Microverse.app --args --debug-open-system-network
open -n /tmp/Microverse.app --args --debug-open-system-audio

# Open Settings directly (optionally pre-select a section)
open -n /tmp/Microverse.app --args --debug-open-settings
open -n /tmp/Microverse.app --args --debug-open-settings=alerts
open -n /tmp/Microverse.app --args --debug-open-settings=weather

# Deterministic Weather demo (exercises notch + widget; then quits)
open -n /tmp/Microverse.app --args --debug-weather-demo
```

---

## Current “core” image set (keep these updated)

These filenames are already referenced by the site + README:

### Website (`docs/assets/images/`)
- `docs/assets/images/app-overview-tab.png`
- `docs/assets/images/app-battery-tab.png`
- `docs/assets/images/app-cpu-tab.png`
- `docs/assets/images/app-memory-tab.png`
- `docs/assets/images/app-weather-tab.png`
- `docs/assets/images/app-settings-notch-glow.png`
- `docs/assets/images/notch-widget-compact.png`
- `docs/assets/images/notch-widget-expanded.png`
- `docs/assets/images/notch-weather-compact.png`
- `docs/assets/images/notch-weather-expanded.png`
- `docs/assets/images/notch-glow-success.png`
- `docs/assets/images/desktop-widget-glance.png`
- `docs/assets/images/desktop-widget-glance-weather.png`
- `docs/assets/images/desktop-widget-status.png`
- `docs/assets/images/desktop-widget-dashboard.png`

### README (`docs/screenshots/`)
- `docs/screenshots/app-overview-tab.png`
- `docs/screenshots/app-battery-tab.png`
- `docs/screenshots/app-cpu-tab.png`
- `docs/screenshots/app-memory-tab.png`
- `docs/screenshots/app-weather-tab.png`
- `docs/screenshots/app-settings-compact.png`
- `docs/screenshots/notch-widget-compact.png`
- `docs/screenshots/notch-widget-expanded.png`
- `docs/screenshots/notch-weather-compact.png`
- `docs/screenshots/notch-weather-expanded.png`
- `docs/screenshots/desktop-widget-glance.png`
- `docs/screenshots/desktop-widget-glance-weather.png`
- `docs/screenshots/desktop-widget-status.png`
- `docs/screenshots/desktop-widget-dashboard.png`

---

## Recommended additions (new features)

The repo gained new user-facing surfaces (Network, Audio, Alerts, Weather Alerts / Current location).
If you want the website/README to visually reflect them, capture and add:

- Popover System → Network: `app-network-tab.png`
- Popover System → Audio: `app-audio-tab.png`
- Popover Alerts tab: `app-alerts-tab.png`
- Settings → Alerts (Notch Glow + Weather Alerts): `app-settings-alerts.png`
- Settings → Weather showing “Current location”: `app-settings-weather-current-location.png`

If you add these, place them in both:
- `docs/assets/images/` (website)
- `docs/screenshots/` (README / repo)

Then update:
- `docs/index.md` and/or `docs/features.md` (website)
- `README.md` (repo)

---

## Capture checklist

- Use a clean desktop background and hide sensitive menu bar items if possible.
- Use a generic location name (e.g. “San Francisco, CA”) for Weather.
- Avoid showing SSIDs or device serials.
- Keep the popover at its default size (don’t resize mid-capture).
