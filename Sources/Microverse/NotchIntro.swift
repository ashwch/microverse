import SwiftUI

/// Launch sequence for the compact notch: "microverse" types out letter by letter like an old
/// phone keypad, holds, fades away, the startup glow runs, and only then do the metrics fade in.
///
/// The compact views ask this controller whether to show the typing view or their metrics, so the
/// sequence works in every layout (the text goes wherever the leading slot is).
@MainActor
final class NotchIntroController: ObservableObject {
  static let shared = NotchIntroController()

  enum Phase: Equatable {
    /// Nothing to show; metrics render normally. Also the state before and after a sequence.
    case done
    case typing
    case holding
    case fadingOut
    /// Text gone, pill empty, glow running. Metrics still hidden.
    case lights
    /// Glow still running, metrics fading in.
    case revealing
  }

  static let text = "microverse"

  @Published private(set) var phase: Phase = .done
  @Published private(set) var typedCount = 0

  private init() {}

  /// True while the typing pill should be on screen (including its fade-out).
  var showsText: Bool {
    phase == .typing || phase == .holding || phase == .fadingOut
  }

  /// True while the metrics must stay hidden: the whole text phase plus the first light pass.
  var hidesMetrics: Bool {
    showsText || phase == .lights
  }

  var isActive: Bool { phase != .done }

  /// Call before the notch appears so the first frame is the empty typing pill, not the metrics.
  func prepare() {
    phase = .typing
    typedCount = 0
  }

  /// Runs the whole sequence. `lights` is the startup glow; it is started once the text has faded
  /// and the metrics reveal begins shortly after it, so the order is text, lights, metrics.
  func play(lights: @escaping @MainActor () async -> Void) async {
    if phase == .done { prepare() }

    // Type. Slightly uneven keystrokes read as a person, not a timer.
    for count in 1...Self.text.count {
      typedCount = count
      let jitter = Double((count * 37) % 5) * 0.012
      try? await Task.sleep(for: .seconds(0.11 + jitter))
    }

    phase = .holding
    try? await Task.sleep(for: .seconds(0.7))

    withAnimation(.easeInOut(duration: 0.45)) { phase = .fadingOut }
    try? await Task.sleep(for: .seconds(0.55))

    // Text is gone and the pill is empty. Lights first, on their own.
    phase = .lights
    let lightsTask = Task { @MainActor in await lights() }
    try? await Task.sleep(for: .seconds(1.0))

    // Then the metrics come in under the remaining light passes.
    withAnimation(.easeOut(duration: 0.7)) { phase = .revealing }
    try? await Task.sleep(for: .seconds(0.7))
    phase = .done
    await lightsTask.value
  }

  func cancel() {
    phase = .done
  }
}

/// The typing pill: monospaced, mascot green, blinking block cursor.
struct NotchIntroTypingView: View {
  @ObservedObject private var intro = NotchIntroController.shared

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
      let cursorOn = Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
      let typed = String(NotchIntroController.text.prefix(intro.typedCount))

      HStack(spacing: 0) {
        Text(typed)
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundColor(MicroverseDesign.Colors.mascot)
          .shadow(color: MicroverseDesign.Colors.mascot.opacity(0.6), radius: 4)

        // Block cursor keeps its slot while blinking so the pill width never twitches.
        Text("▍")
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundColor(MicroverseDesign.Colors.mascot)
          .opacity(cursorOn || intro.phase == .typing ? 1 : 0)
      }
      .monospacedDigit()
      .frame(height: MicroverseDesign.Notch.Dimensions.compactWidgetHeight)
      .padding(.horizontal, MicroverseDesign.Notch.Spacing.compactHorizontal + 4)
      .padding(.vertical, MicroverseDesign.Notch.Spacing.compactVertical)
      .background(
        RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
          .fill(MicroverseDesign.Notch.Materials.compactBackground)
          .opacity(MicroverseDesign.Notch.Materials.compactOpacity)
          .overlay(
            RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
              .stroke(
                MicroverseDesign.Colors.mascot.opacity(0.25),
                lineWidth: MicroverseDesign.Notch.Materials.strokeWidth)
          )
      )
      .opacity(intro.phase == .fadingOut ? 0 : 1)
      .animation(.easeInOut(duration: 0.12), value: intro.typedCount)
    }
  }
}

extension View {
  /// Hides metric content while the intro text owns the pill, then fades it in for the reveal.
  func notchIntroMetrics() -> some View {
    modifier(NotchIntroMetricsModifier())
  }
}

private struct NotchIntroMetricsModifier: ViewModifier {
  @ObservedObject private var intro = NotchIntroController.shared

  func body(content: Content) -> some View {
    content
      .opacity(intro.hidesMetrics ? 0 : 1)
      // Collapse so the pill does not reserve the metrics' width behind the text.
      .frame(width: intro.hidesMetrics ? 0 : nil)
      .clipped()
  }
}
