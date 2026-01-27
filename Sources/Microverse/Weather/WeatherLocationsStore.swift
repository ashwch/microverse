import Combine
import Foundation
import os.log

/// Snapshot for one location used by `WeatherLocationsStore`.
struct WeatherLocationSummary: Identifiable, Equatable, Sendable {
    var id: String { location.id }
    var location: WeatherLocation
    var current: WeatherSnapshot?
    var fetchState: WeatherFetchState
    var lastUpdated: Date?
    var lastProvider: WeatherPayload.Provider?

    static func placeholder(location: WeatherLocation) -> WeatherLocationSummary {
        WeatherLocationSummary(
            location: location,
            current: nil,
            fetchState: .idle,
            lastUpdated: nil,
            lastProvider: nil
        )
    }
}

/// Lightweight per-location weather summaries (multi-location support).
///
/// ## Why this exists
/// `WeatherStore` is intentionally “single selected location” — it drives the main Weather tab and compact surfaces.
/// When Microverse needs *multiple* locations (e.g. “show all locations” in the compact notch), we don’t want to:
/// - spam the provider with frequent fetches for every saved location, or
/// - inflate the main `WeatherStore` with list concerns.
///
/// This store maintains a small `WeatherLocationSummary` for each saved location, backed by a disk cache, and refreshes:
/// - **on-demand** when UI asks (`triggerRefresh`)
/// - **periodically** only for the high-value scenario where multi-location is actively visible (pinned + cycling)
@MainActor
final class WeatherLocationsStore: ObservableObject {
    @Published private(set) var summaries: [WeatherLocationSummary] = []

    private let provider: WeatherProvider
    private let settings: WeatherSettingsStore
    private let cache: WeatherDiskCache
    private let logger = Logger(subsystem: "com.microverse.app", category: "WeatherLocationsStore")

    private var cancellables = Set<AnyCancellable>()
    private var periodicRefreshTask: Task<Void, Never>?
    private var debouncedRefreshTask: Task<Void, Never>?
    private var inFlightFetches: [String: Task<WeatherPayload, Error>] = [:]

    init(provider: WeatherProvider, settings: WeatherSettingsStore) {
        self.provider = provider
        self.settings = settings
        self.cache = WeatherDiskCache(filename: "weather-locations-cache-v1.json")

        Publishers.MergeMany([
            settings.$weatherEnabled.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherShowInNotch.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherPinInNotch.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherShowAllLocationsInNotch.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherUseCurrentLocation.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherLocations.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherSelectedLocationID.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            settings.$weatherRefreshInterval.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
        ])
        .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
        .sink { [weak self] in
            self?.recompute(reason: "settings")
        }
        .store(in: &cancellables)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let cached = await cache.loadAll()
            self.applyCachedPayloads(cached)
            self.recompute(reason: "init")
        }
    }

    func triggerRefresh(reason: String) {
        guard canFetch else { return }

        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            await self?.refreshAllNow(reason: reason)
        }
    }

    private var canFetch: Bool {
        settings.weatherEnabled
            && (settings.weatherLocations.count > 1 || (settings.weatherUseCurrentLocation && !settings.weatherLocations.isEmpty))
    }

    private var shouldRunPeriodically: Bool {
        canFetch
            && settings.weatherShowInNotch
            && settings.weatherPinInNotch
            && settings.weatherShowAllLocationsInNotch
    }

    private func recompute(reason: String) {
        publishSummariesFromCurrentState()

        if !canFetch {
            cancelAll()
            return
        }

        if shouldRunPeriodically {
            startPeriodicRefreshIfNeeded()
            triggerRefresh(reason: reason)
        } else {
            stopPeriodic()
        }
    }

    private func startPeriodicRefreshIfNeeded() {
        guard periodicRefreshTask == nil else { return }

        periodicRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshAllNow(reason: "timer")
                let interval = max(5 * 60, self.settings.weatherRefreshInterval)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }

        #if DEBUG
        logger.debug("Started periodic refresh")
        #endif
    }

    private func stopPeriodic() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil
    }

    private func cancelAll() {
        stopPeriodic()

        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = nil

        for (_, task) in inFlightFetches {
            task.cancel()
        }
        inFlightFetches.removeAll()
    }

    private func refreshAllNow(reason: String) async {
        guard canFetch else { return }

        let locations = settings.weatherLocations
        guard !locations.isEmpty else { return }

        for location in locations {
            await refresh(location: location, reason: reason)
        }
    }

    private func refresh(location: WeatherLocation, reason: String) async {
        setFetchState(.loading, for: location)

        do {
            let payload = try await fetchDeduped(location: location)
            Task { await cache.save(payload) }
            apply(payload: payload, isStale: false)
        } catch is CancellationError {
            // ignore
        } catch {
            let state: WeatherFetchState = {
                if summaries.first(where: { $0.id == location.id })?.current != nil {
                    return .stale
                }
                return .failed(error.localizedDescription)
            }()
            setFetchState(state, for: location)
        }
    }

    private func fetchDeduped(location: WeatherLocation) async throws -> WeatherPayload {
        if let existing = inFlightFetches[location.id] {
            return try await existing.value
        }

        let task = Task<WeatherPayload, Error> {
            try await provider.fetch(location: location)
        }

        inFlightFetches[location.id] = task
        defer { inFlightFetches[location.id] = nil }
        return try await task.value
    }

    private func apply(payload: WeatherPayload, isStale: Bool) {
        let loc = payload.location
        let idx = summaries.firstIndex(where: { $0.id == loc.id })

        let next = WeatherLocationSummary(
            location: loc,
            current: payload.current,
            fetchState: isStale ? .stale : .loaded,
            lastUpdated: payload.fetchedAt,
            lastProvider: payload.provider
        )

        if let idx {
            summaries[idx] = next
        } else {
            summaries.append(next)
        }

        publishSummariesFromCurrentState()
    }

    private func setFetchState(_ state: WeatherFetchState, for location: WeatherLocation) {
        if let idx = summaries.firstIndex(where: { $0.id == location.id }) {
            var s = summaries[idx]
            s.fetchState = state
            summaries[idx] = s
        } else {
            var s = WeatherLocationSummary.placeholder(location: location)
            s.fetchState = state
            summaries.append(s)
        }
        publishSummariesFromCurrentState()
    }

    private func applyCachedPayloads(_ payloads: [String: WeatherPayload]) {
        guard !payloads.isEmpty else { return }

        for payload in payloads.values {
            apply(payload: payload, isStale: true)
        }
    }

    private func publishSummariesFromCurrentState() {
        let locations = settings.weatherLocations
        let selectedID = settings.weatherSelectedLocationID

        let ordered: [WeatherLocation] = {
            if let selectedID, let selected = locations.first(where: { $0.id == selectedID }) {
                return [selected] + locations.filter { $0.id != selectedID }
            }
            return locations
        }()

        let byID = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        summaries = ordered.map { byID[$0.id] ?? .placeholder(location: $0) }
    }
}
