# Audio Devices — Research Notes (macOS)

## 1) What users expect (mental model)

On macOS, users manage audio routing through:

- **Control Center / menu bar** quick selection
- **System Settings → Sound** for full device lists and volume controls

The standard model:
- **Output**: choose device (Speakers, AirPods, HDMI, etc), adjust output volume, sometimes mute.
- **Input**: choose device (Built‑in mic, headset mic, etc), sometimes see input level meter.

Apple Support references:
- Sound settings overview: https://support.apple.com/guide/mac-help/change-sound-settings-mchlp9777ee30/mac
- Choose input/output devices: https://support.apple.com/guide/mac-help/output-settings-mchlp2256/mac

## 2) What Microverse should show (UX targets)

### Default (clean + fast)

Popover UI should allow:
- See the **current output device** and **current input device** at a glance.
- Switch output/input device via a simple list (no dropdowns).
- Adjust output volume *when supported*.
- Provide a one-tap “Open Sound Settings”.

### Respect device limitations

Not every audio route supports volume/mute controls (e.g., some HDMI/AirPlay routes).
UI should:
- show volume when readable
- disable controls when not settable (instead of failing silently)

## 3) APIs & feasibility (Swift / macOS)

### CoreAudio (recommended)

CoreAudio exposes:
- device enumeration
- default input/output device IDs
- per-device properties (name/uid, stream configs, volume/mute)
- setting default device (output/input)

Useful references:
- Enumerating devices with CoreAudio: https://stackoverflow.com/questions/74266107/getting-audio-devices-in-macos
- Device selection patterns: https://gist.github.com/insidegui/2b1f747ebeb9070d36c528c61e535c20
- Volume property notes (older but helpful): https://developer.apple.com/library/archive/qa/qa1016/_index.html

### AVFoundation

AVFoundation is great for audio playback/recording, but is not the primary tool for system-wide device routing on macOS.

## 4) Privacy & security posture

Listing devices and switching defaults is not the same as recording audio.

Microverse should:
- not capture microphone audio for “device list” features
- not request microphone permission unless we add an explicit feature requiring it (e.g., live mic level meter)

## 5) Performance guidance

Audio device changes are event-driven in reality, but a slow poll (2–5s) is acceptable for a lightweight monitor.
If we ever observe:
- excessive CPU usage
- noticeable UI latency during polling

…we should move to CoreAudio property listeners (more complex but efficient).

## 6) Suggested future enhancements (optional)

- Show “input level” meter (requires additional CoreAudio metering work and careful permissions stance).
- Surface per-device sample rate / format (for power users) under a disclosure.
- Add a custom widget module: “Audio Output” (device + volume) and “Audio Input” (device).
