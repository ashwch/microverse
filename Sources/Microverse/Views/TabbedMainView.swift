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
                        Text("Menu Bar")
                            .font(.headline)
                        
                        Toggle("Show percentage in menu bar", isOn: $viewModel.showPercentageInMenuBar)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Desktop Widget Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Desktop Widget")
                            .font(.headline)
                        
                        Toggle("Enable widget", isOn: $viewModel.showDesktopWidget)
                        
                        if viewModel.showDesktopWidget {
                            HStack {
                                Text("Style:")
                                Picker("", selection: $viewModel.widgetStyle) {
                                    ForEach(WidgetStyle.allCases, id: \.self) { style in
                                        Text(style.displayName).tag(style)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(MenuPickerStyle())
                                .fixedSize()
                            }
                            
                            Toggle("Show system info", isOn: $viewModel.showSystemInfoInWidget)
                                .font(MicroverseDesign.Typography.caption)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General")
                            .font(.headline)
                        
                        Toggle("Launch at startup", isOn: $viewModel.launchAtStartup)
                        
                        HStack {
                            Text("Refresh interval:")
                            Picker("", selection: $viewModel.refreshInterval) {
                                Text("2 seconds").tag(2.0)
                                Text("5 seconds").tag(5.0)
                                Text("10 seconds").tag(10.0)
                                Text("30 seconds").tag(30.0)
                            }
                            .labelsHidden()
                            .pickerStyle(MenuPickerStyle())
                            .fixedSize()
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
}