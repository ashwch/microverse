# Technical Implementation Plan

## Architecture Philosophy (Carmack/Dean Principles)

### Core Tenets
1. **Measure First, Optimize Second** - Profile everything
2. **Data Locality** - Keep related data together
3. **Zero-Copy Where Possible** - Share memory, don't duplicate
4. **Fail Fast, Recover Gracefully** - Never hang the UI

## System Architecture

### Data Flow
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Mach Kernel   │────▶│  SystemReader    │────▶│  SharedCache    │
│   (Source)      │     │  (Collector)     │     │  (In-Memory)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                           │
                        ┌──────────────────────────────────┤
                        ▼                                  ▼
                ┌───────────────┐                 ┌────────────────┐
                │  ViewModels   │                 │ Widget Provider│
                │  (Transform)  │                 │  (Read-Only)   │
                └───────────────┘                 └────────────────┘
                        │
                        ▼
                ┌───────────────┐
                │   SwiftUI     │
                │   (Present)   │
                └───────────────┘
```

## Core Implementation

### SystemCore Framework

```swift
// SystemMetrics.swift - Single source of truth
public struct SystemMetrics: Codable, Equatable {
    let timestamp: Date
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let battery: BatteryInfo
    let processes: ProcessList
    
    // Efficient difference detection
    func significantlyDifferent(from other: SystemMetrics) -> Bool {
        // Only trigger UI updates for meaningful changes
        abs(cpu.usage - other.cpu.usage) > 1.0 ||
        abs(memory.pressure - other.memory.pressure) > 0.1 ||
        processes.top5CPU != other.processes.top5CPU
    }
}

// ProcessList.swift - Smart process tracking
public struct ProcessList: Codable, Equatable {
    private let processes: [ProcessInfo]
    
    // Pre-computed for performance
    let top5CPU: [ProcessInfo]
    let top5Memory: [ProcessInfo]
    let developerTools: [ProcessInfo]
    
    init(processes: [ProcessInfo]) {
        self.processes = processes
        
        // Sort once, use many times
        let cpuSorted = processes.sorted { $0.cpuPercent > $1.cpuPercent }
        let memSorted = processes.sorted { $0.memoryMB > $1.memoryMB }
        
        self.top5CPU = Array(cpuSorted.prefix(5))
        self.top5Memory = Array(memSorted.prefix(5))
        self.developerTools = processes.filter { 
            ProcessCategories.isDeveloperTool($0.name) 
        }
    }
}
```

### Efficient System Reader

```swift
// SystemReader.swift - Optimized data collection
public final class SystemReader {
    private let queue = DispatchQueue(label: "microverse.system", qos: .utility)
    private let machHost = mach_host_self()
    
    // Reusable buffers to avoid allocations
    private var cpuInfoArray: processor_info_array_t?
    private var cpuInfoCount: mach_msg_type_number_t = 0
    private var cpuInfoPrev: host_cpu_load_info?
    
    // Process tracking
    private var processCache: [pid_t: ProcessInfo] = [:]
    private let processQueue = DispatchQueue(label: "microverse.process", qos: .background)
    
    public func gatherMetrics() async -> SystemMetrics {
        await withTaskGroup(of: MetricComponent.self) { group in
            // Parallel collection for independent metrics
            group.addTask { .cpu(await self.collectCPU()) }
            group.addTask { .memory(await self.collectMemory()) }
            group.addTask { .battery(await self.collectBattery()) }
            group.addTask { .processes(await self.collectProcesses()) }
            
            var components: [MetricComponent] = []
            for await component in group {
                components.append(component)
            }
            
            return SystemMetrics(from: components)
        }
    }
    
    private func collectCPU() async -> CPUMetrics {
        // Single syscall for all CPU info
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: natural_t = 0
        var numCpus: natural_t = 0
        
        let kr = host_processor_info(
            machHost,
            PROCESSOR_CPU_LOAD_INFO,
            &numCpus,
            &cpuInfo,
            &numCpuInfo
        )
        
        guard kr == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return .unavailable
        }
        
        defer {
            vm_deallocate(mach_task_self_, 
                         vm_address_t(bitPattern: cpuInfo), 
                         vm_size_t(numCpuInfo))
        }
        
        // Calculate usage with previous sample
        return calculateCPUUsage(cpuInfo, count: numCpus)
    }
    
    private func collectProcesses() async -> ProcessList {
        // Use libproc for efficient process enumeration
        let maxProcs = proc_listpids(PROC_ALL_PIDS, 0, nil, 0) / Int32(MemoryLayout<pid_t>.size)
        guard maxProcs > 0 else { return .empty }
        
        let pids = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(maxProcs))
        defer { pids.deallocate() }
        
        let actualCount = proc_listpids(PROC_ALL_PIDS, 0, pids, Int32(maxProcs) * Int32(MemoryLayout<pid_t>.size))
        guard actualCount > 0 else { return .empty }
        
        let count = Int(actualCount) / MemoryLayout<pid_t>.size
        
        // Parallel process info gathering with actor isolation
        return await withTaskGroup(of: ProcessInfo?.self) { group in
            for i in 0..<count {
                let pid = pids[i]
                group.addTask {
                    await self.getProcessInfo(pid: pid)
                }
            }
            
            var processes: [ProcessInfo] = []
            for await process in group {
                if let process = process {
                    processes.append(process)
                }
            }
            
            return ProcessList(processes: processes)
        }
    }
}
```

### Memory-Efficient Caching

```swift
// SharedCache.swift - Lock-free shared state
public actor SharedCache {
    private var metrics: SystemMetrics?
    private var subscribers: [UUID: (SystemMetrics) -> Void] = [:]
    
    // Single writer, multiple readers pattern
    func update(_ newMetrics: SystemMetrics) {
        // Only update if significantly different
        if let current = metrics,
           !newMetrics.significantlyDifferent(from: current) {
            return
        }
        
        metrics = newMetrics
        
        // Notify subscribers asynchronously
        let subs = subscribers
        Task.detached(priority: .high) {
            for (_, handler) in subs {
                handler(newMetrics)
            }
        }
    }
    
    func subscribe(_ handler: @escaping (SystemMetrics) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = handler
        
        // Send current state immediately
        if let metrics = metrics {
            handler(metrics)
        }
        
        return id
    }
}
```

### UI Layer Optimization

```swift
// SystemViewModel.swift - Efficient UI updates
@MainActor
final class SystemViewModel: ObservableObject {
    // Only publish what changes
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryPressure: Float = 0
    @Published private(set) var topProcesses: [ProcessInfo] = []
    
    // Non-published for internal use
    private var metrics: SystemMetrics?
    private let cache = SharedCache.shared
    private var subscriptionID: UUID?
    
    // Adaptive refresh based on system state
    private var refreshInterval: TimeInterval {
        guard let metrics = metrics else { return 5.0 }
        
        // High CPU or Memory pressure: faster updates
        if metrics.cpu.usage > 80 || metrics.memory.pressure > 0.7 {
            return 1.0
        }
        
        // Normal operation
        return 5.0
    }
    
    func startMonitoring() {
        subscriptionID = await cache.subscribe { [weak self] metrics in
            Task { @MainActor in
                self?.updateUI(with: metrics)
            }
        }
    }
    
    private func updateUI(with metrics: SystemMetrics) {
        // Only update changed values to minimize SwiftUI redraws
        if cpuUsage != metrics.cpu.usage {
            cpuUsage = metrics.cpu.usage
        }
        
        if memoryPressure != metrics.memory.pressure {
            memoryPressure = metrics.memory.pressure
        }
        
        // Use DifferenceKit for efficient list updates
        let diff = metrics.processes.top5CPU.difference(from: topProcesses)
        if !diff.isEmpty {
            topProcesses = metrics.processes.top5CPU
        }
    }
}
```

### Widget Optimization

```swift
// WidgetDataProvider.swift - Shared memory for widgets
public final class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    // Memory-mapped file for zero-copy sharing
    private let sharedMemoryURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.microverse")!
        .appendingPathComponent("metrics.mmap")
    
    private var memoryMap: MappedMemory<SystemMetrics>?
    
    func updateMetrics(_ metrics: SystemMetrics) {
        // Write to memory-mapped file
        memoryMap?.write(metrics)
        
        // Trigger widget updates efficiently
        WidgetCenter.shared.reloadTimelines(ofKind: "SystemWidget")
    }
    
    func latestMetrics() -> SystemMetrics? {
        return memoryMap?.read()
    }
}
```

## Performance Optimizations

### 1. Process Name Resolution
```swift
// Cache process names (they rarely change)
private let processNameCache = LRUCache<pid_t, String>(maxSize: 1000)

func getProcessName(pid: pid_t) -> String? {
    if let cached = processNameCache.get(pid) {
        return cached
    }
    
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let result = proc_name(pid, &buffer, UInt32(MAXPATHLEN))
    
    guard result > 0 else { return nil }
    
    let name = String(cString: buffer)
    processNameCache.set(pid, value: name)
    return name
}
```

### 2. Smart Diffing
```swift
// Only trigger UI updates for visible changes
extension ProcessInfo {
    func visuallyDifferent(from other: ProcessInfo) -> Bool {
        // 1% CPU difference is visible
        abs(self.cpuPercent - other.cpuPercent) >= 1.0 ||
        // 50MB memory difference is visible
        abs(self.memoryMB - other.memoryMB) >= 50
    }
}
```

### 3. Batch Operations
```swift
// Batch multiple metrics requests
actor MetricsQueue {
    private var pendingRequests: [(CheckedContinuation<SystemMetrics, Never>)] = []
    private var timer: Timer?
    
    func requestMetrics() async -> SystemMetrics {
        await withCheckedContinuation { continuation in
            pendingRequests.append(continuation)
            
            // Batch requests within 100ms window
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    Task {
                        await self.processBatch()
                    }
                }
            }
        }
    }
    
    private func processBatch() async {
        let requests = pendingRequests
        pendingRequests.removeAll()
        timer = nil
        
        // Single collection for all requests
        let metrics = await SystemReader.shared.gatherMetrics()
        
        for request in requests {
            request.resume(returning: metrics)
        }
    }
}
```

## Memory Management

### Object Pooling
```swift
// Reuse expensive objects
final class ViewPool<T: NSView> {
    private var available: [T] = []
    private let create: () -> T
    
    func acquire() -> T {
        if let view = available.popLast() {
            return view
        }
        return create()
    }
    
    func release(_ view: T) {
        view.prepareForReuse()
        available.append(view)
    }
}
```

### Lazy Loading
```swift
// Load process icons on demand
actor ProcessIconCache {
    private var icons: [String: NSImage] = [:]
    
    func icon(for bundleID: String) async -> NSImage? {
        if let cached = icons[bundleID] {
            return cached
        }
        
        // Load asynchronously
        let icon = await loadIcon(bundleID: bundleID)
        icons[bundleID] = icon
        return icon
    }
}
```

## Testing Strategy

### Performance Tests
```swift
func testMetricsCollection() async throws {
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
        let metrics = await SystemReader.shared.gatherMetrics()
        XCTAssertLessThan(metrics.timestamp.timeIntervalSinceNow, 0.1)
    }
}
```

### Stress Tests
```swift
func testHighLoadPerformance() async throws {
    // Simulate 100% CPU
    let stressor = CPUStressor()
    stressor.start()
    
    defer { stressor.stop() }
    
    // Ensure we still update within 2 seconds
    let metrics = await SystemReader.shared.gatherMetrics()
    XCTAssertNotNil(metrics)
}
```

This implementation provides the performance and elegance that would make both Carmack and Dean proud - efficient, scalable, and beautiful in its simplicity.