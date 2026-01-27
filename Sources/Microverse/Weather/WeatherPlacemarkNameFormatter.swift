import CoreLocation
import Foundation

/// Turns a `CLPlacemark` into a stable, human-friendly location name for Microverse UI.
///
/// Goals:
/// - Prefer **City** (or placemark name) as the primary label.
/// - Avoid noisy or ambiguous region codes for non-local locations (e.g. “Meerut, UP” → “Meerut, India”).
/// - Keep local admin abbreviations when they’re actually helpful for the current user (e.g. “San Francisco, CA”).
enum WeatherPlacemarkNameFormatter {
    static func displayName(for placemark: CLPlacemark) -> String {
        func trimmed(_ s: String?) -> String? {
            let value = s?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false) ? value : nil
        }

        func isCompactRegionCode(_ s: String) -> Bool {
            let value = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.count <= 4 else { return false }
            guard value == value.uppercased() else { return false }
            return value.allSatisfy { $0.isLetter || $0.isNumber }
        }

        var parts: [String] = []

        if let locality = trimmed(placemark.locality) {
            parts.append(locality)
        } else if let name = trimmed(placemark.name) {
            parts.append(name)
        }

        let userRegion = Locale.current.region?.identifier.uppercased()
        let iso = trimmed(placemark.isoCountryCode)?.uppercased()

        // Keep administrative area only for the user's own region (e.g., "San Francisco, CA"),
        // otherwise prefer the country ("Meerut, India") to reduce noisy codes like "UP".
        if let admin = trimmed(placemark.administrativeArea),
           isCompactRegionCode(admin),
           iso == userRegion
        {
            parts.append(admin)
        }

        if let iso, iso != userRegion {
            if let country = trimmed(placemark.country) {
                parts.append(country)
            } else {
                parts.append(iso)
            }
        }

        if parts.isEmpty {
            return "Selected Location"
        }

        return parts.joined(separator: ", ")
    }
}
