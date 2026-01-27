# Wi‑Fi Strength — Research Notes (macOS)

## 1) What users mean by “Wi‑Fi strength”

On macOS, users typically interpret Wi‑Fi strength as the **bars icon** in the menu bar:

- Bars correlate with perceived quality; users mentally map “more bars” → “stronger signal” and fewer → “weak / unstable”.
- Users also expect common states (Wi‑Fi off, disconnected, no internet).

Reference (Apple Support): menu bar Wi‑Fi icons and their meanings:
- https://support.apple.com/guide/mac-help/wi-fi-menu-icons-on-mac-mchlcedc581e/mac
- https://support.apple.com/guide/mac-help/use-the-wi-fi-status-menu-on-mac-mchlfad426fa/mac

## 2) What Microverse should show (UX targets)

### Default (high-signal, low-noise)

- Strength as **3‑bar** indicator (0–3) + **percentage** (optional).
- A short quality word: **Excellent / Good / Fair / Weak**.
- A single “status line” for state:
  - *Wi‑Fi off*
  - *Not connected*
  - *Connected* (optionally show network name if available and user opts in)

### “Details” (only when needed)

Advanced data is useful for debugging, but should not dominate the UI:

- RSSI (dBm)
- Noise (dBm)
- Transmit rate (Mbps)
- (Optional future) Channel, band (2.4/5/6GHz), PHY mode

## 3) APIs & feasibility (Swift / macOS)

### CoreWLAN (recommended for this app)

CoreWLAN provides access to the current Wi‑Fi interface and common metrics (RSSI/noise/tx rate/SSID).

Pros:
- Can read “current connection” metrics without active scanning.
- Lightweight enough for a periodic poll model.

Cons / gotchas:
- On newer macOS versions, **SSID/BSSID can be redacted** depending on privacy settings (often related to location authorization).
- Actively scanning for nearby SSIDs is more invasive and can trigger permission requirements.

Practical approach:
- Prefer showing **signal strength without SSID** by default.
- If SSID is present, we can display it; otherwise show “Connected”.

Helpful discussion (SSID privacy / location authorization):
- https://stackoverflow.com/questions/47102280/cwinterface-ssid-returning-nil
- https://stackoverflow.com/questions/57879767/cllocationmanager-authorizationstatus-always-returns-notdetermined
- https://www.netspotapp.com/help/how-to-fix-wi-fi-scanning-issues-in-macos-catalina/

### NetworkExtension / NEHotspotHelper (not recommended here)

Generally intended for managed Wi‑Fi / special use-cases; higher friction and not appropriate for a lightweight system monitor.

## 4) Privacy & security posture

Wi‑Fi can reveal sensitive info (network name, location inference).

Microverse should:
- Avoid requesting location permission for “strength” only.
- Avoid logging SSIDs in release builds.
- Prefer “connected” + strength unless the user explicitly opts in to show SSID.

## 5) Performance guidance

Wi‑Fi metrics change slower than CPU/network throughput; a **2–5s polling interval** is usually sufficient.
Avoid:
- frequent scans
- heavy background work

## 6) Suggested future enhancements (optional)

- Optional user setting: “Show network name (SSID)”.
- Optional: show “internet reachable” status by checking route reachability (not just association).
- Optional: show which interface is active (Wi‑Fi vs Ethernet) and prioritize accordingly.
