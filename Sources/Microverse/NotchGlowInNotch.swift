import Foundation
import SwiftUI

@MainActor
final class NotchGlowInNotchController: ObservableObject {
    static let shared = NotchGlowInNotchController()

    struct Trigger: Identifiable {
        let id = UUID()
        let type: NotchAlertType
        let duration: TimeInterval
        let pulseCount: Int
        let motion: NotchGlowMotion
    }

    @Published private(set) var current: Trigger?

    private var clearTask: Task<Void, Never>?

    private init() {}

    func trigger(type: NotchAlertType, duration: TimeInterval, pulseCount: Int, motion: NotchGlowMotion) {
        clearTask?.cancel()
        let trigger = Trigger(type: type, duration: duration, pulseCount: pulseCount, motion: motion)
        current = trigger

        clearTask = Task { @MainActor in
            // Give a small tail so any fade-out finishes cleanly.
            let nanos = UInt64(max(0.0, duration + 0.5) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            if self.current?.id == trigger.id {
                self.current = nil
            }
        }
    }
}

/// Renders the notch glow *inside* the DynamicNotchKit pill coordinate space.
///
/// This avoids external overlay-window coordinate mismatches (physical notch vs software pill),
/// and inherits DynamicNotchKit's compact-only transforms like `.offset(x:)`.
struct MicroverseNotchGlowDecorationView: View {
    @ObservedObject private var controller = NotchGlowInNotchController.shared

    private let topCornerRadius: CGFloat = 6
    private let bottomCornerRadius: CGFloat = 14
    private let padding: CGFloat = 30

    var body: some View {
        GeometryReader { proxy in
            if let trigger = controller.current {
                let pillWidth = proxy.size.width
                let pillHeight = proxy.size.height

                NotchGlowView(
                    alertType: trigger.type,
                    pillWidth: pillWidth,
                    pillHeight: pillHeight,
                    topCornerRadius: topCornerRadius,
                    bottomCornerRadius: bottomCornerRadius,
                    glowPadding: padding,
                    rotations: trigger.pulseCount,
                    motion: trigger.motion,
                    animationDuration: trigger.duration
                )
                .id(trigger.id)
                // Make room for blur/particles, then align the padded container back to the pill bounds.
                .frame(width: pillWidth + (padding * 2), height: pillHeight + (padding * 2), alignment: .top)
                .offset(x: -padding, y: -padding)
                .allowsHitTesting(false)
            }
        }
    }
}
