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
            
            ScrollView {
                VStack(spacing: 0) {
                    // Menu Bar Option
                    SettingsRow(
                        title: "Show in Menu Bar",
                        subtitle: "Display battery percentage",
                        toggle: $viewModel.showPercentageInMenuBar
                    )
                    
                    SettingsDivider()
                    
                    // Desktop Widget - Compact Style
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Desktop Widget")
                                .font(MicroverseDesign.Typography.body)
                                .foregroundColor(.white)
                            Text("Floating system monitor")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.showDesktopWidget)
                            .labelsHidden()
                            .toggleStyle(ElegantToggleStyle())
                    }
                    .padding(.horizontal, MicroverseDesign.Layout.space5)
                    .padding(.vertical, MicroverseDesign.Layout.space4)
                    
                    if viewModel.showDesktopWidget {
                        HStack {
                            Text("Style")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Picker("", selection: $viewModel.widgetStyle) {
                                ForEach(WidgetStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 160)
                        }
                        .padding(.horizontal, MicroverseDesign.Layout.space5)
                        .padding(.vertical, MicroverseDesign.Layout.space2)
                        .background(Color.white.opacity(0.03))
                    }
                    
                    SettingsDivider()
                    
                    // Enhanced Notch Display (only show on Macs with notch)
                    if viewModel.isNotchAvailable {
                        // Compact Smart Notch Section
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
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
                                                    .fill(viewModel.notchLayoutMode == mode ? 
                                                          MicroverseDesign.Colors.processor.opacity(0.8) : 
                                                          Color.clear)
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
                        .padding(.horizontal, MicroverseDesign.Layout.space5)
                        .padding(.vertical, MicroverseDesign.Layout.space4)
                        
                        SettingsDivider()
                    }
                    
                    // Launch at Startup
                    SettingsRow(
                        title: "Launch at Startup",
                        subtitle: "Start when you log in",
                        toggle: $viewModel.launchAtStartup
                    )
                    
                    SettingsDivider()
                    
                    // Refresh Rate - Compact Section
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Refresh Rate")
                                .font(MicroverseDesign.Typography.body)
                                .foregroundColor(.white)
                            Text("How often to update system data")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        // Compact segmented control
                        HStack(spacing: 1) {
                            ForEach([2.0, 5.0, 10.0, 30.0], id: \.self) { interval in
                                Button(action: { viewModel.refreshInterval = interval }) {
                                    Text("\(Int(interval))s")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(viewModel.refreshInterval == interval ? .white : .white.opacity(0.7))
                                        .frame(width: 32, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(viewModel.refreshInterval == interval ? 
                                                      MicroverseDesign.Colors.processor.opacity(0.8) : 
                                                      Color.clear)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, MicroverseDesign.Layout.space5)
                    .padding(.vertical, MicroverseDesign.Layout.space4)
                    
                    SettingsDivider()
                    
                    // Software Updates Section
                    ElegantUpdateSection()
                        .environmentObject(viewModel)
                    
                    Spacer(minLength: MicroverseDesign.Layout.space4)
                }
            }
        }
        .frame(width: 420, height: 520)
        .background(MicroverseDesign.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: MicroverseDesign.Layout.cornerRadiusLarge)
                .stroke(MicroverseDesign.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MicroverseDesign.Layout.cornerRadiusLarge))
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

