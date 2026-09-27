# Microverse

> **A unified macOS system monitoring application with elegant desktop widgets, smart notch integration, and secure auto-updates**

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/Architecture-Universal%20Binary-success.svg)](https://developer.apple.com/documentation/apple-silicon)
[![Performance](https://img.shields.io/badge/Performance-%3C1%25%20CPU-brightgreen.svg)](docs/PERFORMANCE.md)

[**Download**](https://github.com/ashwch/microverse/releases/latest) • [Architecture](docs/CURRENT_ARCHITECTURE.md) • [Design System](docs/DESIGN.md) • [Performance](docs/PERFORMANCE.md) • [Contributing](CONTRIBUTING.md)

## 🎯 Mission

Transform your Mac into a comprehensive system intelligence hub with **real-time monitoring**, **elegant widgets**, and **seamless notch integration** — all while maintaining **<1% CPU usage** and **<50MB memory footprint**.

Perfect for developers who need real-time system insights without compromising performance.

## ✨ Features

### 🔋 **Comprehensive System Monitoring**
- **Battery Intelligence**: Health metrics, cycle count, time estimates, charging optimization
- **CPU Performance**: Real-time usage, core breakdown, thermal state monitoring  
- **Memory Analysis**: Pressure detection, usage breakdown, swap monitoring
- **Wi‑Fi & Network**: Wi‑Fi strength + connection state + live throughput
- **Audio Routing**: Switch input/output devices, with volume/mute controls when supported
- **Weather (Optional)**: Temperature and upcoming changes in the Weather tab, menu bar, Smart Notch, and desktop widget
- **System Health**: Intelligent insights with actionable recommendations

### 🎨 **Adaptive User Interface**
- **Desktop Widget Styles**: Multiple layout options from compact to comprehensive displays
- **Smart Notch Integration**: Seamless integration with macOS notch area
- **Notch Glow Alerts**: Animated glow around the notch for key battery, weather, and device events
- **Menu Bar Integration**: Battery percentage and optional temperature display
- **Tabbed Interface**: System, Weather, and Alerts with a unified design system

### ⚡ **Performance Excellence**
- **Adaptive Refresh Rates**: 2s critical → 30s idle (up to 83% CPU reduction)
- **Direct System Access**: IOKit + mach APIs (no subprocess overhead)
- **Demand-Driven Polling**: CPU/memory sampling only while visible surfaces are active
- **Universal Binary**: Native Intel + Apple Silicon optimization
- **Memory Efficient**: Smart caching with minimal footprint

### 🔒 **Enterprise-Grade Security**
- **Secure Auto-Updates**: Sparkle 2.10 with code signature verification
- **Sandboxed Architecture**: Minimal entitlements, maximum security
- **Privacy First**: No analytics; system metrics are local; optional network requests for updates + weather; optional permissions for location (current-location weather) and bluetooth (AirPods battery)

## 📸 Screenshots

### Smart Notch Integration
<table>
<tr>
<td><img src="docs/screenshots/notch-widget-compact.png" width="300"/><br><b>Compact Mode</b><br>Unified metrics display</td>
<td><img src="docs/screenshots/notch-widget-expanded.png" width="300"/><br><b>Expanded Mode</b><br>Detailed system status</td>
</tr>
<tr>
<td><img src="docs/screenshots/notch-weather-compact.png" width="300"/><br><b>Weather Peek</b><br>Temperature + upcoming change</td>
<td><img src="docs/screenshots/notch-weather-expanded.png" width="300"/><br><b>Weather (Expanded)</b><br>Optional weather row</td>
</tr>
</table>

### Desktop Widgets
<table>
<tr>
<td><img src="docs/screenshots/desktop-widget-glance.png" width="150"/><br><b>System Glance</b><br>Compact horizontal layout</td>
<td><img src="docs/screenshots/desktop-widget-status.png" width="150"/><br><b>System Status</b><br>Three-column detailed view</td>
<td><img src="docs/screenshots/desktop-widget-dashboard.png" width="150"/><br><b>System Dashboard</b><br>Comprehensive metrics display</td>
</tr>
<tr>
<td colspan="3"><img src="docs/screenshots/desktop-widget-glance-weather.png" width="200"/><br><b>Weather Peek</b><br>System Glance temperature swap-in</td>
</tr>
</table>

### Application Interface
<table>
<tr>
<td><img src="docs/screenshots/app-overview-tab.png" width="200"/><br><b>Overview Tab</b><br>System health at a glance</td>
<td><img src="docs/screenshots/app-battery-tab.png" width="200"/><br><b>Battery Tab</b><br>Detailed power metrics</td>
</tr>
<tr>
<td><img src="docs/screenshots/app-cpu-tab.png" width="200"/><br><b>CPU Tab</b><br>Processor performance analysis</td>
<td><img src="docs/screenshots/app-memory-tab.png" width="200"/><br><b>Memory Tab</b><br>Memory usage and pressure</td>
</tr>
<tr>
<td><img src="docs/screenshots/app-weather-tab.png" width="200"/><br><b>Weather Tab</b><br>Temperature + upcoming changes</td>
<td><img src="docs/screenshots/app-settings-compact.png" width="200"/><br><b>Settings</b><br>Elegant controls and preferences</td>
</tr>
</table>

## 🚀 Installation

### Quick Install
**[Download Latest Release](https://github.com/ashwch/microverse/releases/latest)**

1. Download `Microverse-v{version}.dmg`
2. Drag to `/Applications` 
3. **First Launch**: System Settings → Privacy & Security → "Open Anyway"
4. Look for the alien 👽 icon in your menu bar

### Build from Source
```bash
git clone https://github.com/ashwch/microverse.git
cd microverse
make install    # Requires Xcode 16+ or Swift 6.0+
```

**Requirements**: macOS 13.0+, Universal Binary support

## 🏗️ Architecture

### Modular Framework Design
```
Package.swift
├── Microverse (executable) - SwiftUI + App Logic
│   ├── depends: BatteryCore
│   ├── depends: SystemCore  
│   ├── depends: Sparkle (auto-updates)
│   └── depends: DynamicNotchKit (notch integration)
├── BatteryCore (framework) - IOKit battery monitoring
├── SystemCore (framework) - mach CPU/memory monitoring
└── MicroverseBenchmark (executable) - release-mode performance harness
```

### Quick Usage
**Menu Bar**: Click 👽 icon → System (Overview/Battery/CPU/Memory/Network/Audio) + Weather + Alerts  
**Desktop Widgets**: Settings → Desktop Widget (toggle + style)  
**Smart Notch**: Settings → Smart Notch (Left / Split / Off)  
**Weather**: Settings → Weather (manual locations or current location + surfaces + optional peeks/highlights)  
**Notch Glow Alerts**: Settings → Alerts → Notch Glow Alerts (toggle + rules + test buttons)

### Data Flow
```
Hardware → Core Frameworks → Services → ViewModels → UI Components
IOKit     BatteryCore      SystemMonitoringService   SwiftUI Views
mach      SystemCore       BatteryViewModel          Desktop Widgets
```

### Performance Monitoring
- **CPU Usage**: Target <1% average (verified with Activity Monitor)
- **Memory Footprint**: Target <50MB (measured in Memory tab)
- **Battery Impact**: Minimal drain optimization
- **Adaptive Refresh**: 83% CPU reduction when idle

## 🎨 Design System

### Design Philosophy

**Semantic Color System**
- 🟢 **Battery** (Energy) → Green success palette
- 🔵 **CPU** (Computing) → Blue neutral palette  
- 🟣 **Memory** (Storage) → Purple distinctive palette
- ⚪ **System** (Overall) → White accent system

**Typography Hierarchy** (SF Pro Rounded)
- 32pt Display → Hero numbers (CPU/Memory percentages)
- 24pt Large Title → Battery percentage, section headers
- 18pt Title → Memory format ("X.X / Y.Y GB")
- 14pt Body → Standard content, time remaining
- 12pt Caption → Status text, info labels

**Layout System** (4px Grid)
- Consistent spacing scale: 4, 8, 12, 16, 24, 32pt
- Golden ratio proportions for UI elements
- Mathematical precision in component sizing

## 🔧 Development

### Local Development
```bash
# Development build & run
make run

# Release build & install  
make install

# Clean build artifacts
make clean

# Interactive Xcode build
./build_local.sh
```

### Testing
```bash
# Run unit tests (when available)
swift test

# Performance benchmark harness
make benchmark

# Process-level validation
# Monitor with Activity Monitor during development/release checks
```

### Code Quality Standards
- **SwiftUI Best Practices**: @MainActor isolation, async/await patterns
- **Design System Compliance**: All UI uses MicroverseDesign tokens
- **Performance First**: Profile all changes for CPU/memory impact
- **Error Handling**: Graceful degradation with safe defaults
- **Documentation**: Comprehensive inline documentation

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Follow our [Contributing Guide](CONTRIBUTING.md)
4. Ensure all changes use the design system tokens
5. Test performance impact (CPU <1%, Memory <50MB)
6. Submit a pull request with detailed description

## 📚 Documentation

- [**Technical Architecture**](docs/CURRENT_ARCHITECTURE.md) - System design and data flow
- [**Design System**](docs/DESIGN.md) - UI components and guidelines  
- [**Performance Guide**](docs/PERFORMANCE.md) - Optimization architecture and benchmark workflow
- [**Auto-Update System**](docs/SPARKLE_AUTO_UPDATE_SYSTEM.md) - Security and implementation
- [**Wi‑Fi + Audio**](docs/WIFI_AUDIO_FEATURES.md) - Stores, surfaces, permissions, and testing
- [**Weather locations + alerts**](docs/WEATHER_LOCATIONS_AND_ALERTS.md) - Multi-location, current location, and glow alerts
- [**Screenshots guide**](docs/SCREENSHOTS.md) - Capture checklist + filename conventions
- [**SystemCore Reference**](Sources/SystemCore/SystemMonitor.swift) - CPU and memory monitor implementation

## 🔒 Security

- **Sandboxed Application**: Minimal entitlements for maximum security
- **Secure Updates**: Sparkle framework with signed appcast verification
- **Privacy First**: No analytics; system metrics are local; optional network requests for updates + weather
- **Minimal Permissions**: Network client for updates/weather + local system APIs for monitoring

## 📊 Performance Metrics

| Metric | Target | Typical (machine-dependent) |
|--------|--------|--------|
| CPU Usage (Active) | <1% | varies by active modules and surfaces |
| CPU Usage (Idle) | <0.1% | near zero when monitoring clients are inactive |
| Memory Footprint | <50MB | framework-dependent baseline + active features |
| Battery Impact | Minimal | lower with coalesced timers and demand-driven polling |
| Launch Time | <2s | hardware dependent |

## 🙏 Acknowledgments

### Core Dependencies
- **[Sparkle Framework](https://github.com/sparkle-project/Sparkle)** - Secure automatic software updates
- **[DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)** - Elegant notch integration for macOS

### Engineering Excellence
- **Swift Concurrency** - Modern async/await patterns for responsive UI
- **SwiftUI Framework** - Declarative UI with reactive state management
- **IOKit & mach APIs** - Direct system access for optimal performance

## 📄 License

**MIT License** - Free and open source forever ✨

```
Copyright (c) 2024 Ashwini Chaudhary

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[Full MIT License text...]
```

## 👨‍💻 Contributors

**Ashwini Chaudhary** ([@ashwch](https://github.com/ashwch))  
*Project Creator & Maintainer*

**Engineering Contributors**
- [@napender](https://github.com/napender) - Bug fixes and stability improvements

---

## 🌟 Star History

If Microverse enhances your development workflow, please **star the repository** to show your support and help others discover this project!

[![Star History Chart](https://api.star-history.com/svg?repos=ashwch/microverse&type=Date)](https://star-history.com/#ashwch/microverse&Date)

---

**Built with ❤️ for the macOS development community**

*Perfect for developers who demand both elegance and performance in their system monitoring tools.*
