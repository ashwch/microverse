// MARK: - Microverse Performance Benchmarks
//
// Validates the performance patterns used across the Microverse app.
// Run with `make benchmark` (builds in release mode for accurate timings).
//
// ## What this benchmarks (and why)
//
// The app uses several patterns to reduce CPU, energy, and SwiftUI overhead.
// This tool measures them so we can verify they actually help:
//
//   Category              │ What we're proving
//   ──────────────────────┼────────────────────────────────────────────
//   Syscall Latency       │ getCPUUsage() and getMemoryInfo() are fast
//                         │ enough to run sequentially. TaskGroup adds
//                         │ overhead that exceeds the syscalls themselves.
//   ──────────────────────┼────────────────────────────────────────────
//   Publish Suppression   │ setIfChanged (skip-if-equal) is cheap (~22ns).
//                         │ The real savings is avoiding @Published fanout
//                         │ which triggers SwiftUI diffs on every observer.
//   ──────────────────────┼────────────────────────────────────────────
//   Formatter Caching     │ ByteCountFormatter init has allocation cost.
//                         │ Caching as `static let` avoids this per call.
//
// ## How the harness works
//
//   1. Warmup phase (discarded) — primes caches, JIT, branch predictors.
//   2. Measured phase — each iteration timed individually.
//   3. Stats — min / median / mean / max reported per benchmark.
//
// For very fast operations (sub-100ns), `measureBatched` runs 1000 iterations
// per timing sample and divides, avoiding `ContinuousClock` resolution floor.
//
// ## Compiler optimization barriers
//
// Release-mode benchmarks need protection against three optimizer tricks:
//   - Dead code elimination: unused results get deleted entirely.
//   - Constant folding: predictable inputs get precomputed at compile time.
//   - Loop-invariant hoisting: pure calls get lifted out of the loop.
//
// We use `@inline(never)` on `consume()` / `opaqueIdentity()` functions,
// and print sink values to stderr so the compiler can't prove they're unused.
// See the "Compiler Optimization Barriers" section below for details.

import Foundation
import SystemCore

// MARK: - Data Types

/// One row of benchmark output: the label, iteration count, and timing stats.
private struct BenchmarkResult {
    let label: String
    let iterations: Int
    let minNs: Double
    let medianNs: Double
    let meanNs: Double
    let maxNs: Double
}

/// A titled group of benchmark results (e.g., "Syscall Latency").
private struct BenchmarkSection {
    let title: String
    let results: [BenchmarkResult]
}

// MARK: - Measurement Harness

/// Timing harness that runs closures with warmup and collects per-iteration stats.
///
/// Three measurement modes:
/// - `measure(...)` — one clock sample per iteration. Good for operations ≥ 1μs.
/// - `measureBatched(...)` — runs `batchSize` iterations per clock sample, then
///   divides. Good for sub-100ns operations where clock resolution is a floor.
/// - `measureAsync(...)` — like `measure` but for `async` closures (e.g., TaskGroup).
private struct BenchmarkHarness {
    private let clock = ContinuousClock()

    /// Measure a synchronous operation. Each iteration is timed individually.
    func measure(
        label: String,
        iterations: Int,
        warmup: Int = 100,
        body: () -> Void
    ) -> BenchmarkResult {
        precondition(iterations > 0)

        for _ in 0..<max(0, warmup) {
            body()
        }

        var samplesNs: [Double] = []
        samplesNs.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = clock.now
            body()
            let elapsed = clock.now - start
            samplesNs.append(durationToNanoseconds(elapsed))
        }

        return summarize(label: label, iterations: iterations, samplesNs: samplesNs)
    }

    /// Measure a very fast operation using an inner batch loop.
    ///
    /// `ContinuousClock` resolution is ~40-80ns on Apple Silicon. For operations
    /// that take <10ns, a single-iteration measurement would read as 0ns. This
    /// mode runs `batchSize` iterations (default: 1000) in one timing window
    /// and reports the per-iteration average (`elapsed / batchSize`).
    func measureBatched(
        label: String,
        iterations: Int,
        warmup: Int = 20,
        batchSize: Int = 1_000,
        body: () -> Void
    ) -> BenchmarkResult {
        precondition(iterations > 0)
        precondition(batchSize > 0)

        for _ in 0..<max(0, warmup) {
            for _ in 0..<batchSize {
                body()
            }
        }

        var samplesNs: [Double] = []
        samplesNs.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = clock.now
            for _ in 0..<batchSize {
                body()
            }
            let elapsed = clock.now - start
            let perIteration = durationToNanoseconds(elapsed) / Double(batchSize)
            samplesNs.append(perIteration)
        }

        return summarize(label: label, iterations: iterations, samplesNs: samplesNs)
    }

    /// Measure an `async` operation (e.g., TaskGroup). Each iteration is timed individually.
    func measureAsync(
        label: String,
        iterations: Int,
        warmup: Int = 100,
        body: () async -> Void
    ) async -> BenchmarkResult {
        precondition(iterations > 0)

        for _ in 0..<max(0, warmup) {
            await body()
        }

        var samplesNs: [Double] = []
        samplesNs.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = clock.now
            await body()
            let elapsed = clock.now - start
            samplesNs.append(durationToNanoseconds(elapsed))
        }

        return summarize(label: label, iterations: iterations, samplesNs: samplesNs)
    }

    /// Compute min / median / mean / max from raw nanosecond samples.
    private func summarize(label: String, iterations: Int, samplesNs: [Double]) -> BenchmarkResult {
        let sorted = samplesNs.sorted()
        let total = samplesNs.reduce(0, +)
        let mean = total / Double(samplesNs.count)
        let median: Double = {
            let mid = sorted.count / 2
            if sorted.count.isMultiple(of: 2) {
                return (sorted[mid - 1] + sorted[mid]) / 2
            }
            return sorted[mid]
        }()

        return BenchmarkResult(
            label: label,
            iterations: iterations,
            minNs: sorted.first ?? 0,
            medianNs: median,
            meanNs: mean,
            maxNs: sorted.last ?? 0
        )
    }
}

// MARK: - Simulated Store for Publish Suppression Benchmarks
//
// In the real app, WiFiStore / NetworkStore / AudioDevicesStore are
// `ObservableObject` classes with `@Published` properties. Every write to
// a `@Published` property calls `objectWillChange.send()`, triggering a
// SwiftUI diff for every observing view — even when the value didn't change.
//
// The `setIfChanged` pattern skips the write when old == new, avoiding that
// fanout. We can't import the real stores here (they depend on SwiftUI), so
// this `FakeStore` replicates the pattern to measure the comparison cost.

private final class FakeStore {
    var intValue: Int = 0

    /// Mirrors the `setIfChanged` helper used in WiFiStore, NetworkStore,
    /// and AudioDevicesStore. Returns `true` if a write occurred.
    ///
    /// `@inline(never)` is critical for benchmarking: without it, the
    /// compiler can inline the Equatable check, prove the result is constant
    /// (e.g., always `false` in the "no change" benchmark), and eliminate
    /// the entire call — measuring nothing.
    @inline(never) @discardableResult
    func setIfChanged<T: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<FakeStore, T>,
        to value: T
    ) -> Bool {
        if self[keyPath: keyPath] == value {
            return false
        }
        self[keyPath: keyPath] = value
        return true
    }
}

// MARK: - Compiler Optimization Barriers
//
// In release mode (-O, -Osize), the Swift compiler aggressively optimizes
// code. Microbenchmarks must defeat three specific tricks, or the measured
// operation vanishes entirely:
//
//   Trick                     │ How we defeat it
//   ──────────────────────────┼──────────────────────────────────────────
//   Dead code elimination     │ `consume()` accumulates into a `sink`
//   (result unused → deleted) │ variable that is printed via `_printSink`
//                             │ at the end. The compiler must keep every
//                             │ value that feeds the sink.
//   ──────────────────────────┼──────────────────────────────────────────
//   Constant folding          │ `opaqueIdentity()` wraps inputs so the
//   (known input → precomp.)  │ compiler can't see the value at the call
//                             │ site. Both are `@inline(never)`.
//   ──────────────────────────┼──────────────────────────────────────────
//   Loop-invariant hoisting   │ The `consume()` call inside the loop body
//   (pure call → lifted out)  │ creates a data dependency on the loop
//                             │ iteration, preventing hoisting.
//
// Usage in a benchmark closure:
//
//   consume(someExpensiveCall(opaqueIdentity(input)), into: &sink)
//           ─────────────────────────────────────────
//           │  opaqueIdentity hides the input constant
//           │  someExpensiveCall must actually execute
//           │  consume writes the result into the sink
//           └─ all three are forced to stay in the loop

/// Accumulate a Double result so the compiler can't eliminate the computation.
@inline(never)
private func consume(_ value: Double, into sink: inout Double) {
    sink += value * 0.000_000_001
}

/// Accumulate an Int result so the compiler can't eliminate the computation.
@inline(never)
private func consume(_ value: Int, into sink: inout Int) {
    sink &+= value
}

/// Accumulate a String result (via its byte count) so the compiler can't
/// eliminate the string formatting that produced it.
@inline(never)
private func consume(_ value: String, into sink: inout Int) {
    sink &+= value.utf8.count
}

/// Return the input unchanged, but the compiler can't see through this call.
///
/// Use this to wrap benchmark inputs that would otherwise be constant-folded.
/// Example: `opaqueIdentity(42)` — the compiler treats the return value as
/// an unknown `Int`, even though it's always 42.
@inline(never)
private func opaqueIdentity<T>(_ value: T) -> T { value }

/// Print accumulated sink values to stderr so the compiler must preserve all
/// computations that feed into them. Uses stderr to keep stdout clean for the
/// benchmark table.
@inline(never)
private func _printSink(_ label: String, _ intSink: Int, _ doubleSink: Double) {
    fputs("  [\(label) sink: int=\(intSink) double=\(doubleSink)]\n", stderr)
}

// MARK: - Formatting Helpers

/// Convert a `Duration` (from `ContinuousClock`) to nanoseconds as a Double.
private func durationToNanoseconds(_ duration: Duration) -> Double {
    let components = duration.components
    let secondsNs = Double(components.seconds) * 1_000_000_000
    let attosecondsNs = Double(components.attoseconds) / 1_000_000_000
    return secondsNs + attosecondsNs
}

/// Human-readable duration string: picks ns / μs / ms / s automatically.
private func formatDuration(_ ns: Double) -> String {
    if ns < 1_000 {
        return String(format: "%.1fns", ns)
    }
    if ns < 1_000_000 {
        return String(format: "%.1fμs", ns / 1_000)
    }
    if ns < 1_000_000_000 {
        return String(format: "%.2fms", ns / 1_000_000)
    }
    return String(format: "%.2fs", ns / 1_000_000_000)
}

/// Same rounding function used in SystemMonitoringService.quantize().
/// Replicated here because we can't import the Microverse target.
private func round(_ value: Double, places: Int) -> Double {
    let scale = pow(10.0, Double(max(0, places)))
    return (value * scale).rounded() / scale
}

private func padLeft(_ text: String, width: Int) -> String {
    if text.count >= width { return text }
    return String(repeating: " ", count: width - text.count) + text
}

private func padRight(_ text: String, width: Int) -> String {
    if text.count >= width { return text }
    return text + String(repeating: " ", count: width - text.count)
}

/// Print one section of the benchmark results as an ASCII table.
private func printSection(_ section: BenchmarkSection) {
    print("  \(section.title)")
    print("  \(String(repeating: "─", count: 74))")
    print(
        "  "
            + padRight("Benchmark", width: 34)
            + padLeft("Iterations", width: 10)
            + padLeft("Min", width: 10)
            + padLeft("Median", width: 10)
            + padLeft("Mean", width: 10)
            + padLeft("Max", width: 10)
    )

    for result in section.results {
        print(
            "  "
                + padRight(result.label, width: 34)
                + padLeft("\(result.iterations)", width: 10)
                + padLeft(formatDuration(result.minNs), width: 10)
                + padLeft(formatDuration(result.medianNs), width: 10)
                + padLeft(formatDuration(result.meanNs), width: 10)
                + padLeft(formatDuration(result.maxNs), width: 10)
        )
    }

    print("")
}

// MARK: - Entry Point

@main
struct MicroverseBenchmarkMain {
    static func main() async {
        let harness = BenchmarkHarness()

        let syscallResults = await runSyscallBenchmarks(harness: harness)
        let publishResults = runPublishSuppressionBenchmarks(harness: harness)
        let formatterResults = runFormatterBenchmarks(harness: harness)

        print("⏱  Microverse Performance Benchmarks")
        print(String(repeating: "━", count: 76))
        print("")

        printSection(BenchmarkSection(title: "Syscall Latency", results: syscallResults))
        printSection(BenchmarkSection(title: "Publish Suppression", results: publishResults))
        printSection(BenchmarkSection(title: "Formatter Caching", results: formatterResults))
    }

    // MARK: - A. Syscall Latency
    //
    // Why this matters:
    // SystemMonitoringService calls getCPUUsage() and getMemoryInfo() every 3s.
    // We chose to run them sequentially in a single Task.detached rather than
    // in parallel via TaskGroup. This section proves that's the right call:
    //
    //   Sequential:  ~5.7μs (just the two syscalls back-to-back)
    //   TaskGroup:   ~8.8μs (adds 2 child-task allocations + coordination)
    //
    // TaskGroup overhead exceeds the syscalls themselves when they're this fast.

    private static func runSyscallBenchmarks(harness: BenchmarkHarness) async -> [BenchmarkResult] {
        var sink = 0.0

        // Individual syscall: getCPUUsage()
        // Uses HOST_CPU_LOAD_INFO mach kernel call. ~500ns per call.
        // Note: first call returns 0% (needs two samples for tick-delta).
        // The warmup phase handles this.
        let cpuMonitor = SystemMonitor()
        cpuMonitor.resetCPUUsageSampling()
        let cpuUsage = harness.measure(label: "getCPUUsage()", iterations: 5_000, warmup: 250) {
            consume(cpuMonitor.getCPUUsage(), into: &sink)
        }

        // Individual syscall: getMemoryInfo()
        // Uses HOST_VM_INFO64 mach kernel call. ~5μs per call.
        let memoryMonitor = SystemMonitor()
        let memoryInfo = harness.measure(label: "getMemoryInfo()", iterations: 5_000, warmup: 100) {
            let info = memoryMonitor.getMemoryInfo()
            consume(info.usagePercentage, into: &sink)
        }

        // Sequential: both syscalls back-to-back on the same thread.
        // This is what SystemMonitoringService.updateMetrics() actually does
        // (inside a Task.detached). Measures raw syscall cost without async overhead.
        let sequentialMonitor = SystemMonitor()
        sequentialMonitor.resetCPUUsageSampling()
        let sequential = harness.measure(
            label: "Sequential (both)",
            iterations: 2_000,
            warmup: 180
        ) {
            let cpu = sequentialMonitor.getCPUUsage()
            let memory = sequentialMonitor.getMemoryInfo()
            consume(cpu + memory.usagePercentage, into: &sink)
        }

        // TaskGroup: both syscalls in parallel child tasks.
        // This is the alternative we chose NOT to use. Measures the overhead
        // of 2 child-task allocations + structured concurrency coordination.
        let groupMonitor = SystemMonitor()
        groupMonitor.resetCPUUsageSampling()
        let taskGroup = await harness.measureAsync(
            label: "TaskGroup parallel (both)",
            iterations: 2_000,
            warmup: 180
        ) {
            let total = await withTaskGroup(of: Double.self, returning: Double.self) { group in
                group.addTask {
                    groupMonitor.getCPUUsage()
                }
                group.addTask {
                    groupMonitor.getMemoryInfo().usagePercentage
                }

                var aggregate = 0.0
                for await value in group {
                    aggregate += value
                }
                return aggregate
            }
            consume(total, into: &sink)
        }

        _printSink("syscall", 0, sink)

        return [cpuUsage, memoryInfo, sequential, taskGroup]
    }

    // MARK: - B. Publish Suppression
    //
    // Why this matters:
    // Every `@Published` property write calls `objectWillChange.send()`, which
    // triggers SwiftUI to re-evaluate ALL views observing that store. When RSSI
    // is steady at -55 dBm, writing -55 every 2 seconds is pure waste.
    //
    // The `setIfChanged` pattern adds a cheap Equatable check (~22ns) to skip
    // the write when old == new. The check is much cheaper than the SwiftUI diff
    // it prevents (which can cost milliseconds across the view hierarchy).
    //
    // This section also measures the quantization patterns used in
    // SystemMonitoringService to round CPU/memory values before comparing,
    // ensuring invisible sub-integer changes don't trigger publishes.

    private static func runPublishSuppressionBenchmarks(harness: BenchmarkHarness) -> [BenchmarkResult] {
        var intSink = 0
        var doubleSink = 0.0

        // setIfChanged when value hasn't changed (the common case in steady state).
        // Measures: KeyPath read + Equatable comparison. Should be very cheap.
        let noChangeStore = FakeStore()
        noChangeStore.intValue = 42
        let noChange = harness.measureBatched(
            label: "setIfChanged (no change)",
            iterations: 50,
            warmup: 10,
            batchSize: 1_000
        ) {
            // opaqueIdentity hides the constant 42 from the optimizer so it
            // can't prove the comparison always returns false.
            consume(noChangeStore.setIfChanged(\.intValue, to: opaqueIdentity(42)) ? 1 : 0, into: &intSink)
        }

        // setIfChanged when value DID change (less common, happens on real deltas).
        // Measures: KeyPath read + Equatable comparison + KeyPath write.
        let changedStore = FakeStore()
        var changedValue = 0
        let changed = harness.measureBatched(
            label: "setIfChanged (changed)",
            iterations: 50,
            warmup: 10,
            batchSize: 1_000
        ) {
            changedValue &+= 1
            consume(changedStore.setIfChanged(\.intValue, to: opaqueIdentity(changedValue)) ? 1 : 0, into: &intSink)
        }

        // Unconditional write (baseline). This is what happens WITHOUT setIfChanged.
        // In the real app, this would trigger objectWillChange.send() every time.
        let unconditionalStore = FakeStore()
        var rawWrite = 0
        let unconditional = harness.measureBatched(
            label: "Unconditional property write",
            iterations: 50,
            warmup: 10,
            batchSize: 1_000
        ) {
            rawWrite &+= 1
            unconditionalStore.intValue = opaqueIdentity(rawWrite)
            consume(unconditionalStore.intValue, into: &intSink)
        }

        // CPU quantization: Double(Int(raw))
        // SystemMonitoringService stores CPU as Double(Int(raw)) so that
        // 42.1 and 42.9 both become 42.0 — invisible changes don't trigger
        // SwiftUI diffs. Measures the truncation cost.
        var rawCPU = 0.0
        let cpuQuantize = harness.measureBatched(
            label: "CPU quantize: Double(Int(raw))",
            iterations: 100,
            warmup: 20,
            batchSize: 1_000
        ) {
            rawCPU += 0.031
            if rawCPU > 100 {
                rawCPU -= 100
            }
            // opaqueIdentity prevents the compiler from strength-reducing
            // the Double(Int(...)) truncation across loop iterations.
            consume(Double(Int(opaqueIdentity(rawCPU))), into: &doubleSink)
        }

        // Memory quantization: round all 5 MemoryInfo fields.
        // Same pattern as SystemMonitoringService.quantize(memory:).
        // Rounds totalMemory/usedMemory/cachedMemory to 1dp, compressionRatio to 2dp.
        var used = 17.456_789
        var cached = 6.334_221
        var compression = 0.312_765
        let memoryQuantize = harness.measureBatched(
            label: "Memory quantize (5 fields)",
            iterations: 100,
            warmup: 20,
            batchSize: 1_000
        ) {
            // Slowly drift values each iteration to prevent constant folding.
            used += 0.000_17
            cached += 0.000_11
            compression += 0.000_01
            if used > 20 { used = 17.456_789 }
            if cached > 8 { cached = 6.334_221 }
            if compression > 0.9 { compression = 0.312_765 }

            let quantized = MemoryInfo(
                totalMemory: round(opaqueIdentity(36.751_2), places: 1),
                usedMemory: round(opaqueIdentity(used), places: 1),
                cachedMemory: round(opaqueIdentity(cached), places: 1),
                pressure: .warning,
                compressionRatio: round(opaqueIdentity(compression), places: 2)
            )
            consume(quantized.usagePercentage, into: &doubleSink)
        }

        _printSink("publish", intSink, doubleSink)

        return [noChange, changed, unconditional, cpuQuantize, memoryQuantize]
    }

    // MARK: - C. Formatter Caching
    //
    // Why this matters:
    // NetworkStore formats bytes/sec and total bytes for display using
    // ByteCountFormatter. The formatter is cached as `static let` to avoid
    // re-allocating internal locale data on every format call.
    //
    // We test both approaches: reusing a cached formatter vs creating a fresh
    // one each time. Varied byte counts prevent internal caching bias.

    private static func runFormatterBenchmarks(harness: BenchmarkHarness) -> [BenchmarkResult] {
        var sink = 0

        // Spread of realistic byte values from small to multi-GB, cycling
        // through them to avoid formatter internal caching bias.
        let sampleBytes: [Int64] = [
            187,              // bytes
            2_048,            // 2 KB
            73_911,           // 74 KB
            1_240_552,        // 1.2 MB
            52_334_190,       // 52 MB
            880_123_004,      // 880 MB
            4_123_551_998,    // 4.1 GB
        ]

        // Cached formatter: allocated once, reused every call.
        // This is what NetworkStore.rateFormatter does.
        let cachedFormatter: ByteCountFormatter = {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
            formatter.countStyle = .decimal
            formatter.includesUnit = true
            formatter.isAdaptive = true
            return formatter
        }()

        var cachedIndex = 0
        let cached = harness.measure(
            label: "Cached ByteCountFormatter",
            iterations: 10_000,
            warmup: 250
        ) {
            let value = sampleBytes[cachedIndex % sampleBytes.count]
            cachedIndex &+= 1
            consume(cachedFormatter.string(fromByteCount: value), into: &sink)
        }

        // Fresh formatter: allocated + configured from scratch every call.
        // This is what would happen without the `static let` caching pattern.
        var freshIndex = 0
        let fresh = harness.measure(
            label: "Fresh ByteCountFormatter",
            iterations: 10_000,
            warmup: 100
        ) {
            let value = sampleBytes[freshIndex % sampleBytes.count]
            freshIndex &+= 1

            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
            formatter.countStyle = .decimal
            formatter.includesUnit = true
            formatter.isAdaptive = true

            consume(formatter.string(fromByteCount: value), into: &sink)
        }

        _printSink("formatter", sink, 0)

        return [cached, fresh]
    }
}
