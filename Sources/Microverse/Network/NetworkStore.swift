import CoreWLAN
import Foundation
import os.log

/// Aggregate network throughput (upload/download) for Microverse.
///
/// ## First principles
/// - **Glanceable:** show “what’s happening right now” (bytes/sec) plus lifetime-ish counters.
/// - **Low friction:** no special entitlements; uses `getifaddrs` interface byte counters.
/// - **Energy-aware:** sampling only runs while the UI surface that needs it is visible.
///
/// ## How it works
/// We periodically read `if_data` counters and compute deltas over time.
///
/// - `downloadBytesPerSecond` / `uploadBytesPerSecond`: best-effort sum of all active interfaces.
/// - `wifiDownloadBytesPerSecond` / `wifiUploadBytesPerSecond`: bytes/sec for the current Wi‑Fi interface (if any).
///
/// Rates are lightly smoothed with an EMA to avoid 0→spike→0 jitter in UI.
///
/// ## Usage
/// Call `start()`/`stop()` from view lifecycles (popover tabs, widget surfaces).
@MainActor
final class NetworkStore: ObservableObject {
    @Published private(set) var downloadBytesPerSecond: Double = 0
    @Published private(set) var uploadBytesPerSecond: Double = 0
    @Published private(set) var totalDownloadedBytes: UInt64 = 0
    @Published private(set) var totalUploadedBytes: UInt64 = 0
    @Published private(set) var wifiDownloadBytesPerSecond: Double = 0
    @Published private(set) var wifiUploadBytesPerSecond: Double = 0
    @Published private(set) var wifiTotalDownloadedBytes: UInt64 = 0
    @Published private(set) var wifiTotalUploadedBytes: UInt64 = 0
    @Published private(set) var lastUpdated: Date?

    private let logger = Logger(subsystem: "com.microverse.app", category: "NetworkStore")
    private var monitorTask: Task<Void, Never>?
    private var lastSample: (uptime: TimeInterval, inBytes: UInt64, outBytes: UInt64)?
    private var lastWifiSample: (uptime: TimeInterval, interfaceName: String, inBytes: UInt64, outBytes: UInt64)?
    private var emaDown: Double?
    private var emaUp: Double?
    private var emaWiFiDown: Double?
    private var emaWiFiUp: Double?
    private let emaAlpha: Double = 0.3

    func start(interval: TimeInterval = 1.0) {
        guard monitorTask == nil else { return }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--debug-screenshot-mode") {
            // Deterministic, “looks alive” values for docs screenshots.
            downloadBytesPerSecond = 2_400_000
            uploadBytesPerSecond = 320_000
            totalDownloadedBytes = 12_345_678_901
            totalUploadedBytes = 1_234_567_890
            wifiDownloadBytesPerSecond = 2_400_000
            wifiUploadBytesPerSecond = 320_000
            wifiTotalDownloadedBytes = 12_345_678_901
            wifiTotalUploadedBytes = 1_234_567_890
            lastUpdated = Date()
            logger.debug("NetworkStore screenshot mode started")
            return
        }
        #endif

        resetSamplerState()

        let initial = snapshot(interfaceFilter: nil)
        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        totalDownloadedBytes = initial.inBytes
        totalUploadedBytes = initial.outBytes
        lastSample = (uptime: uptime, inBytes: initial.inBytes, outBytes: initial.outBytes)

        if let wifiName = wifiInterfaceName() {
            let wifiInitial = snapshot(interfaceFilter: wifiName)
            wifiTotalDownloadedBytes = wifiInitial.inBytes
            wifiTotalUploadedBytes = wifiInitial.outBytes
            lastWifiSample = (
                uptime: uptime,
                interfaceName: wifiName,
                inBytes: wifiInitial.inBytes,
                outBytes: wifiInitial.outBytes
            )
        } else {
            wifiDownloadBytesPerSecond = 0
            wifiUploadBytesPerSecond = 0
            wifiTotalDownloadedBytes = 0
            wifiTotalUploadedBytes = 0
            lastWifiSample = nil
        }
        lastUpdated = now

        monitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(0.25, interval) * 1_000_000_000))
                } catch {
                    break
                }
                if Task.isCancelled { break }

                let now = Date()
                let uptime = ProcessInfo.processInfo.systemUptime

                self.tickAggregate(uptime: uptime, interval: interval)
                self.tickWiFi(uptime: uptime, interval: interval)
                self.lastUpdated = now
            }
        }

        logger.debug("NetworkStore started")
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        resetSamplerState()
        logger.debug("NetworkStore stopped")
    }

    func formattedRate(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        let base = formatter.string(fromByteCount: Int64(bytesPerSecond))
        return "\(base)/s"
    }

    func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func resetSamplerState() {
        lastSample = nil
        lastWifiSample = nil
        emaDown = nil
        emaUp = nil
        emaWiFiDown = nil
        emaWiFiUp = nil

        downloadBytesPerSecond = 0
        uploadBytesPerSecond = 0
        wifiDownloadBytesPerSecond = 0
        wifiUploadBytesPerSecond = 0
    }

    private func tickAggregate(uptime: TimeInterval, interval: TimeInterval) {
        let current = snapshot(interfaceFilter: nil)

        guard let last = lastSample else {
            totalDownloadedBytes = current.inBytes
            totalUploadedBytes = current.outBytes
            lastSample = (uptime: uptime, inBytes: current.inBytes, outBytes: current.outBytes)
            return
        }

        let dt = max(0.001, uptime - last.uptime)
        if dt > max(5.0, interval * 6.0) {
            // Large gaps (sleep/wake): reset baseline to avoid bogus spikes.
            totalDownloadedBytes = current.inBytes
            totalUploadedBytes = current.outBytes
            downloadBytesPerSecond = 0
            uploadBytesPerSecond = 0
            emaDown = nil
            emaUp = nil
            lastSample = (uptime: uptime, inBytes: current.inBytes, outBytes: current.outBytes)
            return
        }

        let downDelta = current.inBytes >= last.inBytes ? (current.inBytes - last.inBytes) : 0
        let upDelta = current.outBytes >= last.outBytes ? (current.outBytes - last.outBytes) : 0
        let downSample = Double(downDelta) / dt
        let upSample = Double(upDelta) / dt

        emaDown = ema(previous: emaDown, sample: downSample)
        emaUp = ema(previous: emaUp, sample: upSample)

        totalDownloadedBytes = current.inBytes
        totalUploadedBytes = current.outBytes
        downloadBytesPerSecond = emaDown ?? downSample
        uploadBytesPerSecond = emaUp ?? upSample
        lastSample = (uptime: uptime, inBytes: current.inBytes, outBytes: current.outBytes)
    }

    private func tickWiFi(uptime: TimeInterval, interval: TimeInterval) {
        guard let wifiName = wifiInterfaceName() else {
            wifiDownloadBytesPerSecond = 0
            wifiUploadBytesPerSecond = 0
            wifiTotalDownloadedBytes = 0
            wifiTotalUploadedBytes = 0
            lastWifiSample = nil
            emaWiFiDown = nil
            emaWiFiUp = nil
            return
        }

        let current = snapshot(interfaceFilter: wifiName)

        guard let last = lastWifiSample, last.interfaceName == wifiName else {
            wifiTotalDownloadedBytes = current.inBytes
            wifiTotalUploadedBytes = current.outBytes
            wifiDownloadBytesPerSecond = 0
            wifiUploadBytesPerSecond = 0
            emaWiFiDown = nil
            emaWiFiUp = nil
            lastWifiSample = (
                uptime: uptime,
                interfaceName: wifiName,
                inBytes: current.inBytes,
                outBytes: current.outBytes
            )
            return
        }

        let dt = max(0.001, uptime - last.uptime)
        if dt > max(5.0, interval * 6.0) {
            // Large gaps (sleep/wake): reset baseline to avoid bogus spikes.
            wifiTotalDownloadedBytes = current.inBytes
            wifiTotalUploadedBytes = current.outBytes
            wifiDownloadBytesPerSecond = 0
            wifiUploadBytesPerSecond = 0
            emaWiFiDown = nil
            emaWiFiUp = nil
            lastWifiSample = (
                uptime: uptime,
                interfaceName: wifiName,
                inBytes: current.inBytes,
                outBytes: current.outBytes
            )
            return
        }

        let downDelta = current.inBytes >= last.inBytes ? (current.inBytes - last.inBytes) : 0
        let upDelta = current.outBytes >= last.outBytes ? (current.outBytes - last.outBytes) : 0
        let downSample = Double(downDelta) / dt
        let upSample = Double(upDelta) / dt

        emaWiFiDown = ema(previous: emaWiFiDown, sample: downSample)
        emaWiFiUp = ema(previous: emaWiFiUp, sample: upSample)

        wifiTotalDownloadedBytes = current.inBytes
        wifiTotalUploadedBytes = current.outBytes
        wifiDownloadBytesPerSecond = emaWiFiDown ?? downSample
        wifiUploadBytesPerSecond = emaWiFiUp ?? upSample
        lastWifiSample = (
            uptime: uptime,
            interfaceName: wifiName,
            inBytes: current.inBytes,
            outBytes: current.outBytes
        )
    }

    private func ema(previous: Double?, sample: Double) -> Double {
        guard let previous else { return sample }
        return previous + emaAlpha * (sample - previous)
    }

    private func wifiInterfaceName() -> String? {
        guard let iface = CWWiFiClient.shared().interface(), iface.powerOn() else { return nil }
        return iface.interfaceName
    }

    private func snapshot(interfaceFilter: String?) -> (inBytes: UInt64, outBytes: UInt64) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return (0, 0) }
        defer { freeifaddrs(addrs) }

        if let interfaceFilter {
            if let data = linkData(for: interfaceFilter, in: first) {
                return data
            }
            return (0, 0)
        }

        var inBytes: UInt64 = 0
        var outBytes: UInt64 = 0
        var seenInterfaces = Set<String>()

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let addr = ptr.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: ptr.pointee.ifa_name)
            if seenInterfaces.contains(name) { continue }
            seenInterfaces.insert(name)

            let flags = ptr.pointee.ifa_flags
            if (flags & UInt32(IFF_LOOPBACK)) != 0 { continue }
            if (flags & UInt32(IFF_UP)) == 0 { continue }

            guard let raw = ptr.pointee.ifa_data else { continue }
            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            inBytes += UInt64(data.ifi_ibytes)
            outBytes += UInt64(data.ifi_obytes)
        }
        return (inBytes, outBytes)
    }

    private func linkData(for interfaceName: String, in first: UnsafeMutablePointer<ifaddrs>) -> (inBytes: UInt64, outBytes: UInt64)? {
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let addr = ptr.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: ptr.pointee.ifa_name)
            guard name == interfaceName else { continue }

            let flags = ptr.pointee.ifa_flags
            if (flags & UInt32(IFF_LOOPBACK)) != 0 { return nil }
            if (flags & UInt32(IFF_UP)) == 0 { return nil }

            guard let raw = ptr.pointee.ifa_data else { return nil }
            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            return (UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes))
        }
        return nil
    }
}
