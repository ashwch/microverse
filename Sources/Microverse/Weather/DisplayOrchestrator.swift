import Combine
import BatteryCore
import Foundation
import os.log

@MainActor
final class DisplayOrchestrator: ObservableObject {
    enum CompactSlotContent: Equatable, Sendable {
        case systemMetrics
        case weather
    }

    @Published private(set) var compactTrailing: CompactSlotContent = .systemMetrics
    @Published private(set) var debugReason: String = "system"

    private let settings: WeatherSettingsStore
    private let weather: WeatherStore
    private let battery: BatteryViewModel
    private let logger = Logger(subsystem: "com.microverse.app", category: "DisplayOrchestrator")

    private var cancellables = Set<AnyCancellable>()
    private var schedulerTask: Task<Void, Never>?

    private var weatherUntil: Date = .distantPast
    private var lockedUntil: Date = .distantPast
    private var cooldownUntil: Date = .distantPast
    private var nextRotationAt: Date = .distantFuture

    private var lastWeatherReady = false
    private var lastRotationEnabled = false
    private var lastRotationInterval: TimeInterval = 0
    private var lastOnDemandRefreshAt: Date = .distantPast
    private var activePeekReason: String = "system"

    private var lastSwitchAt: Date = .distantPast
    private var lastSwitchedToWeatherAt: Date = .distantPast
    private var lastSwitchedToSystemAt: Date = .distantPast
    private var switchToWeatherCount: Int = 0
    private var switchToSystemCount: Int = 0

    /// When the next event is within this window, we may show a brief highlight.
    private let eventLeadTime: TimeInterval = 90 * 60

    /// Avoid spamming provider calls when peeking in compact notch.
    private let minimumOnDemandRefreshInterval: TimeInterval = 10 * 60

    init(settings: WeatherSettingsStore, weatherStore: WeatherStore, batteryViewModel: BatteryViewModel) {
        self.settings = settings
        self.weather = weatherStore
        self.battery = batteryViewModel

        Publishers.Merge3(
            settings.objectWillChange.map { _ in () },
            weatherStore.objectWillChange.map { _ in () },
            batteryViewModel.objectWillChange.map { _ in () }
        )
        .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            self.recompute(now: Date(), reason: "inputs")
        }
        .store(in: &cancellables)

        recompute(now: Date(), reason: "init")
    }

    func refresh(reason: String) {
        recompute(now: Date(), reason: reason)
    }

    func previewWeatherInNotch(duration: TimeInterval? = nil) {
        schedulerTask?.cancel()
        schedulerTask = nil

        let now = Date()
        let snapshot = settings.snapshot()

        guard snapshot.enabled, snapshot.showInNotch, snapshot.location != nil else { return }
        guard !isBatteryCritical(battery.batteryInfo) else { return }

        beginWeatherPeek(
            now: now,
            duration: duration ?? max(snapshot.minDwell, snapshot.eventBoostDuration),
            reason: "preview",
            snapshot: snapshot
        )

        // Force visible immediately (don’t wait for the next scheduled recompute).
        setCompactTrailing(.weather, reason: "preview", now: now)
        scheduleNextWake(now: now, snapshot: snapshot)
    }

    private func recompute(now: Date, reason: String) {
        schedulerTask?.cancel()
        schedulerTask = nil

        let snapshot = settings.snapshot()
        let rotationIntervalChanged = snapshot.rotationInterval != lastRotationInterval

        // Gate: only compact "swap surfaces" (notch + widget) use the orchestrator.
        let shouldConsiderCompactSwaps = snapshot.showInNotch || snapshot.showInWidget
        let weatherReady = snapshot.enabled && shouldConsiderCompactSwaps && snapshot.location != nil
        if !weatherReady {
            setCompactTrailing(.systemMetrics, reason: "weather_disabled", now: now)
            resetTransientState(now: now)
            lastWeatherReady = false
            lastRotationEnabled = snapshot.rotationEnabled
            lastRotationInterval = snapshot.rotationInterval
            scheduleNextWake(now: now, snapshot: snapshot)
            return
        }

        // Battery-critical override: never hide system during critical battery.
        if isBatteryCritical(battery.batteryInfo) {
            setCompactTrailing(.systemMetrics, reason: "battery_critical", now: now)
            resetTransientState(now: now)
            // Consider weather “not shown” yet so we can show it after the critical period ends.
            lastWeatherReady = false
            lastRotationEnabled = snapshot.rotationEnabled
            lastRotationInterval = snapshot.rotationInterval
            scheduleNextWake(now: now, snapshot: snapshot)
            return
        }

        // Show a brief peek when Weather becomes ready (enabled + location set) so the user sees it immediately.
        if !lastWeatherReady {
            lastWeatherReady = true
            beginWeatherPeek(now: now, duration: max(snapshot.minDwell, snapshot.eventBoostDuration), reason: "weather_enabled", snapshot: snapshot)
        }

        // Rotation peeks (opt-in).
        if snapshot.rotationEnabled {
            if rotationIntervalChanged, nextRotationAt != .distantFuture {
                nextRotationAt = now.addingTimeInterval(snapshot.rotationInterval)
            }
            // When the user turns peeks on, show one immediately so they can confirm it works.
            if !lastRotationEnabled, now >= cooldownUntil {
                beginWeatherPeek(now: now, duration: snapshot.minDwell, reason: "rotation_enabled", snapshot: snapshot)
                nextRotationAt = now.addingTimeInterval(snapshot.rotationInterval)
            } else if nextRotationAt == .distantFuture {
                nextRotationAt = now.addingTimeInterval(snapshot.rotationInterval)
            } else if now >= nextRotationAt, now >= cooldownUntil {
                beginWeatherPeek(now: now, duration: snapshot.minDwell, reason: "rotation_peek", snapshot: snapshot)
                nextRotationAt = now.addingTimeInterval(snapshot.rotationInterval)
            }
        } else {
            nextRotationAt = .distantFuture
        }
        lastRotationEnabled = snapshot.rotationEnabled
        lastRotationInterval = snapshot.rotationInterval

        // Event-driven highlight (default ON, conservative, cooldown-protected).
        if snapshot.smartSwitchingEnabled,
           let next = weather.nextEvent {
            let windowStart = next.startTime.addingTimeInterval(-eventLeadTime)
            if now >= windowStart, now >= cooldownUntil {
                beginWeatherPeek(now: now, duration: snapshot.eventBoostDuration, reason: "event_boost", snapshot: snapshot)
                cooldownUntil = now.addingTimeInterval(snapshot.cooldown)
            }
        }

        // Decide desired content.
        let desired: CompactSlotContent = now < weatherUntil ? .weather : .systemMetrics

        // Respect minimum dwell: once we show weather, don't switch back too quickly.
        if compactTrailing == .weather, desired == .systemMetrics, now < lockedUntil {
            setCompactTrailing(.weather, reason: "dwell(\(activePeekReason))", now: now)
            scheduleNextWake(now: now, snapshot: snapshot)
            return
        }

        setCompactTrailing(desired, reason: desired == .weather ? activePeekReason : "system", now: now)
        scheduleNextWake(now: now, snapshot: snapshot)
    }

    private func beginWeatherPeek(now: Date, duration: TimeInterval, reason: String, snapshot: WeatherSettingsSnapshot) {
        activePeekReason = reason
        let dwell = max(2.0, snapshot.minDwell)
        lockedUntil = max(lockedUntil, now.addingTimeInterval(dwell))
        weatherUntil = max(weatherUntil, now.addingTimeInterval(max(dwell, duration)))

        #if DEBUG
        logger.debug("Begin peek (\(reason, privacy: .public)) dwell=\(dwell, privacy: .public)s until=\(self.weatherUntil.timeIntervalSince(now), privacy: .public)s nextRotation=\(self.nextRotationAt.timeIntervalSince(now), privacy: .public)s cooldown=\(self.cooldownUntil.timeIntervalSince(now), privacy: .public)s")
        #endif

        // Opportunistic refresh when we’re about to surface weather.
        if now.timeIntervalSince(lastOnDemandRefreshAt) >= minimumOnDemandRefreshInterval {
            lastOnDemandRefreshAt = now
            weather.triggerRefresh(reason: "orchestrator:\(reason)")
        }
    }

    private func resetTransientState(now: Date) {
        weatherUntil = now
        lockedUntil = now
        cooldownUntil = now
        nextRotationAt = .distantFuture
        activePeekReason = "system"
    }

    private func scheduleNextWake(now: Date, snapshot: WeatherSettingsSnapshot) {
        var nextWake = Date.distantFuture

        if lockedUntil > now {
            nextWake = min(nextWake, lockedUntil)
        }
        if weatherUntil > now {
            nextWake = min(nextWake, weatherUntil)
        }
        if cooldownUntil > now {
            nextWake = min(nextWake, cooldownUntil)
        }
        if snapshot.rotationEnabled, nextRotationAt > now {
            nextWake = min(nextWake, nextRotationAt)
        }
        if snapshot.smartSwitchingEnabled, let e = weather.nextEvent {
            let windowStart = e.startTime.addingTimeInterval(-eventLeadTime)
            if windowStart > now {
                nextWake = min(nextWake, windowStart)
            }
        }

        guard nextWake != .distantFuture else { return }
        let sleepNanos = UInt64(max(0, nextWake.timeIntervalSince(now)) * 1_000_000_000)
        schedulerTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: sleepNanos)
            } catch {
                // Important: cancelled scheduler tasks must not immediately call recompute, or we can
                // create a cancellation→recompute loop that defeats rotation intervals.
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.recompute(now: Date(), reason: "schedule")
            }
        }
    }

    private func setCompactTrailing(_ content: CompactSlotContent, reason: String, now: Date) {
        if compactTrailing != content {
            compactTrailing = content
            lastSwitchAt = now
            switch content {
            case .weather:
                lastSwitchedToWeatherAt = now
                switchToWeatherCount += 1
            case .systemMetrics:
                lastSwitchedToSystemAt = now
                switchToSystemCount += 1
            }

            #if DEBUG
            logger.debug("Switch compactTrailing=\(String(describing: content), privacy: .public) reason=\(reason, privacy: .public)")
            #endif
        }
        debugReason = reason
    }

    private func isBatteryCritical(_ info: BatteryInfo) -> Bool {
        info.currentCharge <= 10 && !info.isPluggedIn
    }

    #if DEBUG
    func debugCompactScheduleDescription(now: Date = Date()) -> String {
        let snapshot = settings.snapshot()

        func fmtInterval(_ seconds: TimeInterval) -> String {
            if seconds < 60 { return "\(Int(seconds))s" }
            let minutes = Int((seconds / 60).rounded())
            if minutes < 60 { return "\(minutes)m" }
            let hours = Int((Double(minutes) / 60.0).rounded(.down))
            return "\(hours)h"
        }

        func rel(_ date: Date) -> String {
            guard date != .distantFuture, date != .distantPast else { return "—" }
            let seconds = max(0, Int(date.timeIntervalSince(now).rounded()))
            if seconds < 60 { return "\(seconds)s" }
            let minutes = seconds / 60
            if minutes < 60 { return "\(minutes)m" }
            let hours = minutes / 60
            return "\(hours)h"
        }

        let rotation = snapshot.rotationEnabled ? fmtInterval(snapshot.rotationInterval) : "off"
        let highlights = snapshot.smartSwitchingEnabled ? "on" : "off"
        return "reason=\(debugReason) lastSwitch=\(rel(lastSwitchAt)) switches(w:\(switchToWeatherCount) s:\(switchToSystemCount)) lastWeather=\(rel(lastSwitchedToWeatherAt)) until=\(rel(weatherUntil)) nextRotation=\(rel(nextRotationAt)) cooldown=\(rel(cooldownUntil)) rotationEvery=\(rotation) highlights=\(highlights)"
    }
    #endif
}
