import Foundation

enum MicroverseWeatherAnnouncement {
    static let leadTime: TimeInterval = 90 * 60

    static func symbolName(for event: WeatherEvent, isDaylight: Bool) -> String {
        switch event.kind {
        case .precipStart:
            return (event.toBucket ?? .rain).symbolName(isDaylight: isDaylight)
        case .precipStop:
            return isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case .conditionShift:
            if let b = event.toBucket { return b.symbolName(isDaylight: isDaylight) }
            return "sparkles"
        case .tempDrop:
            return "thermometer.low"
        case .tempRise:
            return "thermometer.high"
        }
    }

    static func relativeTimeShort(from now: Date, to target: Date) -> String {
        let delta = target.timeIntervalSince(now)
        if abs(delta) < 60 { return "now" }

        let minutes = Int((delta / 60).rounded())
        let absMinutes = abs(minutes)
        if absMinutes < 60 { return "\(absMinutes)m" }

        let hours = Int((Double(absMinutes) / 60.0).rounded(.down))
        return "\(hours)h"
    }
}

