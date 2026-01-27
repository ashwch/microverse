import BatteryCore
import SwiftUI
import SystemCore

struct FlatButtonStyle: ButtonStyle {
  @State private var isHovered = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(MicroverseDesign.Colors.accent)  // FORCE WHITE TEXT
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(
            configuration.isPressed
              ? MicroverseDesign.Colors.background
              : isHovered ? MicroverseDesign.Colors.backgroundDark : Color.clear)
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .onHover { hovering in
        isHovered = hovering
      }
  }
}

struct TabbedMainView: View {
  @EnvironmentObject var viewModel: BatteryViewModel
  @State private var selectedTab = Tab.system
  @State private var showingSettings = false
  @State private var settingsSelection: SettingsView.Category = .general

  enum Tab: String, CaseIterable {
    case system = "System"
    case weather = "Weather"
    case alerts = "Alerts"

    var icon: String {
      switch self {
      case .system: return "square.grid.2x2"
      case .weather: return "cloud.sun"
      case .alerts: return "bell.badge"
      }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Tab Bar
      HStack(spacing: 2) {
        ForEach(Tab.allCases, id: \.self) { tab in
          TabButton(
            title: tab.rawValue,
            icon: tab.icon,
            isSelected: selectedTab == tab
          ) {
            selectedTab = tab
          }
        }
      }
      .padding(2)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.white.opacity(0.06))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.white.opacity(0.12), lineWidth: 1)
          )
      )
      .padding(.horizontal, 8)
      .padding(.vertical, 6)

      Divider()

      ScrollView(.vertical, showsIndicators: false) {
        Group {
          switch selectedTab {
          case .system:
            SystemTab()
          case .weather:
            WeatherTab(openSettings: {
              settingsSelection = .weather
              showingSettings = true
            })
          case .alerts:
            AlertsTab(openSettings: {
              settingsSelection = .alerts
              showingSettings = true
            })
          }
        }
        .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      // Action Bar (shared across all tabs)
      HStack(spacing: 8) {
        Button(action: {
          settingsSelection = .general
          showingSettings = true
        }) {
          HStack(spacing: 4) {
            Image(systemName: "gear")
              .font(.system(size: 11))
              .foregroundColor(.white)
            Text("Settings")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.white)
          }
        }
        .buttonStyle(FlatButtonStyle())

        Spacer()

        Button(action: {
          // Switch to regular app mode temporarily for About panel
          NSApp.setActivationPolicy(.regular)
          NSApp.activate(ignoringOtherApps: true)

          // Show the about panel
          NSApp.orderFrontStandardAboutPanel(nil)

          // Don't switch back immediately - let the user close it
        }) {
          HStack(spacing: 4) {
            Image(systemName: "info.circle")
              .font(.system(size: 11))
              .foregroundColor(.white)
            Text("About")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.white)
          }
        }
        .buttonStyle(FlatButtonStyle())

        Button(action: {
          NSApplication.shared.terminate(nil)
        }) {
          HStack(spacing: 4) {
            Image(systemName: "power")
              .font(.system(size: 11))
              .foregroundColor(.white)
            Text("Quit")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.white)
          }
        }
        .buttonStyle(FlatButtonStyle())
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
    }
    .frame(width: 280, height: 500)
    .onAppear {
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--debug-weather-demo")
          || ProcessInfo.processInfo.arguments.contains("--debug-open-weather")
        {
          selectedTab = .weather
        }

        if ProcessInfo.processInfo.arguments.contains("--debug-open-settings") {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showingSettings = true
          }
        }
      #endif
    }
    .sheet(isPresented: $showingSettings) {
      SettingsView(isPresented: $showingSettings, selection: $settingsSelection)
        .environmentObject(viewModel)
    }
  }
}

private struct SystemTab: View {
  private enum Section: String, CaseIterable {
    case overview = "Overview"
    case battery = "Battery"
    case cpu = "CPU"
    case memory = "Memory"
    case network = "Network"
    case audio = "Audio"

    var icon: String {
      switch self {
      case .overview: return "square.grid.2x2"
      case .battery: return "battery.100"
      case .cpu: return "cpu"
      case .memory: return "memorychip"
      case .network: return "network"
      case .audio: return "speaker.wave.2"
      }
    }
  }

  @State private var selection: Section = .overview

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 2) {
        ForEach(Section.allCases, id: \.self) { section in
          systemSectionButton(section)
        }
      }
      .padding(2)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.white.opacity(0.06))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.white.opacity(0.12), lineWidth: 1)
          )
      )
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 6)

      Group {
        switch selection {
        case .overview:
          UnifiedOverviewTab()
        case .battery:
          UnifiedBatteryTab()
        case .cpu:
          UnifiedCPUTab()
        case .memory:
          UnifiedMemoryTab()
        case .network:
          NetworkTab()
        case .audio:
          AudioTab()
        }
      }
    }
  }

  private func systemSectionButton(_ section: Section) -> some View {
    let isSelected = selection == section

    return Button {
      selection = section
    } label: {
      Image(systemName: section.icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(isSelected ? .white : .white.opacity(0.65))
        .frame(maxWidth: .infinity, minHeight: 26)
        .background(
          RoundedRectangle(cornerRadius: 7)
            .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
    .help(section.rawValue)
    .accessibilityLabel(section.rawValue)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// Unified tab button following design system
struct TabButton: View {
  let title: String
  let icon: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(isSelected ? .white : .white.opacity(0.65))

        Text(title.uppercased())
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(isSelected ? .white : .white.opacity(0.65))
          .tracking(0.5)
      }
      .frame(maxWidth: .infinity, minHeight: 36)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
      )
      .contentShape(Rectangle())  // Make entire area clickable
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// Settings View
struct SettingsView: View {
  @EnvironmentObject var viewModel: BatteryViewModel
  @Binding var isPresented: Bool
  @Binding var selection: Category

  enum Category: String, CaseIterable {
    case general = "General"
    case weather = "Weather"
    case notch = "Notch"
    case alerts = "Alerts"
    case updates = "Updates"

    var icon: String {
      switch self {
      case .general: return "gearshape"
      case .weather: return "cloud.sun"
      case .notch: return "display"
      case .alerts: return "bell.badge"
      case .updates: return "arrow.triangle.2.circlepath"
      }
    }
  }

  @State private var hoveredCustomModule: WidgetModule?

  var body: some View {
    VStack(spacing: 0) {
      // Header matching main app style
      HStack {
        Text("Settings")
          .font(MicroverseDesign.Typography.largeTitle)
          .foregroundColor(MicroverseDesign.Colors.accent)

        Spacer()

        Button(action: { isPresented = false }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(MicroverseDesign.Colors.accentSubtle)
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(MicroverseDesign.Layout.space4)

      Divider()

      settingsCategoryBar

      Divider()

      ScrollView {
        content
          .padding(12)
      }
    }
    .frame(width: 520, height: 560)
    .background(MicroverseDesign.Colors.backgroundDark)
    .overlay(
      RoundedRectangle(cornerRadius: MicroverseDesign.Layout.cornerRadiusLarge)
        .stroke(MicroverseDesign.Colors.border, lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: MicroverseDesign.Layout.cornerRadiusLarge))
  }

  private var settingsCategoryBar: some View {
    HStack(spacing: 2) {
      ForEach(Category.allCases, id: \.self) { category in
        settingsCategoryButton(category)
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(2)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.06))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    )
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private func settingsCategoryButton(_ category: Category) -> some View {
    let isSelected = selection == category

    return Button {
      selection = category
    } label: {
      HStack(spacing: 6) {
        Image(systemName: category.icon)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(isSelected ? .white : .white.opacity(0.65))
          .frame(width: 14, alignment: .center)

        Text(category.rawValue)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(isSelected ? .white : .white.opacity(0.65))
          .lineLimit(1)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  @ViewBuilder
  private var content: some View {
    switch selection {
    case .general:
      generalContent
    case .weather:
      WeatherSettingsSection(style: .card)
    case .notch:
      notchContent
    case .alerts:
      alertsContent
    case .updates:
      updatesContent
    }
  }

  private var generalContent: some View {
    VStack(spacing: 12) {
      SettingsCard(title: "General", systemIcon: "gearshape") {
        SettingsToggleRow(
          icon: "menubar.rectangle",
          title: "Show battery in menu bar",
          subtitle: "Display battery percentage next to the Microverse icon",
          isOn: $viewModel.showPercentageInMenuBar
        )

        SettingsToggleRow(
          icon: "power",
          title: "Launch at startup",
          subtitle: "Start when you log in",
          isOn: $viewModel.launchAtStartup
        )

        SettingsIntervalRow(
          icon: "arrow.clockwise",
          title: "Refresh rate",
          subtitle: "How often to update system data",
          selection: $viewModel.refreshInterval,
          options: [2.0, 5.0, 10.0, 30.0]
        )
      }

      SettingsCard(title: "Desktop Widget", systemIcon: "rectangle.on.rectangle") {
        SettingsToggleRow(
          icon: "rectangle.on.rectangle",
          title: "Show desktop widget",
          subtitle: "Floating system monitor",
          isOn: $viewModel.showDesktopWidget
        )
        .disabled(viewModel.isDesktopWidgetForcedByClamshell)

        SettingsToggleRow(
          icon: "laptopcomputer",
          title: "Auto-enable in clamshell mode",
          subtitle: "Show widget when lid is closed and an external display is connected",
          isOn: $viewModel.autoEnableWidgetInClamshell
        )

        if viewModel.autoEnableWidgetInClamshell {
          SettingsNoticeRow(text: viewModel.clamshellWidgetStatusText)
        }

        if viewModel.showDesktopWidget {
          widgetStyleGrid
          if viewModel.widgetStyle == .custom {
            customWidgetBuilder
          }
        }
      }
    }
  }

  private var notchContent: some View {
    VStack(spacing: 12) {
      if viewModel.isNotchAvailable {
        SmartNotchSection(style: .card)
      } else {
        SettingsCard(title: "Notch", systemIcon: "display") {
          SettingsNoticeRow(text: "Smart Notch requires a Mac with a notch.")
        }
      }
    }
  }

  private var alertsContent: some View {
    VStack(spacing: 12) {
      if viewModel.isNotchAvailable {
        NotchAlertsSection(style: .card)
        WeatherAlertsSection(style: .card)
      } else {
        SettingsCard(title: "Alerts", systemIcon: "bell.badge") {
          SettingsNoticeRow(text: "Notch Glow Alerts require a Mac with a notch.")
        }
      }
    }
  }

  private var updatesContent: some View {
    VStack(spacing: 12) {
      ElegantUpdateSection(style: .card)
    }
  }

  private var widgetStyleGrid: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("WIDGET STYLE")
        .font(MicroverseDesign.Typography.label)
        .foregroundColor(.white.opacity(0.5))
        .tracking(0.8)

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
        spacing: 8
      ) {
        ForEach(WidgetStyle.allCases, id: \.self) { style in
          widgetStyleTile(style)
        }
      }
    }
    .padding(.top, 6)
  }

  private var customWidgetBuilder: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("CUSTOM WIDGET")
        .font(MicroverseDesign.Typography.label)
        .foregroundColor(.white.opacity(0.5))
        .tracking(0.8)

      SettingsToggleRow(
        icon: "sparkles",
        title: "Adaptive emphasis",
        subtitle: "Highlights the most important module automatically",
        isOn: $viewModel.widgetCustomAdaptiveEmphasis
      )

      customWidgetModulesCard
    }
    .padding(.top, 10)
  }

  private var customWidgetModulesCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("MODULES")
        .font(MicroverseDesign.Typography.label)
        .foregroundColor(.white.opacity(0.45))
        .tracking(0.8)

      let maxModules = WidgetModule.maximumSelection
      let selected = viewModel.widgetCustomModules

      VStack(spacing: 8) {
        ForEach(selected, id: \.self) { module in
          customWidgetSelectedModuleRow(module, all: selected)
        }
      }

      if selected.count < maxModules {
        Divider()
          .background(Color.white.opacity(0.08))

        VStack(spacing: 6) {
          ForEach(WidgetModule.allCases.filter { !selected.contains($0) }, id: \.self) { module in
            customWidgetAddModuleRow(module)
          }
        }
      } else {
        SettingsNoticeRow(
          text: "Selected \(maxModules) modules (maximum). Remove one to add another.")
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.04))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    )
  }

  private func customWidgetSelectedModuleRow(_ module: WidgetModule, all selected: [WidgetModule])
    -> some View
  {
    let index = selected.firstIndex(of: module) ?? 0
    let canMoveUp = index > 0
    let canMoveDown = index < (selected.count - 1)
    let isHovered = hoveredCustomModule == module

    return HStack(spacing: 10) {
      Image(systemName: module.systemIcon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.65))
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(module.title)
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.9))
        Text(module.subtitle)
          .font(.system(size: 10, weight: .regular))
          .foregroundColor(.white.opacity(0.5))
      }

      Spacer()

      if isHovered {
        HStack(spacing: 6) {
          Button {
            moveCustomWidgetModule(from: index, to: index - 1)
          } label: {
            Image(systemName: "chevron.up")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.white.opacity(canMoveUp ? 0.7 : 0.25))
              .frame(width: 18, height: 18)
          }
          .buttonStyle(PlainButtonStyle())
          .disabled(!canMoveUp)
          .help("Move up")

          Button {
            moveCustomWidgetModule(from: index, to: index + 1)
          } label: {
            Image(systemName: "chevron.down")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.white.opacity(canMoveDown ? 0.7 : 0.25))
              .frame(width: 18, height: 18)
          }
          .buttonStyle(PlainButtonStyle())
          .disabled(!canMoveDown)
          .help("Move down")

          Button {
            removeCustomWidgetModule(module)
          } label: {
            Image(systemName: "trash")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.white.opacity(0.55))
              .frame(width: 18, height: 18)
          }
          .buttonStyle(PlainButtonStyle())
          .help("Remove")
        }
      } else {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white.opacity(0.18))
          .frame(width: 18, height: 18)
          .accessibilityHidden(true)
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 8)
    .background(Color.white.opacity(0.03))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .onHover { hovering in
      if hovering {
        hoveredCustomModule = module
      } else if hoveredCustomModule == module {
        hoveredCustomModule = nil
      }
    }
  }

  private func customWidgetAddModuleRow(_ module: WidgetModule) -> some View {
    Button {
      addCustomWidgetModule(module)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.white.opacity(0.55))
          .frame(width: 16)

        Text(module.title)
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.85))

        Spacer()
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
    .help("Add \(module.title)")
  }

  private func addCustomWidgetModule(_ module: WidgetModule) {
    var next = viewModel.widgetCustomModules
    guard !next.contains(module) else { return }
    guard next.count < WidgetModule.maximumSelection else { return }
    next.append(module)
    viewModel.widgetCustomModules = next
  }

  private func removeCustomWidgetModule(_ module: WidgetModule) {
    var next = viewModel.widgetCustomModules
    next.removeAll { $0 == module }
    viewModel.widgetCustomModules = next
  }

  private func moveCustomWidgetModule(from index: Int, to newIndex: Int) {
    guard index != newIndex else { return }
    var next = viewModel.widgetCustomModules
    guard index >= 0, index < next.count else { return }
    guard newIndex >= 0, newIndex < next.count else { return }
    let item = next.remove(at: index)
    next.insert(item, at: newIndex)
    viewModel.widgetCustomModules = next
  }

  private func widgetStyleTile(_ style: WidgetStyle) -> some View {
    let isSelected = viewModel.widgetStyle == style

    return Button {
      viewModel.widgetStyle = style
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Image(systemName: widgetStyleIcon(style))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(isSelected ? 0.9 : 0.65))

          Text(style.displayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(isSelected ? 0.95 : 0.8))
            .lineLimit(1)

          Spacer()

          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.white.opacity(0.8))
          }
        }

        Text(widgetStyleSizeText(style))
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(.white.opacity(0.45))
          .monospacedDigit()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.white.opacity(isSelected ? 0.20 : 0.10), lineWidth: 1)
          )
      )
    }
    .buttonStyle(PlainButtonStyle())
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func widgetStyleIcon(_ style: WidgetStyle) -> String {
    switch style {
    case .custom:
      return "slider.horizontal.3"
    case .batterySimple:
      return "battery.100"
    case .cpuMonitor:
      return "cpu"
    case .memoryMonitor:
      return "memorychip"
    case .systemGlance:
      return "circle.grid.2x2"
    case .systemStatus:
      return "gauge.with.dots.needle.67percent"
    case .systemDashboard:
      return "rectangle.3.offgrid"
    }
  }

  private func widgetStyleSizeText(_ style: WidgetStyle) -> String {
    switch style {
    case .custom:
      return "240×120"
    case .batterySimple:
      return "100×40"
    case .cpuMonitor, .memoryMonitor:
      return "160×80"
    case .systemGlance:
      return "160×50"
    case .systemStatus:
      return "240×80"
    case .systemDashboard:
      return "240×120"
    }
  }
}

private struct SettingsCard<Content: View>: View {
  let title: String
  let systemIcon: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title, systemIcon: systemIcon)
      content
    }
    .padding(12)
    .background(MicroverseDesign.cardBackground())
  }
}

private struct SettingsToggleRow: View {
  let icon: String
  let title: String
  let subtitle: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.65))
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.9))
        Text(subtitle)
          .font(.system(size: 10, weight: .regular))
          .foregroundColor(.white.opacity(0.5))
      }

      Spacer()

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(ElegantToggleStyle())
    }
    .padding(.vertical, 2)
  }
}

private struct SettingsIntervalRow: View {
  let icon: String
  let title: String
  let subtitle: String
  @Binding var selection: TimeInterval
  let options: [TimeInterval]

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.65))
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 6) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.9))
          Text(subtitle)
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(.white.opacity(0.5))
        }

        HStack(spacing: 1) {
          ForEach(options, id: \.self) { interval in
            Button {
              selection = interval
            } label: {
              Text("\(Int(interval))s")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(abs(selection - interval) < 0.01 ? .white : .white.opacity(0.7))
                .frame(width: 36, height: 24)
                .background(
                  RoundedRectangle(cornerRadius: 4)
                    .fill(
                      abs(selection - interval) < 0.01 ? Color.white.opacity(0.14) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .background(
          RoundedRectangle(cornerRadius: 7)
            .fill(Color.white.opacity(0.08))
            .overlay(
              RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        )
      }

      Spacer()
    }
    .padding(.vertical, 2)
  }
}

private struct SettingsNoticeRow: View {
  let text: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "info.circle")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.55))
        .frame(width: 16)

      Text(text)
        .font(MicroverseDesign.Typography.caption)
        .foregroundColor(.white.opacity(0.6))
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
  }
}

// MARK: - Settings Helper Components

struct SettingsRow: View {
  let title: String
  let subtitle: String
  @Binding var toggle: Bool

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(MicroverseDesign.Typography.body)
          .foregroundColor(.white)
        Text(subtitle)
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.6))
      }
      Spacer()
      Toggle("", isOn: $toggle)
        .labelsHidden()
        .toggleStyle(ElegantToggleStyle())
    }
    .padding(.horizontal, MicroverseDesign.Layout.space5)
    .padding(.vertical, MicroverseDesign.Layout.space4)
  }
}

struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.white.opacity(0.1))
      .frame(height: 1)
      .padding(.horizontal, MicroverseDesign.Layout.space5)
  }
}

// MARK: - Smart Notch Section

struct SmartNotchSection: View {
  enum Style {
    case settings
    case card
  }

  var style: Style = .settings

  @EnvironmentObject var viewModel: BatteryViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space3) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Smart Notch")
            .font(MicroverseDesign.Typography.body)
            .foregroundColor(.white)
          Text("System stats around the notch")
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.6))
        }

        Spacer()

        // Compact 3-option segmented control
        HStack(spacing: 0) {
          ForEach(MicroverseNotchViewModel.NotchLayoutMode.allCases, id: \.self) { mode in
            Button(action: {
              viewModel.notchLayoutMode = mode
            }) {
              Text(mode.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(viewModel.notchLayoutMode == mode ? .white : .white.opacity(0.7))
                .frame(width: 45, height: 24)
                .background(
                  RoundedRectangle(cornerRadius: 4)
                    .fill(
                      viewModel.notchLayoutMode == mode
                        ? MicroverseDesign.Colors.processor.opacity(0.8) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.white.opacity(0.08))
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        )
      }

      if viewModel.notchLayoutMode != .off {
        Text(viewModel.notchLayoutMode.description)
          .font(MicroverseDesign.Typography.caption)
          .foregroundColor(.white.opacity(0.6))

        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Click notch to show details")
              .font(MicroverseDesign.Typography.caption)
              .foregroundColor(.white.opacity(0.7))
            Text("Toggle expanded Smart Notch view")
              .font(.system(size: 10, weight: .regular))
              .foregroundColor(.white.opacity(0.5))
          }

          Spacer()

          Toggle("", isOn: $viewModel.notchClickToToggleExpanded)
            .labelsHidden()
            .toggleStyle(ElegantToggleStyle())
        }
        .padding(.top, MicroverseDesign.Layout.space2)
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
}

// MARK: - Notch Alerts Section

struct NotchAlertsSection: View {
  enum Style {
    case settings
    case card
  }

  var style: Style = .settings

  @EnvironmentObject var viewModel: BatteryViewModel

  @State private var isShowingBatteryRules = false
  @State private var isShowingDeviceRules = false
  @State private var isShowingAdvanced = false

  var body: some View {
    VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space3) {
      // Toggle for notch alerts
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Notch Glow Alerts")
            .font(MicroverseDesign.Typography.body)
            .foregroundColor(.white)
          Text("Visual alerts around the notch area")
            .font(MicroverseDesign.Typography.caption)
            .foregroundColor(.white.opacity(0.6))
        }
        Spacer()
        Toggle("", isOn: $viewModel.enableNotchAlerts)
          .labelsHidden()
          .toggleStyle(ElegantToggleStyle())
      }

      if viewModel.enableNotchAlerts {
        DisclosureGroup(isExpanded: $isShowingBatteryRules) {
          VStack(spacing: 6) {
            alertToggleRow(
              icon: "bolt.fill", color: MicroverseDesign.Colors.success, title: "Charger connected",
              isOn: $viewModel.notchAlertChargerConnected)
            alertToggleRow(
              icon: "battery.100", color: MicroverseDesign.Colors.success, title: "Fully charged",
              isOn: $viewModel.notchAlertFullyCharged)

            alertToggleRow(
              icon: "battery.25", color: MicroverseDesign.Colors.warning, title: "Low battery",
              isOn: $viewModel.notchAlertLowBatteryEnabled)
            if viewModel.notchAlertLowBatteryEnabled {
              thresholdStepperRow(
                title: "Threshold",
                value: $viewModel.notchAlertLowBatteryThreshold,
                minValue: 5,
                maxValue: 50
              )
              .padding(.leading, 22)
            }

            alertToggleRow(
              icon: "battery.0", color: MicroverseDesign.Colors.critical, title: "Critical battery",
              isOn: $viewModel.notchAlertCriticalBatteryEnabled)
            if viewModel.notchAlertCriticalBatteryEnabled {
              thresholdStepperRow(
                title: "Threshold",
                value: $viewModel.notchAlertCriticalBatteryThreshold,
                minValue: 5,
                maxValue: viewModel.notchAlertLowBatteryThreshold
              )
              .padding(.leading, 22)
            }
          }
          .padding(.top, 8)
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "battery.100")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.white.opacity(0.6))
              .frame(width: 16)

            Text("Battery")
              .font(MicroverseDesign.Typography.body)
              .foregroundColor(.white.opacity(0.9))

            Spacer()

            Text(batterySummaryText)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.white.opacity(0.45))
              .monospacedDigit()
          }
        }
        .accentColor(.white.opacity(0.7))
        .padding(.top, MicroverseDesign.Layout.space2)

        DisclosureGroup(isExpanded: $isShowingDeviceRules) {
          VStack(spacing: 6) {
            alertToggleRow(
              icon: "airpods",
              color: MicroverseDesign.Colors.critical,
              title: "AirPods low battery",
              isOn: $viewModel.notchAlertAirPodsLowBatteryEnabled
            )

            if viewModel.notchAlertAirPodsLowBatteryEnabled {
              thresholdStepperRow(
                title: "Threshold",
                value: $viewModel.notchAlertAirPodsLowBatteryThreshold,
                minValue: 5,
                maxValue: 50
              )
              .padding(.leading, 22)

              if let status = airPodsStatusText {
                Text(status)
                  .font(.system(size: 10, weight: .regular))
                  .foregroundColor(.white.opacity(0.55))
                  .fixedSize(horizontal: false, vertical: true)
                  .padding(.leading, 22)
              }
            }
          }
          .padding(.top, 8)
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "airpods")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.white.opacity(0.6))
              .frame(width: 16)

            Text("Devices")
              .font(MicroverseDesign.Typography.body)
              .foregroundColor(.white.opacity(0.9))

            Spacer()

            Text(devicesSummaryText)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.white.opacity(0.45))
              .monospacedDigit()
          }
        }
        .accentColor(.white.opacity(0.7))
        .padding(.top, 6)

        DisclosureGroup(isExpanded: $isShowingAdvanced) {
          VStack(spacing: 10) {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text("Startup animation")
                  .font(MicroverseDesign.Typography.caption)
                  .foregroundColor(.white.opacity(0.8))
                Text("Play a glow when Microverse starts")
                  .font(.system(size: 10, weight: .regular))
                  .foregroundColor(.white.opacity(0.5))
              }
              Spacer()
              Toggle("", isOn: $viewModel.enableNotchStartupAnimation)
                .labelsHidden()
                .toggleStyle(ElegantToggleStyle())
            }

            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 8) {
                Image(systemName: "airpods")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundColor(.white.opacity(0.6))
                  .frame(width: 16)

                Text("AirPods battery override")
                  .font(MicroverseDesign.Typography.caption)
                  .foregroundColor(.white.opacity(0.8))

                Spacer(minLength: 0)
              }

              LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8
              ) {
                diagnosticButton(label: "Low", color: .orange) {
                  let value = max(0, viewModel.notchAlertAirPodsLowBatteryThreshold - 5)
                  viewModel.setDebugAirPodsBatteryOverride(percent: value)
                }

                diagnosticButton(label: "Critical", color: .red) {
                  viewModel.setDebugAirPodsBatteryOverride(percent: 5)
                }

                diagnosticButton(label: "Clear", color: .white.opacity(0.3)) {
                  viewModel.clearDebugAirPodsBatteryOverride()
                }
              }

              if let override = viewModel.debugAirPodsBatteryOverridePercent {
                Text("Override: \(override)% (auto clears)")
                  .font(.system(size: 10, weight: .regular))
                  .foregroundColor(.white.opacity(0.55))
                  .monospacedDigit()
              }
            }

            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8
            ) {
              testAlertButton(type: .success, label: "Success", color: .green)
              testAlertButton(type: .warning, label: "Warning", color: .orange)
              testAlertButton(type: .critical, label: "Critical", color: .red)
              testAlertButton(type: .info, label: "Info", color: .blue)
            }
          }
          .padding(.top, 8)
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "gearshape")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.white.opacity(0.6))
              .frame(width: 16)

            Text("Advanced")
              .font(MicroverseDesign.Typography.body)
              .foregroundColor(.white.opacity(0.9))

            Spacer()
          }
        }
        .accentColor(.white.opacity(0.7))
        .padding(.top, 6)
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

  private func ruleToggleRow(color: Color, title: String, isOn: Binding<Bool>) -> some View {
    HStack(spacing: MicroverseDesign.Layout.space2) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
      Text(title)
        .font(MicroverseDesign.Typography.caption)
        .foregroundColor(.white.opacity(0.8))

      Spacer()

      Toggle("", isOn: isOn)
        .labelsHidden()
        .toggleStyle(ElegantToggleStyle())
    }
  }

  private func alertToggleRow(icon: String, color: Color, title: String, isOn: Binding<Bool>)
    -> some View
  {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(color.opacity(0.9))
        .frame(width: 16)

      Text(title)
        .font(MicroverseDesign.Typography.caption)
        .foregroundColor(.white.opacity(0.85))

      Spacer()

      Toggle("", isOn: isOn)
        .labelsHidden()
        .toggleStyle(ElegantToggleStyle())
    }
    .padding(.vertical, 2)
  }

  private func thresholdStepperRow(title: String, value: Binding<Int>, minValue: Int, maxValue: Int)
    -> some View
  {
    HStack {
      Text(title)
        .font(MicroverseDesign.Typography.caption)
        .foregroundColor(.white.opacity(0.55))

      Spacer()

      thresholdStepperControl(value: value, minValue: minValue, maxValue: maxValue)
    }
  }

  private var batterySummaryText: String {
    var parts: [String] = []

    if viewModel.notchAlertLowBatteryEnabled {
      parts.append("Low ≤ \(viewModel.notchAlertLowBatteryThreshold)%")
    }
    if viewModel.notchAlertCriticalBatteryEnabled {
      parts.append("Crit ≤ \(viewModel.notchAlertCriticalBatteryThreshold)%")
    }

    if parts.isEmpty {
      return "Off"
    }
    return parts.joined(separator: " · ")
  }

  private var devicesSummaryText: String {
    if viewModel.notchAlertAirPodsLowBatteryEnabled {
      return "Low ≤ \(viewModel.notchAlertAirPodsLowBatteryThreshold)%"
    }
    return "Off"
  }

  private var airPodsStatusText: String? {
    guard viewModel.notchAlertAirPodsLowBatteryEnabled else { return nil }

    switch viewModel.airPodsBatteryAvailability {
    case .unauthorized:
      return "Bluetooth access denied. Enable it in System Settings."
    case .poweredOff:
      return "Turn on Bluetooth to read AirPods battery."
    case .unavailable:
      return "Bluetooth is unavailable on this Mac."
    case .ready:
      if let percent = viewModel.airPodsBatteryPercent {
        return "Current: \(percent)%"
      }
      return "Waiting for AirPods battery…"
    case .unknown:
      return "Checking Bluetooth…"
    }
  }

  private func thresholdStepperControl(value: Binding<Int>, minValue: Int, maxValue: Int)
    -> some View
  {
    let minValue = minValue
    let maxValue = max(minValue, maxValue)
    let current = value.wrappedValue

    let canDec = current > minValue
    let canInc = current < maxValue

    return HStack(spacing: 8) {
      Button {
        value.wrappedValue = max(minValue, current - 5)
      } label: {
        Image(systemName: "minus")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.white.opacity(canDec ? 0.75 : 0.25))
          .frame(width: 18, height: 18)
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(!canDec)
      .accessibilityLabel("Decrease threshold")

      Text("\(current)%")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.white.opacity(0.8))
        .monospacedDigit()
        .frame(minWidth: 42, alignment: .center)

      Button {
        value.wrappedValue = min(maxValue, current + 5)
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.white.opacity(canInc ? 0.75 : 0.25))
          .frame(width: 18, height: 18)
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(!canInc)
      .accessibilityLabel("Increase threshold")
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
    .accessibilityLabel("Threshold")
    .accessibilityValue("\(current)%")
  }

  private func diagnosticButton(label: String, color: Color, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Text(label)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.25))
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.5), lineWidth: 1)
            )
        )
    }
    .buttonStyle(PlainButtonStyle())
  }

  private func testAlertButton(type: NotchAlertType, label: String, color: Color) -> some View {
    Button(action: {
      viewModel.testNotchAlert(type: type)
    }) {
      Text(label)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.3))
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.6), lineWidth: 1)
            )
        )
    }
    .buttonStyle(PlainButtonStyle())
  }
}
