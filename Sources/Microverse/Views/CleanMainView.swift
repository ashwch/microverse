import SwiftUI
import AppKit
import BatteryCore

struct CleanMainView: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Battery Status
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: viewModel.batteryInfo.isCharging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: 48))
                        .foregroundColor(viewModel.batteryInfo.currentCharge > 20 ? .green : .red)
                    
                    VStack(alignment: .leading) {
                        Text("\(viewModel.batteryInfo.currentCharge)%")
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                        
                        Text(viewModel.batteryInfo.isCharging ? "Charging" : 
                             viewModel.batteryInfo.isPluggedIn ? "Connected" : "On Battery")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if let timeString = viewModel.batteryInfo.timeRemainingFormatted {
                    HStack {
                        Text(viewModel.batteryInfo.isCharging ? "Time to full:" : "Time remaining:")
                            .foregroundColor(.secondary)
                        Text(timeString)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            
            // Battery Info
            HStack(spacing: 12) {
                InfoCard(
                    title: "Cycle Count",
                    value: "\(viewModel.batteryInfo.cycleCount)",
                    icon: "arrow.2.circlepath",
                    color: .blue
                )
                
                InfoCard(
                    title: "Temperature",
                    value: String(format: "%.1f°C", viewModel.batteryInfo.temperature),
                    icon: "thermometer",
                    color: .orange
                )
                
                InfoCard(
                    title: "Voltage",
                    value: String(format: "%.1fV", viewModel.batteryInfo.voltage),
                    icon: "bolt",
                    color: .purple
                )
            }
            
            Divider()
            
            // Widget Controls
            VStack(spacing: 12) {
                HStack {
                    Text("Widgets")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    Toggle("Desktop Widget", isOn: $viewModel.showDesktopWidget)
                    Spacer()
                    if viewModel.showDesktopWidget {
                        Picker("Style", selection: $viewModel.widgetStyle) {
                            ForEach(WidgetStyle.allCases, id: \.self) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                    }
                }
                
                Toggle("Show percentage in menu bar", isOn: $viewModel.showPercentageInMenuBar)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            
            Divider()
            
            // App Controls
            HStack {
                Toggle("Launch at startup", isOn: $viewModel.launchAtStartup)
                
                Spacer()
                
                Button("Refresh") {
                    viewModel.refreshBatteryInfo()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            .padding(.horizontal)
            
            // Error display
            if let error = viewModel.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear {
            viewModel.refreshBatteryInfo()
            viewModel.checkCapabilities()
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}