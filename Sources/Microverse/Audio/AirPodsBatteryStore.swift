import CoreBluetooth
import Foundation
import os.log

/// Best-effort AirPods battery readings from Bluetooth LE advertisements.
///
/// ## First principles
/// - **Opt-in:** we only scan when the user enables AirPods-related features (alerts/widgets).
/// - **Privacy-minimal:** we do not connect to peripherals or enumerate paired devices; we only observe broadcast packets.
/// - **Energy-aware:** scan briefly on a long interval (defaults: scan 4s every 30s).
/// - **Glanceable:** expose a small `Reading` model that can drive UI + simple “low battery” rules.
///
/// ## How it works
/// AirPods periodically advertise manufacturer data that includes battery percentages. We look for Apple’s company ID,
/// validate the payload shape we know how to parse, and publish a snapshot of recent readings.
///
/// ## Limitations
/// This is heuristic and can vary by model/firmware/macOS behavior. Treat as “nice to have” and always fail gracefully.
@MainActor
final class AirPodsBatteryStore: NSObject, ObservableObject {
  struct Reading: Equatable, Sendable {
    var id: UUID
    var name: String
    var rssi: Int?
    var leftPercent: Int?
    var rightPercent: Int?
    var casePercent: Int?
    var updatedAt: Date
  }

  enum Availability: Equatable, Sendable {
    case unknown
    case poweredOff
    case unauthorized
    case unavailable
    case ready
  }

  @Published private(set) var availability: Availability = .unknown
  @Published private(set) var readings: [Reading] = []
  @Published private(set) var lastUpdated: Date?

  private let logger = Logger(subsystem: "com.microverse.app", category: "AirPodsBatteryStore")
  private var central: CBCentralManager?
  private var scanLoopTask: Task<Void, Never>?
  private var activeClients = 0

  private var discovered: [String: Reading] = [:]

  func start(scanInterval: TimeInterval = 30, scanDuration: TimeInterval = 4) {
    activeClients += 1
    guard scanLoopTask == nil else { return }

    if central == nil {
      central = CBCentralManager(delegate: self, queue: nil)
    }

    scanLoopTask = Task { [weak self] in
      guard let self else { return }
      await self.scanLoop(interval: scanInterval, duration: scanDuration)
    }

    logger.debug("AirPodsBatteryStore started (clients=\(self.activeClients))")
  }

  func stop() {
    activeClients = max(0, activeClients - 1)
    guard activeClients == 0 else { return }

    scanLoopTask?.cancel()
    scanLoopTask = nil
    central?.stopScan()
    discovered.removeAll()
    readings = []
    lastUpdated = nil
    logger.debug("AirPodsBatteryStore stopped")
  }

  func bestReading(matchingDeviceName deviceName: String) -> Reading? {
    let target = Self.normalizeName(deviceName)
    guard !target.isEmpty else { return nil }

    let candidates = readings.filter { reading in
      let name = Self.normalizeName(reading.name)
      guard !name.isEmpty else { return false }
      return name == target || name.contains(target) || target.contains(name)
    }

    return candidates.max(by: { $0.updatedAt < $1.updatedAt })
  }

  private func scanLoop(interval: TimeInterval, duration: TimeInterval) async {
    let cycleInterval = max(10, interval)
    let scanDuration = min(max(2, duration), cycleInterval)

    while !Task.isCancelled {
      if central?.state == .poweredOn {
        scanOnce(duration: scanDuration)
      }

      do {
        try await Task.sleep(nanoseconds: UInt64(cycleInterval * 1_000_000_000))
      } catch {
        break
      }
    }
  }

  private func scanOnce(duration: TimeInterval) {
    guard let central else { return }
    guard central.state == .poweredOn else { return }

    central.scanForPeripherals(
      withServices: nil,
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    )

    Task { [weak self] in
      guard let self else { return }
      do {
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      self.central?.stopScan()
      self.publishSnapshot()
    }
  }

  private func publishSnapshot() {
    let values = Array(discovered.values)
      .sorted { $0.updatedAt > $1.updatedAt }

    readings = values
    lastUpdated = Date()
  }

  private func updateAvailability(for state: CBManagerState) {
    switch state {
    case .poweredOn:
      availability = .ready
    case .poweredOff:
      availability = .poweredOff
    case .unauthorized:
      availability = .unauthorized
    case .unsupported:
      availability = .unavailable
    case .resetting, .unknown:
      availability = .unknown
    @unknown default:
      availability = .unknown
    }
  }

  private static func normalizeName(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
  }

  private static func parseBatteryPercent(_ byte: UInt8) -> Int? {
    if byte == 0xFF { return nil }
    let raw = Int(byte)
    let percent = raw > 100 ? raw - 100 : raw
    return max(0, min(100, percent))
  }

  private func handleAirPodsAdvertisement(
    name: String,
    rssi: Int,
    manufacturerData: Data
  ) {
    let normalized = Self.normalizeName(name)
    guard normalized.contains("airpods") else { return }
    guard manufacturerData.count >= 4 else { return }

    // Manufacturer data begins with Apple company identifier 0x004C (little-endian).
    let company = UInt16(manufacturerData[0]) | (UInt16(manufacturerData[1]) << 8)
    guard company == 0x004C else { return }

    let bytes = [UInt8](manufacturerData)

    // Most AirPods battery broadcasts use 29-byte (open) or 25-byte (closed) payloads.
    guard bytes.count == 29 || bytes.count == 25 else { return }
    guard bytes.count >= 4, bytes[2] == 0x07, bytes[3] == 0x19 else { return }

    let left: Int?
    let right: Int?
    let `case`: Int?
    if bytes.count == 29 {
      left = Self.parseBatteryPercent(bytes[14])
      right = Self.parseBatteryPercent(bytes[15])
      `case` = Self.parseBatteryPercent(bytes[16])
    } else if bytes.count == 25 {
      `case` = Self.parseBatteryPercent(bytes[12])
      left = Self.parseBatteryPercent(bytes[13])
      right = Self.parseBatteryPercent(bytes[14])
    } else {
      return
    }

    // Ignore payloads that don't contain any useful readings.
    guard left != nil || right != nil || `case` != nil else { return }

    let now = Date()
    let reading = Reading(
      id: discovered[normalized]?.id ?? UUID(),
      name: name,
      rssi: rssi,
      leftPercent: left,
      rightPercent: right,
      casePercent: `case`,
      updatedAt: now
    )

    // Use the normalized name as the stable identity key. Peripheral UUIDs can rotate.
    discovered[normalized] = reading
  }
}

extension AirPodsBatteryStore: CBCentralManagerDelegate {
  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let state = central.state
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.updateAvailability(for: state)

      #if DEBUG
        self.logger.debug(
          "Bluetooth state updated: \(String(describing: state.rawValue), privacy: .public)")
      #endif
    }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
      return
    }

    let name =
      (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
      ?? peripheral.name
      ?? "AirPods"

    let rssi = RSSI.intValue
    Task { @MainActor [weak self] in
      self?.handleAirPodsAdvertisement(name: name, rssi: rssi, manufacturerData: data)
    }
  }
}
