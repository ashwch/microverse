import SwiftUI

/// Popover “Alerts” tab.
///
/// This is the **quick-glance** surface: it summarizes alert rules and exposes a few high-signal toggles.
/// Deeper configuration lives in Settings → Alerts (`NotchAlertsSection` and `WeatherAlertsSection`).
struct AlertsTab: View {
  var openSettings: (() -> Void)? = nil

  @EnvironmentObject private var viewModel: BatteryViewModel
  @EnvironmentObject private var settings: WeatherSettingsStore
  @EnvironmentObject private var weather: WeatherStore

  var body: some View {
    VStack(spacing: 8) {
      notchGlowCard
      weatherAlertsCard
    }
    .padding(8)
  }

  private var notchGlowCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Notch Glow Alerts")
            .font(MicroverseDesign.Typography.body)
            .foregroundColor(.white)

          Text("Subtle glow cues for battery and weather changes")
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Toggle("", isOn: $viewModel.enableNotchAlerts)
          .labelsHidden()
          .toggleStyle(ElegantToggleStyle())
          .disabled(!viewModel.isNotchAvailable)
      }

      if !viewModel.isNotchAvailable {
        hintRow(icon: "macbook", text: "Requires a Mac with a notch.")
      } else if viewModel.enableNotchAlerts {
        VStack(alignment: .leading, spacing: 6) {
          alertTagGroup("Battery", tags: notchBatteryRuleTags)

          alertTagGroup("Devices", tags: notchDeviceRuleTags)

          alertKeyValueRow(
            title: "Startup",
            value: viewModel.enableNotchStartupAnimation ? "On" : "Off",
            valueTint: viewModel.enableNotchStartupAnimation
              ? MicroverseDesign.Colors.success.opacity(0.85) : .white.opacity(0.6)
          )
        }
      } else {
        Text("Off")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.55))
      }

      if let openSettings {
        Button {
          openSettings()
        } label: {
          HStack(spacing: 8) {
            Text("Configure")
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.white.opacity(0.55))
          }
        }
        .buttonStyle(FlatButtonStyle())
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var weatherAlertsCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Weather Alerts")
            .font(MicroverseDesign.Typography.body)
            .foregroundColor(.white)

          Text("Notch glow for upcoming changes")
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Toggle("", isOn: $settings.weatherAlertsEnabled)
          .labelsHidden()
          .toggleStyle(ElegantToggleStyle())
      }

      if settings.weatherAlertsEnabled {
        if !viewModel.isNotchAvailable {
          hintRow(icon: "macbook", text: "Requires a Mac with a notch.")
        } else if !viewModel.enableNotchAlerts {
          hintRow(icon: "bell.slash", text: "Enable Notch Glow Alerts to use weather alerts.")
        } else if !settings.weatherEnabled {
          hintRow(icon: "cloud.sun", text: "Enable Weather first.")
        } else if settings.selectedLocation == nil {
          hintRow(icon: "mappin.and.ellipse", text: "Add a location in Settings → Weather.")
        } else {
          VStack(alignment: .leading, spacing: 6) {
            alertTagGroup("Rules", tags: weatherRuleTags)
            alertTagGroup("Timing", tags: weatherTimingTags)

            alertKeyValueRow(
              title: "Next",
              value: nextWeatherEventValue,
              valueTint: .white.opacity(0.75)
            )
          }
        }
      } else {
        Text("Off")
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.55))
      }

      if let openSettings {
        Button {
          openSettings()
        } label: {
          HStack(spacing: 8) {
            Text("Configure")
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.white.opacity(0.55))
          }
        }
        .buttonStyle(FlatButtonStyle())
      }
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }

  private var notchBatteryRuleTags: [MicroverseAlertTag] {
    var tags: [MicroverseAlertTag] = []

    if viewModel.notchAlertChargerConnected {
      tags.append(.init(text: "Charger", dot: MicroverseDesign.Colors.success))
    }
    if viewModel.notchAlertFullyCharged {
      tags.append(.init(text: "Full", dot: MicroverseDesign.Colors.success))
    }
    if viewModel.notchAlertLowBatteryEnabled {
      tags.append(
        .init(
          text: "Low ≤\(viewModel.notchAlertLowBatteryThreshold)%",
          dot: MicroverseDesign.Colors.warning))
    }
    if viewModel.notchAlertCriticalBatteryEnabled {
      tags.append(
        .init(
          text: "Crit ≤\(viewModel.notchAlertCriticalBatteryThreshold)%",
          dot: MicroverseDesign.Colors.critical))
    }

    return tags.isEmpty ? [.init(text: "Off", style: .secondary)] : tags
  }

  private var notchDeviceRuleTags: [MicroverseAlertTag] {
    var tags: [MicroverseAlertTag] = []

    if viewModel.notchAlertAirPodsLowBatteryEnabled {
      tags.append(
        .init(
          text: "AirPods ≤\(viewModel.notchAlertAirPodsLowBatteryThreshold)%",
          dot: MicroverseDesign.Colors.critical))
      if let percent = viewModel.airPodsBatteryPercent {
        let isLow = percent <= viewModel.notchAlertAirPodsLowBatteryThreshold
        tags.append(
          .init(
            text: "Now \(percent)%",
            dot: isLow ? MicroverseDesign.Colors.critical : MicroverseDesign.Colors.success))
      }
    }

    return tags.isEmpty ? [.init(text: "Off", style: .secondary)] : tags
  }

  private var weatherRuleTags: [MicroverseAlertTag] {
    var tags: [MicroverseAlertTag] = []
    if settings.weatherAlertPrecipitation {
      tags.append(.init(text: "Rain", dot: MicroverseDesign.Colors.neutral))
    }
    if settings.weatherAlertStorm {
      tags.append(.init(text: "Storm", dot: MicroverseDesign.Colors.warning))
    }
    if settings.weatherAlertTempChange {
      tags.append(.init(text: "Temp", dot: MicroverseDesign.Colors.accent))
    }
    return tags.isEmpty ? [.init(text: "Off", style: .secondary)] : tags
  }

  private var weatherTimingTags: [MicroverseAlertTag] {
    [
      .init(text: "Lead \(formatTiming(settings.weatherAlertLeadTime))", style: .secondary),
      .init(text: "Cooldown \(formatTiming(settings.weatherAlertCooldown))", style: .secondary),
    ]
  }

  private var nextWeatherEventValue: String {
    guard let e = weather.nextEvent else { return "Steady" }
    return "\(e.title) \(relativeTime(to: e.startTime))"
  }

  private func formatTiming(_ interval: TimeInterval) -> String {
    let seconds = Int(interval.rounded())
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    return "\(hours)h"
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

  private func alertTagGroup(_ title: String, tags: [MicroverseAlertTag]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(MicroverseDesign.Typography.label)
        .foregroundColor(.white.opacity(0.5))
        .tracking(0.8)

      MicroverseTagFlow(spacing: 6, lineSpacing: 6) {
        ForEach(tags) { tag in
          MicroverseTagPill(tag: tag)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(tags.map(\.text).joined(separator: ", "))
  }

  private func alertKeyValueRow(title: String, value: String, valueTint: Color) -> some View {
    HStack(spacing: 8) {
      Text(title.uppercased())
        .font(MicroverseDesign.Typography.label)
        .foregroundColor(.white.opacity(0.5))
        .tracking(0.8)

      Spacer(minLength: 0)

      Text(value)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(valueTint)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(value)
  }

  private func hintRow(icon: String, text: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.55))

      Text(text)
        .font(MicroverseDesign.Typography.caption)
        .foregroundColor(.white.opacity(0.6))
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
    .padding(.top, 2)
  }
}

private struct MicroverseAlertTag: Identifiable, Hashable {
  enum Style {
    case normal
    case secondary
  }

  let id = UUID()
  let text: String
  var dot: Color? = nil
  var style: Style = .normal
}

private struct MicroverseTagPill: View {
  let tag: MicroverseAlertTag

  var body: some View {
    HStack(spacing: 6) {
      if let dot = tag.dot {
        Circle()
          .fill(dot.opacity(0.9))
          .frame(width: 6, height: 6)
      }

      Text(tag.text)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.white.opacity(tag.style == .secondary ? 0.55 : 0.85))
        .lineLimit(1)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(
      Capsule()
        .fill(Color.white.opacity(tag.style == .secondary ? 0.04 : 0.06))
        .overlay(
          Capsule()
            .stroke(Color.white.opacity(tag.style == .secondary ? 0.08 : 0.12), lineWidth: 1)
        )
    )
    .fixedSize(horizontal: true, vertical: true)
  }
}

private struct MicroverseTagFlow<Content: View>: View {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 6
  @ViewBuilder var content: () -> Content

  var body: some View {
    MicroverseFlowLayout(spacing: spacing, lineSpacing: lineSpacing) {
      content()
    }
  }
}

private struct MicroverseFlowLayout: Layout {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 6

  init(spacing: CGFloat = 6, lineSpacing: CGFloat = 6) {
    self.spacing = spacing
    self.lineSpacing = lineSpacing
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var usedWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > maxWidth {
        usedWidth = max(usedWidth, x)
        x = 0
        y += rowHeight + lineSpacing
        rowHeight = 0
      }

      x += (x > 0 ? spacing : 0) + size.width
      rowHeight = max(rowHeight, size.height)
    }

    usedWidth = max(usedWidth, x)
    let totalHeight = y + rowHeight
    return CGSize(width: min(maxWidth, usedWidth), height: totalHeight)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let maxWidth = bounds.width
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      if x > bounds.minX, x + size.width > bounds.minX + maxWidth {
        x = bounds.minX
        y += rowHeight + lineSpacing
        rowHeight = 0
      }

      subview.place(
        at: CGPoint(x: x, y: y),
        anchor: .topLeading,
        proposal: ProposedViewSize(width: size.width, height: size.height)
      )

      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
