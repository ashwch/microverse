# 007 - Next Additions Roadmap

## Goal

Identify the next high-leverage feature(s) that fit Microverse’s philosophy (fast glanceability, minimal distraction, notch-native UX) while staying safe, performant, and maintainable.

## Dependencies

- Requires: 001
- Blocks: None

## Scope

**In scope:**
- Concrete next-feature proposals, each with UX goals, technical approach, and risks.
- A rough ordering that balances user value and engineering risk.
- Quality bar notes: UI, performance, energy, privacy/security.

**Out of scope:**
- Implementing the features (this is roadmap only).

## Checklist

- [ ] Reconfirm Microverse’s product constraints:
  - Menu bar first (quick glance)
  - Notch UX must stay in DynamicNotchKit’s coordinate space (no drift)
  - Avoid requiring extra entitlements unless the value is undeniable
- [ ] Pick the “next 1 feature” and define:
  - The user story
  - The UI surface(s) (popover tab, notch compact/expanded, widget)
  - The data source and its refresh strategy
  - A minimal first release (v1) that can ship without perfection debt
- [ ] Define acceptance criteria that match a high-quality macOS app:
  - Good defaults
  - Clear privacy story
  - Energy efficient (no hot polling)
  - Accessible (reduce motion, contrast, keyboard navigation where relevant)

## Tests

- [ ] N/A (roadmap-only file). Justification: this file proposes work; it doesn’t change runtime behavior.

## Completion Criteria

- [ ] A new contributor can read this file and confidently start implementing the chosen “next 1 feature” without reopening old design debates.
- [ ] Each proposed feature includes at least one explicit risk and mitigation.

## Notes

### Top recommendation: Unified “Alerts + Rules” system

**Why it fits:** Microverse already has notch glow alerts (battery-driven). Generalizing this into a small “rules engine” unlocks multiple high-value alerts without bloating the UI.

**v1 scope idea:**

- New “Alerts” tab (popover) + settings section.
- Rule types:
  - Battery: low/critical, charge reached, charging state changes
  - Weather: rain starting soon / clearing soon / temp delta (already computed)
  - System: CPU sustained high, memory pressure high
- Delivery channels:
  - Notch glow (in-pill)
  - macOS notifications (optional toggle)
  - Menu bar indicator (optional)

**Risks / mitigations:**
- Too many alerts → require cooldown/dwell defaults; add “quiet hours”.
- Energy use → drive alerts from existing measurement streams; avoid new hot polling loops.
- UX clutter → start with a small set of opinionated presets + an “advanced” section.

### Other strong candidates (after Alerts)

1. **Network glance** (up/down rate, maybe per-interface) with careful energy budgeting.
2. **Top processes** (CPU/memory) with privacy sensitivity and sampling limits.
3. **Disk / I/O** (lightweight, avoid aggressive polling).
4. **Weather v2** (optional CoreLocation “use current location”, behind a clear permission prompt and strong privacy explanation).

### Quality bar references (useful links)

- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
- macOS menu bar extras best practices (HIG section): https://developer.apple.com/design/human-interface-guidelines/menu-bars
- App Sandbox/entitlements: https://developer.apple.com/documentation/security/app_sandbox
- Energy efficiency: https://developer.apple.com/documentation/xcode/energy-efficiency

