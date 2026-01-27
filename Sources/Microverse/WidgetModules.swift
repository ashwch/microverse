import Foundation

/// Modules that can appear in the **Custom** Desktop Widget.
///
/// This enum is deliberately “UI-facing”: each case provides a title/subtitle/icon and is persisted via UserDefaults.
/// To add a new module:
/// 1. Add a new case here (and update `title`/`subtitle`/`systemIcon`).
/// 2. Implement its rendering in `Sources/Microverse/DesktopWidget.swift` (primary + secondary tiles).
/// 3. Consider whether it needs a shared store injected via `BatteryViewModel` (so popover + widget + notch share state).
enum WidgetModule: String, CaseIterable, Codable, Sendable, Hashable {
    case battery
    case batteryTime
    case batteryHealth
    case cpu
    case memory
    case network
    case wifi
    case audioOutput
    case audioInput
    case weather
    case systemHealth

    static let maximumSelection = 5

    static let defaultSelection: [WidgetModule] = [
        .battery,
        .cpu,
        .memory,
        .weather,
    ]

    var title: String {
        switch self {
        case .battery: return "Battery"
        case .batteryTime: return "Time Remaining"
        case .batteryHealth: return "Battery Health"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .wifi: return "Wi‑Fi"
        case .audioOutput: return "Audio Output"
        case .audioInput: return "Audio Input"
        case .weather: return "Weather"
        case .systemHealth: return "System Health"
        }
    }

    var subtitle: String {
        switch self {
        case .battery:
            return "Percentage and charging state"
        case .batteryTime:
            return "Time to empty/full"
        case .batteryHealth:
            return "Capacity and cycle count"
        case .cpu:
            return "Current CPU load"
        case .memory:
            return "Usage and pressure"
        case .network:
            return "Upload and download rate"
        case .wifi:
            return "Signal strength and link rate"
        case .audioOutput:
            return "Output device and volume"
        case .audioInput:
            return "Input device selection"
        case .weather:
            return "Temperature and conditions"
        case .systemHealth:
            return "Overall status signal"
        }
    }

    var systemIcon: String {
        switch self {
        case .battery: return "battery.100percent"
        case .batteryTime: return "clock"
        case .batteryHealth: return "heart"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "network"
        case .wifi: return "wifi"
        case .audioOutput: return "speaker.wave.2"
        case .audioInput: return "mic"
        case .weather: return "cloud.sun"
        case .systemHealth: return "gauge.with.dots.needle.67percent"
        }
    }
}
