import SwiftUI
import BatteryCore
import AppKit


struct BatteryControlGuideView: View {
    @State private var features = BatteryControlFeatures()
    @State private var showingTerminalInstructions = false
    
    private let batteryControl = SimpleBatteryControl()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "battery.75.bolt")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Enable Battery Control")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Battery control requires administrator privileges to access hardware directly")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Current Status
            StatusCard(features: features)
            
            // Instructions based on user's situation
            if features.canRequestAdmin {
                AdminUserInstructions(showingTerminalInstructions: $showingTerminalInstructions)
            } else {
                StandardUserInstructions()
            }
            
            // What you can do now
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Now (No Admin Required):")
                    .font(.headline)
                
                FeatureRow(icon: "chart.line.uptrend.xyaxis", 
                          text: "Real-time battery monitoring",
                          available: true)
                
                FeatureRow(icon: "thermometer", 
                          text: "Battery temperature reading",
                          available: true)
                
                FeatureRow(icon: "heart.text.square", 
                          text: "Battery health assessment",
                          available: true)
                
                FeatureRow(icon: "arrow.2.circlepath", 
                          text: "Cycle count tracking",
                          available: true)
                
                if features.isAppleSilicon && features.canUseBatteryOptimization {
                    FeatureRow(icon: "leaf.fill", 
                              text: "Basic battery optimization (80% limit)",
                              available: true)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // What requires admin
            VStack(alignment: .leading, spacing: 12) {
                Text("Requires Administrator Access:")
                    .font(.headline)
                
                FeatureRow(icon: "slider.horizontal.3", 
                          text: "Custom charge limits",
                          available: false)
                
                FeatureRow(icon: "power", 
                          text: "Enable/disable charging",
                          available: false)
                
                FeatureRow(icon: "cpu", 
                          text: "Direct SMC hardware access",
                          available: false)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            features = batteryControl.getAvailableFeatures()
        }
        .sheet(isPresented: $showingTerminalInstructions) {
            TerminalInstructionsView()
        }
    }
}

struct StatusCard: View {
    let features: BatteryControlFeatures
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                StatusRow(label: "User Type", 
                         value: features.canRequestAdmin ? "Administrator" : "Standard User",
                         isGood: features.canRequestAdmin)
                
                StatusRow(label: "Hardware", 
                         value: features.isAppleSilicon ? "Apple Silicon" : "Intel",
                         isGood: true)
                
                StatusRow(label: "Battery Control", 
                         value: features.canControlSMC ? "Available" : "Requires Setup",
                         isGood: features.canControlSMC)
                
                StatusRow(label: "Built-in Optimization", 
                         value: features.canUseBatteryOptimization ? "Available" : "Not Available",
                         isGood: features.canUseBatteryOptimization)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let isGood: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack {
                Image(systemName: isGood ? "checkmark.circle.fill" : "info.circle.fill")
                    .foregroundColor(isGood ? .green : .orange)
                
                Text(value)
                    .fontWeight(.medium)
            }
        }
        .font(.subheadline)
    }
}

struct AdminUserInstructions: View {
    @Binding var showingTerminalInstructions: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You're an Administrator! 🎉")
                .font(.headline)
                .foregroundColor(.green)
            
            Text("You can enable battery control features:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                InstructionStep(number: "1", 
                               title: "Close Microverse",
                               description: "Quit the current Microverse app first")
                
                InstructionStep(number: "2", 
                               title: "Use Terminal Method",
                               description: "Click 'Show Terminal Method' below for the working approach")
                
                InstructionStep(number: "3", 
                               title: "Enjoy Full Battery Control",
                               description: "Set custom charge limits and control charging")
            }
            
            HStack {
                Button("Show Terminal Method") {
                    showingTerminalInstructions = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("I'll Set This Up Later") {
                    // Close this view
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StandardUserInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Standard User Account")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("Your account doesn't have administrator privileges. You have a few options:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                InstructionStep(number: "1", 
                               title: "Ask Your IT Administrator",
                               description: "They can make your account an administrator or run Microverse for you")
                
                InstructionStep(number: "2", 
                               title: "Use Read-Only Features",
                               description: "Monitor battery health, temperature, and cycles without control features")
                
                InstructionStep(number: "3", 
                               title: "Use Built-in macOS Features",
                               description: "Go to System Preferences → Battery → Battery Health for basic optimization")
            }
            
            Button("Continue with Monitoring Only") {
                // Close this view and continue with read-only features
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InstructionStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let available: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(available ? .green : .orange)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .strikethrough(!available)
                .foregroundColor(available ? .primary : .secondary)
            
            Spacer()
            
            if available {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
}

struct TerminalInstructionsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Terminal Method")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Alternative method using Terminal.app")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                InstructionStep(number: "1", 
                               title: "Open Terminal",
                               description: "Press Cmd+Space, type 'Terminal', and press Enter")
                
                InstructionStep(number: "2", 
                               title: "Run Microverse with Admin Rights",
                               description: "Copy and paste this command:")
                
                // Command to copy
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("sudo /Applications/Microverse.app/Contents/MacOS/Microverse")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button("Copy") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString("sudo /Applications/Microverse.app/Contents/MacOS/Microverse", forType: .string)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("⚠️ You'll be prompted for your Mac password")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                InstructionStep(number: "3", 
                               title: "Enter Your Password",
                               description: "Type your Mac login password (text won't appear as you type)")
                
                InstructionStep(number: "4", 
                               title: "Battery Control Enabled",
                               description: "Microverse will restart with full battery control access")
            }
            
            // Warning
            VStack(alignment: .leading, spacing: 8) {
                Text("ℹ️ Why is this needed?")
                    .font(.headline)
                
                Text("Battery control requires direct access to your Mac's System Management Controller (SMC). This is the same requirement as AlDente and other battery apps. Apple restricts this access for security reasons.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Close button
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding()
        .frame(width: 500)
    }
}