import SwiftUI

/// Fills the middle of the compact notch pill on screens without a physical notch.
///
/// DynamicNotchKit reserves a notch-sized gap even on external displays. With a real notch that gap
/// is the camera housing; here it would just be empty, so this view shows Wi‑Fi, output volume, and
/// weather there using the same status colors as every other surface.
struct MicroverseCompactCenterView: View {
  @EnvironmentObject private var viewModel: BatteryViewModel
  @EnvironmentObject private var wifi: WiFiStore
  @EnvironmentObject private var audio: AudioDevicesStore
  @EnvironmentObject private var weatherSettings: WeatherSettingsStore
  @EnvironmentObject private var weatherStore: WeatherStore
  @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var systemService = SystemMonitoringService.shared

  var body: some View {
    HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
      if wifi.status != .unavailable {
        NotchCompactMetric(
          icon: wifiIcon,
          value: wifi.signalPercent ?? 0,
          suffix: "%",
          color: viewModel.status.color(for: .wifi)
        )
        NotchSeparatorDot()
      }

      NotchCompactMetric(
        icon: audio.outputSymbolName,
        value: Int(((audio.outputVolume ?? 0) * 100).rounded()),
        suffix: "%",
        color: viewModel.status.color(for: .audioOutput)
      )

      if showWeather {
        NotchSeparatorDot()
        weatherMetric
      }

      // Disk only earns pill space once it needs attention (80% full and up).
      if diskNeedsAttention {
        NotchSeparatorDot()
        NotchCompactMetric(
          icon: "internaldrive",
          value: Int(systemService.diskInfo.usagePercentage),
          suffix: "%",
          color: WidgetModuleStatusResolver.diskStatus(systemService.diskInfo).color
        )
      }
    }
    .systemMonitoringActive(diskNeedsAttention)
    .frame(height: MicroverseDesign.Notch.Dimensions.compactWidgetHeight)
    .padding(.horizontal, MicroverseDesign.Notch.Spacing.compactHorizontal)
    .padding(.vertical, MicroverseDesign.Notch.Spacing.compactVertical)
    .background(
      // Same pill treatment as the leading and trailing slots so the three read as one row.
      RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
        .fill(MicroverseDesign.Notch.Materials.compactBackground)
        .opacity(MicroverseDesign.Notch.Materials.compactOpacity)
        .overlay(
          RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
            .stroke(
              .white.opacity(MicroverseDesign.Notch.Materials.strokeOpacity),
              lineWidth: MicroverseDesign.Notch.Materials.strokeWidth)
        )
    )
    .onAppear {
      wifi.start()
      audio.start()
    }
    .onDisappear {
      wifi.stop()
      audio.stop()
    }
    .microverseNotchTapToToggleExpanded(enabled: viewModel.notchClickToToggleExpanded)
  }

  private var diskNeedsAttention: Bool {
    WidgetModuleStatusResolver.diskStatus(systemService.diskInfo).needsAttention
  }

  private var weatherMetric: some View {
    HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
      MicroverseWeatherGlyph(
        bucket: weatherStore.current?.bucket ?? .unknown,
        isDaylight: weatherStore.current?.isDaylight ?? true,
        renderMode: weatherAnimationBudget.renderMode(
          for: .compactNotch, isVisible: true, reduceMotion: reduceMotion)
      )
      .font(MicroverseDesign.Notch.Typography.compactIcon)
      .foregroundColor(.white.opacity(0.85))
      .symbolRenderingMode(.hierarchical)
      .frame(width: MicroverseDesign.Layout.iconSizeSmall + 2, alignment: .center)

      Text(temperatureText)
        .font(MicroverseDesign.Notch.Typography.compactValue)
        .foregroundColor(MicroverseDesign.Colors.accent)
        .monospacedDigit()
    }
  }

  private var showWeather: Bool {
    weatherSettings.weatherEnabled && weatherSettings.weatherShowInNotch
      && weatherSettings.selectedLocation != nil
  }

  private var temperatureText: String {
    guard let c = weatherStore.current?.temperatureC else { return "—" }
    return weatherSettings.weatherUnits.formatTemperatureShort(celsius: c)
  }

  private var wifiIcon: String {
    switch wifi.status {
    case .connected, .disconnected: return "wifi"
    case .poweredOff, .unavailable: return "wifi.slash"
    }
  }
}
