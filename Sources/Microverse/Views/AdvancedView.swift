import SwiftUI
import BatteryCore
import SMCKit

struct AdvancedView: View {
    @ObservedObject var viewModel: BatteryViewModel
    @State private var smcDiagnostics = ""
    @State private var isRunningDiagnostics = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced Settings")
                .font(.title2)
                .bold()
            
            // Refresh interval
            HStack {
                Text("Refresh Interval:")
                Picker("", selection: $viewModel.refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                .pickerStyle(MenuPickerStyle())
                .fixedSize()
            }
            
            Divider()
            
            // SMC Diagnostics
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SMC Diagnostics")
                        .font(.headline)
                    
                    Spacer()
                    
                    if isRunningDiagnostics {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Run Diagnostics") {
                            runSMCDiagnostics()
                        }
                    }
                }
                
                if !smcDiagnostics.isEmpty {
                    ScrollView {
                        Text(smcDiagnostics)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                    .frame(height: 200)
                }
                
                Text("SMC diagnostics help identify available battery control features")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func runSMCDiagnostics() {
        isRunningDiagnostics = true
        smcDiagnostics = ""
        
        Task {
            let tester = SMCTester()
            let report = await Task.detached(priority: .userInitiated) {
                tester.getDiagnosticReport()
            }.value
            
            await MainActor.run {
                smcDiagnostics = report
                isRunningDiagnostics = false
            }
        }
    }
}