import SwiftUI

/// Remembers the widest width each compact-pill presentation has reached.
///
/// A pill's content changes size as values tick over. Rendering it at the widest width its
/// current presentation has ever needed keeps it from pumping, while letting a different
/// presentation (the weather peek versus the system metrics) take its own width when the mode
/// swaps. DynamicNotchKit animates that swap.
struct NotchPillWidthMemory {
  enum Presentation: Equatable {
    case system
    case weather
    case pinned
  }

  /// Sanity ceiling well above any real pill. A cap below the content width would clip the pill
  /// under the notch, because the trailing frame is trailing-aligned.
  private static let cap: CGFloat = 400

  private var widths: [Presentation: CGFloat] = [:]

  func width(for presentation: Presentation) -> CGFloat? {
    widths[presentation]
  }

  /// Records a measured width; only growth of more than half a point is kept, and never animated,
  /// so the stored width settles quickly and stays put.
  mutating func remember(_ width: CGFloat, for presentation: Presentation) {
    guard width > 0 else { return }
    let next = max(widths[presentation] ?? 0, min(width, Self.cap))
    guard let current = widths[presentation] else {
      widths[presentation] = next
      return
    }
    guard next > current + 0.5 else { return }
    var transaction = Transaction()
    transaction.animation = nil
    withTransaction(transaction) { widths[presentation] = next }
  }
}
