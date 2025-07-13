import SwiftUI
import BatteryCore


struct HelperInstallationView: View {
    @State private var installationState: InstallationState = .notInstalled
    @State private var errorMessage: String?
    @State private var isInstalling = false
    
    private let helperManager = HelperManager()
    
    enum InstallationState {
        case notInstalled
        case installing
        case installed
        case testingConnection
        case ready
        case error(String)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Enable Battery Control")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Microverse needs to install a small helper tool to control your battery. This is the same approach used by AlDente and other battery apps.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 8) {
                Text("What you'll be able to do:")
                    .font(.headline)
                
                BenefitRow(icon: "battery.75.bolt", text: "Set charge limits (20-100% on Intel, 80%/100% on Apple Silicon)")
                BenefitRow(icon: "power", text: "Enable/disable charging on demand")
                BenefitRow(icon: "thermometer", text: "Read precise battery temperature")
                BenefitRow(icon: "arrow.2.circlepath", text: "Monitor battery cycles and health")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Security info
            VStack(alignment: .leading, spacing: 8) {
                Text("Security & Privacy:")
                    .font(.headline)
                
                SecurityRow(icon: "lock.shield", text: "Helper runs only when needed")
                SecurityRow(icon: "checkmark.seal", text: "Code-signed and sandboxed")
                SecurityRow(icon: "xmark.circle", text: "No network access or data collection")
                SecurityRow(icon: "trash", text: "Can be removed anytime from settings")
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Installation status and button
            VStack(spacing: 16) {
                switch installationState {
                case .notInstalled:
                    Button(action: installHelper) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Install Helper Tool")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isInstalling)
                    
                case .installing:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Installing helper tool...")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                case .installed:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Helper tool installed")
                    }
                    .font(.subheadline)
                    
                case .testingConnection:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Testing connection...")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                case .ready:
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Battery control is ready!")
                        }
                        .font(.headline)
                        
                        Button("Continue") {
                            // Close this view and enable battery features
                            NotificationCenter.default.post(name: .helperInstalled, object: nil)
                        }
                    }
                    
                case .error(let message):
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Installation failed")
                        }
                        .font(.headline)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            installHelper()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // Technical details (collapsible)
            DisclosureGroup("Technical Details") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Helper tool location: /Library/PrivilegedHelperTools/")
                    Text("• Communication: Secure XPC (Inter-Process Communication)")
                    Text("• Privileges: SMC (System Management Controller) write access")
                    Text("• Installation method: SMJobBless (Apple's recommended approach)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            checkHelperStatus()
        }
    }
    
    private func checkHelperStatus() {
        if helperManager.isHelperInstalled() {
            installationState = .testingConnection
            testConnection()
        } else {
            installationState = .notInstalled
        }
    }
    
    private func installHelper() {
        installationState = .installing
        isInstalling = true
        
        helperManager.installHelper { success, error in
            DispatchQueue.main.async {
                self.isInstalling = false
                
                if success {
                    self.installationState = .installed
                    // Test the connection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.testConnection()
                    }
                } else {
                    let message = error?.localizedDescription ?? "Unknown error occurred"
                    self.installationState = .error(message)
                }
            }
        }
    }
    
    private func testConnection() {
        installationState = .testingConnection
        
        helperManager.testHelper { success, version in
            DispatchQueue.main.async {
                if success {
                    self.installationState = .ready
                } else {
                    self.installationState = .error("Helper installed but connection failed")
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct SecurityRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// Notification for when helper is installed
extension Notification.Name {
    static let helperInstalled = Notification.Name("helperInstalled")
}