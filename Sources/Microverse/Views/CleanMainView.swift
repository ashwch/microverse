import SwiftUI
import AppKit
import BatteryCore

struct CleanMainView: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Battery Status
            BatteryStatusCard(info: viewModel.batteryInfo)
            
            // Battery Info
            BatteryInfoCards(info: viewModel.batteryInfo)
            
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

