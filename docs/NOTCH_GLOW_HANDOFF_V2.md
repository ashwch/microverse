# Help Request: Notch Glow Alignment Bug (Microverse) — Handoff v2

Date: 2026-01-09  
App: Microverse (SwiftUI + AppKit, SwiftPM)  
Feature: Notch Glow Alerts (animated glow/sparkles on battery events)

Hi! We’re building a “notch glow alert” for Microverse (glow/sparkles around the notch on battery events). We can render an animated glow overlay, but we’re stuck getting it to align with what users visually perceive as “the notch”.

We’d love your help validating our diagnosis and recommending the cleanest implementation path.

## UPDATE (2026-01-11): Resolved — What we changed to fix alignment

We ultimately fixed the “misaligned glow” by **moving the glow rendering inside DynamicNotchKit’s SwiftUI tree**, instead of trying to line up a separate overlay window with the physical notch geometry.

This removed the core mismatch:

- **Physical notch geometry** (safe area + `auxiliaryTopLeftArea/right`) is not the same as…
- **DynamicNotchKit’s pill** (content-driven width + compact-only `.offset(x:)`), which is what users visually anchor to.

By rendering the glow in the **same** coordinate space as the pill, the glow automatically inherits DynamicNotchKit’s offsets/transforms and stays perfectly aligned.

### Implementation summary (current code)

- Vendored DynamicNotchKit locally: `Packages/DynamicNotchKit/` and switched SwiftPM to `.package(path: "Packages/DynamicNotchKit")`.
- Added a “decoration hook” to DynamicNotchKit:
  - `DynamicNotch` now has a `decoration` view + `setDecoration { ... }`.
  - `NotchView` renders `dynamicNotch.decoration` **after** the mask using `.overlay(alignment: .top)` so blur can extend beyond the pill without being clipped.
- Microverse wires the decoration on notch creation:
  - `MicroverseNotchSystem.swift` calls `notch.setDecoration { MicroverseNotchGlowDecorationView() }`.
- Glow triggering prefers the in-notch path:
  - `NotchGlowManager.showAlert(...)` routes to `NotchGlowInNotchController` whenever Smart Notch is enabled (layoutMode != `.off`).
  - The old overlay-window approach remains as a fallback when the notch UI is disabled.

### Current rules: when the glow shows

Defined in `BatteryViewModel.checkAndTriggerAlerts()`:

- `enableNotchAlerts` must be ON, and the main screen must have a notch.
- Charger connected: `isPluggedIn` flips `false -> true` (shows **success** glow, slow ping-pong).
- Fully charged: battery reaches `100%` while plugged in (shows **success** glow).
- Low battery: crossing down past `20%` while on battery power (shows **warning** glow once until recovered > 20%).
- Critical battery: `<= 10%` while on battery power (shows **critical** glow once until recovered > 10%).

### Motion + startup animation

- Success (“charging”): **ping-pong sweep** (anticlockwise then clockwise to end), slower timing for charging-start.
- Success (“charging”): **ping-pong sweep** (anticlockwise then clockwise to end), slower timing for charger-connected.
- Warning/critical/info: loop sweep.
- Startup animation: optional 1-time-per-run **RGB** sequence (red/green/blue in shuffled order with mixed motions), gated by `enableNotchStartupAnimation`.

## Copy/paste help request (short)

Hi — we’d love help debugging a “notch glow” overlay alignment bug in our macOS app (Microverse).

We can render a visible glow (transparent `.screenSaver`-level overlay panel), but it doesn’t line up with what users perceive as “the notch”. We think this is because we accidentally treated two different geometries as the same contract:

- macOS “physical notch / safe-area” geometry (`NSScreen.safeAreaInsets.top`, `auxiliaryTopLeftArea/right`)
- DynamicNotchKit’s **software pill** geometry (content-driven width + compact-only `xOffset` via SwiftUI `.offset(x:)`)

Today we “best-effort” replicate DynamicNotchKit’s compact pill math externally by measuring our compact leading/trailing SwiftUI widths and computing `pillFrame` (see below). It’s visible but still sometimes misaligned due to width timing, constant mismatch, and possibly SwiftUI transform-vs-layout nuances.

Could you recommend the cleanest fix under these constraints?
- Option A: add a small hook to DynamicNotchKit to draw the glow *inside* the pill SwiftUI tree (decoration slot outside the mask).
- Option B: keep an external overlay panel but measure the **true pill frame** from inside the pill (e.g., NSViewRepresentable reporter + window notifications) and drive the overlay from that.

Questions:
- In SwiftUI, does DynamicNotchKit’s `.offset(x:)` mean external “layout measurement” can diverge from the *visual* pill frame?
- Is there any macOS API / best practice we’re missing for “exact notch frame” or safe-area compatibility quirks?
- Any caveats around `.screenSaver` panels, child windows, Spaces/fullscreen, and occlusion near the menu bar?

## What we’re asking you for

- Please sanity-check the diagnosis below (especially the geometry assumptions).
- Given our constraints, what’s the cleanest fix?
  - Integrate glow into DynamicNotchKit’s SwiftUI tree?
  - Keep a separate overlay window but measure the true pill frame?
  - Something else (Core Animation layer, NSView overlay, etc.)?
- Is there any macOS API or known technique we’re missing for “exact notch/island frame”?
- Any gotchas around “Display Safe Area Compatibility Mode” (Info.plist `NSPrefersDisplaySafeAreaCompatibilityMode`) affecting screen coordinates / window placement?
- Any caveats about `.screenSaver` panels, layering, and occlusion near the menu bar/notch area?

## TL;DR (our current hypothesis)

This is not (primarily) a “window level” or “SwiftUI glow strength” bug anymore.

We believe it’s a **coordinate-system contract bug**: we accidentally treated two different “notch” geometries as the same thing.

- **Physical notch / safe-area geometry (system):** what macOS reports via `NSScreen.safeAreaInsets.top` and `auxiliaryTopLeftArea/right`.
- **DynamicNotchKit pill geometry (software):** a black “island/pill” drawn inside a big `.screenSaver` `NSPanel`, whose width and horizontal offset depend on runtime-measured SwiftUI content widths.

If we anchor the glow to the physical notch frame, it will drift relative to the DynamicNotchKit pill. Users compare against the pill, so it looks “wrong”.

## What users see

We can render an animated glow overlay and it’s visible, but it:

- appears “under the notch”
- has the wrong width (too narrow vs pill)
- is shifted left/right depending on leading vs trailing content width (split layout)

Earlier, the glow could also be completely invisible due to occlusion/clipping. That part is largely solved now.

## Short history (why we’re still “seeing the same output” after many iterations)

We’ve iterated a lot and it can *look* like nothing changes because there are **two separate issues** that can mask progress:

1) **The original implementation was anchoring to the physical notch**, while users are judging alignment against **DynamicNotchKit’s software pill**.

2) Even after improving math, it’s easy to accidentally test an old build or test before geometry is available:
   - If the app instance isn’t truly restarted, you can be looking at old behavior/old args (see “workflow trap” below).
   - If the alert triggers before leading/trailing widths have been measured, the code falls back to `0` widths, making the glow look like the older “narrow centered” behavior.

Timeline summary:

- **Phase 1 (manual notch windows):** We created our own `NSWindow`/SwiftUI `Canvas` overlay around the “physical notch frame” from `NSScreen.safeAreaInsets` + auxiliary areas. The glow was often **invisible** (occluded / clipped), and when visible it didn’t match what users perceived as “the notch” (because the visible pill comes from DynamicNotchKit).
- **Phase 2 (restore working notch system):** We restored the previously-working DynamicNotchKit-based notch UI that lived in an orphan commit (`319fb3f`) and wasn’t merged.
- **Phase 3 (visible but misaligned):** After raising window level and/or attaching as a child of the DynamicNotchKit panel, the glow became **consistently visible**, but still **misaligned** (wrong width/offset).
- **Phase 4 (current):** We now try to align to DynamicNotchKit’s compact pill by measuring compact leading/trailing widths (SwiftUI) and replicating the library’s compact geometry math externally. This is “best effort” but still sometimes looks unchanged due to startup timing or constant mismatch.

## The suspected root cause (two notch definitions)

### 1) Physical notch/safe-area geometry (system)

This is derived from `NSScreen.safeAreaInsets.top` and `auxiliaryTopLeftArea/right` (available on notched screens). Example computation:

```swift
extension NSScreen {
    var hasNotch: Bool {
        auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil
    }

    var notchSize: CGSize {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return .zero }
        let width = frame.width - left.width - right.width
        let height = safeAreaInsets.top
        return CGSize(width: width, height: height)
    }

    var notchFrame: CGRect {
        let size = notchSize
        guard size != .zero else { return .zero }
        return CGRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
```

Important nuance (please confirm): On notched MacBooks, parts of that top region correspond to the **camera cutout (no pixels)**, so drawing “around the cutout” (especially along the top edge) can be partially invisible/clipped.

Small question: is the best-practice way to compute the physical notch width to use the **edges** of the auxiliary rects (instead of subtracting widths)? We suspect this is more robust for multi-display coordinate quirks:

```swift
extension NSScreen {
    var physicalNotchFrame: CGRect {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return .zero }

        // These are global screen coordinates.
        let notchX = left.maxX
        let notchWidth = right.minX - left.maxX

        // Height is typically safeAreaInsets.top; auxiliary heights can also be used as a fallback.
        let notchHeight = max(safeAreaInsets.top, left.height, right.height)
        let notchY = frame.maxY - notchHeight

        guard notchWidth > 0, notchHeight > 0 else { return .zero }
        return CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
    }
}
```

### 2) DynamicNotchKit compact pill geometry (software)

DynamicNotchKit does not render “the notch frame”. It renders a pill whose geometry depends on the content (please confirm this mental model matches reality).

In compact mode it effectively does:

```text
pillWidth = notchWidth + leadingWidth + trailingWidth + 2*topCornerRadius
xOffset   = (trailingWidth - leadingWidth) / 2
pillX     = screen.midX - pillWidth/2 + xOffset
pillY     = screen.maxY - notchHeight
```

So if Microverse uses a split layout (battery left, cpu/mem right) the leading/trailing widths differ; the pill shifts and changes width. A glow anchored to “physical notchWidth centered at midX” cannot match.

**Version note / request for confirmation:** we are pinned to `DynamicNotchKit` `1.0.0` (SwiftPM `from: "1.0.0"`, macOS 13+). In this version, the library appears to *explicitly* compute and apply a compact horizontal offset based on leading/trailing widths:

```swift
// DynamicNotchKit (v1.0.0) NotchView.swift (simplified)
private var compactXOffset: CGFloat { (compactTrailingWidth - compactLeadingWidth) / 2 }
private var xOffset: CGFloat { dynamicNotch.state != .compact ? 0 : compactXOffset }
...
.offset(x: xOffset)
```

If you’re familiar with a newer/older DynamicNotchKit revision where this behavior differs, please call it out — it affects whether an external overlay should apply the same `xOffset` or stay centered.

## What we tried (and why it still sometimes looks “the same”)

### Visibility fixes (worked)

DynamicNotchKit uses an `NSPanel` at `.screenSaver`. A separate overlay window can be hidden behind it unless it’s ordered above it.

Microverse therefore uses:

- glow panel level: `.screenSaver + 1`
- and optionally attaches it as a child window of the DynamicNotchKit panel

```swift
// Microverse: Sources/Microverse/NotchGlowManager.swift
self.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
```

This mostly resolved “invisible glow” caused by occlusion.

Key window config (Microverse):

```swift
// Microverse: Sources/Microverse/NotchGlowManager.swift
final class NotchGlowWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // DynamicNotchKit uses `.screenSaver`; bump slightly so we can draw above it.
        self.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
    }
}
```

Child-window attachment (Microverse):

```swift
// Microverse: Sources/Microverse/NotchGlowManager.swift
private func attachAboveDynamicNotchIfPossible(glowWindow: NSWindow, on screen: NSScreen) {
    guard let parent = findDynamicNotchParentWindow(on: screen) else { return }
    parent.addChildWindow(glowWindow, ordered: .above)
}
```

### Why it can appear like code changes “did nothing” (workflow trap)

Launching with:

```bash
open /tmp/Microverse.app --args ...
```

often **reuses an already-running instance** of the app, so you end up viewing old behavior/old args.

Use one of:

```bash
pkill -f Microverse
open -n /tmp/Microverse.app --args ...
```

Microverse also has a debug flag that triggers glow on startup:

```swift
// Microverse: Sources/Microverse/MenuBarApp.swift
--debug-notch-glow=success|warning|critical|info
```

## Current approach in Microverse (best-effort external alignment)

Because DynamicNotchKit doesn’t expose a stable “pill frame” API, Microverse currently tries to replicate the compact pill math externally:

1) Measure leading/trailing compact content widths in SwiftUI via a `PreferenceKey`.
2) Compute `pillFrame` using the formula above.
3) Position the overlay window around `pillFrame`.
4) Draw a pill-shaped glow using radii that match DynamicNotchKit’s compact mode (top=6, bottom=14).

### Width measurement code (Microverse)

```swift
// Microverse: Sources/Microverse/MicroverseNotchSystem.swift
@Published private(set) var compactLeadingContentWidth: CGFloat = 0
@Published private(set) var compactTrailingContentWidth: CGFloat = 0

private struct MicroverseWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private extension View {
    func microverseReportWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background { GeometryReader { proxy in
            Color.clear.preference(key: MicroverseWidthPreferenceKey.self, value: proxy.size.width)
        }}
        .onPreferenceChange(MicroverseWidthPreferenceKey.self, perform: onChange)
    }
}
```

Where those widths are captured (at notch creation time):

```swift
// Microverse: Sources/Microverse/MicroverseNotchSystem.swift (inside DynamicNotch { ... } creation)
MicroverseCompactLeadingView()
    .environmentObject(batteryViewModel)
    .microverseReportWidth { self.compactLeadingContentWidth = $0 }

MicroverseCompactTrailingView()
    .environmentObject(batteryViewModel)
    .microverseReportWidth { self.compactTrailingContentWidth = $0 }
```

### DynamicNotchKit’s actual compact layout constants (v1.0.0)

We are trying to replicate these key behaviors from DynamicNotchKit’s `NotchView.swift` (v1.0.0):

```swift
// DynamicNotchKit: Sources/DynamicNotchKit/Views/NotchView.swift (v1.0.0)
private var compactNotchCornerRadii: (top: CGFloat, bottom: CGFloat) { (top: 6, bottom: 14) }
private var compactXOffset: CGFloat { (compactTrailingWidth - compactLeadingWidth) / 2 }

func compactContent() -> some View {
    HStack(spacing: 0) {
        dynamicNotch.compactLeadingContent
            .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: 8) }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 4) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 8) }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { compactLeadingWidth = $0 }

        Spacer().frame(width: dynamicNotch.notchSize.width)

        dynamicNotch.compactTrailingContent
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 8) }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 4) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 8) }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { compactTrailingWidth = $0 }
    }
}

private func notchContent() -> some View {
    ZStack { ... }
        .padding(.horizontal, topCornerRadius)
        .fixedSize()
}
```

Our key mismatch risk: **Microverse measures the “raw” leading/trailing content widths before DynamicNotchKit’s `safeAreaInset(edge: .leading/.trailing) { width: 8 }` is applied**, so we add an extra `+8` to each side in our computation.

### Pill-frame computation (Microverse)

```swift
// Microverse: Sources/Microverse/NotchGlowManager.swift
let compactTopCornerRadius: CGFloat = 6
let compactSectionInset: CGFloat = 8 // mirrors DynamicNotchKit’s compact side inset

let leadingWidth  = rawLeadingWidth  > 0 ? (rawLeadingWidth  + compactSectionInset) : 0
let trailingWidth = rawTrailingWidth > 0 ? (rawTrailingWidth + compactSectionInset) : 0

let pillWidth = baseNotchWidth + leadingWidth + trailingWidth + (compactTopCornerRadius * 2)
let xOffset = (trailingWidth - leadingWidth) / 2

let pillFrame = CGRect(
    x: screen.frame.midX - (pillWidth / 2) + xOffset,
    y: screen.frame.maxY - baseNotchHeight,
    width: pillWidth,
    height: baseNotchHeight
)
```

We also log the computed geometry each time we show an alert:

```swift
// Microverse: Sources/Microverse/NotchGlowManager.swift
NSLog("NotchGlow: baseNotch=(\\(baseNotchWidth)x\\(baseNotchHeight)) leading=\\(leadingWidth) trailing=\\(trailingWidth) pill=\\(pillFrame) window=\\(windowFrame)")
```

### Why this still bites us (even if the math is “right”)

Even if the formula matches the library today, it remains brittle:

1) **Timing:** width measurements can be `0` until after SwiftUI layout. Battery alerts can fire at startup before widths are available.
2) **State:** if notch UI is disabled/off, there are no widths to measure; we fall back to physical geometry.
3) **Library drift:** any future DynamicNotchKit padding/radius adjustments make our constants wrong.
4) **Multiple layouts:** Left vs Split changes widths dramatically and changes `xOffset`.

So this approach can *still* look like “same output” if (1) happens and widths are 0, or if the app instance wasn’t actually relaunched.

#### Most likely “still looks wrong” causes (please sanity-check)

1) **Width timing:** At the moment `showAlert()` runs, `compactLeadingContentWidth` and/or `compactTrailingContentWidth` might still be `0`. That makes the computed `pillWidth` collapse to something close to the physical notch width, producing the “narrow centered glow” look.
2) **Constant mismatch:** We add `+8` per side to account for DynamicNotchKit’s `safeAreaInset(width: 8)`, but if the library’s geometry differs (or we attached the width reporter to the wrong SwiftUI node), our “replicated” pill math will be wrong.
3) **Transform-driven visuals:** If DynamicNotchKit ever animates the pill boundary using transforms rather than layout, our external math will match the steady-state rect but can look “off” mid-transition.

## Extra nuance we’d love your take on: SwiftUI transforms vs layout (why Option B can still drift)

DynamicNotchKit’s `NotchView.swift` (v1.0.0) applies a compact-only horizontal shift using SwiftUI’s `.offset(x:)`:

```swift
// DynamicNotchKit: Sources/DynamicNotchKit/Views/NotchView.swift (v1.0.0)
private var compactXOffset: CGFloat { (compactTrailingWidth - compactLeadingWidth) / 2 }
...
.offset(x: dynamicNotch.state != .compact ? 0 : compactXOffset)
```

As far as we understand, SwiftUI `.offset` is a **render-time transform** and not necessarily a layout change. This raises a subtle concern for “measure the pill rect and drive an external overlay” approaches:

- If we measure something that reflects the *layout* rect but not the *visual* rect after transforms, our overlay can be “correct” numerically but still appear off.

If you’ve dealt with this before, we’d love guidance:

- Is it safe to assume an AppKit `NSView` frame conversion (`convert(bounds,to:nil)` + `window.convertToScreen`) will reflect SwiftUI `.offset` for the relevant pill container?
- If not, what’s the best practice way to measure the *visual* pill bounds? For example, would you recommend measuring in SwiftUI using anchors, then converting to screen coordinates?

Sketch of an “anchor-based” approach (if you recommend it):

```swift
private struct PillBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = nextValue() ?? value }
}

// Attach this to the exact pill-boundary view (after transforms if possible).
pillView
    .anchorPreference(key: PillBoundsKey.self, value: .bounds) { $0 }
    .overlayPreferenceValue(PillBoundsKey.self) { anchor in
        GeometryReader { proxy in
            Color.clear.onAppear {
                guard let anchor else { return }
                let rectInLocal = proxy[anchor]
                // TODO: convert this to window/screen coords (likely via an NSViewRepresentable hook).
            }
        }
    }
```

Our suspicion: if transforms matter, this pushes strongly toward **Option A (glow inside DynamicNotchKit’s SwiftUI tree)** so glow inherits the exact same transforms and animations.

## What we think the cleanest fix is (seeking your guidance)

### Option A (best): Put the glow inside DynamicNotchKit’s view tree

This removes the ambiguity: the glow shares the exact same coordinate space, offsets, mask, and animation state.

Key rule: don’t draw glow in a subtree that’s clipped by the pill mask (or you’ll cut off the blur). Instead draw glow as a sibling layer:

```swift
ZStack {
  GlowOverlay(pillShape: NotchShape(...))
    .allowsHitTesting(false)

  ZStack {
    PillBackground()
    Content()
  }
  .clipShape(NotchShape(...))
}
.padding(glowPadding) // prevent blur clipping at container bounds
```

Practical ways to do this:

- **Fork/vendor DynamicNotchKit (MIT)** and add an overlay “slot” (a hook) in `NotchView`.
- Or upstream a small change to expose either:
  - `decoration: () -> some View`, or
  - `onPillFrameChange: (CGRect) -> Void`

### Option B (if separate overlay window must remain): Measure the *actual pill frame*, don’t replicate math

If we insist on keeping a separate overlay panel:

1) Add a tiny `NSViewRepresentable` “frame reporter” view *inside* the pill container (this likely still requires a small DynamicNotchKit hook/fork).
2) Convert its bounds to screen coordinates:
   - `view.convert(view.bounds, to: nil)` → window coords
   - `window.convertToScreen(...)` → screen coords
3) Use that true `CGRect` to position the glow overlay window.

This avoids guessing constants, avoids timing races, and handles hover/expanded transitions correctly.

Could you sanity-check whether the following “frame reporter” approach is sound on macOS 13+ SwiftUI (and recommend improvements if not)?

We suspect the *naive* approach (listen only to `NSView.frameDidChangeNotification`) is insufficient because the view’s frame can stay identical while the **window moves/screens change**, which still changes the view’s **screen-space rect**. So we think we need to observe window events too (`didMove`, `didResize`, `didChangeScreen`, `didChangeBackingProperties`) and re-report.

```swift
import SwiftUI
import AppKit

struct ScreenFrameReporter: NSViewRepresentable {
    var onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> ReportingView {
        let v = ReportingView()
        v.onChange = onChange
        return v
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onChange = onChange
        nsView.scheduleReport()
    }

    final class ReportingView: NSView {
        var onChange: ((CGRect) -> Void)?

        private var lastReported: CGRect = .null
        private var windowTokens: [NSObjectProtocol] = []
        private var reportScheduled = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            lastReported = .null // ensure we always emit after window attach/switch

            // If we detached from the window, proactively publish an invalid rect so consumers can hide/stop.
            if window == nil {
                unhookWindowNotifications()
                onChange?(.null)
                return
            }

            hookWindowNotifications()
            scheduleReport()
        }

        override func layout() {
            super.layout()
            scheduleReport()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            scheduleReport()
        }

        override func setFrameOrigin(_ newOrigin: NSPoint) {
            super.setFrameOrigin(newOrigin)
            scheduleReport()
        }

        deinit { unhookWindowNotifications() }

        private func unhookWindowNotifications() {
            let nc = NotificationCenter.default
            windowTokens.forEach(nc.removeObserver)
            windowTokens.removeAll()
        }

        private func hookWindowNotifications() {
            let nc = NotificationCenter.default
            unhookWindowNotifications()

            guard let w = window else { return }

            // Track events that can change screen-space rect even if the view-local frame doesn't change.
            windowTokens.append(nc.addObserver(forName: NSWindow.didMoveNotification, object: w, queue: .main) { [weak self] _ in
                self?.scheduleReport()
            })
            windowTokens.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: w, queue: .main) { [weak self] _ in
                self?.scheduleReport()
            })
            windowTokens.append(nc.addObserver(forName: NSWindow.didChangeScreenNotification, object: w, queue: .main) { [weak self] _ in
                self?.scheduleReport()
            })
            windowTokens.append(nc.addObserver(forName: NSWindow.didChangeBackingPropertiesNotification, object: w, queue: .main) { [weak self] _ in
                self?.scheduleReport()
            })

            // Optional: display config changes (monitor plug/unplug, resolution/layout changes).
            windowTokens.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleReport()
            })
        }

        func scheduleReport() {
            guard !reportScheduled else { return }
            reportScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.reportScheduled = false
                self.reportIfChanged()
            }
        }

        private func reportIfChanged() {
            guard let w = window, let onChange else { return }

            // Convert view bounds -> window -> screen
            let rectInWindow = convert(bounds, to: nil)
            guard rectInWindow.width > 0, rectInWindow.height > 0 else { return }

            let rectOnScreen = w.convertToScreen(rectInWindow)

            // Avoid jitter spam: snap to device pixel boundaries (in points).
            let step = 1.0 / max(1.0, w.backingScaleFactor) // 1.0 on 1x, 0.5 on 2x, etc.
            let stableRectOnScreen = snappedEdges(rectOnScreen, to: step)

            guard stableRectOnScreen != lastReported else { return }
            lastReported = stableRectOnScreen

            onChange(stableRectOnScreen)
        }

        private func snappedEdges(_ rect: CGRect, to step: CGFloat) -> CGRect {
            func snap(_ x: CGFloat) -> CGFloat { (x / step).rounded() * step }
            let minX = snap(rect.minX)
            let minY = snap(rect.minY)
            let maxX = snap(rect.maxX)
            let maxY = snap(rect.maxY)
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
}
```

Usage sketch (inside the pill container view):

```swift
PillContainerView()
    .background(ScreenFrameReporter { pillRectOnScreen in
        // Position glow overlay window from this rect (inflate by blur radius).
        glowManager.updateTargetRect(pillRectOnScreen)
    })
```

Small footgun we’d love you to call out if you’ve seen it before: we need to attach the reporter to the **exact view whose bounds match the pill** (not a padded parent), otherwise we’ll measure padding-inclusive bounds and the glow will still “feel off”.

Related footgun: in DynamicNotchKit’s notch view, there is a black `Rectangle()` background that is intentionally padded (e.g., `padding(-50)`) to avoid animation overshoot leaving transparent gaps. That background is *not* the pill bounds; measuring it will produce a rect that’s much larger than the visible pill.

One more question: does DynamicNotchKit animate the compact pill using **transforms** (e.g., `scaleEffect`, `offset`) rather than pure layout changes? If so, our reporter will measure the *layout* rect, not necessarily the *visual* rect. If you’ve dealt with this before, what’s the best practice:

- integrate glow into the same SwiftUI tree (Option A), or
- measure a different view (e.g., the mask host), or
- another technique to obtain the visual bounds?

## Product decisions to confirm (questions)

1) **What is the glow supposed to wrap?**
   - the DynamicNotchKit pill (software island), or
   - the physical notch cutout (hardware/safe area)?

2) **When notch UI is “Off”, should glow still show?**
   - If yes, what geometry should it use (physical notch? a centered fallback pill?)?

3) **Expanded / hover states:**
   - Should glow always use compact geometry?
   - Should it react to hover changes (DynamicNotchKit can adjust height on hover)?

4) **Multi-monitor rules:**
   - Follow the notch screen the UI is on?
   - Screen with mouse?
   - Always built-in display?

5) **OS compatibility:**
   - Microverse currently targets macOS 13+ due to DynamicNotchKit 1.0.0. Is that acceptable?

## Windowing / Spaces caveats we’d love guidance on

- DynamicNotchKit’s parent window is an `NSPanel` at `.screenSaver` with `collectionBehavior = [.canJoinAllSpaces, .stationary]`.
- Microverse’s glow overlay window is also an `NSPanel` at `.screenSaver + 1` and we often attach it as a child window ordered above.

Questions:

- Is `collectionBehavior` missing anything for reliability in fullscreen apps? (e.g. should we add `.fullScreenAuxiliary`?)
- Are there any known pitfalls with `.screenSaver + 1` as a rawValue bump?
- Should we observe occlusion state (`didChangeOcclusionState`) and hide/stop updates when the notch window is occluded?

## Display “safe area compatibility” mode (potential gotcha)

We’re aware there’s:

- A system setting for some apps like “Scale to fit below built-in camera” (which effectively avoids using the notch area).
- An Info.plist key `NSPrefersDisplaySafeAreaCompatibilityMode`.

Microverse does **not** currently set `NSPrefersDisplaySafeAreaCompatibilityMode`.

If a user enables the compatibility behavior, do you recommend we:

- disable notch glow (and maybe show a one-time explanation), or
- try to adapt and still render relative to the “compatibility” safe area?

## Minimal repro commands (local)

```bash
pkill -f Microverse 2>/dev/null || true
make debug-app
open -n /tmp/Microverse.app --args --debug-notch-glow=critical --debug-notch-glow-solid
```

Then repeat without the solid overlay:

```bash
pkill -f Microverse 2>/dev/null || true
open -n /tmp/Microverse.app --args --debug-notch-glow=critical
```

## Data we can provide quickly (if you tell us what you need)

- A macOS screen recording showing the glow + the notch pill while repeatedly triggering `--debug-notch-glow=critical`.
- The `NSLog` output of the computed geometry line:
  - `NotchGlow: baseNotch=(...) leading=... trailing=... pill=(...) window=(...)`
- A screenshot with `--debug-notch-glow-solid` enabled (it draws a translucent “GLOW” bounds box) so you can see the exact window frame we’re drawing into.
- Additional optional logs if you want them:
  - `DynamicNotchKit` compact leading/trailing widths *as the library sees them* (including its internal insets)
  - computed compact `xOffset` (trailing-leading)/2
  - current notch state (`hidden`/`compact`/`expanded`) and hover flag

## References

- Apple docs: `NSScreen.auxiliaryTopLeftArea` (and `.auxiliaryTopRightArea`)  
  `https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea`
- Swift Package Registry: DynamicNotchKit  
  `https://swiftpackageregistry.com/MrKai77/DynamicNotchKit`
- GitHub: DynamicNotchKit  
  `https://github.com/MrKai77/DynamicNotchKit`
