# Microverse Performance Guide

This guide documents how Microverse keeps CPU, energy impact, and memory usage low while preserving real-time system metrics.

## Goals

- Keep average process CPU low during normal use.
- Reduce Energy Impact by minimizing unnecessary wake-ups.
- Keep resident memory stable and avoid allocation churn.
- Preserve metric accuracy vs macOS Activity Monitor.

## Measurement Methods

### 1) Activity Monitor (process-level)

Use Activity Monitor to validate real app behavior:

- `% CPU` (CPU tab)
- `Energy Impact` and `12 hr Power` (Energy tab)
- `Memory` and `Idle Wake Ups` (CPU/Memory tabs)

Filter by `Microverse`, let the app settle for at least 2-3 minutes, and test both:

- Idle state (no active interaction)
- Active state (open popover, switch tabs, interact with widgets/notch)

### 2) Built-in CLI Benchmarks

Microverse includes a release-mode benchmark executable:

```bash
make benchmark
```

It benchmarks:

- `SystemCore` syscall latency (`getCPUUsage`, `getMemoryInfo`)
- Sequential vs `TaskGroup` overhead for CPU+memory sampling
- Publish-suppression helpers (`setIfChanged`, quantization)
- `ByteCountFormatter` usage patterns

## Current Performance Architecture

### Accurate CPU Sampling

- `SystemCore.SystemMonitor` now uses `HOST_CPU_LOAD_INFO` tick deltas.
- CPU usage is computed from interval deltas, matching Activity Monitor style sampling.
- Counter rollover is handled with 32-bit wrapping arithmetic.

### Accurate Memory Pressure

- Memory pressure uses kernel signal `kern.memorystatus_vm_pressure_level`.
- Heuristic fallback remains for sysctl failure.
- `speculative_count` is not double-counted.

### Demand-Driven Monitoring Lifecycle

- `SystemMonitoringService` polling is ref-counted via `acquireClient()` / `releaseClient()`.
- Views opt in with `.systemMonitoringActive(...)`.
- Polling stops when no visible surface requires CPU/memory metrics.

### Publish Suppression and Change Tokens

- Metrics are quantized before publish (CPU integer bucket; memory rounded fields).
- `@Published` updates occur only when display-visible values change.
- `sampleID: UInt64` replaces timestamp-style change signaling.

### Wake-Up Reduction

- Poll loops use `Task.sleep(for:tolerance:)` across system/network/audio/battery/weather paths.
- Removed hard periodic force-update loop in adaptive notch metric mode.
- Added one-shot dwell retries for adaptive switching so deferred switches are not lost.

## Quick Validation Checklist

1. Build and run:
   - `make install-debug`
2. Validate process-level behavior in Activity Monitor:
   - CPU decreases at idle
   - Energy Impact decreases at idle
   - Idle Wake Ups trends lower
3. Run synthetic checks:
   - `make benchmark`
4. Functional smoke tests:
   - CPU/Memory tabs update in near real time
   - Notch auto metric switches correctly after dwell windows
   - Desktop widget adaptive primary switching still updates correctly

## Notes

- Benchmark numbers are machine- and thermal-state-dependent.
- Prefer release-mode measurements (`-c release`) for any timing conclusion.
- Activity Monitor remains the source of truth for end-user process impact.
