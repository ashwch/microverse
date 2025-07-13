import Foundation

// Shared ViewModel instance to ensure menu bar and main window use the same data
@MainActor
class SharedViewModel {
    static let shared = BatteryViewModel()
}