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
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            
            Divider()
            
            // Battery Stats Row
            HStack(spacing: 0) {
                StatItem(label: "Cycles", value: "\(viewModel.batteryInfo.cycleCount)")
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 16)
                
                StatItem(label: "Health", value: String(format: "%.0f%%", viewModel.batteryInfo.health * 100))
            }
            .padding(.vertical, 12)
            
            Divider()
            
            // Action Bar
            HStack(spacing: 12) {
                Button(action: { 
                    print("Settings button clicked, current state: \(showingSettings)")
                    showingSettings = true
                    print("Settings state after click: \(showingSettings)")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                        Text("Settings")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(FlatButtonStyle())
                .help("Open settings")
                
                Spacer()
                
                Button(action: { viewModel.refreshBatteryInfo() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(FlatButtonStyle())
                .help("Refresh battery info")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
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
    
    var batteryColor: Color {
        if batteryInfo.currentCharge <= 10 {
            return .red
        } else if batteryInfo.currentCharge <= 20 {
            return .orange
        } else if batteryInfo.isCharging {
            return .green
        } else {
            return .primary
        }
    }
    
    var batteryIconName: String {
        let baseIcon = batteryInfo.currentCharge <= 10 ? "battery.0" :
                      batteryInfo.currentCharge <= 25 ? "battery.25" :
                      batteryInfo.currentCharge <= 50 ? "battery.50" :
                      batteryInfo.currentCharge <= 75 ? "battery.75" : "battery.100"
        
        return batteryInfo.isCharging ? "\(baseIcon).bolt" : baseIcon
    }
    
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
        VStack(spacing: 8) {
            // Battery Icon
            Image(systemName: batteryIconName)
                .font(.system(size: 48))
                .foregroundColor(batteryColor)
            
            // Percentage
            Text("\(batteryInfo.currentCharge)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(batteryColor)
            
            // Status
            Text(statusText)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            // Time remaining (if applicable)
            if let timeString = batteryInfo.timeRemainingFormatted {
                Text(batteryInfo.isCharging ? "Time to full: \(timeString)" : "Time remaining: \(timeString)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FlatButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.secondary.opacity(0.2) : 
                          isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
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
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
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
        .frame(width: 320, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

