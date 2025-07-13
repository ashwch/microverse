# Adaptive Refresh Rate Documentation

## Overview

Microverse implements an intelligent adaptive refresh rate system that optimizes battery monitoring frequency based on the current battery state. This reduces unnecessary CPU usage while ensuring timely updates when needed.

## How It Works

The refresh rate dynamically adjusts based on these conditions:

### Critical Battery (≤5%)
- **Refresh Rate**: Every 2 seconds (or user preference if lower)
- **Rationale**: Users need frequent updates when battery is critically low

### Low Battery (≤20%)
- **Refresh Rate**: Normal user preference (default 5 seconds)
- **Rationale**: Important to monitor but not critical

### Charging
- **Refresh Rate**: Normal user preference (default 5 seconds)
- **Rationale**: Users want to see charging progress

### Plugged In at 100%
- **Refresh Rate**: 6x slower (30 seconds if base is 5)
- **Rationale**: Battery state is stable, minimal monitoring needed

### Plugged In at 80%+
- **Refresh Rate**: 3x slower (15 seconds if base is 5)
- **Rationale**: Battery changing slowly, reduced monitoring sufficient

### On Battery Power
- **Refresh Rate**: Normal user preference (default 5 seconds)
- **Rationale**: Standard monitoring for battery drain

## Implementation Details

The adaptive logic is implemented in `BatteryViewModel.swift`:

```swift
private func calculateAdaptiveRefreshInterval() -> TimeInterval {
    let baseInterval = refreshInterval
    
    if batteryInfo.currentCharge <= 5 {
        return min(baseInterval, 2.0)
    } else if batteryInfo.currentCharge <= 20 {
        return baseInterval
    } else if batteryInfo.isCharging {
        return baseInterval
    } else if batteryInfo.isPluggedIn && batteryInfo.currentCharge >= 100 {
        return baseInterval * 6
    } else if batteryInfo.isPluggedIn && batteryInfo.currentCharge >= 80 {
        return baseInterval * 3
    } else {
        return baseInterval
    }
}
```

## Benefits

1. **Reduced CPU Usage**: Up to 83% reduction when plugged in at 100%
2. **Better Battery Life**: Less frequent wake-ups on battery power
3. **Responsive When Needed**: Fast updates during critical situations
4. **User Control**: Base interval still respects user preference

## Monitoring

The system logs adaptive refresh decisions for debugging:
```
Adaptive refresh: Next update in 30s (battery: 100%, charging: false)
```

This can be viewed in Console.app by filtering for "com.microverse.app".

## Technical Implementation Details

### Algorithm Location & Code References
The adaptive refresh logic is implemented in `BatteryViewModel.swift` at lines 145-165:

```swift
private func calculateAdaptiveRefreshInterval() -> TimeInterval {
    let baseInterval = refreshInterval
    
    if batteryInfo.currentCharge <= 5 {
        return min(baseInterval, 2.0)           // Critical: max 2s
    } else if batteryInfo.currentCharge <= 20 {
        return baseInterval                     // Low: normal rate
    } else if batteryInfo.isCharging {
        return baseInterval                     // Charging: normal rate
    } else if batteryInfo.isPluggedIn && batteryInfo.currentCharge >= 100 {
        return baseInterval * 6                 // Full & plugged: 6x slower
    } else if batteryInfo.isPluggedIn && batteryInfo.currentCharge >= 80 {
        return baseInterval * 3                 // High & plugged: 3x slower
    } else {
        return baseInterval                     // On battery: normal rate
    }
}
```

### Integration with Timer System
The adaptive refresh integrates with the main timer in `startTimer()` method:

```swift
private func startTimer() {
    timer?.invalidate()
    let interval = calculateAdaptiveRefreshInterval()
    
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor in
            await self?.updateBatteryInfo()
        }
    }
    
    logger.info("Adaptive refresh: Next update in \(interval)s (battery: \(batteryInfo.currentCharge)%, charging: \(batteryInfo.isCharging))")
}
```

### Performance Impact Measurements

#### CPU Usage Reduction
- **100% Battery (Plugged)**: 83% reduction (5s → 30s intervals)
- **80-99% Battery (Plugged)**: 67% reduction (5s → 15s intervals)  
- **Critical Battery (<5%)**: 60% increase (5s → 2s intervals)
- **Normal Operation**: No change (5s intervals maintained)

#### Battery Life Impact
- **Plugged Operation**: Minimal CPU wake-ups extend battery life
- **Critical Battery**: More frequent updates provide crucial information when needed most
- **Overall**: Balanced approach optimizing for both performance and user experience

### Edge Cases & Handling

#### State Transition Handling
```swift
// Timer is recreated on every battery state change
private func updateBatteryInfo() async {
    let oldCharge = batteryInfo.currentCharge
    let oldCharging = batteryInfo.isCharging
    
    // Update battery information
    batteryInfo = batteryReader.getBatteryInfoSafe()
    
    // Check if adaptive interval should change
    let newInterval = calculateAdaptiveRefreshInterval()
    let currentInterval = timer?.timeInterval ?? refreshInterval
    
    if abs(newInterval - currentInterval) > 0.1 {
        startTimer() // Recreate timer with new interval
    }
}
```

#### User Setting Override
The adaptive system respects user-configured refresh intervals:
- **User sets 2s**: Critical battery uses 2s (no acceleration)
- **User sets 30s**: Critical battery uses 2s (overrides for safety)
- **User sets 10s**: Normal scaling applies (10s → 60s at 100%)

### Logging & Debugging

#### Debug Information Available
```swift
// Logged on every interval change
logger.info("Adaptive refresh: Next update in \(interval)s (battery: \(batteryInfo.currentCharge)%, charging: \(batteryInfo.isCharging))")

// Additional context for debugging
logger.debug("Battery state: charge=\(batteryInfo.currentCharge)%, plugged=\(batteryInfo.isPluggedIn), charging=\(batteryInfo.isCharging)")
logger.debug("Calculated interval: \(newInterval)s (base: \(refreshInterval)s)")
```

#### Console Monitoring
Use Console.app with filter "com.microverse.app" to monitor:
- Interval calculations in real-time
- Battery state transitions
- Performance impact of adaptive refresh

### Configuration & Tuning

#### Threshold Customization
Current thresholds are optimized for typical usage but could be made configurable:

```swift
// Potential future enhancement
struct AdaptiveRefreshSettings {
    let criticalThreshold: Int = 5      // Below this: 2s max
    let lowThreshold: Int = 20          // Below this: normal rate  
    let highThreshold: Int = 80         // Above this when plugged: 3x slower
    let fullThreshold: Int = 100        // At this when plugged: 6x slower
    let criticalMaxInterval: TimeInterval = 2.0
    let pluggedSlowMultiplier: Double = 3.0
    let fullSlowMultiplier: Double = 6.0
}
```

### Testing & Validation

#### Test Scenarios
1. **Gradual Discharge**: Verify smooth interval transitions from 100% → 0%
2. **Charging Cycle**: Test plugged → charging → full transitions
3. **Critical Battery**: Ensure 2s maximum interval below 5%
4. **User Setting Interaction**: Verify user preferences are respected
5. **State Persistence**: Test behavior across app restarts

#### Performance Validation
- Monitor actual CPU usage during different battery states
- Verify battery life improvement during plugged operation
- Measure user experience impact during critical battery situations

This adaptive refresh system balances system performance with user information needs, automatically optimizing based on battery state while respecting user preferences and ensuring critical information is always available when needed.