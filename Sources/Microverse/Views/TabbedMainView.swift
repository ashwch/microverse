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
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Menu Bar Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(MicroverseDesign.Colors.accent)
                            Text("Menu Bar")
                                .font(.headline)
                        }
                        
                        Toggle("Show battery percentage", isOn: $viewModel.showPercentageInMenuBar)
                            .toggleStyle(SwitchToggleStyle(tint: MicroverseDesign.Colors.success))
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Desktop Widget Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "rectangle.badge.checkmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(MicroverseDesign.Colors.accent)
                            Text("Desktop Widget")
                                .font(.headline)
                        }
                        
                        Toggle("Enable floating widget", isOn: $viewModel.showDesktopWidget)
                            .toggleStyle(SwitchToggleStyle(tint: MicroverseDesign.Colors.success))
                        
                        if viewModel.showDesktopWidget {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Widget Type")
                                    .font(MicroverseDesign.Typography.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $viewModel.widgetStyle) {
                                    // Single Metric Section
                                    Section(header: Text("Single Metric")) {
                                        Text("🔋 Battery Simple").tag(WidgetStyle.batterySimple)
                                        Text("🖥️ CPU Monitor").tag(WidgetStyle.cpuMonitor)
                                        Text("🧠 Memory Monitor").tag(WidgetStyle.memoryMonitor)
                                    }
                                    
                                    Divider()
                                    
                                    // Multi-Metric Section
                                    Section(header: Text("System Overview")) {
                                        Text("👀 System Glance").tag(WidgetStyle.systemGlance)
                                        Text("📊 System Status").tag(WidgetStyle.systemStatus)
                                        Text("📈 System Dashboard").tag(WidgetStyle.systemDashboard)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Widget preview hint
                                Text(widgetDescription)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            .padding(12)
                            .background(MicroverseDesign.cardBackground())
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "gear")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(MicroverseDesign.Colors.accent)
                            Text("General")
                                .font(.headline)
                        }
                        
                        Toggle("Launch at startup", isOn: $viewModel.launchAtStartup)
                            .toggleStyle(SwitchToggleStyle(tint: MicroverseDesign.Colors.success))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("System refresh rate")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $viewModel.refreshInterval) {
                                Text("Fast (2 sec)").tag(2.0)
                                Text("Normal (5 sec)").tag(5.0)
                                Text("Balanced (10 sec)").tag(10.0)
                                Text("Power Saver (30 sec)").tag(30.0)
                            }
                            .labelsHidden()
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .frame(width: 400, height: 500)
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