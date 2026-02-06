import SwiftUI

// MARK: - Demand-Driven System Monitoring Activation
//
// Problem: CPU/memory polling burns energy even when no UI surface is visible.
// Solution: tie polling lifetime to SwiftUI view lifecycle so cost is zero when
// the notch, widget, and popover are all hidden.
//
// Lifecycle (ref-counted):
//
//   View appears           View disappears
//        │                      │
//        ▼                      ▼
//   acquireClient()        releaseClient()
//   activeClients: 0→1     activeClients: 1→0
//        │                      │
//        ▼                      ▼
//   startMonitoring()      stopMonitoring()
//   (timer begins)         (timer cancelled)
//
// Multiple views can independently acquire/release. The polling timer starts
// when the *first* surface appears and stops only when the *last* one
// disappears. This is plain ref-counting, not ARC — just an Int counter
// inside `SystemMonitoringService`.
//
// The `reconcile()` pattern handles two distinct triggers:
//   1. View appear / disappear (normal lifecycle).
//   2. The `enabled` flag toggling at runtime (e.g., the user switches widget
//      style from "battery-only" to "system glance", which now needs CPU data).
// By funnelling both paths through `reconcile()`, we avoid duplicated
// acquire/release bookkeeping.
//
// Usage:
//
//   SomeView()
//       .systemMonitoringActive(needsCPUData)
//

/// View-lifecycle bridge for demand-driven `SystemMonitoringService`.
///
/// Attaching this modifier keeps polling active only while the view is visible.
/// When the view disappears (or `enabled` becomes `false`), the modifier
/// releases its client reference. Polling stops automatically when no
/// surfaces hold a reference.
private struct SystemMonitoringActivationModifier: ViewModifier {
    let enabled: Bool

    @State private var isAcquired = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                reconcile()
            }
            .onChange(of: enabled) { _ in
                reconcile()
            }
            .onDisappear {
                releaseIfNeeded()
            }
    }

    private func reconcile() {
        if enabled {
            acquireIfNeeded()
        } else {
            releaseIfNeeded()
        }
    }

    private func acquireIfNeeded() {
        guard !isAcquired else { return }
        SystemMonitoringService.shared.acquireClient()
        isAcquired = true
    }

    private func releaseIfNeeded() {
        guard isAcquired else { return }
        SystemMonitoringService.shared.releaseClient()
        isAcquired = false
    }
}

extension View {
    /// Keeps system monitoring active while this view is visible.
    ///
    /// Pass `false` to release the polling reference without removing the view
    /// (e.g., when the widget style no longer needs CPU/memory data).
    func systemMonitoringActive(_ enabled: Bool = true) -> some View {
        modifier(SystemMonitoringActivationModifier(enabled: enabled))
    }
}
