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
        logger.debug("WiFiStore stopped")
    }

    func refresh(reason: String) {
        let now = Date()

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

        guard let iface = CWWiFiClient.shared().interface() else {
            status = .unavailable
            rssi = nil
            noise = nil
            transmitRateMbps = nil
            lastUpdated = now
            return
        }

        guard iface.powerOn() else {
            status = .poweredOff
            rssi = nil
            noise = nil
            transmitRateMbps = nil
            lastUpdated = now
            return
        }

        let name = iface.ssid()
        let nextRSSI = iface.rssiValue()
        let nextNoise = iface.noiseMeasurement()
        let nextRate = iface.transmitRate()

        // SSID can be redacted by privacy controls on newer macOS versions. If we have any link metrics,
        // treat this as connected even when the name is unavailable.
        let looksConnected = name != nil || (nextRSSI != 0 && nextRSSI != Int.min) || nextRate > 0

        status = looksConnected ? .connected(networkName: name) : .disconnected
        rssi = nextRSSI == 0 || nextRSSI == Int.min ? nil : nextRSSI
        noise = nextNoise == 0 || nextNoise == Int.min ? nil : nextNoise
        transmitRateMbps = nextRate > 0 ? nextRate : nil
        lastUpdated = now

        #if DEBUG
        logger.debug("WiFi refresh reason=\(reason, privacy: .public) status=\(String(describing: self.status), privacy: .public)")
        #endif
    }

    var signalPercent: Int? {
        guard let rssi else { return nil }
        // Heuristic: map RSSI [-90...-50] dBm → [0...100] for a UI-friendly “strength percent”.
        let clamped = max(-90, min(-50, rssi))
        let t = Double(clamped + 90) / 40.0
        return Int((t * 100.0).rounded())
    }

    var signalBars: Int {
        guard let rssi else { return 0 }
        switch rssi {
        case (-55)...:
            return 3
        case (-67)...(-56):
            return 2
        case (-75)...(-68):
            return 1
        default:
            return 0
        }
    }

    var qualityText: String {
        guard let rssi else { return "—" }
        switch rssi {
        case (-55)...:
            return "Excellent"
        case (-67)...(-56):
            return "Good"
        case (-75)...(-68):
            return "Fair"
        default:
            return "Weak"
        }
    }
}
