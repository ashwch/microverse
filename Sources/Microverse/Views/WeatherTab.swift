import SwiftUI

struct WeatherTab: View {
    @EnvironmentObject private var settings: WeatherSettingsStore
    @EnvironmentObject private var weather: WeatherStore
    @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let weatherKitAttributionURL = URL(string: "https://developer.apple.com/weatherkit/data-source-attribution/")
    private static let openMeteoTermsURL = URL(string: "https://open-meteo.com/en/terms")

    var body: some View {
        VStack(spacing: 8) {
            if !settings.weatherEnabled {
                disabledCard
            } else if settings.weatherLocation == nil {
                missingLocationCard
            } else {
                currentCard
                nextChangeCard
                hourlyCard
                attributionCard
            }
        }
        .padding(8)
        .onAppear {
            weather.triggerRefresh(reason: "weather-tab")
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

            Text("Set a manual location in Settings → Weather.")
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(12)
        .background(MicroverseDesign.cardBackground())
    }

    private var currentCard: some View {
        VStack(spacing: 8) {
            HStack {
                SectionHeader("WEATHER NOW", systemIcon: "location")
                Spacer()

                Button(action: { weather.triggerRefresh(reason: "manual-refresh") }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh")
            }

            HStack(alignment: .center, spacing: 12) {
                MicroverseWeatherGlyph(
                    bucket: weather.current?.bucket ?? .unknown,
                    isDaylight: weather.current?.isDaylight ?? true,
                    renderMode: weatherAnimationBudget.renderMode(for: .popoverWeatherTab, isVisible: true, reduceMotion: reduceMotion)
                )
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.weatherLocation?.displayName ?? "—")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

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

                                Image(systemName: h.bucket.symbolName(isDaylight: h.isDaylight ?? isDaylight(at: h.date)))
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
        f.timeZone = settings.weatherLocation?.timeZone ?? .current
        f.setLocalizedDateFormatFromTemplate("j")
        return f.string(from: date).lowercased().replacingOccurrences(of: " ", with: "")
    }

    private func isDaylight(at date: Date) -> Bool {
        var cal = Calendar.current
        cal.timeZone = settings.weatherLocation?.timeZone ?? .current
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
