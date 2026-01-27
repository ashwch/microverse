import AppKit
import CoreLocation
import SwiftUI

struct WeatherTab: View {
  var openSettings: (() -> Void)? = nil

  @EnvironmentObject private var settings: WeatherSettingsStore
  @EnvironmentObject private var weather: WeatherStore
  @EnvironmentObject private var weatherLocationsStore: WeatherLocationsStore
  @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private static let weatherKitAttributionURL = URL(
    string: "https://developer.apple.com/weatherkit/data-source-attribution/")
  private static let openMeteoTermsURL = URL(string: "https://open-meteo.com/en/terms")

  var body: some View {
    VStack(spacing: 8) {
      if !settings.weatherEnabled {
        disabledCard
      } else if settings.weatherUseCurrentLocation, settings.selectedLocation == nil {
        currentLocationSetupCard
      } else if settings.selectedLocation == nil {
        missingLocationCard
      } else {
        if shouldShowLocationsCard {
          locationsCard
        }
        currentCard
        if shouldPrioritizeHourlyForecast {
          hourlyCard
          nextChangeCard
        } else {
          nextChangeCard
          hourlyCard
        }
        attributionCard
      }
    }
    .padding(8)
    .onAppear {
      if settings.weatherUseCurrentLocation {
        settings.requestCurrentLocationUpdate()
      }
      weather.triggerRefresh(reason: "weather-tab")
      weatherLocationsStore.triggerRefresh(reason: "weather-tab")
    }
    .onChange(of: settings.weatherLocations.map(\.id)) { _ in
      weatherLocationsStore.triggerRefresh(reason: "weather-locations-changed")
    }
  }

  private var disabledCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader("WEATHER", systemIcon: "cloud.sun")

      Text("Weather is off.")
        .font(MicroverseDesign.Typography.title)
        .foregroundColor(.white)

      Text("Enable Weather in Settings to see the current temperature and upcoming changes.")
        .font(MicroverseDesign.Typography.caption)
        .foregroundColor(.white.opacity(0.6))
        .fixedSize(horizontal: false, vertical: true)

      if let openSettings {
        Button("Open Settings") {
          openSettings()
        }
        .buttonStyle(FlatButtonStyle())
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var missingLocationCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader("WEATHER", systemIcon: "cloud.sun")

      Text("No location set.")
        .font(MicroverseDesign.Typography.title)
        .foregroundColor(.white)

      Text("Set a manual location in Settings → Weather, or enable Current location.")
        .font(MicroverseDesign.Typography.caption)
        .foregroundColor(.white.opacity(0.6))

      if let openSettings {
        Button("Add Location") {
          openSettings()
        }
        .buttonStyle(FlatButtonStyle())
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var currentLocationSetupCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader("WEATHER", systemIcon: "location")

      Text("Current location isn’t available yet.")
        .font(MicroverseDesign.Typography.title)
        .foregroundColor(.white)

      if !CLLocationManager.locationServicesEnabled() {
        Text("Turn on Location Services in System Settings to use local weather.")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.6))
          .fixedSize(horizontal: false, vertical: true)

        Button("Open System Settings") {
          openLocationSystemSettings()
        }
        .buttonStyle(FlatButtonStyle())
      } else {
        switch settings.weatherCurrentLocationAuthorizationStatus {
        case .notDetermined:
          Text("Allow Microverse to use your location for local weather.")
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)

          Button("Allow Location") {
            settings.requestCurrentLocationAuthorization()
          }
          .buttonStyle(FlatButtonStyle())
        case .restricted, .denied:
          Text("Location access is disabled for Microverse.")
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.6))

          Button("Open System Settings") {
            openLocationSystemSettings()
          }
          .buttonStyle(FlatButtonStyle())
        case .authorizedAlways, .authorized:
          HStack(spacing: 8) {
            ProgressView()
              .controlSize(.small)
              .tint(.white.opacity(0.8))
            Text("Finding your location…")
              .font(MicroverseDesign.Typography.caption)
              .foregroundColor(.white.opacity(0.6))
          }
        @unknown default:
          Text("Finding your location…")
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.6))
        }
      }

      if let message = settings.weatherCurrentLocationErrorMessage {
        Text(message)
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(MicroverseDesign.Colors.warning)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var currentCard: some View {
    VStack(spacing: 8) {
      WeatherCardHeaderRow(title: "WEATHER NOW", systemIcon: "location", help: "Refresh") {
        if settings.weatherUseCurrentLocation {
          settings.requestCurrentLocationUpdate()
        }
        weather.triggerRefresh(reason: "manual-refresh")
        weatherLocationsStore.triggerRefresh(reason: "manual-refresh")
      }

      HStack(alignment: .center, spacing: 12) {
        MicroverseWeatherGlyph(
          bucket: weather.current?.bucket ?? .unknown,
          isDaylight: weather.current?.isDaylight ?? true,
          renderMode: weatherAnimationBudget.renderMode(
            for: .popoverWeatherTab, isVisible: true, reduceMotion: reduceMotion)
        )
        .font(.system(size: 22, weight: .semibold))
        .foregroundColor(.white.opacity(0.9))
        .symbolRenderingMode(.hierarchical)
        .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 2) {
          Group {
            let displayName = settings.selectedLocation?.microverseDisplayName() ?? "—"

            Text(displayName)
              .lineLimit(1)
          }
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.7))

          HStack(spacing: 6) {
            Text(temperatureText)
              .font(.system(size: 26, weight: .bold, design: .rounded))
              .foregroundColor(.white)
              .monospacedDigit()

            if weather.fetchState == .loading {
              ProgressView()
                .controlSize(.small)
                .tint(.white.opacity(0.7))
            }
          }

          if let feelsLike = weather.current?.feelsLikeC {
            Text("Feels like \(settings.weatherUnits.formatTemperature(celsius: feelsLike))")
              .font(MicroverseDesign.Typography.caption)
              .foregroundColor(.white.opacity(0.6))
          }
        }

        Spacer()
      }

      HStack(spacing: 8) {
        fetchStatePill
        Spacer()
        if let updated = weather.lastUpdated {
          TimelineView(.periodic(from: .now, by: 60)) { tl in
            Text("Updated \(relativeTime(from: tl.date, to: updated))")
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.white.opacity(0.5))
          }
        }
      }

      switch weather.fetchState {
      case .failed(let message):
        Text(message)
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(MicroverseDesign.Colors.warning)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      case .stale:
        Text("Using cached weather (offline or temporarily unavailable).")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.55))
      default:
        EmptyView()
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var locationsCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      WeatherCardHeaderRow(title: "LOCATIONS", systemIcon: "map", help: "Refresh all locations") {
        weatherLocationsStore.triggerRefresh(reason: "locations-refresh")
      }

      let manualSummaries = weatherLocationsStore.summaries

      let currentSummary: WeatherLocationSummary? = {
        guard settings.weatherUseCurrentLocation,
          let currentLocation = settings.weatherCurrentLocation
        else { return nil }

        return WeatherLocationSummary(
          location: currentLocation,
          current: weather.current,
          fetchState: weather.fetchState,
          lastUpdated: weather.lastUpdated,
          lastProvider: weather.lastProvider
        )
      }()

      let summaries: [WeatherLocationSummary] = {
        var all: [WeatherLocationSummary] = []
        if let currentSummary {
          all.append(currentSummary)
        }
        all.append(contentsOf: manualSummaries.filter { $0.id != currentSummary?.id })
        return all
      }()

      VStack(spacing: 0) {
        ForEach(Array(summaries.enumerated()), id: \.offset) { idx, summary in
          locationRow(summary, isCurrentLocation: summary.id == currentSummary?.id)

          if idx < summaries.count - 1 {
            Rectangle()
              .fill(Color.white.opacity(0.08))
              .frame(height: 1)
          }
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.white.opacity(0.03))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.white.opacity(0.10), lineWidth: 1)
          )
      )
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private func locationRow(_ summary: WeatherLocationSummary, isCurrentLocation: Bool) -> some View {
    let isSelected: Bool = {
      if isCurrentLocation { return settings.weatherUseCurrentLocation }
      return !settings.weatherUseCurrentLocation && summary.id == settings.weatherSelectedLocationID
    }()
    let location = summary.location

    let snapshot: WeatherSnapshot? = {
      if summary.id == settings.selectedLocation?.id {
        return weather.current ?? summary.current
      }
      return summary.current
    }()

    let tempText: String = {
      guard let c = snapshot?.temperatureC else { return "—°" }
      return settings.weatherUnits.formatTemperatureShort(celsius: c)
    }()

    let bucket = snapshot?.bucket ?? .unknown
    let isDaylight = snapshot?.isDaylight ?? true

    let primary = location.microversePrimaryName()
    let secondary = location.microverseSecondaryName()

    return Button {
      if isCurrentLocation {
        settings.weatherUseCurrentLocation = true
        settings.requestCurrentLocationUpdate()
        weather.triggerRefresh(reason: "select-current-location")
      } else {
        settings.selectLocation(id: summary.id)
        weather.triggerRefresh(reason: "select-location")
      }
    } label: {
      HStack(spacing: 10) {
        MicroverseWeatherGlyph(
          bucket: bucket,
          isDaylight: isDaylight,
          renderMode: weatherAnimationBudget.renderMode(
            for: .popoverWeatherTab, isVisible: true, reduceMotion: reduceMotion)
        )
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white.opacity(0.85))
        .symbolRenderingMode(.hierarchical)
        .frame(width: 18, height: 18)

        VStack(alignment: .leading, spacing: 1) {
          Text(primary)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.85))
            .lineLimit(1)

          if let secondary {
            Text(secondary)
              .font(.system(size: 10, weight: .regular))
              .foregroundColor(.white.opacity(0.5))
              .lineLimit(1)
          }
        }

        Spacer()

        if summary.fetchState == .loading {
          ProgressView()
            .controlSize(.small)
            .tint(.white.opacity(0.6))
        } else {
          Text(tempText)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .monospacedDigit()
        }

        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white.opacity(0.8))
        }
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 10)
      .contentShape(Rectangle())
      .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
    }
    .buttonStyle(PlainButtonStyle())
  }

  private var shouldShowLocationsCard: Bool {
    !settings.weatherLocations.isEmpty
      && (settings.weatherLocations.count > 1 || settings.weatherUseCurrentLocation)
  }

  private func openLocationSystemSettings() {
    // Best-effort deep link; falls back to opening System Settings if the URL isn't supported.
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
    {
      NSWorkspace.shared.open(url)
      return
    }
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
      NSWorkspace.shared.open(url)
    }
  }

  private var nextChangeCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader("UP NEXT", systemIcon: "clock")

      if let e = weather.nextEvent {
        HStack(spacing: 8) {
          Text(e.title)
            .font(MicroverseDesign.Typography.body)
            .foregroundColor(.white)

          Spacer()

          TimelineView(.periodic(from: .now, by: 60)) { tl in
            Text(relativeTime(from: tl.date, to: e.startTime))
              .font(MicroverseDesign.Typography.body)
              .foregroundColor(.white.opacity(0.8))
              .monospacedDigit()
          }
        }
      } else {
        Text("No significant changes in the next few hours.")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.6))
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var shouldPrioritizeHourlyForecast: Bool {
    weather.nextEvent == nil
  }

  private var hourlyCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader("HOURLY", systemIcon: "chart.line.uptrend.xyaxis")

      if weather.hourly.isEmpty {
        Text("No forecast yet.")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.6))
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(Array(weather.hourly.prefix(12).enumerated()), id: \.offset) { _, h in
              VStack(spacing: 4) {
                Text(hourLabel(for: h.date))
                  .font(.system(size: 9, weight: .medium))
                  .foregroundColor(.white.opacity(0.6))

                Image(
                  systemName: h.bucket.symbolName(
                    isDaylight: h.isDaylight ?? isDaylight(at: h.date))
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .symbolRenderingMode(.hierarchical)

                Text(settings.weatherUnits.formatTemperature(celsius: h.temperatureC))
                  .font(.system(size: 10, weight: .semibold, design: .rounded))
                  .foregroundColor(.white)
                  .monospacedDigit()
              }
              .frame(width: 52)
              .padding(.vertical, 6)
              .background(Color.white.opacity(0.04))
              .clipShape(RoundedRectangle(cornerRadius: 10))
            }
          }
          .padding(.vertical, 2)
        }
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var attributionCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      SectionHeader("ATTRIBUTION", systemIcon: "checkmark.seal")

      switch weather.lastProvider ?? .weatherKit {
      case .weatherKit:
        Text("Weather data attribution is required when displaying WeatherKit data.")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.6))

        if let url = Self.weatherKitAttributionURL {
          Link("Weather data sources", destination: url)
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.85))
        }
      case .openMeteo:
        Text("Weather data provided by Open‑Meteo (fallback when WeatherKit isn’t available).")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.6))

        if let url = Self.openMeteoTermsURL {
          Link("Open‑Meteo terms", destination: url)
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.85))
        }
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var fetchStatePill: some View {
    let text: String
    let color: Color

    switch weather.fetchState {
    case .idle:
      text = "Idle"
      color = .white.opacity(0.25)
    case .loading:
      text = "Updating"
      color = MicroverseDesign.Colors.neutral.opacity(0.6)
    case .loaded:
      text = "Live"
      color = MicroverseDesign.Colors.success.opacity(0.7)
    case .stale:
      text = "Stale"
      color = MicroverseDesign.Colors.warning.opacity(0.7)
    case .failed:
      text = "Error"
      color = MicroverseDesign.Colors.critical.opacity(0.7)
    }

    return Text(text.uppercased())
      .font(.system(size: 9, weight: .semibold))
      .foregroundColor(.white.opacity(0.85))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(color)
      )
  }

  private var temperatureText: String {
    guard let c = weather.current?.temperatureC else { return "—" }
    return settings.weatherUnits.formatTemperature(celsius: c)
  }

  private func hourLabel(for date: Date) -> String {
    let f = DateFormatter()
    f.locale = .current
    f.timeZone = settings.selectedLocation?.timeZone ?? .current
    f.setLocalizedDateFormatFromTemplate("j")
    return f.string(from: date).lowercased().replacingOccurrences(of: " ", with: "")
  }

  private func isDaylight(at date: Date) -> Bool {
    var cal = Calendar.current
    cal.timeZone = settings.selectedLocation?.timeZone ?? .current
    let hour = cal.component(.hour, from: date)
    return hour >= 6 && hour < 18
  }

  private func relativeTime(from now: Date, to target: Date) -> String {
    let delta = target.timeIntervalSince(now)
    if abs(delta) < 60 { return "now" }

    let minutes = Int((delta / 60).rounded())
    if minutes < 0 {
      return "\(-minutes)m ago"
    }
    if minutes < 60 {
      return "in \(minutes)m"
    }
    let hours = Int((Double(minutes) / 60.0).rounded(.down))
    return "in \(hours)h"
  }
}

private struct WeatherCardHeaderRow: View {
  let title: String
  let systemIcon: String
  let help: String
  let action: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: systemIcon)
          .font(.system(size: MicroverseDesign.Layout.iconSizeSmall, weight: .medium))
          .foregroundColor(MicroverseDesign.Colors.accentSubtle)

        Text(title.uppercased())
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(MicroverseDesign.Colors.accentSubtle)
          .tracking(1.2)
      }

      Spacer()

      Button(action: action) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.8))
          .frame(width: 18, height: 18)
      }
      .buttonStyle(PlainButtonStyle())
      .help(help)
      .padding(4)
      .background(
        RoundedRectangle(cornerRadius: 7)
          .fill(Color.white.opacity(0.06))
      )
      .contentShape(Rectangle())
    }
  }
}
