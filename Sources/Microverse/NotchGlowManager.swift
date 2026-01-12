import SwiftUI
import AppKit

// MARK: - Alert Types

enum NotchAlertType {
    case success    // Green - battery charged, system optimal
    case warning    // Yellow/Orange - battery low, moderate load
    case critical   // Red - battery critical, high CPU/memory
    case info       // Blue - informational

    var color: NSColor {
        switch self {
        case .success:  return NSColor.systemGreen
        case .warning:  return NSColor.systemOrange
        case .critical: return NSColor.systemRed
        case .info:     return NSColor.systemBlue
        }
    }

    var glowColor: NSColor {
        return color.withAlphaComponent(0.8)
    }

    var defaultMotion: NotchGlowMotion {
        switch self {
        case .success:
            // Charging/fully-charged should feel calmer: sweep anticlockwise then clockwise.
            return .pingPong
        case .warning, .critical, .info:
            return .loop
        }
    }
}

enum NotchGlowMotion {
    /// Continuous forward sweep (direction is determined by the path definition).
    case loop
    /// Sweep anticlockwise, then reverse clockwise to end.
    case pingPong
}

// MARK: - NSScreen Extension for Notch Detection

extension NSScreen {
    /// Whether this screen has a notch
    var hasNotch: Bool {
        auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil
    }

    /// The size of the notch (width x height)
    var notchSize: CGSize {
        guard let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else {
            return .zero
        }
        // Use the *edges* of the auxiliary areas instead of subtracting widths.
        // This is more robust across multi-monitor coordinate systems.
        let width = max(0, right.minX - left.maxX)
        let height = max(safeAreaInsets.top, left.height, right.height)
        return CGSize(width: width, height: height)
    }

    /// The frame of the notch in screen coordinates
    var notchFrame: CGRect {
        guard let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else {
            return .zero
        }

        let width = max(0, right.minX - left.maxX)
        let height = max(safeAreaInsets.top, left.height, right.height)
        guard width > 0, height > 0 else { return .zero }

        let x = left.maxX
        let y = frame.maxY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Menu bar height (for fallback on non-notch displays)
    var menuBarHeight: CGFloat {
        frame.maxY - visibleFrame.maxY
    }
}

// MARK: - Notch Glow Manager

@MainActor
class NotchGlowManager {
    static let shared = NotchGlowManager()

    private var glowWindow: NotchGlowWindow?
    private weak var notchParentWindow: NSWindow?
    private var dismissTimer: Timer?
    private var isAnimating = false

    private init() {}

    /// Startup animation (RGB + mixed motions) to show the app is running.
    func playStartupAnimation() async {
        // RGB-ish sequence: red, green, blue (mixed order each launch).
        let colors: [NotchAlertType] = [.critical, .success, .info]
        let sequence = colors.shuffled()

        // Mix motions so the startup feels "alive" without being too aggressive.
        let motions: [NotchGlowMotion] = [.loop, .pingPong]

        for (index, type) in sequence.enumerated() {
            let motion = motions[index % motions.count]
            let duration: TimeInterval = 0.95
            let pulseCount: Int = (motion == .loop) ? 1 : 2

            showAlert(type: type, duration: duration, pulseCount: pulseCount, motion: motion)

            // Avoid overlap: the in-notch controller replaces the current trigger, so overlapping would look like a hard cut.
            let pause = duration + 0.15
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
        }
    }

    /// Show a brief glow alert around the notch
    /// - Parameters:
    ///   - type: The alert type (determines color)
    ///   - duration: How long to show the glow (default 2 seconds)
    ///   - rotations: Number of full rotations around the notch (default 2)
    func showAlert(type: NotchAlertType, duration: TimeInterval = 2.0, pulseCount: Int = 2, motion: NotchGlowMotion? = nil) {
        let resolvedMotion = motion ?? type.defaultMotion

        // Preferred path: render the glow inside the DynamicNotchKit pill coordinate space.
        // This avoids external overlay math (physical notch vs software pill) and matches SwiftUI transforms like `.offset(x:)`.
        if
            let notchService = NotchServiceLocator.current as? MicroverseNotchViewModel,
            notchService.layoutMode != .off,
            notchService.isNotchVisible
        {
            NotchGlowInNotchController.shared.trigger(type: type, duration: duration, pulseCount: pulseCount, motion: resolvedMotion)
            return
        }

        // Don't stack alerts - dismiss existing first
        if isAnimating {
            dismissImmediately()
        }

        guard let screen = {
            if
                let notchService = NotchServiceLocator.current as? MicroverseNotchViewModel,
                notchService.selectedScreen >= 0,
                notchService.selectedScreen < NSScreen.screens.count
            {
                return NSScreen.screens[notchService.selectedScreen]
            }

            return NSScreen.screens.first(where: { $0.hasNotch }) ?? NSScreen.main
        }() else {
            return
        }

        isAnimating = true

        // Create the glow window if needed
        if glowWindow == nil {
            glowWindow = NotchGlowWindow()
        }

        guard let window = glowWindow else { return }
        window.alphaValue = 1

        // Base notch dimensions (cutout width + safe area height).
        let baseNotchSize = screen.notchSize
        let baseNotchWidth: CGFloat
        let baseNotchHeight: CGFloat

        if screen.hasNotch && baseNotchSize.width > 0 {
            baseNotchWidth = baseNotchSize.width
            baseNotchHeight = baseNotchSize.height
        } else {
            // No notch detected (or test environment). Use a sensible pill sized to the menubar.
            baseNotchWidth = 300
            baseNotchHeight = screen.menuBarHeight > 0 ? screen.menuBarHeight : 24
        }

        // If DynamicNotchKit is visible, align to the *actual* compact pill:
        // width = leading + cutout + trailing + 2*topCornerRadius, with an xOffset to keep the cutout centered.
        let compactTopCornerRadius: CGFloat = 6
        let compactBottomCornerRadius: CGFloat = 14
        let compactSectionInset: CGFloat = 8 // mirrors DynamicNotchKit's compact safeAreaInset on each side

        let (rawLeadingWidth, rawTrailingWidth): (CGFloat, CGFloat) = {
            guard let notchService = NotchServiceLocator.current as? MicroverseNotchViewModel else { return (0, 0) }
            guard notchService.isNotchVisible else { return (0, 0) }
            return (notchService.compactLeadingContentWidth, notchService.compactTrailingContentWidth)
        }()

        let leadingWidth = rawLeadingWidth > 0 ? (rawLeadingWidth + compactSectionInset) : 0
        let trailingWidth = rawTrailingWidth > 0 ? (rawTrailingWidth + compactSectionInset) : 0

        let pillWidth = baseNotchWidth + leadingWidth + trailingWidth + (compactTopCornerRadius * 2)
        let pillHeight = baseNotchHeight
        let xOffset = (trailingWidth - leadingWidth) / 2

        let pillFrame = CGRect(
            x: screen.frame.midX - (pillWidth / 2) + xOffset,
            y: screen.frame.maxY - pillHeight,
            width: pillWidth,
            height: pillHeight
        )

        // Window dimensions – extend beyond the pill for glow/blur headroom.
        let glowPadding: CGFloat = 30
        let windowWidth = pillWidth + glowPadding * 2
        let windowHeight = pillHeight + glowPadding * 2

        // Position the window so the pill sits at (glowPadding, glowPadding) inside the view.
        let windowX = pillFrame.minX - glowPadding
        let windowY = pillFrame.minY - glowPadding

        let windowFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
        window.setFrame(windowFrame, display: true)

        #if DEBUG
        NSLog("NotchGlow: baseNotch=(\(baseNotchWidth)x\(baseNotchHeight)) leading=\(leadingWidth) trailing=\(trailingWidth) pill=\(pillFrame) window=\(windowFrame)")
        #endif

        // Keep the panel above the DynamicNotchKit panel (also .screenSaver) so the glow isn't occluded.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

        // Set up the glow view with detected dimensions
        let glowView = NotchGlowView(
            alertType: type,
            pillWidth: pillWidth,
            pillHeight: pillHeight,
            topCornerRadius: compactTopCornerRadius,
            bottomCornerRadius: compactBottomCornerRadius,
            glowPadding: glowPadding,
            rotations: pulseCount,
            motion: resolvedMotion,
            animationDuration: duration
        )

        let hostingView = ZeroSafeAreaHostingView(rootView: glowView)
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: windowWidth, height: windowHeight))

        window.contentView = hostingView
        window.backgroundColor = .clear
        attachAboveDynamicNotchIfPossible(glowWindow: window, on: screen)
        window.orderFrontRegardless()

        // Schedule dismiss
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration + 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            glowWindow?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.detachFromDynamicNotchParent()
                self?.glowWindow?.orderOut(nil)
                self?.glowWindow?.alphaValue = 1
                self?.isAnimating = false
            }
        })
    }

    private func dismissImmediately() {
        dismissTimer?.invalidate()
        detachFromDynamicNotchParent()
        glowWindow?.orderOut(nil)
        glowWindow?.alphaValue = 1
        isAnimating = false
    }

    private func attachAboveDynamicNotchIfPossible(glowWindow: NSWindow, on screen: NSScreen) {
        // If DynamicNotchKit is active, attach as a child window ordered above so we can render on top of the notch.
        // This avoids any odd window ordering behavior at `.screenSaver` level.
        guard let parent = findDynamicNotchParentWindow(on: screen) else { return }

        if notchParentWindow != parent {
            detachFromDynamicNotchParent()
            notchParentWindow = parent
        }

        if !(parent.childWindows?.contains(glowWindow) ?? false) {
            parent.addChildWindow(glowWindow, ordered: .above)
        }
    }

    private func detachFromDynamicNotchParent() {
        guard let parent = notchParentWindow, let glowWindow else { return }
        parent.removeChildWindow(glowWindow)
        notchParentWindow = nil
    }

    private func findDynamicNotchParentWindow(on screen: NSScreen) -> NSWindow? {
        // Prefer the actual DynamicNotchKit panel type if present.
        if let exact = NSApp.windows.first(where: { window in
            window.screen == screen && NSStringFromClass(type(of: window)).contains("DynamicNotchPanel")
        }) {
            return exact
        }

        // Fallback: pick the largest `.screenSaver` window on that screen (DynamicNotchKit uses a large panel).
        let candidates = NSApp.windows.filter { window in
            window.screen == screen && window.level == .screenSaver && window != glowWindow
        }

        return candidates.max(by: { ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height) })
    }

    // MARK: - Convenience Methods

    func showSuccess(duration: TimeInterval = 1.5) {
        showAlert(type: .success, duration: duration, pulseCount: 2)
    }

    func showWarning(duration: TimeInterval = 2.0) {
        showAlert(type: .warning, duration: duration, pulseCount: 3)
    }

    func showCritical(duration: TimeInterval = 3.0) {
        showAlert(type: .critical, duration: duration, pulseCount: 4)
    }

    func showInfo(duration: TimeInterval = 1.5) {
        showAlert(type: .info, duration: duration, pulseCount: 2)
    }
}

// MARK: - Notch Glow Window

class NotchGlowWindow: NSPanel {
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
        self.ignoresMouseEvents = true  // Click-through
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Notch Glow View (SwiftUI)

private final class ZeroSafeAreaHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets { .init() }
}

struct NotchGlowView: View {
    let alertType: NotchAlertType
    let pillWidth: CGFloat
    let pillHeight: CGFloat
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let glowPadding: CGFloat
    let rotations: Int
    let motion: NotchGlowMotion
    let animationDuration: TimeInterval

    @State private var sweepProgress: Double = 0
    @State private var opacity: Double = 1
    @State private var sparklePhase: Double = 0

    private var glowColor: Color {
        Color(alertType.color)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shape = NotchPillShape(
                topCornerRadius: topCornerRadius,
                bottomCornerRadius: bottomCornerRadius
            )

            let pillRect = CGRect(
                x: (size.width - pillWidth) / 2,
                y: glowPadding,
                width: pillWidth,
                height: pillHeight
            )
            let pillCenter = CGPoint(x: pillRect.midX, y: pillRect.midY)

            ZStack {
                // Strong base glow (ensures visibility even on bright wallpapers)
                shape
                    .stroke(glowColor.opacity(0.25 * opacity), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .frame(width: pillRect.width, height: pillRect.height)
                    .position(pillCenter)
                    .blur(radius: 10)

                shape
                    .stroke(glowColor.opacity(0.40 * opacity), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: pillRect.width, height: pillRect.height)
                    .position(pillCenter)
                    .blur(radius: 6)

                shape
                    .stroke(glowColor.opacity(0.85 * opacity), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: pillRect.width, height: pillRect.height)
                    .position(pillCenter)

                // Sweeping highlight (trimmed stroke)
                let head = max(0, min(1, sweepProgress))
                let sweepLength: Double = 0.35
                let start = max(0, head - sweepLength)
                let end = head

                shape
                    .trim(from: start, to: end)
                    .stroke(Color.white.opacity(0.95 * opacity), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: pillRect.width, height: pillRect.height)
                    .position(pillCenter)
                    .shadow(color: glowColor.opacity(0.9 * opacity), radius: 10)
                    .blendMode(.plusLighter)

                // Sparkles (white dots)
                //
                // Goal: dots should look evenly spaced and symmetric at a glance.
                //
                // Humans judge spacing primarily by *horizontal gaps*, and the curved corners can make
                // "uniform along path length" look visually uneven. To keep the result clean and symmetric,
                // we place sparkles on the *flat* bottom segment only and distribute them uniformly in X.
                //
                // Use an odd count so we always get a dot centered on the pill.
                let topR = max(0, min(topCornerRadius, pillRect.width / 2, pillRect.height / 2))
                let bottomR = max(0, min(bottomCornerRadius, pillRect.width / 2, pillRect.height / 2))

                // Flat bottom segment endpoints (matches NotchPillShape): p4 -> p5 is the bottom line.
                let p4x = pillRect.minX + topR + bottomR
                let p5x = pillRect.maxX - topR - bottomR

                // Inset from the curve joins so dots don't "climb" the corner radii.
                let edgeInsetX = max(8, bottomR * 0.25)
                let startX = p4x + edgeInsetX
                let endX = p5x - edgeInsetX
                let availableX = max(0, endX - startX)

                let targetSpacing: CGFloat = 22
                let minDots = 15
                let maxDots = 41
                let baseCount = max(minDots, Int((availableX / max(1, targetSpacing)).rounded(.down)) + 1)
                let sparkleCount = min(maxDots, (baseCount % 2 == 0) ? (baseCount + 1) : baseCount)
                let denom = max(1, sparkleCount - 1)

                if availableX > 1 {
                    ForEach(0..<sparkleCount, id: \.self) { i in
                        let u = Double(i) / Double(denom)
                        let x = startX + (availableX * CGFloat(u))
                        let y = pillRect.maxY

                        // Keep flicker symmetric (mirror pairs share the same phase).
                        let mirroredIndex = min(i, denom - i)
                        let phase = (sparklePhase * (2 * .pi)) + (Double(mirroredIndex) * 0.85)

                        // Keep variation subtle so spacing reads as even.
                        let flicker = 0.78 + 0.22 * abs(sin(phase))
                        let sparkleOpacity = opacity * flicker
                        let sparkleSize: CGFloat = 2.8 + CGFloat(abs(sin(phase * 1.3))) * 0.45

                        Circle()
                            .fill(Color.white.opacity(0.95 * sparkleOpacity))
                            .frame(width: sparkleSize, height: sparkleSize)
                            .position(x: x, y: y)
                            .shadow(color: glowColor.opacity(0.8 * sparkleOpacity), radius: 8)
                            .blendMode(.plusLighter)
                    }
                }

                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--debug-notch-glow-solid") {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(glowColor.opacity(0.25))
                        .overlay(alignment: .bottom) {
                            Text("GLOW")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.bottom, 6)
                        }
                }
                #endif
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .ignoresSafeArea()
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Fade in
        opacity = 0
        withAnimation(.easeOut(duration: 0.2)) { opacity = 1.0 }

        switch motion {
        case .loop:
            sweepProgress = 0
            let sweepDuration = max(0.35, (animationDuration - 0.3) / Double(max(1, rotations)))
            withAnimation(.linear(duration: sweepDuration).repeatCount(rotations, autoreverses: false)) {
                sweepProgress = 1.0
            }
        case .pingPong:
            // Two-phase sweep: anticlockwise then clockwise to end. (SwiftUI path direction defines "forward".)
            sweepProgress = 0.0
            let halfDuration = max(0.35, (animationDuration - 0.3) / 2)
            withAnimation(.linear(duration: halfDuration)) {
                sweepProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + halfDuration) {
                withAnimation(.linear(duration: halfDuration)) {
                    sweepProgress = 0.0
                }
            }
        }

        // Animate sparkle phase
        switch motion {
        case .loop:
            sparklePhase = 0
            withAnimation(.linear(duration: 0.35).repeatForever(autoreverses: false)) {
                sparklePhase = 1.0
            }
        case .pingPong:
            // Match the sweep timing: anticlockwise then clockwise, slow and deliberate.
            sparklePhase = 0.0
            let halfDuration = max(0.35, (animationDuration - 0.3) / 2)
            withAnimation(.linear(duration: halfDuration)) {
                sparklePhase = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + halfDuration) {
                withAnimation(.linear(duration: halfDuration)) {
                    sparklePhase = 0.0
                }
            }
        }

        // Fade out at the end
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration - 0.3) {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 0
            }
        }
    }
}

private struct NotchPillShape: Shape {
    private var topCornerRadius: CGFloat
    private var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}

// MARK: - Preview

#if DEBUG
struct NotchGlowView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            NotchGlowView(
                alertType: .critical,
                pillWidth: 240,
                pillHeight: 32,
                topCornerRadius: 6,
                bottomCornerRadius: 14,
                glowPadding: 30,
                rotations: 2,
                motion: .loop,
                animationDuration: 2.0
            )
        }
        .frame(width: 300, height: 92)
    }
}
#endif
