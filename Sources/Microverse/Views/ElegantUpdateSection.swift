import SwiftUI

struct ElegantUpdateSection: View {
    enum Style {
        case settings
        case card
    }

    var style: Style = .settings

    @EnvironmentObject var viewModel: BatteryViewModel
    @StateObject private var updateService = SecureUpdateService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SOFTWARE UPDATES")
                        .font(MicroverseDesign.Typography.label)
                        .foregroundColor(MicroverseDesign.Colors.accentSubtle)
                        .tracking(1.2)
                    
                    Text("Version \(updateService.currentVersion)")
                        .font(MicroverseDesign.Typography.body)
                        .foregroundColor(MicroverseDesign.Colors.accent)
                        .help("Current installed version")
                }
                
                Spacer()
                
                // Status Indicator
                updateStatusBadge
            }
            .padding(.horizontal, MicroverseDesign.Layout.space4)
            .padding(.vertical, MicroverseDesign.Layout.space3)
            
            // Automatic Updates Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatic Updates")
                        .font(MicroverseDesign.Typography.body)
                        .foregroundColor(.white)
                    
                    Text("Check for updates every 24 hours")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.checkForUpdatesAutomatically)
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
            }
            .padding(.horizontal, MicroverseDesign.Layout.space4)
            .padding(.vertical, MicroverseDesign.Layout.space3)
            .background(Color.black.opacity(0.2))
            
            // Update Status Card
            if updateService.updateAvailable || updateService.isCheckingForUpdates {
                updateStatusCard
                    .padding(.horizontal, MicroverseDesign.Layout.space4)
                    .padding(.vertical, MicroverseDesign.Layout.space3)
            } else {
                // Manual Check Button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Up to Date")
                            .font(MicroverseDesign.Typography.body.weight(.medium))
                            .foregroundColor(MicroverseDesign.Colors.success)
                        
                        if let lastCheck = updateService.lastUpdateCheck {
                            Text("Last checked \(formatLastCheck(lastCheck))")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    ElegantButton(
                        title: "Check Now",
                        style: .secondary,
                        action: {
                            updateService.checkForUpdates()
                        }
                    )
                    .disabled(updateService.isCheckingForUpdates)
                }
                .padding(.horizontal, MicroverseDesign.Layout.space4)
                .padding(.vertical, MicroverseDesign.Layout.space3)
            }
        }
        .background(MicroverseDesign.cardBackground())
        .padding(.horizontal, style == .settings ? MicroverseDesign.Layout.space3 : 0)
        .padding(.vertical, style == .settings ? MicroverseDesign.Layout.space3 : 0)
    }
    
    @ViewBuilder
    private var updateStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .tracking(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
        )
    }
    
    @ViewBuilder
    private var updateStatusCard: some View {
        VStack(spacing: MicroverseDesign.Layout.space3) {
            if updateService.isCheckingForUpdates {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Checking for updates...")
                        .font(MicroverseDesign.Typography.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
            } else if updateService.updateAvailable {
                VStack(spacing: MicroverseDesign.Layout.space2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Update Available")
                                .font(MicroverseDesign.Typography.body.weight(.semibold))
                                .foregroundColor(MicroverseDesign.Colors.success)
                            
                            if let version = updateService.latestVersion {
                                Text("Version \(version) is ready to install")
                                    .font(MicroverseDesign.Typography.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text("Release notes will be displayed during installation")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .italic()
                        }
                        
                        Spacer()
                        
                        ElegantButton(
                            title: "Install",
                            style: .primary,
                            action: {
                                // Use Sparkle's proper update flow
                                SecureUpdateService.shared.installUpdate()
                            }
                        )
                    }
                }
            }
        }
        .padding(MicroverseDesign.Layout.space3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(statusBorderColor, lineWidth: 1)
                )
        )
    }
    
    private var statusColor: Color {
        if updateService.isCheckingForUpdates {
            return MicroverseDesign.Colors.processor
        } else if updateService.updateAvailable {
            return MicroverseDesign.Colors.success
        } else {
            return MicroverseDesign.Colors.success
        }
    }
    
    private var statusText: String {
        if updateService.isCheckingForUpdates {
            return "CHECKING"
        } else if updateService.updateAvailable {
            return "UPDATE AVAILABLE"
        } else {
            return "UP TO DATE"
        }
    }
    
    private var statusBackgroundColor: Color {
        if updateService.updateAvailable {
            return MicroverseDesign.Colors.success.opacity(0.1)
        } else {
            return MicroverseDesign.Colors.processor.opacity(0.1)
        }
    }
    
    private var statusBorderColor: Color {
        if updateService.updateAvailable {
            return MicroverseDesign.Colors.success.opacity(0.3)
        } else {
            return MicroverseDesign.Colors.processor.opacity(0.3)
        }
    }
    
    private func formatLastCheck(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        
        let daysBetween = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        
        if daysBetween == 0 {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "today at \(formatter.string(from: date))"
        } else if daysBetween == 1 {
            return "yesterday"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return "on \(formatter.string(from: date))"
        }
    }
}

// MARK: - Elegant Design Components

struct ElegantToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: MicroverseDesign.Layout.space3)
                .fill(configuration.isOn ? MicroverseDesign.Colors.success : Color.gray.opacity(0.3))
                .frame(width: MicroverseDesign.Layout.space4 * 2.5, height: MicroverseDesign.Layout.space3 + 10)
                .overlay(
                    Circle()
                        .fill(MicroverseDesign.Colors.accent)
                        .frame(width: MicroverseDesign.Layout.space4 + 2, height: MicroverseDesign.Layout.space4 + 2)
                        .offset(x: configuration.isOn ? MicroverseDesign.Layout.space2 + 1 : -(MicroverseDesign.Layout.space2 + 1))
                        .animation(MicroverseDesign.Animation.notchToggle, value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

struct ElegantButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary
        
        var colors: (background: Color, foreground: Color, border: Color) {
            switch self {
            case .primary:
                return (MicroverseDesign.Colors.processor, .white, MicroverseDesign.Colors.processor)
            case .secondary:
                return (Color.clear, .white, Color.white.opacity(0.3))
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(style.colors.foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(style.colors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(style.colors.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
