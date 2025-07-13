import WidgetKit
import SwiftUI
import BatteryCore

// Helper for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Check if containerBackground is available
var containerBackgroundAvailable: Bool {
    if #available(iOS 17.0, macOS 14.0, *) {
        return true
    } else {
        return false
    }
}

// MARK: - Widget Provider

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: Date(), batteryInfo: BatteryInfo.placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> ()) {
        let entry = BatteryEntry(date: Date(), batteryInfo: getCurrentBatteryInfo())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [BatteryEntry] = []
        let currentDate = Date()
        let batteryInfo = getCurrentBatteryInfo()
        
        // Create timeline entries for the next hour, updating every 5 minutes
        for minuteOffset in stride(from: 0, to: 60, by: 5) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = BatteryEntry(date: entryDate, batteryInfo: batteryInfo)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func getCurrentBatteryInfo() -> BatteryInfo {
        guard let controller = try? BatteryController() else {
            return BatteryInfo.placeholder
        }
        
        let status = controller.getBatteryStatus()
        return BatteryInfo(
            percentage: status.currentCharge,
            isCharging: status.isCharging,
            isPluggedIn: status.isPluggedIn,
            temperature: status.temperature,
            health: Int(status.health * 100),
            cycleCount: status.cycleCount,
            mode: UserDefaults(suiteName: "group.microverse")?.string(forKey: "managementMode") ?? "adaptive"
        )
    }
}

// MARK: - Widget Entry

struct BatteryEntry: TimelineEntry {
    let date: Date
    let batteryInfo: BatteryInfo
}

struct BatteryInfo {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let temperature: Double
    let health: Int
    let cycleCount: Int
    let mode: String
    
    static let placeholder = BatteryInfo(
        percentage: 80,
        isCharging: true,
        isPluggedIn: true,
        temperature: 25.0,
        health: 95,
        cycleCount: 150,
        mode: "adaptive"
    )
}

// MARK: - Widget Views

struct BatteryWidgetEntryView : View {
    var entry: BatteryProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallBatteryWidget(info: entry.batteryInfo)
        case .systemMedium:
            MediumBatteryWidget(info: entry.batteryInfo)
        case .systemLarge:
            LargeBatteryWidget(info: entry.batteryInfo)
        case .accessoryCircular:
            CircularBatteryWidget(info: entry.batteryInfo)
        case .accessoryRectangular:
            RectangularBatteryWidget(info: entry.batteryInfo)
        case .accessoryInline:
            InlineBatteryWidget(info: entry.batteryInfo)
        default:
            SmallBatteryWidget(info: entry.batteryInfo)
        }
    }
}

// MARK: - Small Widget

struct SmallBatteryWidget: View {
    let info: BatteryInfo
    
    var batteryColor: Color {
        if info.percentage <= 20 {
            return .red
        } else if info.percentage <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Battery Icon
            ZStack {
                Image(systemName: info.isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 40))
                    .foregroundColor(batteryColor)
                    .symbolRenderingMode(.hierarchical)
                
                Text("\(info.percentage)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("\(info.percentage)%")
                .font(.system(size: 24, weight: .bold))
            
            HStack(spacing: 4) {
                Image(systemName: info.isCharging ? "bolt.fill" : "bolt.slash")
                    .font(.caption)
                Text(info.isCharging ? "Charging" : "Not Charging")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .if(containerBackgroundAvailable) { view in
            view.containerBackground(for: .widget) {
                Color.clear
            }
        }
    }
}

// MARK: - Medium Widget

struct MediumBatteryWidget: View {
    let info: BatteryInfo
    
    var body: some View {
        HStack(spacing: 20) {
            // Left side - battery visual
            VStack(spacing: 8) {
                BatteryVisual(percentage: info.percentage, isCharging: info.isCharging)
                    .frame(width: 100, height: 50)
                
                Text("\(info.percentage)%")
                    .font(.title2.bold())
            }
            
            // Right side - details
            VStack(alignment: .leading, spacing: 6) {
                Label(info.isCharging ? "Charging" : "Not Charging", 
                      systemImage: info.isCharging ? "bolt.fill" : "bolt.slash")
                    .font(.caption)
                
                Label("\(info.temperature, specifier: "%.1f")°C", 
                      systemImage: "thermometer")
                    .font(.caption)
                
                Label("\(info.health)% Health", 
                      systemImage: "heart.fill")
                    .font(.caption)
                
                Label(info.mode.capitalized + " Mode", 
                      systemImage: "cpu")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .if(containerBackgroundAvailable) { view in
            view.containerBackground(for: .widget) {
                Color.clear
            }
        }
    }
}

// MARK: - Large Widget

struct LargeBatteryWidget: View {
    let info: BatteryInfo
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Battery Manager")
                    .font(.headline)
                Spacer()
                Text(Date(), style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Battery Visual
            BatteryVisual(percentage: info.percentage, isCharging: info.isCharging)
                .frame(height: 80)
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Charge", value: "\(info.percentage)%", icon: "battery.100")
                StatCard(title: "Health", value: "\(info.health)%", icon: "heart.fill")
                StatCard(title: "Temperature", value: "\(info.temperature, specifier: "%.1f")°C", icon: "thermometer")
                StatCard(title: "Cycles", value: "\(info.cycleCount)", icon: "arrow.2.circlepath")
            }
            
            // Mode indicator
            HStack {
                Label(info.mode.capitalized + " Mode Active", systemImage: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .if(containerBackgroundAvailable) { view in
            view.containerBackground(for: .widget) {
                Color.clear
            }
        }
    }
}

// MARK: - Accessory Widgets

struct CircularBatteryWidget: View {
    let info: BatteryInfo
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: info.isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.title3)
                Text("\(info.percentage)%")
                    .font(.caption2)
            }
        }
    }
}

struct RectangularBatteryWidget: View {
    let info: BatteryInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Battery")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(info.percentage)%")
                    .font(.system(.title3, design: .rounded))
                    .bold()
            }
            Spacer()
            Image(systemName: info.isCharging ? "bolt.fill" : "battery.100")
                .font(.title2)
        }
        .if(containerBackgroundAvailable) { view in
            view.containerBackground(for: .widget) {
                Color.clear
            }
        }
    }
}

struct InlineBatteryWidget: View {
    let info: BatteryInfo
    
    var body: some View {
        ViewThatFits {
            Text("Battery: \(info.percentage)% \(info.isCharging ? "charging" : "")")
            Text("\(info.percentage)% \(info.isCharging ? "⚡" : "")")
            Text("\(info.percentage)%")
        }
    }
}

// MARK: - Helper Views

struct BatteryVisual: View {
    let percentage: Int
    let isCharging: Bool
    
    var batteryColor: Color {
        if percentage <= 20 {
            return .red
        } else if percentage <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Battery outline
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary, lineWidth: 2)
                
                // Battery fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(batteryColor.opacity(0.8))
                    .frame(width: geometry.size.width * CGFloat(percentage) / 100.0)
                    .padding(2)
                
                // Charging indicator
                if isCharging {
                    HStack {
                        Spacer()
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.system(.body, design: .rounded))
                .bold()
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Widget Configuration

@main
struct MicroverseWidget: Widget {
    let kind: String = "MicroverseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryProvider()) { entry in
            BatteryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Battery Status")
        .description("Monitor your MacBook battery health and status")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}