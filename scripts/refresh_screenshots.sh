#!/usr/bin/env bash
set -euo pipefail

# Microverse screenshot refresh (website + README)
# ===============================================
#
# Why this script exists:
# - The Microverse website (GitHub Pages) and README are powered by PNGs in `docs/`.
# - OS-level screenshot tools (`screencapture`) are often blocked in CI or agent environments.
# - Microverse includes a DEBUG-only in-app PNG exporter (`--debug-export-*`) that can render the
#   popover/settings/notch/widget deterministically without any screen recording permission.
#
# First principles:
# - Deterministic + privacy-safe: always run with `--debug-screenshot-mode` so no SSIDs/device names leak.
# - One Microverse at a time: kill any running copies before capturing to avoid mismatched windows.
# - Stable filenames: replace the existing `docs/**.png` files in-place so links don’t break.
#
# Usage:
#   scripts/refresh_screenshots.sh
#
# Notes:
# - This uses `make debug-app` and runs `/tmp/Microverse.app/Contents/MacOS/Microverse` directly (fast + reliable).
# - Each capture is a fresh process so UI state from one run can’t pollute the next screenshot.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/tmp/Microverse.app/Contents/MacOS/Microverse"

kill_microverse() {
  # Be aggressive: screenshot exports should never run alongside an interactive Microverse instance.
  pkill -f "/tmp/Microverse.app/Contents/MacOS/Microverse" 2>/dev/null || true
  pkill -f "/private/tmp/Microverse.app/Contents/MacOS/Microverse" 2>/dev/null || true
  pkill -f "/Applications/Microverse.app/Contents/MacOS/Microverse" 2>/dev/null || true
}

capture() {
  local kind="$1"    # popover|settings|widget|notch
  local out="$2"     # full output path
  shift 2
  local args=("$@")

  local tmpdir
  tmpdir="$(mktemp -d /tmp/microverse-screenshot-run.XXXXXX)"
  trap 'rm -rf "$tmpdir"' RETURN

  kill_microverse

  local exportFlag
  case "$kind" in
    popover) exportFlag="--debug-export-popover=$tmpdir/out.png" ;;
    settings) exportFlag="--debug-export-settings=$tmpdir/out.png" ;;
    widget) exportFlag="--debug-export-widget=$tmpdir/out.png" ;;
    notch) exportFlag="--debug-export-notch=$tmpdir/out.png" ;;
    *)
      echo "Unknown kind: $kind" >&2
      exit 2
      ;;
  esac

  "$APP" \
    --debug-screenshot-mode \
    --debug-export-wait=3.0 \
    "$exportFlag" \
    "${args[@]}"

  mkdir -p "$(dirname "$out")"
  cp "$tmpdir/out.png" "$out"
  echo "Wrote $out"
}

cd "$ROOT"

echo "Building /tmp/Microverse.app (Debug)…"
make debug-app

echo "Refreshing website images in docs/assets/images/…"
capture popover "docs/assets/images/app-overview-tab.png" --debug-open-system-overview
capture popover "docs/assets/images/app-battery-tab.png" --debug-open-system-battery
capture popover "docs/assets/images/app-cpu-tab.png" --debug-open-system-cpu
capture popover "docs/assets/images/app-memory-tab.png" --debug-open-system-memory
capture popover "docs/assets/images/app-weather-tab.png" --debug-screenshot-weather --debug-weather-scenario=rainIn25m

# Settings screenshots
capture settings "docs/assets/images/app-settings-notch-glow.png" --debug-open-settings=alerts

# Notch + widget (system)
capture notch "docs/assets/images/notch-widget-compact.png" --debug-notch-layout=split --debug-notch-style=compact
capture notch "docs/assets/images/notch-widget-expanded.png" --debug-notch-layout=split --debug-notch-style=expanded
capture widget "docs/assets/images/desktop-widget-glance.png" --debug-widget-show --debug-widget-style=systemGlance
capture widget "docs/assets/images/desktop-widget-status.png" --debug-widget-show --debug-widget-style=systemStatus
capture widget "docs/assets/images/desktop-widget-dashboard.png" --debug-widget-show --debug-widget-style=systemDashboard

# Notch + widget (weather peek)
capture notch "docs/assets/images/notch-weather-compact.png" --debug-preview-weather --debug-weather-scenario=rainIn25m --debug-notch-layout=split --debug-notch-style=compact
capture notch "docs/assets/images/notch-weather-expanded.png" --debug-preview-weather --debug-weather-scenario=rainIn25m --debug-notch-layout=split --debug-notch-style=expanded
capture widget "docs/assets/images/desktop-widget-glance-weather.png" --debug-preview-weather --debug-weather-scenario=rainIn25m --debug-widget-show --debug-widget-style=systemGlance

# Notch glow demo
capture notch "docs/assets/images/notch-glow-success.png" --debug-notch-glow=success --debug-notch-layout=split --debug-notch-style=expanded

echo "Refreshing README screenshots in docs/screenshots/…"
capture popover "docs/screenshots/app-overview-tab.png" --debug-open-system-overview
capture popover "docs/screenshots/app-battery-tab.png" --debug-open-system-battery
capture popover "docs/screenshots/app-cpu-tab.png" --debug-open-system-cpu
capture popover "docs/screenshots/app-memory-tab.png" --debug-open-system-memory
capture popover "docs/screenshots/app-weather-tab.png" --debug-screenshot-weather --debug-weather-scenario=rainIn25m

# README settings screenshot (compact crop: use the same alerts view as the website for now)
capture settings "docs/screenshots/app-settings-compact.png" --debug-open-settings=general

capture notch "docs/screenshots/notch-widget-compact.png" --debug-notch-layout=split --debug-notch-style=compact
capture notch "docs/screenshots/notch-widget-expanded.png" --debug-notch-layout=split --debug-notch-style=expanded
capture notch "docs/screenshots/notch-weather-compact.png" --debug-preview-weather --debug-weather-scenario=rainIn25m --debug-notch-layout=split --debug-notch-style=compact
capture notch "docs/screenshots/notch-weather-expanded.png" --debug-preview-weather --debug-weather-scenario=rainIn25m --debug-notch-layout=split --debug-notch-style=expanded

capture widget "docs/screenshots/desktop-widget-glance.png" --debug-widget-show --debug-widget-style=systemGlance
capture widget "docs/screenshots/desktop-widget-status.png" --debug-widget-show --debug-widget-style=systemStatus
capture widget "docs/screenshots/desktop-widget-dashboard.png" --debug-widget-show --debug-widget-style=systemDashboard
capture widget "docs/screenshots/desktop-widget-glance-weather.png" --debug-preview-weather --debug-weather-scenario=rainIn25m --debug-widget-show --debug-widget-style=systemGlance

kill_microverse

echo "Done."
