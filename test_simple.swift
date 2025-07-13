#!/usr/bin/env swift

import Foundation

print("Testing Microverse initialization components...")

// Test 1: Check system_profiler speed
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
    let deadline = DispatchTime.now() + .seconds(5)
    let result = DispatchGroup()
    result.enter()
    
    DispatchQueue.global().async {
        task.waitUntilExit()
        result.leave()
    }
    
    if result.wait(timeout: deadline) == .timedOut {
        print("⚠️  system_profiler timed out after 5 seconds!")
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

// Test 2: Check pmset
print("\n2. Testing pmset -g batt...")
let pmsetStart = Date()
let pmset = Process()
pmset.launchPath = "/usr/bin/pmset"
pmset.arguments = ["-g", "batt"]

let pmsetPipe = Pipe()
pmset.standardOutput = pmsetPipe

do {
    try pmset.run()
    pmset.waitUntilExit()
    let elapsed = Date().timeIntervalSince(pmsetStart)
    print("✅ pmset completed in \(elapsed) seconds")
    
    let data = pmsetPipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        print("   Output: \(output.prefix(100))...")
    }
} catch {
    print("❌ Failed to run pmset: \(error)")
}

print("\n✅ All tests completed")
print("\nIf system_profiler is timing out, that's likely the cause of the 'Loading...' issue.")