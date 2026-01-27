import Combine
import Foundation
import os.log

/// Fetches and publishes weather for the *currently selected* location.
///
/// This store is intentionally single-location: it always reflects `WeatherSettingsStore.selectedLocation`.
/// When Microverse needs multiple locations (e.g. cycling in the compact notch), it uses `WeatherLocationsStore`.
///
/// Design goals:
/// - Debounced refresh (avoid hot polling while the user is toggling settings).
/// - Disk cache per location (fast startup + offline/stale UI).
/// - Provider-agnostic (WeatherKit when available, with a network fallback via `WeatherProviderFallback`).
@MainActor
final class WeatherStore: ObservableObject {
    @Published private(set) var current: WeatherSnapshot?
    @Published private(set) var hourly: [HourlyForecastPoint] = []
    @Published private(set) var nextEvent: WeatherEvent?
    @Published private(set) var fetchState: WeatherFetchState = .idle
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastProvider: WeatherPayload.Provider?

    private let provider: WeatherProvider
    private let settings: WeatherSettingsStore
    private let detector: WeatherEventDetector
    private let cache: WeatherDiskCache

    private var periodicRefreshTask: Task<Void, Never>?
    private var debouncedRefreshTask: Task<Void, Never>?
    private var inFlightFetch: (locationID: String, task: Task<WeatherPayload, Error>)?
    private var cancellables = Set<AnyCancellable>()

    init(provider: WeatherProvider, settings: WeatherSettingsStore, detector: WeatherEventDetector = WeatherEventDetector()) {
        self.provider = provider
        self.settings = settings
        self.detector = detector
        self.cache = WeatherDiskCache(filename: "weather-cache-v2.json")

        Task { [weak self] in
            guard let self else { return }
            if let locationID = settings.selectedLocation?.id,
               let cached = await cache.load(locationID: locationID)
            {
                self.apply(payload: cached, isStale: true)
            }
        }

        // Settings-driven refresh triggers (so enabling Weather / changing location feels immediate).
        settings.$weatherEnabled
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.triggerRefresh(reason: "settings_enabled")
                } else {
                    self.inFlightFetch?.task.cancel()
                    self.inFlightFetch = nil
                    self.fetchState = .idle
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            settings.$weatherSelectedLocationID,
            settings.$weatherLocations,
            settings.$weatherUseCurrentLocation,
            settings.$weatherCurrentLocation
        )
        .map { (selectedID, locations, useCurrentLocation, currentLocation) -> WeatherLocation? in
            if useCurrentLocation {
                return currentLocation
            }
            if let selectedID, let found = locations.first(where: { $0.id == selectedID }) {
                return found
            }
            return locations.first
        }
        .removeDuplicates(by: { lhs, rhs in lhs?.id == rhs?.id })
        .dropFirst()
        .sink { [weak self] (location: WeatherLocation?) in
                guard let self else { return }
                self.inFlightFetch?.task.cancel()
                self.inFlightFetch = nil

                if let location {
                    // Avoid showing stale data from a previously-selected location.
                    self.current = nil
                    self.hourly = []
                    self.nextEvent = nil
                    self.lastUpdated = nil
                    self.lastProvider = nil
                    self.fetchState = .loading

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let cached = await self.cache.load(locationID: location.id) {
                            self.apply(payload: cached, isStale: true)
                        }
                    }
                } else {
                    self.current = nil
                    self.hourly = []
                    self.nextEvent = nil
                    self.lastUpdated = nil
                    self.lastProvider = nil
                    self.fetchState = .idle
                }

                self.triggerRefresh(reason: "settings_location")
            }
            .store(in: &cancellables)
    }

    func start() {
        if periodicRefreshTask == nil {
            periodicRefreshTask = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    await self.refreshNow(reason: "timer")
                    let interval = max(5 * 60, self.settings.weatherRefreshInterval)
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }

        triggerRefresh(reason: "startup")
    }

    func stop() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil

        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = nil

        inFlightFetch?.task.cancel()
        inFlightFetch = nil
    }

    func triggerRefresh(reason: String) {
        guard settings.weatherEnabled, settings.selectedLocation != nil else { return }

        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                // Cancellation must not immediately fall through and refresh, or we defeat debounce.
                return
            }
            await self?.refreshNow(reason: reason)
        }
    }

    func refreshNow(reason: String) async {
        let snapshot = settings.snapshot()
        guard snapshot.enabled, let location = snapshot.location else {
            fetchState = .idle
            return
        }

        fetchState = .loading

        do {
            let payload = try await fetchDeduped(location: location)
            Task { await cache.save(payload) }
            apply(payload: payload, isStale: false)
        } catch is CancellationError {
            // ignore
        } catch {
            fetchState = (current != nil) ? .stale : .failed(error.localizedDescription)
        }
    }

    private func fetchDeduped(location: WeatherLocation) async throws -> WeatherPayload {
        if let inFlightFetch, inFlightFetch.locationID == location.id {
            return try await inFlightFetch.task.value
        }

        inFlightFetch?.task.cancel()

        let task = Task<WeatherPayload, Error> {
            try await provider.fetch(location: location)
        }

        inFlightFetch = (locationID: location.id, task: task)
        defer {
            if inFlightFetch?.locationID == location.id {
                inFlightFetch = nil
            }
        }

        return try await task.value
    }

    private func apply(payload: WeatherPayload, isStale: Bool) {
        if isStale, lastUpdated != nil {
            // Never let an async cache load override fresh provider data.
            return
        }
        guard settings.weatherEnabled else { return }
        guard payload.location.id == settings.selectedLocation?.id else { return }

        lastProvider = payload.provider
        current = sanitize(snapshot: payload.current)
        hourly = payload.hourly.prefix(24).map(sanitize(hour:))
        lastUpdated = payload.fetchedAt
        fetchState = isStale ? .stale : .loaded

        let now = Date()
        let previous = nextEvent
        let event = detector.nextEvent(payload: payload, previous: previous, now: now, settings: settings.snapshot())
        if event != previous { nextEvent = event }
    }

    private func sanitize(snapshot: WeatherSnapshot) -> WeatherSnapshot {
        var s = snapshot
        s.temperatureC = s.temperatureC.rounded(toPlaces: 1)
        s.feelsLikeC = s.feelsLikeC?.rounded(toPlaces: 1)
        s.precipChance = s.precipChance.map { min(1, max(0, $0)) }
        s.windKph = s.windKph?.rounded(toPlaces: 1)
        return s
    }

    private func sanitize(hour: HourlyForecastPoint) -> HourlyForecastPoint {
        var h = hour
        h.temperatureC = h.temperatureC.rounded(toPlaces: 1)
        h.precipChance = h.precipChance.map { min(1, max(0, $0)) }
        h.windKph = h.windKph?.rounded(toPlaces: 1)
        return h
    }

    #if DEBUG
    func debugApplyScenario(_ scenario: WeatherDebugScenarioProvider.Scenario) {
        guard settings.weatherEnabled, let location = settings.selectedLocation else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            fetchState = .loading
            do {
                let payload = try await WeatherDebugScenarioProvider(scenario: scenario).fetch(location: location)
                apply(payload: payload, isStale: false)
            } catch {
                fetchState = .failed(error.localizedDescription)
            }
        }
    }
    #endif
}

actor WeatherDiskCache {
    private static let logger = Logger(subsystem: "com.microverse.app", category: "WeatherCache")

    private let url: URL
    private var hasLoaded = false
    private var storage: [String: WeatherPayload] = [:]

    init(filename: String) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Microverse", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Failed to create cache directory: \(error.localizedDescription, privacy: .public)")
        }
        url = dir.appendingPathComponent(filename)
    }

    func save(_ payload: WeatherPayload) {
        loadStorageIfNeeded()
        storage[payload.location.id] = payload

        do {
            let data = try JSONEncoder().encode(storage)
            try data.write(to: url, options: [.atomic])
        } catch {
            Self.logger.error("Failed to save weather cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    func load(locationID: String) -> WeatherPayload? {
        loadStorageIfNeeded()
        return storage[locationID]
    }

    func loadAll() -> [String: WeatherPayload] {
        loadStorageIfNeeded()
        return storage
    }

    private func loadStorageIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return
        }

        do {
            storage = try JSONDecoder().decode([String: WeatherPayload].self, from: data)
        } catch {
            Self.logger.error("Failed to decode weather cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
