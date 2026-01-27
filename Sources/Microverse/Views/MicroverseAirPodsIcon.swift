import SwiftUI

/// Small “AirPods” glyph with optional micro-motion.
///
/// Used in compact surfaces (notch + widget) where we want a recognizable AirPods silhouette without custom assets.
/// Animation is deliberately subtle and respects Reduce Motion.
struct MicroverseAirPodsIcon: View {
    let model: AudioDevicesStore.AirPodsModel
    var size: CGFloat = 12
    var weight: Font.Weight = .semibold
    var color: Color = .white.opacity(0.85)
    var renderingMode: SymbolRenderingMode = .hierarchical
    var isAnimating: Bool = true
    var rotationDuration: TimeInterval = 3.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        let shouldAnimate = isAnimating && !reduceMotion

        Image(systemName: model.symbolName)
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
            .symbolRenderingMode(renderingMode)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .onAppear {
                guard shouldAnimate else { return }
                start()
            }
            .onChange(of: shouldAnimate) { enabled in
                if enabled {
                    start()
                } else {
                    stop()
                }
            }
            .onDisappear {
                stop()
            }
            .accessibilityLabel("AirPods connected")
    }

    private func start() {
        rotation = 0
        withAnimation(.linear(duration: rotationDuration).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    private func stop() {
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            rotation = 0
        }
    }
}
