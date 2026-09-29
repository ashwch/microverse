import Foundation

/// One frame of the compact weather peek.
enum WeatherPeekSlide: Equatable, Identifiable {
  case current(WeatherSnapshot)
  case event(WeatherEvent)
  case tomorrow(WeatherTomorrowOutlook)

  var id: String {
    switch self {
    case .current: return "current"
    case .event(let event): return "event:\(event.id)"
    case .tomorrow: return "tomorrow"
    }
  }
}

/// Next-day summary shown in the evening so the user can plan for it the night before.
struct WeatherTomorrowOutlook: Equatable {
  enum Hint: Equatable {
    case none, cooler, warmer, rain, snow, storm
  }

  var highC: Double
  var lowC: Double
  var bucket: WeatherConditionBucket
  var hint: Hint

  /// Short label for the compact pill.
  var shortTitle: String {
    switch hint {
    case .none: return "Tomorrow"
    case .cooler: return "Cooler"
    case .warmer: return "Warmer"
    case .rain: return "Rain"
    case .snow: return "Snow"
    case .storm: return "Storms"
    }
  }

  /// Longer label for surfaces with room.
  var title: String {
    switch hint {
    case .none: return "Tomorrow"
    case .cooler: return "Cooler tomorrow"
    case .warmer: return "Warmer tomorrow"
    case .rain: return "Rain tomorrow"
    case .snow: return "Snow tomorrow"
    case .storm: return "Storms tomorrow"
    }
  }
}

/// Decides what the weather peek cycles through. Pure, so it is easy to reason about and to
/// exercise with fixed dates.
enum WeatherPeekPlanner {
  /// How long each slide stays up.
  static let slideDuration: TimeInterval = 3
  /// At most this many upcoming changes after the current conditions.
  static let maxEvents = 3
  /// Local hour from which the next day's outlook joins the cycle.
  static let eveningHour = 21
  /// A day-to-day swing in the daily high at least this large is worth flagging.
  static let notableDeltaC = 4.0

  /// Slides for the peek: current conditions, then up to three upcoming changes, then, in the
  /// evening, tomorrow's outlook. When nothing is changing the result is just the current slide,
  /// and the orchestrator uses that to end the peek quickly.
  static func slides(
    current: WeatherSnapshot?,
    hourly: [HourlyForecastPoint],
    events: [WeatherEvent],
    now: Date,
    timeZone: TimeZone
  ) -> [WeatherPeekSlide] {
    guard let current else { return [] }
    var slides: [WeatherPeekSlide] = [.current(current)]

    let upcoming = events
      .filter { $0.startTime > now }
      .sorted { $0.startTime < $1.startTime }
      .prefix(maxEvents)
    slides.append(contentsOf: upcoming.map(WeatherPeekSlide.event))

    if isEvening(now, timeZone: timeZone),
      let outlook = tomorrowOutlook(current: current, hourly: hourly, now: now, timeZone: timeZone)
    {
      slides.append(.tomorrow(outlook))
    }
    return slides
  }

  static func isEvening(_ now: Date, timeZone: TimeZone) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.component(.hour, from: now) >= eveningHour
  }

  /// Tomorrow's daytime (7am to 9pm local) high, low, dominant condition, and what to prepare for.
  static func tomorrowOutlook(
    current: WeatherSnapshot,
    hourly: [HourlyForecastPoint],
    now: Date,
    timeZone: TimeZone
  ) -> WeatherTomorrowOutlook? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    else { return nil }

    let daytime = hourly.filter { point in
      calendar.isDate(point.date, inSameDayAs: tomorrow)
        && (7...21).contains(calendar.component(.hour, from: point.date))
    }
    // Need most of the day to say anything useful.
    guard daytime.count >= 6 else { return nil }

    let highC = daytime.map(\.temperatureC).max() ?? current.temperatureC
    let lowC = daytime.map(\.temperatureC).min() ?? current.temperatureC
    let bucket = dominantBucket(daytime.map(\.bucket))

    let todayHighC = max(
      current.temperatureC,
      hourly.filter { calendar.isDate($0.date, inSameDayAs: now) }.map(\.temperatureC).max()
        ?? current.temperatureC)

    let hint: WeatherTomorrowOutlook.Hint
    switch bucket {
    case .thunder: hint = .storm
    case .snow: hint = .snow
    case .rain: hint = .rain
    default:
      if highC - todayHighC <= -notableDeltaC {
        hint = .cooler
      } else if highC - todayHighC >= notableDeltaC {
        hint = .warmer
      } else {
        hint = .none
      }
    }
    return WeatherTomorrowOutlook(highC: highC, lowC: lowC, bucket: bucket, hint: hint)
  }

  /// Severe weather wins if it shows up for at least two hours; otherwise the most common bucket.
  private static func dominantBucket(_ buckets: [WeatherConditionBucket]) -> WeatherConditionBucket {
    let severe: [WeatherConditionBucket] = [.thunder, .snow, .rain, .fog]
    for candidate in severe where buckets.filter({ $0 == candidate }).count >= 2 {
      return candidate
    }
    var counts: [WeatherConditionBucket: Int] = [:]
    for bucket in buckets where bucket != .unknown { counts[bucket, default: 0] += 1 }
    return counts.max { $0.value < $1.value }?.key ?? .unknown
  }
}
