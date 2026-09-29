import SwiftUI

/// Cycles through the weather peek slides: current conditions, upcoming changes, and, in the
/// evening, tomorrow's outlook. Every slide is laid out up front (invisible when inactive) so the
/// container's width is the widest slide from the first frame and nothing shifts while cycling.
struct WeatherPeekView: View {
  let slides: [WeatherPeekSlide]
  let units: WeatherUnits
  let isDaylight: Bool
  let renderMode: WeatherRenderMode
  /// Larger surfaces (the desktop widget) get the longer labels.
  var compact = true

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
      HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
        MicroverseWeatherGlyph(bucket: snapshot.bucket, isDaylight: isDaylight, renderMode: renderMode)
          .font(iconFont)
          .foregroundColor(.white.opacity(0.85))
          .symbolRenderingMode(.hierarchical)
          .frame(width: iconWidth, alignment: .center)

        Text(units.formatTemperatureShort(celsius: snapshot.temperatureC))
          .font(valueFont)
          .foregroundColor(MicroverseDesign.Colors.accent)
          .monospacedDigit()
      }

    case .event(let event):
      let tint = WidgetModuleStatusResolver.status(for: event).color
      HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
        Image(systemName: MicroverseWeatherAnnouncement.symbolName(for: event, isDaylight: isDaylight))
          .font(iconFont)
          .foregroundColor(tint)
          .symbolRenderingMode(.hierarchical)
          .frame(width: iconWidth, alignment: .center)

        Text(compact ? Self.shortTitle(for: event) : event.title)
          .font(valueFont)
          .foregroundColor(MicroverseDesign.Colors.accent)
          .lineLimit(1)

        TimelineView(.periodic(from: .now, by: 60)) { clock in
          Text(MicroverseWeatherAnnouncement.relativeTimeShort(from: clock.date, to: event.startTime))
            .font(detailFont)
            .foregroundColor(.white.opacity(0.55))
            .monospacedDigit()
        }
      }

    case .tomorrow(let outlook):
      HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
        Image(systemName: outlook.bucket.symbolName(isDaylight: true))
          .font(iconFont)
          .foregroundColor(.white.opacity(0.85))
          .symbolRenderingMode(.hierarchical)
          .frame(width: iconWidth, alignment: .center)

        Text(
          "\(units.formatTemperatureShort(celsius: outlook.highC))/\(units.formatTemperatureShort(celsius: outlook.lowC))"
        )
        .font(valueFont)
        .foregroundColor(MicroverseDesign.Colors.accent)
        .monospacedDigit()
        .lineLimit(1)

        Text(compact ? outlook.shortTitle : outlook.title)
          .font(detailFont)
          .foregroundColor(.white.opacity(0.55))
          .lineLimit(1)
      }
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
    compact
      ? MicroverseDesign.Notch.Typography.compactValue
      : .system(size: 18, weight: .bold, design: .rounded)
  }

  private var detailFont: Font {
    compact ? MicroverseDesign.Notch.Typography.statusText : .system(size: 10, weight: .medium)
  }
}
