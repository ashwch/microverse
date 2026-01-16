import Combine
import Foundation

enum WeatherAnimationSurface: Sendable {
    case compactNotch
    case expandedNotch
    case popoverWeatherTab
    case desktopWidget
}

enum WeatherRenderMode: Equatable, Sendable {
    case off
    case low(fps: Double)
    case full(fps: Double)

    var fps: Double? {
        switch self {
        case .off:
            return nil
        case .low(let fps), .full(let fps):
            return fps
        }
    }

    var interval: TimeInterval? {
        guard let fps else { return nil }
        guard fps > 0 else { return nil }
        return 1.0 / fps
    }
}

@MainActor
final class WeatherAnimationBudget: ObservableObject {
    @Published private(set) var isLowPowerModeEnabled: Bool
    @Published private(set) var thermalState: ProcessInfo.ThermalState

    private let settings: WeatherSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(settings: WeatherSettingsStore) {
        self.settings = settings
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState

        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
            }
            .store(in: &cancellables)
    }

    func renderMode(for surface: WeatherAnimationSurface, isVisible: Bool, reduceMotion: Bool) -> WeatherRenderMode {
        guard isVisible else { return .off }
        guard !reduceMotion else { return .off }

        let snapshot = settings.snapshot()
        guard snapshot.animatedIconsMode != .off else { return .off }

        if surface == .compactNotch, !snapshot.animateInCompactNotch {
            return .off
        }

        let powerConstrained = isLowPowerModeEnabled || thermalState == .serious || thermalState == .critical

        let requestedMode = snapshot.animatedIconsMode

        // Base FPS selection per surface.
        let base: WeatherRenderMode = {
            switch surface {
            case .popoverWeatherTab:
                switch requestedMode {
                case .off:
                    return .off
                case .subtle:
                    return .full(fps: 10)
                case .full:
                    return .full(fps: 12)
                }
            case .expandedNotch:
                switch requestedMode {
                case .off:
                    return .off
                case .subtle:
                    return .full(fps: 8)
                case .full:
                    return .full(fps: 12)
                }
            case .desktopWidget:
                switch requestedMode {
                case .off:
                    return .off
                case .subtle:
                    return .low(fps: 4)
                case .full:
                    return .low(fps: 6)
                }
            case .compactNotch:
                switch requestedMode {
                case .off:
                    return .off
                case .subtle:
                    return .low(fps: 2)
                case .full:
                    return .low(fps: 3)
                }
            }
        }()

        guard powerConstrained else { return base }

        // Low Power / thermal constraints: aggressively clamp always-on surfaces.
        switch surface {
        case .desktopWidget, .compactNotch:
            return .off
        case .expandedNotch, .popoverWeatherTab:
            return switch base {
            case .off:
                .off
            case .low:
                .low(fps: 4)
            case .full:
                .low(fps: 6)
            }
        }
    }
}
