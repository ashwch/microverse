import SwiftUI
import AppKit
import BatteryCore

struct CleanMainView: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Battery Status Section
            BatteryStatusView(batteryInfo: viewModel.batteryInfo)
                .padding(.horizontal, DesignSystem.Spacing.large)
                .padding(.vertical, DesignSystem.Spacing.large)
            
            Divider()
            
            // Battery Stats Row
            HStack(spacing: 0) {
                StatItem(label: "Cycles", value: "\(viewModel.batteryInfo.cycleCount)")
                
                Divider()
                    .frame(height: DesignSystem.Layout.dividerHeight)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                
                StatItem(label: "Health", value: String(format: "%.0f%%", viewModel.batteryInfo.health * 100))
            }
            .padding(.vertical, DesignSystem.Spacing.small + DesignSystem.Spacing.micro)
            
            Divider()
            
            // Action Bar
            HStack(spacing: DesignSystem.Layout.actionBarSpacing) {
                Button(action: { 
                    showingSettings = true
                }) {
                    HStack(spacing: DesignSystem.Spacing.micro) {
                        Image(systemName: "gearshape")
                            .font(DesignSystem.Typography.buttonIcon)
                        Text("Settings")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(FlatButtonStyle())
                .help("Open settings")
                
                Spacer()
                
                Button(action: { viewModel.refreshBatteryInfo() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(DesignSystem.Typography.buttonIcon)
                        .foregroundColor(.primary)
                }
                .buttonStyle(FlatButtonStyle())
                .help("Refresh battery info")
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
        }
        .frame(width: DesignSystem.Layout.mainViewWidth)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            viewModel.refreshBatteryInfo()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
                .environmentObject(viewModel)
        }
    }
}

struct BatteryStatusView: View {
    let batteryInfo: BatteryInfo
    
    var statusText: String {
        if batteryInfo.isCharging {
            return "Charging"
        } else if batteryInfo.isPluggedIn {
            return "Plugged In"
        } else {
            return "On Battery"
        }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            // Battery Icon
            Image(systemName: DesignSystem.batteryIconName(for: batteryInfo))
                .font(DesignSystem.Typography.batteryPercentage)
                .foregroundColor(DesignSystem.batteryColor(for: batteryInfo))
            
            // Percentage - show loading if 0%
            if batteryInfo.currentCharge == 0 && !batteryInfo.isCharging {
                Text("Loading...")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(.secondary)
            } else {
                Text("\(batteryInfo.currentCharge)%")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.batteryColor(for: batteryInfo))
            }
            
            // Status
            Text(statusText)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
            
            // Time remaining (if applicable)
            if let timeString = batteryInfo.timeRemainingFormatted {
                Text(batteryInfo.isCharging ? "Time to full: \(timeString)" : "Time remaining: \(timeString)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Layout.statItemSpacing) {
            Text(value)
                .font(DesignSystem.Typography.statValue)
            Text(label)
                .font(DesignSystem.Typography.smallCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FlatButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.Layout.buttonPaddingHorizontal)
            .padding(.vertical, DesignSystem.Layout.buttonPaddingVertical)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(configuration.isPressed ? Color.secondary.opacity(0.2) : 
                          isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            .onHover { hovering in
                isHovered = hovering
            }
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
                    .font(DesignSystem.Typography.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.settingsIcon)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            Divider()
            
            // Settings Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Display Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Display")
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
        .frame(width: DesignSystem.Layout.settingsViewWidth, height: DesignSystem.Layout.settingsViewHeight)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

