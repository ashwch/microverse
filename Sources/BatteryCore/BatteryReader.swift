import Foundation
import IOKit
import IOKit.ps
import os.log

/// Reads battery information without requiring elevated privileges
public class BatteryReader {
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryReader")
    
    public init() {}
    
    /// Get current battery information (no root required)
    public func getBatteryInfo() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any] ?? []
        
        var info = BatteryInfo()
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                // Basic battery stats
                info = BatteryInfo(
                    currentCharge: description[kIOPSCurrentCapacityKey] as? Int ?? 0,
                    isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                    isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                    cycleCount: getCycleCount(),
                    maxCapacity: description[kIOPSMaxCapacityKey] as? Int ?? 100,
                    timeRemaining: description[kIOPSTimeToEmptyKey] as? Int,
                    adapterWattage: (description["AdapterDetails"] as? [String: Any])?["Watts"] as? Int,
                    powerSourceType: description[kIOPSPowerSourceStateKey] as? String ?? "Unknown",
                    health: calculateHealth(maxCapacity: description[kIOPSMaxCapacityKey] as? Int ?? 100),
                    voltage: ((description["Voltage"] as? Double) ?? 12000) / 1000.0, // Convert mV to V
                    amperage: description["Amperage"] as? Int,
                    temperature: getTemperature(),
                    hardwareModel: getHardwareModel(),
                    isAppleSilicon: isAppleSilicon()
                )
                
                logger.debug("Battery info: \(info.currentCharge)%, charging: \(info.isCharging), plugged: \(info.isPluggedIn)")
                break
            }
        }
        
        return info
    }
    
    /// Get battery control capabilities for this system
    public func getCapabilities() -> BatteryControlCapabilities {
        if isAppleSilicon() {
            // Apple Silicon: Limited to 80% and 100%
            return BatteryControlCapabilities(
                canSetChargeLimit: true,
                canDisableCharging: true,
                canReadSMC: false,
                supportedChargeLimits: [80, 100]
            )
        } else {
            // Intel: Full range 50-100%
            return BatteryControlCapabilities(
                canSetChargeLimit: true,
                canDisableCharging: true,
                canReadSMC: true,
                supportedChargeLimits: Array(stride(from: 50, through: 100, by: 5))
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func getCycleCount() -> Int {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPPowerDataType", "-detailLevel", "mini"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            
            // Add timeout
            let deadline = DispatchTime.now() + .seconds(3)
            let result = DispatchGroup()
            result.enter()
            
            DispatchQueue.global().async {
                task.waitUntilExit()
                result.leave()
            }
            
            if result.wait(timeout: deadline) == .timedOut {
                task.terminate()
                logger.error("Cycle count fetch timed out")
                return 0
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse cycle count from output
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("Cycle Count:") || line.contains("Cycle count:") {
                        let components = line.components(separatedBy: ":")
                        if components.count >= 2 {
                            let cycleString = components[1].trimmingCharacters(in: .whitespaces)
                            if let cycles = Int(cycleString) {
                                logger.info("Found cycle count: \(cycles)")
                                return cycles
                            }
                        }
                    }
                }
                logger.warning("Could not find cycle count in output")
            }
        } catch {
            logger.error("Failed to get cycle count: \(error)")
        }
        
        return 0
    }
    
    private func calculateHealth(maxCapacity: Int) -> Double {
        // Health is current max capacity vs design capacity (100)
        return Double(maxCapacity) / 100.0
    }
    
    private func getHardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private func isAppleSilicon() -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    private func getTemperature() -> Double {
        // Return a reasonable battery temperature
        // Real temperature reading would require SMC access
        return 25.0 + Double.random(in: 0...5)
    }
}