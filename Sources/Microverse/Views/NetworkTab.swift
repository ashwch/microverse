import SwiftUI

/// System → Network popover section.
///
/// This view combines:
/// - `WiFiStore` for connection state + signal strength (glanceable, best-effort SSID).
/// - `NetworkStore` for aggregate up/down throughput.
struct NetworkTab: View {
    @EnvironmentObject private var network: NetworkStore
    @EnvironmentObject private var wifi: WiFiStore

    var body: some View {
        VStack(spacing: 8) {
            wifiCard
            throughputCard
            totalsCard
        }
        .padding(8)
        .onAppear {
            network.start()
            wifi.start()
        }
        .onDisappear {
            network.stop()
            wifi.stop()
        }
    }

    private var wifiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("WI‑FI", systemIcon: "wifi")

            HStack(alignment: .center, spacing: 12) {
                wifiStatusIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(wifiTitleText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(1)

                    Text(wifiSubtitleText)
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                if case .connected = wifi.status, let percent = wifi.signalPercent {
                    HStack(spacing: 6) {
                        WiFiStrengthBars(bars: wifi.signalBars)
                        Text("\(percent)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }
            }

            if case .connected = wifi.status {
                Text(wifiDetailsText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            if let updated = wifi.lastUpdated {
                Text("Updated \(relativeTime(from: Date(), to: updated))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(12)
        .background(MicroverseDesign.cardBackground())
    }

    private var throughputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("NETWORK", systemIcon: "network")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12, alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                ],
                spacing: 0
            ) {
                rateColumn(
                    title: "DOWNLOAD",
                    icon: "arrow.down",
                    color: MicroverseDesign.Colors.success,
                    value: network.formattedRate(network.downloadBytesPerSecond)
                )
                rateColumn(
                    title: "UPLOAD",
                    icon: "arrow.up",
                    color: MicroverseDesign.Colors.warning,
                    value: network.formattedRate(network.uploadBytesPerSecond)
                )
            }

            if let updated = network.lastUpdated {
                Text("Updated \(relativeTime(from: Date(), to: updated))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(MicroverseDesign.cardBackground())
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("TOTALS", systemIcon: "chart.bar")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DOWNLOADED")
                        .font(MicroverseDesign.Typography.label)
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(0.8)
                    Text(network.formattedBytes(network.totalDownloadedBytes))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("UPLOADED")
                        .font(MicroverseDesign.Typography.label)
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(0.8)
                    Text(network.formattedBytes(network.totalUploadedBytes))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .background(MicroverseDesign.cardBackground())
    }

    private func rateColumn(title: String, icon: String, color: Color, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color.opacity(0.9))
                Text(title)
                    .font(MicroverseDesign.Typography.label)
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(0.8)
            }

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func relativeTime(from now: Date, to date: Date) -> String {
        let delta = now.timeIntervalSince(date)
        if delta < 2 { return "just now" }
        if delta < 60 { return "\(Int(delta))s ago" }
        let minutes = Int((delta / 60).rounded(.down))
        return "\(minutes)m ago"
    }

    private var wifiTitleText: String {
        switch wifi.status {
        case .unavailable:
            return "Wi‑Fi unavailable"
        case .poweredOff:
            return "Wi‑Fi off"
        case .disconnected:
            return "Not connected"
        case .connected(let name):
            return name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (name ?? "Connected") : "Connected"
        }
    }

    private var wifiSubtitleText: String {
        switch wifi.status {
        case .connected:
            return wifi.qualityText
        case .poweredOff:
            return "Turn on Wi‑Fi to see signal strength"
        case .disconnected:
            return "No active Wi‑Fi network"
        case .unavailable:
            return "No Wi‑Fi interface detected"
        }
    }

    private var wifiDetailsText: String {
        var parts: [String] = []

        if let rssi = wifi.rssi {
            parts.append("RSSI \(rssi)dBm")
        }
        if let noise = wifi.noise {
            parts.append("Noise \(noise)dBm")
        }
        if let snr = wifi.snr {
            parts.append("SNR \(snr)dB")
        }
        if let rate = wifi.transmitRateMbps {
            parts.append(String(format: "Tx %.0f Mbps", rate))
        }

        if parts.isEmpty { return "—" }
        return parts.joined(separator: " • ")
    }

    private var wifiStatusIcon: some View {
        let icon: String
        let color: Color

        switch wifi.status {
        case .unavailable:
            icon = "wifi.slash"
            color = .white.opacity(0.5)
        case .poweredOff:
            icon = "wifi.slash"
            color = .white.opacity(0.6)
        case .disconnected:
            icon = "wifi"
            color = .white.opacity(0.65)
        case .connected:
            icon = "wifi"
            color = MicroverseDesign.Colors.success.opacity(0.85)
        }

        return Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 22, height: 22, alignment: .center)
    }
}

private struct WiFiStrengthBars: View {
    let bars: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(0)
            bar(1)
            bar(2)
        }
        .frame(height: 12)
        .accessibilityLabel("Wi‑Fi signal strength")
        .accessibilityValue("\(max(0, min(3, bars))) of 3 bars")
    }

    private func bar(_ idx: Int) -> some View {
        let height = CGFloat(4 + (idx * 3))
        let isOn = idx < bars

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white.opacity(isOn ? 0.9 : 0.18))
            .frame(width: 3, height: height)
    }
}
