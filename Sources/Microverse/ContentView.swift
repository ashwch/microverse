import SwiftUI
import AppKit
import BatteryCore

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = SharedViewModel.shared
    
    var body: some View {
        CleanMainView()
            .environmentObject(viewModel)
    }
}

// Keep a reference to prevent deallocation
var settingsWindow: NSWindowController?

func openSettingsWindow(viewModel: BatteryViewModel) {
    if settingsWindow == nil {
        let settingsView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Microverse Settings"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        
        settingsWindow = NSWindowController(window: window)
    }
    
    settingsWindow?.showWindow(nil)
    settingsWindow?.window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: BatteryViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
            
            BatterySettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Battery", systemImage: "battery.75")
                }
                .tag(1)
            
            AdvancedView(viewModel: viewModel)
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(2)
            
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 600, height: 400)
        .padding()
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: BatteryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Text("Menu Bar")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show battery percentage", isOn: $viewModel.showPercentageInMenuBar)
                    
                    HStack {
                        Text("Refresh interval")
                        Spacer()
                        Picker("", selection: $viewModel.refreshInterval) {
                            Text("1 second").tag(1.0)
                            Text("5 seconds").tag(5.0)
                            Text("10 seconds").tag(10.0)
                            Text("30 seconds").tag(30.0)
                            Text("60 seconds").tag(60.0)
                        }
                        .frame(width: 120)
                    }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Text("Startup")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: $viewModel.launchAtStartup)
                        .disabled(true) // Not implemented yet
                    
                    if viewModel.launchAtStartup {
                        Text("Launch at login is not yet implemented")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Battery Settings Tab
struct BatterySettingsTab: View {
    @ObservedObject var viewModel: BatteryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Text("Battery Information")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Charge")
                        Spacer()
                        Text("\(viewModel.batteryInfo.currentCharge)%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Cycle Count")
                        Spacer()
                        Text("\(viewModel.batteryInfo.cycleCount)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Battery Health")
                        Spacer()
                        Text("\(Int(viewModel.batteryInfo.health * 100))%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text(viewModel.batteryInfo.isAppleSilicon ? "Apple Silicon" : "Intel")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Text("Charge Control")) {
                if viewModel.showAdminFeatures {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("✓ Admin access granted")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("⚠️ Important: Battery control on macOS requires additional system modifications")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        if viewModel.batteryInfo.isAppleSilicon {
                            Text("Apple Silicon: Charge limiting requires a privileged helper tool and special entitlements. macOS only supports 80% and 100% limits.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Intel: Charge limiting requires SMC access through a kernel extension or privileged helper.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Link("Learn more about battery management on macOS", 
                             destination: URL(string: "https://support.apple.com/en-us/HT212049")!)
                            .font(.caption)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Charge control requires admin privileges")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Button("Request Admin Access") {
                            viewModel.requestAdminAccess()
                        }
                        .disabled(viewModel.isRequestingAdminAccess)
                        
                        Text("Note: All battery management apps require admin access to control charging. This is a macOS security requirement.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - About Tab
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "battery.75.bolt")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Microverse")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .foregroundColor(.secondary)
            
            Text("Honest battery management for macOS")
                .font(.headline)
            
            Divider()
                .frame(width: 200)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What's Real:")
                    .font(.headline)
                
                Label("Battery statistics (no admin needed)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("Charge limiting (admin required)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("Different limits for Intel vs Apple Silicon", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What's Not:")
                    .font(.headline)
                
                Label("Battery calibration (automatic on modern Macs)", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                Label("Temperature control (read-only)", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                Label("Charge control without admin", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Link("GitHub", destination: URL(string: "https://github.com/ashwch/microverse")!)
                Link("Report Issue", destination: URL(string: "https://github.com/ashwch/microverse/issues")!)
            }
            
            Text("© 2025 ashwch")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}