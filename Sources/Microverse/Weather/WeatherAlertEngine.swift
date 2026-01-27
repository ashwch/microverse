import Combine
import Foundation
import os.log

/// Schedules notch glow alerts for upcoming weather changes.
///
/// ## First principles
/// - **No spam:** alerts are opt-in, cooldown-protected, and deduped per upcoming event.
/// - **No hot polling:** we react to existing published state (`WeatherStore.nextEvent`) and schedule one task.
/// - **Respect user intent:** Weather Alerts require Weather + Notch Glow Alerts + a selected location.
///
/// ## How it works
/// When the selected location’s `WeatherStore.nextEvent` changes, we decide whether that event should alert (based on
/// rule toggles) and schedule a one-shot task at `event.startTime - leadTime`. If inputs change, the task is canceled
/// and recomputed.
@MainActor
final class WeatherAlertEngine {
    private let settings: WeatherSettingsStore
    private let weather: WeatherStore
    private let battery: BatteryViewModel
    private let logger = Logger(subsystem: "com.microverse.app", category: "WeatherAlertEngine")

    private var cancellables = Set<AnyCancellable>()
    private var scheduledTask: Task<Void, Never>?

    private var lastTriggeredEventID: String?
    private var lastTriggeredAt: Date = .distantPast

    init(settings: WeatherSettingsStore, weather: WeatherStore, battery: BatteryViewModel) {
        self.settings = settings
        self.weather = weather
        self.battery = battery

        Publishers.MergeMany([
            settings.$weatherEnabled.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherAlertsEnabled.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherAlertLeadTime.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherAlertCooldown.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherAlertPrecipitation.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherAlertStorm.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherAlertTempChange.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherSelectedLocationID.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherLocations.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            battery.$enableNotchAlerts.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            weather.$nextEvent.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            weather.$fetchState.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
        ])
        .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
        .sink { [weak self] in
            self?.reschedule(reason: "inputs")
        }
        .store(in: &cancellables)

        reschedule(reason: "init")
    }

    deinit {
        scheduledTask?.cancel()
    }

    private func reschedule(reason: String) {
        scheduledTask?.cancel()
        scheduledTask = nil

        guard settings.weatherEnabled else { return }
        guard settings.weatherAlertsEnabled else { return }
        guard settings.selectedLocation != nil else { return }
        guard battery.enableNotchAlerts else { return }
        guard battery.isNotchAvailable else { return }

        guard let event = weather.nextEvent else { return }
        guard shouldAlert(for: event) else { return }

        if event.id == lastTriggeredEventID {
            return
        }

        let now = Date()
        if now < lastTriggeredAt.addingTimeInterval(max(0, settings.weatherAlertCooldown)) {
            return
        }

        let fireAt = event.startTime.addingTimeInterval(-max(0, settings.weatherAlertLeadTime))
        if fireAt <= now {
            triggerIfStillValid(expectedEventID: event.id, reason: "immediate(\(reason))")
            return
        }

        let delayNanos = UInt64(max(0, fireAt.timeIntervalSince(now)) * 1_000_000_000)
        scheduledTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanos)
            } catch {
                return
            }
            await MainActor.run {
                self?.triggerIfStillValid(expectedEventID: event.id, reason: "scheduled(\(reason))")
            }
        }

        #if DEBUG
        logger.debug("Scheduled weather alert in \(fireAt.timeIntervalSince(now), privacy: .public)s for event=\(event.id, privacy: .public)")
        #endif
    }

    private func triggerIfStillValid(expectedEventID: String, reason: String) {
        guard settings.weatherEnabled else { return }
        guard settings.weatherAlertsEnabled else { return }
        guard battery.enableNotchAlerts else { return }
        guard battery.isNotchAvailable else { return }

        guard let event = weather.nextEvent else { return }
        guard event.id == expectedEventID else { return }
        guard shouldAlert(for: event) else { return }

        let now = Date()
        if now < lastTriggeredAt.addingTimeInterval(max(0, settings.weatherAlertCooldown)) {
            return
        }

        lastTriggeredEventID = event.id
        lastTriggeredAt = now

        let type = notchAlertType(for: event)
        let duration: TimeInterval = (type == .critical) ? 3.0 : 2.0
        let pulseCount: Int = (type == .critical) ? 3 : 2

        NotchGlowManager.shared.showAlert(type: type, duration: duration, pulseCount: pulseCount)

        #if DEBUG
        logger.debug("Triggered weather alert type=\(String(describing: type), privacy: .public) reason=\(reason, privacy: .public) event=\(event.title, privacy: .public)")
        #endif
    }

    private func shouldAlert(for event: WeatherEvent) -> Bool {
        switch event.kind {
        case .precipStart:
            return settings.weatherAlertPrecipitation
        case .conditionShift:
            if event.toBucket == .thunder {
                return settings.weatherAlertStorm
            }
            return settings.weatherAlertPrecipitation
        case .tempDrop, .tempRise:
            return settings.weatherAlertTempChange
        case .precipStop:
            // Clearing is handled in-notch as a subtle “next change”; avoid alert spam by default.
            return false
        }
    }

    private func notchAlertType(for event: WeatherEvent) -> NotchAlertType {
        if event.toBucket == .thunder {
            return .critical
        }

        switch event.kind {
        case .precipStart:
            return (event.severity >= 0.6) ? .warning : .info
        case .conditionShift:
            return event.toBucket?.isPrecipitation == true ? .warning : .info
        case .tempDrop, .tempRise:
            return .info
        case .precipStop:
            return .info
        }
    }
}
