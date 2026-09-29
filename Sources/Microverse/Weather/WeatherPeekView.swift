import SwiftUI

/// Cycles through the weather peek slides: current conditions, upcoming changes, and, in the
/// evening, tomorrow's outlook. Every slide is laid out up front (invisible when inactive) so the
/// container's width is the widest slide from the first frame and nothing shifts while cycling.
struct WeatherPeekView: View {
  let slides: [WeatherPeekSlide]
  let units: WeatherUnits
  let isDaylight: Bool
  let renderMode: WeatherRenderMode
  enum Layout {
    /// Icon and text side by side (notch pill, roomy widget tiles).
    case row
    /// Icon above text (the System Glance column).
    case column
    /// Like `row`, but the outlook slide stacks the day over the range because a small tile
    /// cannot hold icon, day, and both temperatures on one line.
    case narrowRow
  }

  /// Larger surfaces (the desktop widget) get the longer labels.
  var compact = true
  var layout: Layout = .row

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var startedAt = Date()

  var body: some View {
    TimelineView(.periodic(from: startedAt, by: WeatherPeekPlanner.slideDuration)) { timeline in
      let index = activeIndex(at: timeline.date)

      // Centered so a short slide (a lone temperature) sits balanced inside the widest slide's width.
      ZStack {
        ForEach(Array(slides.enumerated()), id: \.element.id) { position, slide in
          slideView(slide)
            .opacity(position == index ? 1 : 0)
            .offset(y: reduceMotion || position == index ? 0 : (position < index ? -4 : 4))
            .accessibilityHidden(position != index)
        }
      }
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: index)
    }
    .onChange(of: slides.map(\.id)) { _ in startedAt = Date() }
  }

  private func activeIndex(at date: Date) -> Int {
    guard slides.count > 1 else { return 0 }
    let elapsed = max(0, date.timeIntervalSince(startedAt))
    return Int(elapsed / WeatherPeekPlanner.slideDuration) % slides.count
  }

  @ViewBuilder
  private func slideView(_ slide: WeatherPeekSlide) -> some View {
    switch slide {
    case .current(let snapshot):
      slideBody(
        icon: MicroverseWeatherGlyph(bucket: snapshot.bucket, isDaylight: isDaylight, renderMode: renderMode),
        tint: .white.opacity(0.85),
        primary: units.formatTemperatureShort(celsius: snapshot.temperatureC),
        detail: nil)

    case .event(let event):
      slideBody(
        icon: Image(systemName: MicroverseWeatherAnnouncement.symbolName(for: event, isDaylight: isDaylight)),
        tint: WidgetModuleStatusResolver.status(for: event).color,
        primary: compact ? Self.shortTitle(for: event) : event.title,
        detail: .relative(event.startTime))

    case .tomorrow(let outlook):
      // The coming day's high and low use the Weather app's own "H:19° L:9°" notation, which
      // is the one label users already read as a forecast rather than a current temperature.
      // Both temperatures always show, with a cue for which day: the weekday ("Tue"), "Today"
      // after midnight, or the hint when there is something to prepare for ("Cooler"). Roomy
      // surfaces get the full title ("Cooler tomorrow").
      let range = "H:" + units.formatTemperatureShort(celsius: outlook.highC)
        + " L:" + units.formatTemperatureShort(celsius: outlook.lowC)
      let cue = compact ? (outlook.hint == .none ? outlook.dayLabel : outlook.shortTitle) : outlook.title
      let icon = Image(systemName: outlook.bucket.symbolName(isDaylight: true))
      if layout == .narrowRow {
        // Two short lines fit where one long line would truncate. The icon sits on the range
        // line, not floating between the two lines.
        HStack(alignment: .bottom, spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
          icon
            .font(iconFont)
            .foregroundColor(.white.opacity(0.85))
            .symbolRenderingMode(.hierarchical)
            .frame(width: iconWidth, height: 13, alignment: .center)

          VStack(alignment: .leading, spacing: 0) {
            Text(cue)
              .font(.system(size: 8, weight: .semibold))
              .foregroundColor(.white.opacity(0.6))
              .lineLimit(1)
            Text(range)
              .font(.system(size: 10, weight: .bold, design: .rounded))
              .foregroundColor(MicroverseDesign.Colors.accent)
              .monospacedDigit()
              .lineLimit(1)
              .fixedSize(horizontal: true, vertical: false)
          }
        }
      } else {
        slideBody(icon: icon, tint: .white.opacity(0.85), primary: range, detail: .text(cue))
      }
    }
  }

  private enum Detail {
    case text(String)
    case relative(Date)
  }

  @ViewBuilder
  private func slideBody<Icon: View>(icon: Icon, tint: Color, primary: String, detail: Detail?) -> some View {
    let iconView = icon
      .font(iconFont)
      .foregroundColor(tint)
      .symbolRenderingMode(.hierarchical)
      .frame(width: iconWidth, height: layout == .column ? 18 : nil, alignment: .center)

    let primaryView = Text(primary)
      .font(valueFont)
      .foregroundColor(MicroverseDesign.Colors.accent)
      .monospacedDigit()
      .lineLimit(1)

    switch layout {
    case .row, .narrowRow:
      HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
        iconView
        primaryView
        detailView(detail)
      }
      // Safety valve for the narrowest tiles: both labels shrink together rather than truncate.
      .minimumScaleFactor(0.75)
      .fixedSize(horizontal: false, vertical: true)
    case .column:
      // The column has no room for a second line, so the detail replaces the primary text on
      // event slides (the lead time matters more than repeating the word) and is dropped otherwise.
      VStack(spacing: 1) {
        iconView
        primaryView
        if case .relative(let date) = detail {
          detailView(.relative(date))
        } else {
          Text(" ").font(detailFont)
        }
      }
    }
  }

  @ViewBuilder
  private func detailView(_ detail: Detail?) -> some View {
    switch detail {
    case .text(let text):
      Text(text)
        .font(detailFont)
        .foregroundColor(.white.opacity(0.55))
        .lineLimit(1)
    case .relative(let date):
      TimelineView(.periodic(from: .now, by: 60)) { clock in
        Text(MicroverseWeatherAnnouncement.relativeTimeShort(from: clock.date, to: date))
          .font(detailFont)
          .foregroundColor(.white.opacity(0.55))
          .monospacedDigit()
      }
    case nil:
      EmptyView()
    }
  }

  /// One or two words for the pill; the full title is for surfaces with room.
  static func shortTitle(for event: WeatherEvent) -> String {
    switch event.kind {
    case .precipStart: return event.toBucket == .snow ? "Snow" : "Rain"
    case .precipStop: return "Clearing"
    case .conditionShift:
      switch event.toBucket {
      case .thunder: return "Storm"
      case .fog: return "Fog"
      case .wind: return "Wind"
      case .snow: return "Snow"
      case .rain: return "Rain"
      default: return "Change"
      }
    case .tempDrop: return "Cooler"
    case .tempRise: return "Warmer"
    }
  }

  private var iconFont: Font {
    compact ? MicroverseDesign.Notch.Typography.compactIcon : .system(size: 16, weight: .semibold)
  }

  private var iconWidth: CGFloat {
    compact ? MicroverseDesign.Layout.iconSizeSmall + 2 : 20
  }

  private var valueFont: Font {
    if layout == .column { return .system(size: 13, weight: .bold, design: .rounded) }
    return compact
      ? MicroverseDesign.Notch.Typography.compactValue
      : .system(size: 18, weight: .bold, design: .rounded)
  }

  private var detailFont: Font {
    compact ? MicroverseDesign.Notch.Typography.statusText : .system(size: 10, weight: .medium)
  }
}
