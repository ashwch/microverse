import CoreLocation
import Foundation
import os.log

/// “Current location” controller for Weather (CoreLocation).
///
/// ## First principles
/// - **Opt-in:** only used when the user enables “Current location” in Weather settings.
/// - **Coarse + calm:** kilometer accuracy + a conservative distance filter; weather doesn’t need GPS precision.
/// - **UI-friendly:** publish immediately with a neutral name (“Current Location”), then resolve a city name asynchronously.
///
/// This type is an NSObject wrapper so it can act as a `CLLocationManagerDelegate` while keeping the rest of the Weather
/// system Swift-concurrency friendly (`@MainActor` state, cancellable reverse-geocode task).
@MainActor
final class WeatherCurrentLocationController: NSObject {
    struct Update: Equatable, Sendable {
        var location: WeatherLocation
        var raw: CLLocation
        var resolvedName: Bool
    }

    var onAuthorizationChanged: ((CLAuthorizationStatus) -> Void)?
    var onUpdatingChanged: ((Bool) -> Void)?
    var onUpdate: ((Update) -> Void)?
    var onError: ((String?) -> Void)?

    private let logger = Logger(subsystem: "com.microverse.app", category: "WeatherCurrentLocation")
    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()

    private var isUpdating = false {
        didSet {
            guard isUpdating != oldValue else { return }
            onUpdatingChanged?(isUpdating)
        }
    }

    private var lastPublished: Update?
    private var lastGeocodedRaw: CLLocation?
    private var geocodeTask: Task<Void, Never>?

    override init() {
        manager = CLLocationManager()

        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 750 // ~city block-ish; good enough for weather without jitter.
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var locationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    func start() {
        guard locationServicesEnabled else {
            onAuthorizationChanged?(authorizationStatus)
            onError?("Location Services are disabled.")
            return
        }

        onAuthorizationChanged?(authorizationStatus)

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            onError?("Location access is disabled for Microverse.")
            return
        case .authorizedAlways, .authorized:
            break
        @unknown default:
            break
        }

        isUpdating = true
        manager.startUpdatingLocation()
        manager.requestLocation()
    }

    func stop() {
        geocodeTask?.cancel()
        geocodeTask = nil

        isUpdating = false
        manager.stopUpdatingLocation()
    }

    func requestOneShotUpdate() {
        guard locationServicesEnabled else { return }
        switch authorizationStatus {
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        default:
            break
        }
    }

    private func publish(raw: CLLocation, resolvedName: Bool, displayName: String?) {
        let tz = TimeZone.current.identifier
        let lat = raw.coordinate.latitude.rounded(toPlaces: 3)
        let lon = raw.coordinate.longitude.rounded(toPlaces: 3)

        let fallbackName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (fallbackName?.isEmpty == false) ? (fallbackName ?? "Current Location") : "Current Location"

        guard let location = WeatherLocation(
            displayName: name,
            latitude: lat,
            longitude: lon,
            timezoneIdentifier: tz
        ) else {
            return
        }

        let update = Update(location: location, raw: raw, resolvedName: resolvedName)
        guard update != lastPublished else { return }
        lastPublished = update
        onUpdate?(update)
    }

    private func maybeReverseGeocode(_ raw: CLLocation) {
        guard locationServicesEnabled else { return }
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorized else { return }

        let shouldGeocode: Bool = {
            if lastGeocodedRaw == nil { return true }
            guard let lastGeocodedRaw else { return true }
            let distance = raw.distance(from: lastGeocodedRaw)
            return distance >= 5_000 // ~5km; avoid spamming geocoder on tiny drift.
        }()

        guard shouldGeocode else { return }

        lastGeocodedRaw = raw
        geocodeTask?.cancel()
        geocodeTask = Task { [weak self] in
            guard let self else { return }

            do {
                let placemarks = try await self.geocoder.reverseGeocodeLocation(raw)
                guard let placemark = placemarks.first else { return }
                let name = WeatherPlacemarkNameFormatter.displayName(for: placemark)
                self.publish(raw: raw, resolvedName: true, displayName: name)
            } catch is CancellationError {
                // ignore
            } catch {
                self.logger.debug("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension WeatherCurrentLocationController: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onAuthorizationChanged?(self.authorizationStatus)

            switch self.authorizationStatus {
            case .authorizedAlways, .authorized:
                self.onError?(nil)
                if self.isUpdating {
                    self.manager.requestLocation()
                }
            case .denied, .restricted:
                self.onError?("Location access is disabled for Microverse.")
                self.stop()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.debug("Location update failed: \(error.localizedDescription, privacy: .public)")
            self.onError?("Unable to determine your current location.")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let raw = locations.last else { return }
            guard raw.horizontalAccuracy >= 0, raw.horizontalAccuracy < 50_000 else { return }

            // Publish quickly with a neutral name, then resolve a city name asynchronously.
            self.onError?(nil)
            self.publish(raw: raw, resolvedName: false, displayName: nil)
            self.maybeReverseGeocode(raw)
        }
    }
}
