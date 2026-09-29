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

/// Summary of the coming daytime, shown from the evening through the small hours so the user can
/// plan for it the night before. Before midnight that day is "tomorrow"; after midnight it is
/// already "today".
struct WeatherTomorrowOutlook: Equatable {
  enum Hint: Equatable {
    case none, cooler, warmer, rain, snow, storm
  }

  var highC: Double
  var lowC: Double
  var bucket: WeatherConditionBucket
  var hint: Hint
  /// True once the clock has passed midnight and the day being described has begun.
  var isToday: Bool

  private var dayWord: String { isToday ? "today" : "tomorrow" }

  /// Short label for the compact pill.
  var shortTitle: String {
    switch hint {
    case .none: return dayWord.capitalized
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
    case .none: return dayWord.capitalized
    case .cooler: return "Cooler \(dayWord)"
    case .warmer: return "Warmer \(dayWord)"
    case .rain: return "Rain \(dayWord)"
    case .snow: return "Snow \(dayWord)"
    case .storm: return "Storms \(dayWord)"
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
  /// Local hour from which the coming day's outlook joins the cycle.
  static let eveningHour = 21
  /// Local hour until which the outlook keeps showing after midnight (the day has not really
  /// started yet, so it is still planning information).
  static let lateNightEndHour = 5
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

    if let outlook = tomorrowOutlook(current: current, hourly: hourly, now: now, timeZone: timeZone) {
      slides.append(.tomorrow(outlook))
    }
    return slides
  }

  /// The outlook runs from the evening until early morning. Before midnight it describes tomorrow;
  /// after midnight it describes the day that has just begun. Returns nil outside that window.
  static func outlookDay(for now: Date, timeZone: TimeZone) -> (day: Date, isToday: Bool)? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let hour = calendar.component(.hour, from: now)
    let today = calendar.startOfDay(for: now)
    if hour >= eveningHour {
      return calendar.date(byAdding: .day, value: 1, to: today).map { ($0, false) }
    }
    if hour < lateNightEndHour {
      return (today, true)
    }
    return nil
  }

  /// The coming daytime's (7am to 9pm local) high, low, dominant condition, and what to prepare for.
  static func tomorrowOutlook(
    current: WeatherSnapshot,
    hourly: [HourlyForecastPoint],
    now: Date,
    timeZone: TimeZone
  ) -> WeatherTomorrowOutlook? {
    guard let (day, isToday) = outlookDay(for: now, timeZone: timeZone) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    let daytime = hourly.filter { point in
      calendar.isDate(point.date, inSameDayAs: day)
        && (7...21).contains(calendar.component(.hour, from: point.date))
    }
    // Need most of the day to say anything useful.
    guard daytime.count >= 6 else { return nil }

    let highC = daytime.map(\.temperatureC).max() ?? current.temperatureC
    let lowC = daytime.map(\.temperatureC).min() ?? current.temperatureC
    let bucket = dominantBucket(daytime.map(\.bucket))

    // Compare against the day the user just lived through: today's high before midnight, or, after
    // midnight, yesterday's (the current temperature stands in when no hourly points remain).
    let referenceDay = isToday ? calendar.date(byAdding: .day, value: -1, to: day) ?? now : now
    let referenceHighC = max(
      current.temperatureC,
      hourly.filter { calendar.isDate($0.date, inSameDayAs: referenceDay) }.map(\.temperatureC).max()
        ?? current.temperatureC)

    let hint: WeatherTomorrowOutlook.Hint
    switch bucket {
    case .thunder: hint = .storm
    case .snow: hint = .snow
    case .rain: hint = .rain
    default:
      if highC - referenceHighC <= -notableDeltaC {
        hint = .cooler
      } else if highC - referenceHighC >= notableDeltaC {
        hint = .warmer
      } else {
        hint = .none
      }
    }
    return WeatherTomorrowOutlook(highC: highC, lowC: lowC, bucket: bucket, hint: hint, isToday: isToday)
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
