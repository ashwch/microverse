import SwiftUI
import BatteryCore
import SystemCore

struct FlatButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(MicroverseDesign.Colors.accent) // FORCE WHITE TEXT
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? MicroverseDesign.Colors.background : 
                          isHovered ? MicroverseDesign.Colors.backgroundDark : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct TabbedMainView: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    @State private var selectedTab = Tab.overview
    @State private var showingSettings = false
    
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case battery = "Battery"
        case cpu = "CPU"
        case memory = "Memory"
        
        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .battery: return "battery.100"
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            Divider()
            
            // Content View with unified design
            Group {
                switch selectedTab {
                case .overview:
                    UnifiedOverviewTab()
                case .battery:
                    UnifiedBatteryTab()
                case .cpu:
                    UnifiedCPUTab()
                case .memory:
                    UnifiedMemoryTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Action Bar (shared across all tabs)
            HStack(spacing: 8) {
                Button(action: { 
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
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
                .environmentObject(viewModel)
        }
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
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity, minHeight: 36) // Smaller touch target
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.black.opacity(0.3) : Color.clear)
            )
            .contentShape(Rectangle()) // Make entire area clickable
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Settings View
struct SettingsView: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(MicroverseDesign.Typography.largeTitle)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(MicroverseDesign.Layout.space4)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Menu Bar Option
                    SettingsRow(
                        title: "Show in Menu Bar",
                        subtitle: "Display battery percentage",
                        toggle: $viewModel.showPercentageInMenuBar
                    )
                    
                    SettingsDivider()
                    
                    // Desktop Widget
                    SettingsRow(
                        title: "Desktop Widget",
                        subtitle: "Floating system monitor",
                        toggle: $viewModel.showDesktopWidget
                    )
                    
                    if viewModel.showDesktopWidget {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Widget Style")
                                    .font(MicroverseDesign.Typography.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Picker("", selection: $viewModel.widgetStyle) {
                                    ForEach(WidgetStyle.allCases, id: \.self) { style in
                                        Text(style.displayName).tag(style)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 180)
                            }
                            .padding(MicroverseDesign.Layout.space3)
                            .padding(.leading, MicroverseDesign.Layout.space4)
                            .background(Color.gray.opacity(0.1))
                            
                            HStack {
                                Text(widgetDescription)
                                    .font(MicroverseDesign.Typography.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, MicroverseDesign.Layout.space3)
                            .padding(.horizontal, MicroverseDesign.Layout.space4)
                            .padding(.bottom, MicroverseDesign.Layout.space3)
                        }
                    }
                    
                    SettingsDivider()
                    
                    // Launch at Startup
                    SettingsRow(
                        title: "Launch at Startup",
                        subtitle: "Start when you log in",
                        toggle: $viewModel.launchAtStartup
                    )
                    
                    SettingsDivider()
                    
                    // Refresh Rate
                    VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space3) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Refresh Rate")
                                    .font(MicroverseDesign.Typography.body)
                                    .foregroundColor(.primary)
                                Text("How often to update system data")
                                    .font(MicroverseDesign.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, MicroverseDesign.Layout.space3)
                        
                        HStack(spacing: MicroverseDesign.Layout.space2) {
                            ForEach([2.0, 5.0, 10.0, 30.0], id: \.self) { interval in
                                Button(action: { viewModel.refreshInterval = interval }) {
                                    VStack(spacing: 2) {
                                        Text("\(Int(interval))")
                                            .font(MicroverseDesign.Typography.body.weight(.semibold))
                                        Text("sec")
                                            .font(MicroverseDesign.Typography.caption)
                                    }
                                    .foregroundColor(viewModel.refreshInterval == interval ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, MicroverseDesign.Layout.space2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(viewModel.refreshInterval == interval ? MicroverseDesign.Colors.processor : Color.gray.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, MicroverseDesign.Layout.space3)
                    }
                    .padding(.vertical, MicroverseDesign.Layout.space3)
                    
                    Spacer(minLength: MicroverseDesign.Layout.space4)
                }
            }
        }
        .frame(width: 420, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var widgetDescription: String {
        switch viewModel.widgetStyle {
        case .batterySimple:
            return "Minimal 100×40 widget showing battery percentage"
        case .cpuMonitor:
            return "160×80 widget with CPU usage and progress bar"
        case .memoryMonitor:
            return "160×80 widget with memory usage and pressure"
        case .systemGlance:
            return "Compact 160×50 widget with all three metrics"
        case .systemStatus:
            return "Medium 240×80 widget with detailed metrics"
        case .systemDashboard:
            return "Large 240×120 widget with full system details"
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
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $toggle)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(MicroverseDesign.Layout.space3)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(MicroverseDesign.Colors.divider)
            .padding(.horizontal, MicroverseDesign.Layout.space3)
    }
}