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