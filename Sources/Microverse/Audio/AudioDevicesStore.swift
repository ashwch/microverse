import AudioToolbox
import CoreAudio
import Foundation
import os.log

/// Shared audio routing + output controls store (CoreAudio).
///
/// ## First principles
/// - **Glanceable:** show the current output/input selection in a simple list (like Control Center).
/// - **Respect the system:** read and change the *system* default devices (no custom routing layer).
/// - **Graceful degradation:** many routes (HDMI/AirPlay/etc.) don’t expose settable volume/mute; the UI must
///   reflect that via `canSetOutputVolume` / `canSetOutputMute`.
/// - **Energy-aware:** a light periodic refresh keeps lists stable, while CoreAudio property listeners keep the UI responsive.
///
/// ## What this is (and is not)
/// - ✅ Enumerates devices, reads default input/output, reads/sets output volume + mute (when supported).
/// - ❌ Does *not* record audio and does not require microphone permission.
///
/// ## Usage
/// Call `start()` in `onAppear` and `stop()` in `onDisappear`.
/// Multiple surfaces are safe — we ref-count active clients so popover/notch/widget can share one store.
@MainActor
final class AudioDevicesStore: ObservableObject {
  enum AirPodsModel: String, Sendable, Equatable {
    case airPods
    case airPodsPro
    case airPodsMax

    var symbolName: String {
      switch self {
      case .airPods:
        return "airpods"
      case .airPodsPro:
        return "airpodspro"
      case .airPodsMax:
        return "airpodsmax"
      }
    }
  }

  enum SonyWH1000XMModel: String, Sendable, Equatable {
    case xm4
    case xm5

    var displayName: String {
      switch self {
      case .xm4:
        return "WH‑1000XM4"
      case .xm5:
        return "WH‑1000XM5"
      }
    }
  }

  struct Device: Identifiable, Hashable, Sendable {
    var id: AudioDeviceID
    var name: String
    var uid: String?
    var transportType: UInt32?

    /// UI hint only. We use transport type to pick icons / ordering, not for any functional permission logic.
    var isBuiltIn: Bool {
      transportType == kAudioDeviceTransportTypeBuiltIn
    }

    var isBluetooth: Bool {
      transportType == kAudioDeviceTransportTypeBluetooth
        || transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    var isAirPlay: Bool {
      transportType == kAudioDeviceTransportTypeAirPlay
    }

    var isUSB: Bool {
      transportType == kAudioDeviceTransportTypeUSB
    }

    var trimmedName: String {
      name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  @Published private(set) var outputDevices: [Device] = []
  @Published private(set) var inputDevices: [Device] = []
  @Published private(set) var defaultOutputDeviceID: AudioDeviceID?
  @Published private(set) var defaultInputDeviceID: AudioDeviceID?

  @Published private(set) var outputVolume: Float?
  @Published private(set) var canSetOutputVolume: Bool = false
  @Published private(set) var outputMuted: Bool?
  @Published private(set) var canSetOutputMute: Bool = false

  @Published private(set) var lastUpdated: Date?

  private let logger = Logger(subsystem: "com.microverse.app", category: "AudioDevicesStore")
  private var monitorTask: Task<Void, Never>?
  private var activeClients = 0
  private let listenerQueue = DispatchQueue(label: "com.microverse.app.audio.listeners")

  private var systemDefaultOutputListener: AudioObjectPropertyListenerBlock?
  private var outputVolumeListener: AudioObjectPropertyListenerBlock?
  private var outputMuteListener: AudioObjectPropertyListenerBlock?
  private var observedOutputDeviceID: AudioDeviceID?

  #if DEBUG
  private var isScreenshotMode: Bool {
    ProcessInfo.processInfo.arguments.contains("--debug-screenshot-mode")
  }
  #endif

  var defaultOutputDevice: Device? {
    guard let id = defaultOutputDeviceID else { return nil }
    return outputDevices.first(where: { $0.id == id })
  }

  var defaultInputDevice: Device? {
    guard let id = defaultInputDeviceID else { return nil }
    return inputDevices.first(where: { $0.id == id })
  }

  func airPodsModel(for device: Device) -> AirPodsModel? {
    Self.detectAirPodsModel(deviceName: device.trimmedName)
  }

  func sonyWH1000XMModel(for device: Device) -> SonyWH1000XMModel? {
    Self.detectSonyWH1000XMModel(deviceName: device.trimmedName)
  }

  func isSonyWH1000XM(_ device: Device) -> Bool {
    sonyWH1000XMModel(for: device) != nil
  }

  var defaultOutputAirPodsModel: AirPodsModel? {
    guard let device = defaultOutputDevice else { return nil }
    return airPodsModel(for: device)
  }

  var defaultOutputSonyWH1000XMModel: SonyWH1000XMModel? {
    guard let device = defaultOutputDevice else { return nil }
    return sonyWH1000XMModel(for: device)
  }

  var isSonyWH1000XMDefaultOutput: Bool {
    defaultOutputSonyWH1000XMModel != nil
  }

  var isAirPodsDefaultOutput: Bool {
    defaultOutputAirPodsModel != nil
  }

  func start(interval: TimeInterval = 2.0) {
    activeClients += 1
    guard monitorTask == nil else { return }

    #if DEBUG
    if isScreenshotMode {
      refresh(reason: "screenshot")
      logger.debug("AudioDevicesStore screenshot mode started (clients=\(self.activeClients))")
      return
    }
    #endif

    refresh(reason: "start")
    installPropertyListenersIfNeeded()

    monitorTask = Task { [weak self] in
      guard let self else { return }

      while !Task.isCancelled {
        do {
          // tolerance lets macOS coalesce this 2s timer with nearby work.
          try await Task.sleep(for: .seconds(max(0.75, interval)), tolerance: .seconds(0.5))
        } catch {
          break
        }
        if Task.isCancelled { break }
        self.refresh(reason: "timer")
      }
    }

    logger.debug("AudioDevicesStore started (clients=\(self.activeClients))")
  }

  func stop() {
    activeClients = max(0, activeClients - 1)
    guard activeClients == 0 else { return }

    removePropertyListeners()
    monitorTask?.cancel()
    monitorTask = nil
    logger.debug("AudioDevicesStore stopped")
  }

  /// Re-enumerate audio devices and refresh output controls.
  ///
  /// `didChange` tracks whether *any* `@Published` property was mutated.
  /// We only bump `lastUpdated` when something changed, so downstream
  /// `.onChange(of: lastUpdated)` handlers skip no-op refreshes.
  func refresh(reason: String) {
    let now = Date()
    var didChange = false

    #if DEBUG
    if isScreenshotMode {
      // Privacy-safe, deterministic list (avoid exposing a user's actual device names).
      let builtInOut = Device(
        id: 1,
        name: "MacBook Pro Speakers",
        uid: "builtin-output",
        transportType: kAudioDeviceTransportTypeBuiltIn
      )
      let airPodsOut = Device(
        id: 2,
        name: "AirPods Pro",
        uid: "airpods-output",
        transportType: kAudioDeviceTransportTypeBluetooth
      )
      let hdmiOut = Device(
        id: 3,
        name: "HDMI Display",
        uid: "hdmi-output",
        transportType: kAudioDeviceTransportTypeHDMI
      )

      let builtInIn = Device(
        id: 101,
        name: "MacBook Pro Microphone",
        uid: "builtin-input",
        transportType: kAudioDeviceTransportTypeBuiltIn
      )
      let airPodsIn = Device(
        id: 102,
        name: "AirPods Pro Microphone",
        uid: "airpods-input",
        transportType: kAudioDeviceTransportTypeBluetooth
      )

      didChange = setIfChanged(\.outputDevices, to: [builtInOut, airPodsOut, hdmiOut]) || didChange
      didChange = setIfChanged(\.inputDevices, to: [builtInIn, airPodsIn]) || didChange
      didChange = setIfChanged(\.defaultOutputDeviceID, to: builtInOut.id) || didChange
      didChange = setIfChanged(\.defaultInputDeviceID, to: builtInIn.id) || didChange

      didChange = setIfChanged(\.outputVolume, to: 0.42) || didChange
      didChange = setIfChanged(\.canSetOutputVolume, to: true) || didChange
      didChange = setIfChanged(\.outputMuted, to: false) || didChange
      didChange = setIfChanged(\.canSetOutputMute, to: true) || didChange
      if didChange || lastUpdated == nil {
        lastUpdated = now
      }
      return
    }
    #endif

    let deviceIDs = Self.getAllDeviceIDs()
    let defaultOutput = Self.getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
    let defaultInput = Self.getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice)

    var outputs: [Device] = []
    var inputs: [Device] = []
    outputs.reserveCapacity(deviceIDs.count)
    inputs.reserveCapacity(deviceIDs.count)

    for deviceID in deviceIDs {
      let name = Self.getDeviceName(deviceID) ?? "Unknown"
      let uid = Self.getDeviceUID(deviceID)
      let transport = Self.getDeviceTransportType(deviceID)

      let device = Device(id: deviceID, name: name, uid: uid, transportType: transport)

      if Self.hasOutputChannels(deviceID) {
        outputs.append(device)
      }
      if Self.hasInputChannels(deviceID) {
        inputs.append(device)
      }
    }

    // Stable sort: built-in first, then alphabetical.
    outputs.sort { lhs, rhs in
      if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
    inputs.sort { lhs, rhs in
      if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    didChange = setIfChanged(\.outputDevices, to: outputs) || didChange
    didChange = setIfChanged(\.inputDevices, to: inputs) || didChange
    didChange = setIfChanged(\.defaultOutputDeviceID, to: defaultOutput) || didChange
    didChange = setIfChanged(\.defaultInputDeviceID, to: defaultInput) || didChange

    didChange = refreshOutputControls(for: defaultOutput) || didChange
    if didChange || lastUpdated == nil {
      lastUpdated = now
    }

    updateOutputDeviceListenersIfNeeded()

    #if DEBUG
      logger.debug(
        "Audio refresh reason=\(reason, privacy: .public) outputs=\(outputs.count, privacy: .public) inputs=\(inputs.count, privacy: .public)"
      )
    #endif
  }

  func setDefaultOutputDevice(_ id: AudioDeviceID) {
    setDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice, id: id)
    refresh(reason: "set_default_output")
  }

  func setDefaultInputDevice(_ id: AudioDeviceID) {
    setDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, id: id)
    refresh(reason: "set_default_input")
  }

  func setOutputVolume(_ value: Float) {
    guard let deviceID = defaultOutputDeviceID else { return }
    let clamped = max(0, min(1, value))
    guard Self.setVolume(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput, value: clamped)
    else { return }
    if refreshOutputControls(for: deviceID) {
      lastUpdated = Date()
    }
  }

  func setOutputMuted(_ muted: Bool) {
    guard let deviceID = defaultOutputDeviceID else { return }
    guard Self.setMute(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput, muted: muted)
    else { return }
    if refreshOutputControls(for: deviceID) {
      lastUpdated = Date()
    }
  }

  func formattedPercent(_ volume: Float) -> String {
    "\(Int((max(0, min(1, volume)) * 100).rounded()))%"
  }

  private static func detectAirPodsModel(deviceName: String) -> AirPodsModel? {
    let lower = deviceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard lower.contains("airpods") else { return nil }

    if lower.contains("max") {
      return .airPodsMax
    }
    if lower.contains("pro") {
      return .airPodsPro
    }
    return .airPods
  }

  private static func detectSonyWH1000XMModel(deviceName: String) -> SonyWH1000XMModel? {
    let normalized = deviceName
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .lowercased()
      .filter { $0.isLetter || $0.isNumber }

    if normalized.contains("wh1000xm5") { return .xm5 }
    if normalized.contains("wh1000xm4") { return .xm4 }
    return nil
  }

    // MARK: - Output Controls

  /// Read volume/mute state for the given output device. Returns `true` when
  /// at least one `@Published` property changed, so callers only bump
  /// `lastUpdated` when necessary.
  @discardableResult
  private func refreshOutputControls(for deviceID: AudioDeviceID?) -> Bool {
    var didChange = false
    guard let deviceID else {
      didChange = setIfChanged(\.outputVolume, to: nil) || didChange
      didChange = setIfChanged(\.canSetOutputVolume, to: false) || didChange
      didChange = setIfChanged(\.outputMuted, to: nil) || didChange
      didChange = setIfChanged(\.canSetOutputMute, to: false) || didChange
      return didChange
    }

    var volumeAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    if Self.hasProperty(deviceID, volumeAddress),
      let value = Self.getPropertyFloat32(deviceID, volumeAddress)
    {
      didChange = setIfChanged(\.outputVolume, to: value) || didChange

      var settable: DarwinBoolean = false
      if AudioObjectIsPropertySettable(deviceID, &volumeAddress, &settable) == noErr {
        didChange = setIfChanged(\.canSetOutputVolume, to: settable.boolValue) || didChange
      } else {
        didChange = setIfChanged(\.canSetOutputVolume, to: false) || didChange
      }
    } else {
      didChange = setIfChanged(\.outputVolume, to: nil) || didChange
      didChange = setIfChanged(\.canSetOutputVolume, to: false) || didChange
    }

    var muteAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    if Self.hasProperty(deviceID, muteAddress),
      let raw = Self.getPropertyUInt32(deviceID, muteAddress)
    {
      didChange = setIfChanged(\.outputMuted, to: raw != 0) || didChange

      var settable: DarwinBoolean = false
      if AudioObjectIsPropertySettable(deviceID, &muteAddress, &settable) == noErr {
        didChange = setIfChanged(\.canSetOutputMute, to: settable.boolValue) || didChange
      } else {
        didChange = setIfChanged(\.canSetOutputMute, to: false) || didChange
      }
    } else {
      didChange = setIfChanged(\.outputMuted, to: nil) || didChange
      didChange = setIfChanged(\.canSetOutputMute, to: false) || didChange
    }
    return didChange
  }

  // MARK: - CoreAudio Property Listeners

  private func installPropertyListenersIfNeeded() {
    guard systemDefaultOutputListener == nil else { return }

    var defaultOutputAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor [weak self] in
        self?.refresh(reason: "default_output_changed")
      }
    }

    let status = AudioObjectAddPropertyListenerBlock(
      Self.systemObject(),
      &defaultOutputAddress,
      listenerQueue,
      block
    )

    if status == noErr {
      systemDefaultOutputListener = block
    } else {
      logger.error("Failed to add default output listener status=\(status, privacy: .public)")
    }

    updateOutputDeviceListenersIfNeeded()
  }

  private func removePropertyListeners() {
    if let systemDefaultOutputListener {
      var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(
        Self.systemObject(),
        &defaultOutputAddress,
        listenerQueue,
        systemDefaultOutputListener
      )
      self.systemDefaultOutputListener = nil
    }

    removeOutputDeviceListeners()
  }

  private func updateOutputDeviceListenersIfNeeded() {
    guard systemDefaultOutputListener != nil else { return }

    let deviceID = defaultOutputDeviceID
    guard deviceID != observedOutputDeviceID else { return }

    removeOutputDeviceListeners()
    observedOutputDeviceID = deviceID

    guard let deviceID else { return }

    var volumeAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    let volumeBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.refreshOutputControls(for: deviceID) {
          self.lastUpdated = Date()
        }
      }
    }

    let volumeStatus = AudioObjectAddPropertyListenerBlock(
      deviceID,
      &volumeAddress,
      listenerQueue,
      volumeBlock
    )

    if volumeStatus == noErr {
      outputVolumeListener = volumeBlock
    } else {
      logger.error("Failed to add output volume listener status=\(volumeStatus, privacy: .public)")
    }

    var muteAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.refreshOutputControls(for: deviceID) {
          self.lastUpdated = Date()
        }
      }
    }

    let muteStatus = AudioObjectAddPropertyListenerBlock(
      deviceID,
      &muteAddress,
      listenerQueue,
      muteBlock
    )

    if muteStatus == noErr {
      outputMuteListener = muteBlock
    } else {
      logger.error("Failed to add output mute listener status=\(muteStatus, privacy: .public)")
    }
  }

  private func removeOutputDeviceListeners() {
    if let observedOutputDeviceID {
      if let outputVolumeListener {
        var volumeAddress = AudioObjectPropertyAddress(
          mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
          mScope: kAudioDevicePropertyScopeOutput,
          mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
          observedOutputDeviceID,
          &volumeAddress,
          listenerQueue,
          outputVolumeListener
        )
        self.outputVolumeListener = nil
      }

      if let outputMuteListener {
        var muteAddress = AudioObjectPropertyAddress(
          mSelector: kAudioDevicePropertyMute,
          mScope: kAudioDevicePropertyScopeOutput,
          mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
          observedOutputDeviceID,
          &muteAddress,
          listenerQueue,
          outputMuteListener
        )
        self.outputMuteListener = nil
      }
    }

    observedOutputDeviceID = nil
  }

  // MARK: - CoreAudio Helpers

  private static func systemObject() -> AudioObjectID {
    AudioObjectID(kAudioObjectSystemObject)
  }

  private static func getAllDeviceIDs() -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(systemObject(), &address, 0, nil, &size) == noErr else {
      return []
    }

    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    guard count > 0 else { return [] }

    var devices = Array(repeating: AudioDeviceID(0), count: count)
    guard AudioObjectGetPropertyData(systemObject(), &address, 0, nil, &size, &devices) == noErr
    else { return [] }
    return devices
  }

  private static func getDefaultDeviceID(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(systemObject(), &address, 0, nil, &size, &deviceID)
    guard status == noErr else { return nil }
    return deviceID
  }

  private func setDefaultDevice(selector: AudioObjectPropertySelector, id: AudioDeviceID) {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var deviceID = id
    let size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectSetPropertyData(Self.systemObject(), &address, 0, nil, size, &deviceID)
    if status != noErr {
      logger.error(
        "Failed to set default device selector=\(selector, privacy: .public) status=\(status, privacy: .public)"
      )
    }
  }

  private static func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var name: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr else {
      return nil
    }
    return name?.takeUnretainedValue() as String?
  }

  private static func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var uid: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid) == noErr else {
      return nil
    }
    return uid?.takeUnretainedValue() as String?
  }

  private static func getDeviceTransportType(_ deviceID: AudioDeviceID) -> UInt32? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyTransportType,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else {
      return nil
    }
    return value
  }

  private static func hasOutputChannels(_ deviceID: AudioDeviceID) -> Bool {
    channelCount(deviceID, scope: kAudioDevicePropertyScopeOutput) > 0
  }

  private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
    channelCount(deviceID, scope: kAudioDevicePropertyScopeInput) > 0
  }

  private static func channelCount(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope)
    -> Int
  {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )

    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
      return 0
    }
    guard size >= UInt32(MemoryLayout<AudioBufferList>.size) else { return 0 }

    let raw = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }

    let bufferList = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList) == noErr else {
      return 0
    }

    let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
    return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
  }

  private static func hasProperty(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress)
    -> Bool
  {
    var address = address
    return AudioObjectHasProperty(objectID, &address)
  }

  private static func getPropertyFloat32(
    _ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress
  ) -> Float32? {
    var address = address
    var value: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
    guard status == noErr else { return nil }
    return value
  }

  private static func getPropertyUInt32(
    _ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress
  ) -> UInt32? {
    var address = address
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
    guard status == noErr else { return nil }
    return value
  }

  private static func setVolume(
    deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, value: Float32
  ) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )

    guard AudioObjectHasProperty(deviceID, &address) else { return false }

    var next = value
    let size = UInt32(MemoryLayout<Float32>.size)
    return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &next) == noErr
  }

  private static func setMute(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, muted: Bool)
    -> Bool
  {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )

    guard AudioObjectHasProperty(deviceID, &address) else { return false }

    var next: UInt32 = muted ? 1 : 0
    let size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &next) == noErr
  }

  /// Write `value` only when it differs from the current value; return whether a write occurred.
  ///
  /// Same pattern as `WiFiStore.setIfChanged`: suppresses redundant
  /// `objectWillChange` notifications to avoid needless SwiftUI diffs.
  @discardableResult
  private func setIfChanged<T: Equatable>(
    _ keyPath: ReferenceWritableKeyPath<AudioDevicesStore, T>,
    to value: T
  ) -> Bool {
    if self[keyPath: keyPath] == value {
      return false
    }
    self[keyPath: keyPath] = value
    return true
  }
}
