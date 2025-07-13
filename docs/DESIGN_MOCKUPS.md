# Microverse Design Mockups

## Visual Design Language

### Color Palette
- **System Health Colors**
  - Healthy: System Green (#34C759)
  - Caution: System Orange (#FF9500)  
  - Critical: System Red (#FF3B30)
  - Normal: Primary (adapts to light/dark)
  
- **Metric-Specific Colors**
  - Battery: Green gradient (charging) / White (normal)
  - CPU: Blue gradient (#007AFF to #5856D6)
  - Memory: Purple gradient (#AF52DE to #5856D6)

### Typography Scale
- **Large Display**: SF Pro Display 32pt (Overview percentage)
- **Section Headers**: SF Pro Display 17pt Semibold
- **Metrics**: SF Pro Text 15pt Medium
- **Process Names**: SF Pro Text 13pt Regular
- **Captions**: SF Pro Text 11pt Regular

## Detailed UI Mockups

### Menu Bar States

#### Compact Mode (Default)
```
[█▪▫] 23%    <- Single icon showing worst metric
```

#### Expanded Mode (Optional)
```
[⚡85%] [⚙23%] [🧠67%]    <- Individual metrics
```

#### Alert State
```
[█▪▫] ⚠️ 89%    <- Pulsing warning when critical
```

### Popover - Overview Tab

```
┌──────────────────────────────────────┐
│  ◐ Overview   ⚡   ⚙   🧠           │ 40pt
├──────────────────────────────────────┤
│                                      │
│           SYSTEM HEALTH              │ 20pt
│                                      │
│         ╭─────────────╮              │
│      ╭──┤             ├──╮           │ 120pt ring
│     ╱   │    Good     │   ╲          │
│    │    │             │    │         │
│    │    │  ⚡ ⚙ 🧠   │    │         │
│    │    │   85 23 67  │    │         │
│    │    │             │    │         │
│     ╲   │             │   ╱          │
│      ╰──┤             ├──╯           │
│         ╰─────────────╯              │
│                                      │
│  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌    │
│                                      │
│  ALERTS & INSIGHTS                   │ 20pt
│                                      │
│  ⚠️ Xcode using high CPU (47%)       │
│  💡 Memory pressure increasing       │
│                                      │
├──────────────────────────────────────┤
│  ⚙ Settings                    ↻    │ 40pt
└──────────────────────────────────────┘
Total: 320×400pt
```

### Popover - CPU Tab

```
┌──────────────────────────────────────┐
│  ◐   ⚡   ⚙ CPU   🧠                │
├──────────────────────────────────────┤
│                                      │
│  CPU USAGE          23%              │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░     │
│                                      │
│  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌    │
│                                      │
│  TOP PROCESSES                       │
│                                      │
│  Xcode              47%  ████████░   │
│  Development                         │
│                                      │
│  Safari             12%  ███░░░░░░   │
│  Web Browser                         │
│                                      │
│  Spotify             8%  ██░░░░░░░   │
│  Media                               │
│                                      │
│  Terminal            5%  █░░░░░░░░   │
│  Development                         │
│                                      │
│  Slack               3%  ▌░░░░░░░░   │
│  Communication                       │
│                                      │
│  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌    │
│                                      │
│  Apple M1 Pro • 8 Cores • 3.2 GHz   │
│                                      │
└──────────────────────────────────────┘
```

### Popover - Memory Tab

```
┌──────────────────────────────────────┐
│  ◐   ⚡   ⚙   🧠 Memory              │
├──────────────────────────────────────┤
│                                      │
│  MEMORY USAGE                        │
│                                      │
│      18.2 GB / 32 GB                 │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░         │
│                                      │
│  Pressure: ● Normal                  │
│  Swap Used: 0 MB                     │
│  Compressed: 2.1 GB                  │
│                                      │
│  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌    │
│                                      │
│  TOP PROCESSES                       │
│                                      │
│  Chrome           4.2 GB  ████████   │
│  12 tabs • 4 extensions              │
│                                      │
│  Xcode            3.1 GB  ██████░    │
│  3 projects open                     │
│                                      │
│  Docker           2.8 GB  █████░░    │
│  4 containers running                │
│                                      │
│  Slack            1.2 GB  ███░░░░    │
│  5 workspaces                        │
│                                      │
│  Spotify          0.8 GB  ██░░░░░    │
│  High quality streaming              │
│                                      │
└──────────────────────────────────────┘
```

### Widget Designs

#### System Widget - Minimal (100×40)
```
┌────────────────────┐
│ ⚡85  ⚙23  🧠67   │  <- Compact metrics
└────────────────────┘
```

#### System Widget - Compact (160×50)
```
┌──────────────────────────────┐
│ System  ⚡85% ⚙23% 🧠18.2G  │
│ Health  Good • Low pressure  │
└──────────────────────────────┘
```

#### System Widget - Standard (180×100)
```
┌─────────────────────────────┐
│        Microverse           │
│                             │
│    ◐ System Health: Good    │
│                             │
│    ⚡ Battery    85%  3:42  │
│    ⚙ CPU        23%  Low   │
│    🧠 Memory    57%  18.2G  │
└─────────────────────────────┘
```

#### System Widget - Detailed (240×120)
```
┌────────────────────────────────┐
│           Microverse           │
├────────────────────────────────┤
│  ⚡ 85%   ⚙ 23%   🧠 57%      │
├────────────────────────────────┤
│  HOT: Xcode         47% CPU   │
│       Chrome        4.2GB Mem  │
│                                │
│  System Health: Good           │
└────────────────────────────────┘
```

## Interaction Design

### Animations
- **Tab Transitions**: 0.25s spring animation, slide + fade
- **Ring Animation**: Smooth 0.5s morph between states
- **Process Bars**: 0.3s ease-out when values change
- **Hover States**: 0.1s fade for interactive elements

### Gestures
- **Click on Ring**: Cycle through metrics
- **Click on Process**: Open Activity Monitor to that process
- **Click on Metric**: Jump to respective tab
- **Hover on Process**: Show additional details tooltip

### Adaptive Behavior
- **High CPU/Memory**: Refresh every 2 seconds
- **Normal State**: Refresh every 5 seconds  
- **Idle State**: Refresh every 30 seconds
- **Background**: Pause non-critical updates

## Implementation Notes

### Performance Considerations
1. **Reuse NSProgressIndicator** for bars (native performance)
2. **Cache gradient colors** (expensive to create)
3. **Debounce process list updates** (max 1 update/second)
4. **Use DifferenceKit** for process list changes

### Accessibility
- **VoiceOver**: Full descriptions for all metrics
- **Keyboard Navigation**: Tab through all elements
- **High Contrast**: Respect system settings
- **Reduced Motion**: Disable animations option

### Edge Cases
- **No Battery** (Mac Mini/Studio): Hide battery tab
- **Many Processes**: Scrollable list with virtualization
- **System Overload**: Degrade gracefully, show what we can
- **First Launch**: Tutorial overlay highlighting features

This design creates a cohesive, beautiful, and functional expansion of Microverse that truly represents your digital universe as a developer.