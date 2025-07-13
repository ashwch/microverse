import SwiftUI
import AppKit
import BatteryCore

struct MainView: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Battery Status Card
            BatteryStatusCard(info: viewModel.batteryInfo)
            
            // Battery Control Card (shows admin requirements)
            if viewModel.capabilities.canSetChargeLimit {
                BatteryControlCard(viewModel: viewModel)
            }
            
            // Info Cards
            BatteryInfoCards(info: viewModel.batteryInfo)
            
            Divider()
            
            // App Controls
            HStack {
                Button("Settings") {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        openSettingsWindow(viewModel: appDelegate.viewModel)
                    }
                }
                
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
    }
}

// MARK: - Battery Status Card
struct BatteryStatusCard: View {
    let info: BatteryInfo
    
    var statusText: String {
        if info.isCharging {
            return "Charging"
        } else if info.isPluggedIn {
            return "AC Power"
        } else {
            return "On Battery"
        }
    }
    
    var statusIcon: String {
        if info.isCharging {
            return "bolt.fill"
        } else if info.isPluggedIn {
            return "powerplug"
        } else {
            return "battery.75"
        }
    }
    
    var batteryColor: Color {
        if info.currentCharge <= 20 {
            return .red
        } else if info.currentCharge <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Large battery percentage
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(info.currentCharge)")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                Text("%")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            
            // Battery bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 24)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(batteryColor)
                        .frame(
                            width: geometry.size.width * CGFloat(info.currentCharge) / 100,
                            height: 24
                        )
                }
            }
            .frame(height: 24)
            
            // Status
            HStack {
                Label(statusText, systemImage: statusIcon)
                    .font(.headline)
                
                Spacer()
                
                if let timeRemaining = info.timeRemaining, !info.isPluggedIn, timeRemaining > 0 {
                    let hours = timeRemaining / 60
                    let minutes = timeRemaining % 60
                    Text("\(hours):\(String(format: "%02d", minutes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let wattage = info.adapterWattage, info.isPluggedIn {
                    Text("\(wattage)W")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Battery Control Card
struct BatteryControlCard: View {
    @ObservedObject var viewModel: BatteryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Charge Control", systemImage: "slider.horizontal.3")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.showAdminFeatures {
                    Button(action: { viewModel.requestAdminAccess() }) {
                        Label("Enable", systemImage: "lock")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if viewModel.showAdminFeatures {
                // Charge limit slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Charge Limit")
                        Spacer()
                        Text("\(viewModel.targetChargeLimit)%")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    if viewModel.batteryInfo.isAppleSilicon {
                        // Apple Silicon: Only 80% and 100%
                        Picker("", selection: $viewModel.targetChargeLimit) {
                            Text("80%").tag(80)
                            Text("100%").tag(100)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: viewModel.targetChargeLimit) { newValue in
                            viewModel.setChargeLimit(newValue)
                        }
                    } else {
                        // Intel: Full slider
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.targetChargeLimit) },
                                set: { viewModel.targetChargeLimit = Int($0) }
                            ),
                            in: 50...100,
                            step: 5
                        )
                        .onChange(of: viewModel.targetChargeLimit) { newValue in
                            viewModel.setChargeLimit(newValue)
                        }
                    }
                }
                
                // Charging toggle
                Toggle("Allow Charging", isOn: $viewModel.chargingEnabled)
                    .onChange(of: viewModel.chargingEnabled) { _ in
                        viewModel.toggleCharging()
                    }
            } else {
                Text("Admin access required for charge control")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Battery Info Cards
struct BatteryInfoCards: View {
    let info: BatteryInfo
    
    var body: some View {
        HStack(spacing: 12) {
            InfoCard(
                title: "Cycles",
                value: "\(info.cycleCount)",
                icon: "arrow.2.circlepath"
            )
            
            InfoCard(
                title: "Health",
                value: "\(Int(info.health * 100))%",
                icon: "heart.fill",
                color: healthColor(info.health)
            )
            
            if info.isAppleSilicon {
                InfoCard(
                    title: "Silicon",
                    value: "M-Series",
                    icon: "cpu",
                    color: .orange
                )
            } else {
                InfoCard(
                    title: "Intel",
                    value: "x86",
                    icon: "cpu",
                    color: .blue
                )
            }
        }
    }
    
    func healthColor(_ health: Double) -> Color {
        if health >= 0.8 {
            return .green
        } else if health >= 0.6 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// Placeholder for settings window
