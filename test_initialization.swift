#!/usr/bin/env swift

import Foundation
import os.log

// Simple test to check if the app initialization is hanging

let logger = Logger(subsystem: "com.microverse.test", category: "Init")

print("Testing Microverse initialization...")

// Test 1: Check system_profiler
print("\n1. Testing system_profiler (this is known to be slow)...")
let profilerStart = Date()
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
        print("⚠️  system_profiler timed out after 3 seconds!")
        task.terminate()
    } else {
        let elapsed = Date().timeIntervalSince(profilerStart)
        print("✅ system_profiler completed in \(elapsed) seconds")
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("Cycle Count:") {
                    print("   Found: \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
    }
} catch {
    print("❌ Failed to run system_profiler: \(error)")
}

// Test 2: Check IOKit power sources
print("\n2. Testing IOKit power sources...")
let ioStart = Date()
if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
   let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any] {
    
    for source in sources {
        if let info = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
            let charge = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            let elapsed = Date().timeIntervalSince(ioStart)
            print("✅ IOKit power sources read in \(elapsed) seconds")
            print("   Battery: \(charge)%, Charging: \(isCharging)")
        }
    }
} else {
    print("❌ Failed to read IOKit power sources")
}

// Test 3: Check if running with correct permissions
print("\n3. Testing permissions...")
let whoami = Process()
whoami.launchPath = "/usr/bin/whoami"
let whoamiPipe = Pipe()
whoami.standardOutput = whoamiPipe

do {
    try whoami.run()
    whoami.waitUntilExit()
    let data = whoamiPipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
        print("✅ Running as user: \(output)")
    }
} catch {
    print("❌ Failed to check user: \(error)")
}

print("\n✅ All tests completed")
print("\nIf system_profiler is timing out, that's likely the cause of the 'Loading...' issue.")
print("Consider implementing async initialization or caching the cycle count.")