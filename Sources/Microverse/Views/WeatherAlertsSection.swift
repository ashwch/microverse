import SwiftUI

/// Settings surface for Weather → Notch Glow alerts.
///
/// This is intentionally “rules + timing” only:
/// - the glow rendering is handled by `NotchGlowManager`
/// - the scheduling/triggering is handled by `WeatherAlertEngine`
///
/// We keep this UI conservative (lead time + cooldown) to avoid alert spam.
struct WeatherAlertsSection: View {
    enum Style {
        case settings
        case card
    }

    var style: Style = .settings

    @EnvironmentObject private var viewModel: BatteryViewModel
    @EnvironmentObject private var settings: WeatherSettingsStore
    @EnvironmentObject private var weather: WeatherStore
    @State private var isShowingRules = false
    @State private var isShowingTiming = false

    var body: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space3) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather Alerts")
                        .font(MicroverseDesign.Typography.body)
                        .foregroundColor(.white)
                    Text("Notch glow for upcoming weather changes")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $settings.weatherAlertsEnabled)
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
            }

            if settings.weatherAlertsEnabled {
                if !viewModel.isNotchAvailable {
                    prerequisiteMessage(icon: "macbook", text: "Weather alerts require a notched Mac for glow alerts.")
                } else if !viewModel.enableNotchAlerts {
                    prerequisiteMessage(icon: "bell.slash", text: "Enable Notch Glow Alerts to use weather alerts.")
                } else if !settings.weatherEnabled {
                    prerequisiteMessage(icon: "cloud.sun", text: "Enable Weather to receive weather alerts.")
                } else if settings.selectedLocation == nil {
                    prerequisiteMessage(icon: "mappin.and.ellipse", text: "Add a location to receive weather alerts.")
                } else {
                    rulesDisclosure
                    timingDisclosure
                    nextEventHint
                }
            }
        }
        .padding(.horizontal, style == .settings ? MicroverseDesign.Layout.space5 : 12)
        .padding(.vertical, style == .settings ? MicroverseDesign.Layout.space4 : 12)
        .background {
            if style == .card {
                MicroverseDesign.cardBackground()
            }
        }
    }

    private var rulesDisclosure: some View {
        DisclosureGroup(isExpanded: $isShowingRules) {
            VStack(spacing: 6) {
                ruleToggleRow(
                    icon: "cloud.rain",
                    iconColor: MicroverseDesign.Colors.warning,
                    title: "Precipitation soon",
                    subtitle: "Rain or snow starting",
                    isOn: $settings.weatherAlertPrecipitation
                )
                ruleToggleRow(
                    icon: "cloud.bolt",
                    iconColor: MicroverseDesign.Colors.critical,
                    title: "Storm possible",
                    subtitle: "Thunder in forecast",
                    isOn: $settings.weatherAlertStorm
                )
                ruleToggleRow(
                    icon: "thermometer",
                    iconColor: MicroverseDesign.Colors.neutral,
                    title: "Temperature change",
                    subtitle: "Notifies on big swings",
                    isOn: $settings.weatherAlertTempChange
                )
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 16)

                Text("Rules")
                    .font(MicroverseDesign.Typography.body)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text(rulesSummaryText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .accentColor(.white.opacity(0.7))
        .padding(.top, 6)
    }

    private static let leadTimeOptions: [TimeInterval] = [
        0,
        10 * 60,
        20 * 60,
        30 * 60,
        60 * 60,
    ]

    private static let cooldownOptions: [TimeInterval] = [
        15 * 60,
        30 * 60,
        60 * 60,
        2 * 60 * 60,
    ]

    private var timingDisclosure: some View {
        DisclosureGroup(isExpanded: $isShowingTiming) {
            VStack(spacing: 8) {
                timingRow(title: "Lead time", selection: $settings.weatherAlertLeadTime, options: Self.leadTimeOptions)
                timingRow(title: "Cooldown", selection: $settings.weatherAlertCooldown, options: Self.cooldownOptions)
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 16)

                Text("Timing")
                    .font(MicroverseDesign.Typography.body)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text(timingSummaryText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .monospacedDigit()
            }
        }
        .accentColor(.white.opacity(0.7))
        .padding(.top, 6)
    }

    private var timingSummaryText: String {
        "Lead \(formatTiming(settings.weatherAlertLeadTime)) · Cooldown \(formatTiming(settings.weatherAlertCooldown))"
    }

    private var rulesSummaryText: String {
        var parts: [String] = []
        if settings.weatherAlertPrecipitation { parts.append("Rain") }
        if settings.weatherAlertStorm { parts.append("Storm") }
        if settings.weatherAlertTempChange { parts.append("Temp") }

        if parts.isEmpty { return "Off" }
        return parts.joined(separator: " · ")
    }

    private func timingRow(title: String, selection: Binding<TimeInterval>, options: [TimeInterval]) -> some View {
        HStack {
            Text(title)
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            timingStepper(title: title, selection: selection, options: options)
        }
    }

    private func timingStepper(title: String, selection: Binding<TimeInterval>, options: [TimeInterval]) -> some View {
        let idx = options.firstIndex(where: { abs($0 - selection.wrappedValue) < 0.5 }) ?? 0

        return HStack(spacing: 8) {
            Button {
                selection.wrappedValue = options[max(0, idx - 1)]
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(idx == 0 ? 0.25 : 0.75))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(idx == 0)
            .accessibilityLabel("Decrease \(title)")

            Text(formatTiming(options[idx]))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .monospacedDigit()
                .frame(minWidth: 42, alignment: .center)

            Button {
                selection.wrappedValue = options[min(options.count - 1, idx + 1)]
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(idx == options.count - 1 ? 0.25 : 0.75))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(idx == options.count - 1)
            .accessibilityLabel("Increase \(title)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityLabel(title)
        .accessibilityValue(formatTiming(options[idx]))
    }

    private func formatTiming(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }

    private var nextEventHint: some View {
        Group {
            if let e = weather.nextEvent {
                let summary = "\(e.title) \(relativeTime(to: e.startTime))"
                Text("Next: \(summary)")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            } else {
                Text("Next: steady")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(.top, MicroverseDesign.Layout.space1)
    }

    private func relativeTime(to target: Date) -> String {
        let now = Date()
        let delta = target.timeIntervalSince(now)
        if abs(delta) < 60 { return "now" }

        let minutes = Int((delta / 60).rounded())
        if minutes < 0 { return "\(-minutes)m ago" }
        if minutes < 60 { return "in \(minutes)m" }

        let hours = Int((Double(minutes) / 60.0).rounded(.down))
        return "in \(hours)h"
    }

    private func ruleToggleRow(icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(iconColor.opacity(0.9))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.85))
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(ElegantToggleStyle())
        }
        .padding(.vertical, 2)
    }

    private func prerequisiteMessage(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 16)

            Text(text)
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
}
