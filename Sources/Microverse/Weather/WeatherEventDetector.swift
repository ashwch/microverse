import Foundation

struct WeatherEvent: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case precipStart
        case precipStop
        case conditionShift
        case tempRise
        case tempDrop
    }

    var id: String
    var kind: Kind
    var startTime: Date
    var severity: Double // 0...1
    var title: String
    var valueC: Double?
    var fromBucket: WeatherConditionBucket?
    var toBucket: WeatherConditionBucket?
}

struct WeatherEventDetector: Sendable {
    struct Candidate: Sendable {
        var event: WeatherEvent
        var score: Double
    }

    func nextEvent(payload: WeatherPayload, previous: WeatherEvent?, now: Date, settings: WeatherSettingsSnapshot) -> WeatherEvent? {
        guard settings.enabled else { return nil }

        let horizonHours = 6
        let horizon = now.addingTimeInterval(TimeInterval(horizonHours) * 3600)

        var candidates: [Candidate] = []

        if let c = precipCandidate(payload: payload, now: now, horizon: horizon, s: settings) {
            candidates.append(c)
        }
        if let c = bucketShiftCandidate(payload: payload, now: now, horizon: horizon) {
            candidates.append(c)
        }
        if let c = tempSwingCandidate(payload: payload, now: now, horizon: horizon, s: settings) {
            candidates.append(c)
        }

        guard var best = candidates.max(by: { $0.score < $1.score })?.event else { return nil }

        if let prev = previous, isStillValid(prev, now: now) {
            if shouldKeepPrevious(prev: prev, best: best, now: now) {
                return prev
            }
        }

        best.id = stableID(for: best)
        return best
    }

    // MARK: - Precip (prefer minutely if available)

    private func precipCandidate(payload: WeatherPayload, now: Date, horizon: Date, s: WeatherSettingsSnapshot) -> Candidate? {
        if let minutely = payload.minutely, !minutely.isEmpty {
            return minutelyPrecipCandidate(minutely, now: now, horizon: horizon, s: s)
        }
        return hourlyPrecipCandidate(payload.hourly, now: now, horizon: horizon, s: s)
    }

    private func minutelyPrecipCandidate(_ points: [MinutelyPrecipPoint], now: Date, horizon: Date, s: WeatherSettingsSnapshot) -> Candidate? {
        let window = points.filter { $0.date >= now && $0.date <= horizon }
        guard !window.isEmpty else { return nil }

        func isWet(_ p: MinutelyPrecipPoint) -> Bool {
            let chance = p.precipChance ?? 0
            let intensity = p.intensityMmPerHr ?? 0
            return (chance >= s.precipStartThreshold) || (intensity >= 0.1)
        }

        func isDry(_ p: MinutelyPrecipPoint) -> Bool {
            let chance = p.precipChance ?? 0
            let intensity = p.intensityMmPerHr ?? 0
            return (chance <= s.precipStopThreshold) && (intensity <= 0.05)
        }

        let currentSlice = window.prefix(3)
        let currentlyWet = currentSlice.filter(isWet).count >= 2

        if !currentlyWet, let startIndex = firstConsecutive(window, count: 2, predicate: isWet) {
            let t = window[startIndex].date
            let sev = clamp01(window[startIndex].precipChance ?? 0)
            let e = WeatherEvent(
                id: "",
                kind: .precipStart,
                startTime: t,
                severity: sev,
                title: "Precipitation soon",
                valueC: nil,
                fromBucket: nil,
                toBucket: .rain
            )
            return Candidate(event: e, score: score(kind: .precipStart, startTime: t, now: now, severity: sev))
        }

        if currentlyWet, let stopIndex = firstConsecutive(window, count: 3, predicate: isDry) {
            let t = window[stopIndex].date
            let sev = 0.5
            let e = WeatherEvent(
                id: "",
                kind: .precipStop,
                startTime: t,
                severity: sev,
                title: "Clearing",
                valueC: nil,
                fromBucket: .rain,
                toBucket: .cloudy
            )
            return Candidate(event: e, score: score(kind: .precipStop, startTime: t, now: now, severity: sev))
        }

        return nil
    }

    private func hourlyPrecipCandidate(_ points: [HourlyForecastPoint], now: Date, horizon: Date, s: WeatherSettingsSnapshot) -> Candidate? {
        let window = points.filter { $0.date >= now && $0.date <= horizon }
        guard !window.isEmpty else { return nil }

        func isWet(_ p: HourlyForecastPoint) -> Bool {
            (p.precipChance ?? 0) >= s.precipStartThreshold || p.bucket.isPrecipitation
        }

        func isDry(_ p: HourlyForecastPoint) -> Bool {
            (p.precipChance ?? 0) <= s.precipStopThreshold && !p.bucket.isPrecipitation
        }

        let currentlyWet = window.prefix(1).first.map(isWet) ?? false

        if !currentlyWet, let idx = firstConsecutive(window, count: 2, predicate: isWet) {
            let t = window[idx].date
            let sev = clamp01(window[idx].precipChance ?? 0)
            let e = WeatherEvent(id: "", kind: .precipStart, startTime: t, severity: sev, title: "Precipitation later", valueC: nil, fromBucket: nil, toBucket: .rain)
            return Candidate(event: e, score: score(kind: .precipStart, startTime: t, now: now, severity: sev))
        }

        if currentlyWet, let idx = firstConsecutive(window, count: 2, predicate: isDry) {
            let t = window[idx].date
            let sev = 0.4
            let e = WeatherEvent(id: "", kind: .precipStop, startTime: t, severity: sev, title: "Clearing", valueC: nil, fromBucket: .rain, toBucket: .cloudy)
            return Candidate(event: e, score: score(kind: .precipStop, startTime: t, now: now, severity: sev))
        }

        return nil
    }

    // MARK: - Bucket shift (coarse; only “major” categories)

    private func bucketShiftCandidate(payload: WeatherPayload, now: Date, horizon: Date) -> Candidate? {
        let window = payload.hourly.filter { $0.date >= now && $0.date <= horizon }
        guard let first = window.first else { return nil }

        let from = first.bucket

        func isMajor(_ b: WeatherConditionBucket) -> Bool {
            b.isPrecipitation || b == .fog || b == .thunder
        }

        for i in 0..<window.count {
            let b = window[i].bucket
            guard b != from, isMajor(b) else { continue }

            let slice = window[i..<min(i + 3, window.count)]
            guard slice.allSatisfy({ $0.bucket == b }) else { continue }

            let sev: Double = (b == .thunder) ? 0.9 : (b.isPrecipitation ? 0.7 : 0.6)
            let e = WeatherEvent(
                id: "",
                kind: .conditionShift,
                startTime: window[i].date,
                severity: sev,
                title: bucketTitle(b),
                valueC: nil,
                fromBucket: from,
                toBucket: b
            )
            return Candidate(event: e, score: score(kind: .conditionShift, startTime: e.startTime, now: now, severity: sev))
        }

        return nil
    }

    private func bucketTitle(_ b: WeatherConditionBucket) -> String {
        switch b {
        case .rain: return "Rain later"
        case .snow: return "Snow later"
        case .fog: return "Fog later"
        case .thunder: return "Storm possible"
        case .wind: return "Windy later"
        default: return "Changing"
        }
    }

    // MARK: - Temperature swing

    private func tempSwingCandidate(payload: WeatherPayload, now: Date, horizon: Date, s: WeatherSettingsSnapshot) -> Candidate? {
        let window = payload.hourly.filter { $0.date >= now && $0.date <= horizon }
        guard let start = window.first else { return nil }

        let startTemp = start.temperatureC
        let threshold = s.tempDeltaThresholdC
        let maxHours = max(1, s.tempDeltaWindowHours)

        for (idx, p) in window.enumerated() {
            let hours = p.date.timeIntervalSince(now) / 3600.0
            guard hours <= Double(maxHours) else { break }

            let delta = p.temperatureC - startTemp
            guard abs(delta) >= threshold else { continue }

            let dir = delta >= 0 ? 1.0 : -1.0
            let slice = window[idx..<min(idx + 3, window.count)]
            let consistent = slice.allSatisfy { (($0.temperatureC - startTemp) * dir) >= (threshold * 0.8) }
            guard consistent else { continue }

            let kind: WeatherEvent.Kind = (delta >= 0) ? .tempRise : .tempDrop
            let sev = clamp01(abs(delta) / (threshold * 2.0))
            let e = WeatherEvent(
                id: "",
                kind: kind,
                startTime: p.date,
                severity: sev,
                title: delta >= 0 ? "Warming up" : "Cooling down",
                valueC: abs(delta),
                fromBucket: nil,
                toBucket: nil
            )
            return Candidate(event: e, score: score(kind: kind, startTime: e.startTime, now: now, severity: sev))
        }

        return nil
    }

    // MARK: - Scoring + stickiness

    private func score(kind: WeatherEvent.Kind, startTime: Date, now: Date, severity: Double) -> Double {
        let dtMin = max(0, startTime.timeIntervalSince(now) / 60.0)

        let priority: Double = {
            switch kind {
            case .precipStart: return 3.0
            case .precipStop: return 2.2
            case .conditionShift: return 2.0
            case .tempDrop, .tempRise: return 1.0
            }
        }()

        let timeFactor = 1.0 / (1.0 + dtMin / 30.0) // 30m half-life-ish
        return priority * (0.6 + 0.4 * severity) * timeFactor
    }

    private func isStillValid(_ e: WeatherEvent, now: Date) -> Bool {
        now < e.startTime.addingTimeInterval(10 * 60)
    }

    private func shouldKeepPrevious(prev: WeatherEvent, best: WeatherEvent, now: Date) -> Bool {
        let prevScore = score(kind: prev.kind, startTime: prev.startTime, now: now, severity: prev.severity)
        let bestScore = score(kind: best.kind, startTime: best.startTime, now: now, severity: best.severity)
        return bestScore < (prevScore * 1.20) // require 20% improvement to replace
    }

    private func stableID(for e: WeatherEvent) -> String {
        "\(e.kind.rawValue)|\(Int(e.startTime.timeIntervalSinceReferenceDate / 60))"
    }

    private func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }

    private func firstConsecutive<T>(_ arr: [T], count: Int, predicate: (T) -> Bool) -> Int? {
        guard count > 0 else { return nil }
        var run = 0
        for (i, el) in arr.enumerated() {
            if predicate(el) {
                run += 1
                if run >= count { return i - (count - 1) }
            } else {
                run = 0
            }
        }
        return nil
    }
}

