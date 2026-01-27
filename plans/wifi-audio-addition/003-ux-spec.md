# UX Spec — Wi‑Fi + Audio in Microverse

## Design goals (Microverse style)

- **Clarity**: the primary state should be readable in 1 second.
- **Deference**: the UI should not “shout”; it should feel calm and precise.
- **Hierarchy**: advanced details exist, but stay secondary.
- **Consistency**: match existing Microverse card/list patterns, avoid dropdowns.

## Surfaces

### Popover → System → Network

Add a compact “WI‑FI” card above throughput:
- Icon + state (“Wi‑Fi off / Not connected / Connected”)
- Strength bars + percentage (when connected)
- Optional one-line details (RSSI / Tx rate) in a subtle caption

### Popover → System → Audio

Audio should be a dedicated section (like Battery/CPU/Memory/Network):
- Output devices list + selection highlight + checkmark
- Output volume slider (only if supported)
- Output mute toggle (only if supported)
- Input devices list + selection
- “Open Sound Settings” for full management

### Desktop Widget (Custom Modular)

Expose optional modules:
- Wi‑Fi: percentage + quality
- Audio output: volume (or “Muted”) + device name
- Audio input: device name

## Accessibility

- All icon-only buttons must have `.help` and accessibility labels.
- Values should be readable in VoiceOver (e.g., “Wi‑Fi signal strength: 2 of 3 bars”).
- Respect Reduce Motion when animating metric changes.

## Failure states

- Wi‑Fi interface unavailable → show “Wi‑Fi unavailable” (no empty cards).
- Volume not settable → show explanatory caption + disable slider.
- Device list empty → show “No devices” message.

