import CoreWLAN
import Foundation
import os.log

/// Lightweight Wi‑Fi “glance” state for Microverse.
///
/// ## First principles
/// - **Glanceable:** provide a small set of stable, UI-friendly fields (status + bars + percent).
/// - **Privacy-safe by default:** we do not scan for networks; we only read the *current* Wi‑Fi interface.
///   On newer macOS versions the SSID may be redacted (often due to privacy controls). When that happens,
///   Microverse still treats link metrics as “connected” and simply omits the name.
/// - **Energy-aware:** polling is coarse (default 2s) and only runs while at least one view is observing.
///
/// ## Usage
/// Call `start()` in `onAppear` and `stop()` in `onDisappear`.
/// Multiple callers are safe — we ref-count active clients so popover/notch/widget can share the same store.
@MainActor
final class WiFiStore: ObservableObject {
    enum Status: Equatable, Sendable {
        case unavailable
        case poweredOff
        case disconnected
        case connected(networkName: String?)
    }

    @Published private(set) var status: Status = .unavailable
    @Published private(set) var rssi: Int?
    @Published private(set) var noise: Int?
    @Published private(set) var transmitRateMbps: Double?
    @Published private(set) var lastUpdated: Date?

    private let logger = Logger(subsystem: "com.microverse.app", category: "WiFiStore")
    private var monitorTask: Task<Void, Never>?
    private var activeClients = 0
    private var lastFilterUptime: TimeInterval?

    private struct EWMA {
        private(set) var value: Double?

        mutating func reset() {
            value = nil
        }

        mutating func update(sample: Double, alpha: Double) {
            let a = max(0.0, min(1.0, alpha))
            if let value {
                self.value = value + a * (sample - value)
            } else {
                value = sample
            }
        }
    }

    private var rssiFilter = EWMA()
    private var noiseFilter = EWMA()
    private let filterTimeConstant: TimeInterval = 4.0

    #if DEBUG
    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-screenshot-mode")
    }
    #endif

    func start(interval: TimeInterval = 2.0) {
        activeClients += 1
        guard monitorTask == nil else { return }

        #if DEBUG
        if isScreenshotMode {
            refresh(reason: "screenshot")
            logger.debug("WiFiStore screenshot mode started")
            return
        }
        #endif

        refresh(reason: "start")

        monitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(0.75, interval) * 1_000_000_000))
                } catch {
                    break
                }
                if Task.isCancelled { break }
                self.refresh(reason: "timer")
            }
        }

        logger.debug("WiFiStore started (clients=\(self.activeClients))")
    }

    func stop() {
        activeClients = max(0, activeClients - 1)
        guard activeClients == 0 else { return }

        monitorTask?.cancel()
        monitorTask = nil
        lastFilterUptime = nil
        rssiFilter.reset()
        noiseFilter.reset()
        logger.debug("WiFiStore stopped")
    }

    func refresh(reason: String) {
        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime

        #if DEBUG
        if isScreenshotMode {
            // Privacy-safe, deterministic values for website/docs screenshots.
            status = .connected(networkName: nil)  // Avoid leaking SSID in captures.
            rssi = -55
            noise = -92
            transmitRateMbps = 866
            lastUpdated = now
            return
        }
        #endif

        let wasConnected: Bool = {
            if case .connected = status { return true }
            return false
        }()

        guard let iface = CWWiFiClient.shared().interface() else {
            status = .unavailable
            rssi = nil
            noise = nil
            transmitRateMbps = nil
            lastUpdated = now
            resetFilters()
            return
        }

        guard iface.powerOn() else {
            status = .poweredOff
            rssi = nil
            noise = nil
            transmitRateMbps = nil
            lastUpdated = now
            resetFilters()
            return
        }

        let name = iface.ssid()
        let nextRSSI = iface.rssiValue()
        let nextNoise = iface.noiseMeasurement()
        let nextRate = iface.transmitRate()

        // SSID can be redacted by privacy controls on newer macOS versions. If we have any link metrics,
        // treat this as connected even when the name is unavailable.
        let rssiValue = nextRSSI == 0 || nextRSSI == Int.min ? nil : nextRSSI
        let noiseValue = nextNoise == 0 || nextNoise == Int.min ? nil : nextNoise
        let looksConnected = name != nil || rssiValue != nil || nextRate > 0

        status = looksConnected ? .connected(networkName: name) : .disconnected
        rssi = rssiValue
        noise = noiseValue
        transmitRateMbps = nextRate > 0 ? nextRate : nil
        lastUpdated = now

        let isConnected: Bool = {
            if case .connected = status { return true }
            return false
        }()

        if wasConnected != isConnected, !isConnected {
            resetFilters()
        } else if isConnected {
            updateFilters(uptime: uptime, rssi: rssiValue, noise: noiseValue)
        }

        #if DEBUG
        logger.debug("WiFi refresh reason=\(reason, privacy: .public) status=\(String(describing: self.status), privacy: .public)")
        #endif
    }

    var signalPercent: Int? {
        // Prefer SNR (industry-standard measure of Wi‑Fi link quality) when available.
        if let snr = filteredSNR {
            // Map SNR [10 dB ... 50 dB] → [0% ... 100%]
            return linearPercent(value: snr, low: 10, high: 50)
        }

        // Fallback: RSSI-only mapping when noise data is unavailable.
        guard let rssi = filteredRSSI else { return nil }
        // Map RSSI [-95 ... -30] dBm → [0% ... 100%]
        return linearPercent(value: rssi, low: -95, high: -30)
    }

    var snr: Int? {
        guard let rssi, let noise else { return nil }
        return rssi - noise
    }

    var signalBars: Int {
        if let snr = filteredSNR {
            switch snr {
            case 35...:
                return 3
            case 25..<35:
                return 2
            case 15..<25:
                return 1
            default:
                return 0
            }
        }

        guard let rssi = filteredRSSI else { return 0 }
        switch rssi {
        case (-50)...:
            return 3
        case (-65)...(-51):
            return 2
        case (-75)...(-66):
            return 1
        default:
            return 0
        }
    }

    var qualityText: String {
        guard signalPercent != nil else { return "—" }
        switch signalBars {
        case 3:
            return "Excellent"
        case 2:
            return "Good"
        case 1:
            return "Fair"
        default:
            return "Weak"
        }
    }

    private var filteredRSSI: Double? {
        rssiFilter.value ?? rssi.map(Double.init)
    }

    private var filteredNoise: Double? {
        noiseFilter.value ?? noise.map(Double.init)
    }

    private var filteredSNR: Double? {
        guard let rssi = filteredRSSI, let noise = filteredNoise else { return nil }
        return rssi - noise
    }

    private func updateFilters(uptime: TimeInterval, rssi: Int?, noise: Int?) {
        let dt = max(0.0, uptime - (lastFilterUptime ?? uptime))
        lastFilterUptime = uptime

        let alpha: Double
        if dt <= 0 {
            alpha = 1.0
        } else {
            alpha = 1.0 - exp(-dt / max(0.1, filterTimeConstant))
        }

        if let rssi {
            rssiFilter.update(sample: Double(rssi), alpha: alpha)
        }
        if let noise {
            noiseFilter.update(sample: Double(noise), alpha: alpha)
        }
    }

    private func resetFilters() {
        lastFilterUptime = nil
        rssiFilter.reset()
        noiseFilter.reset()
    }

    private func linearPercent(value: Double, low: Double, high: Double) -> Int {
        let clamped = max(low, min(high, value))
        let t = (clamped - low) / max(0.000_001, (high - low))
        return Int((t * 100.0).rounded())
    }
}
