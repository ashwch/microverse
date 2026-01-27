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
/// We periodically read `if_data` counters for all active, non-loopback interfaces and compute deltas over time.
/// This is an approximation (it’s not per-process and it’s not “internet reachability”), but it’s stable and fast.
///
/// ## Usage
/// Call `start()`/`stop()` from view lifecycles (popover tabs, widget surfaces).
@MainActor
final class NetworkStore: ObservableObject {
    @Published private(set) var downloadBytesPerSecond: Double = 0
    @Published private(set) var uploadBytesPerSecond: Double = 0
    @Published private(set) var totalDownloadedBytes: UInt64 = 0
    @Published private(set) var totalUploadedBytes: UInt64 = 0
    @Published private(set) var lastUpdated: Date?

    private let logger = Logger(subsystem: "com.microverse.app", category: "NetworkStore")
    private var monitorTask: Task<Void, Never>?
    private var lastSample: (at: Date, inBytes: UInt64, outBytes: UInt64)?

    func start(interval: TimeInterval = 1.0) {
        guard monitorTask == nil else { return }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--debug-screenshot-mode") {
            // Deterministic, “looks alive” values for docs screenshots.
            downloadBytesPerSecond = 2_400_000
            uploadBytesPerSecond = 320_000
            totalDownloadedBytes = 12_345_678_901
            totalUploadedBytes = 1_234_567_890
            lastUpdated = Date()
            logger.debug("NetworkStore screenshot mode started")
            return
        }
        #endif

        let initial = snapshot()
        let now = Date()
        totalDownloadedBytes = initial.inBytes
        totalUploadedBytes = initial.outBytes
        lastSample = (at: now, inBytes: initial.inBytes, outBytes: initial.outBytes)
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
                let current = self.snapshot()

                guard let last = self.lastSample else {
                    self.lastSample = (at: now, inBytes: current.inBytes, outBytes: current.outBytes)
                    continue
                }

                let dt = max(0.001, now.timeIntervalSince(last.at))
                let downDelta = current.inBytes >= last.inBytes ? (current.inBytes - last.inBytes) : 0
                let upDelta = current.outBytes >= last.outBytes ? (current.outBytes - last.outBytes) : 0

                self.totalDownloadedBytes = current.inBytes
                self.totalUploadedBytes = current.outBytes
                self.downloadBytesPerSecond = Double(downDelta) / dt
                self.uploadBytesPerSecond = Double(upDelta) / dt
                self.lastSample = (at: now, inBytes: current.inBytes, outBytes: current.outBytes)
                self.lastUpdated = now
            }
        }

        logger.debug("NetworkStore started")
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
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

    private func snapshot() -> (inBytes: UInt64, outBytes: UInt64) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return (0, 0) }
        defer { freeifaddrs(addrs) }

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
}
