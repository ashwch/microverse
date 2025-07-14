# Microverse

A unified system monitoring application for macOS featuring elegant battery, CPU, and memory monitoring with beautiful desktop widgets. Built with elegant design principles and engineering excellence.

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![macOS](https://img.shields.io/badge/macOS-11.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![GitHub release](https://img.shields.io/github/v/release/ashwch/microverse)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/ashwch/microverse/release.yml?branch=main)

## 📖 Overview

Microverse transforms your Mac into a comprehensive system intelligence hub - your personal developer universe in the menu bar. Monitor battery health, CPU performance, memory pressure, and system insights through an elegant tabbed interface with optional desktop widgets.

**Perfect for developers who need real-time system insights without compromising performance.**

## Features

### System Monitoring
- 🔋 **Battery**: Real-time monitoring with health metrics and time estimates
- ⚙️ **CPU**: Live usage tracking with process-level insights  
- 🧠 **Memory**: Pressure monitoring with memory breakdown
- 📊 **Overview**: Unified system health dashboard

### Interface
- 🎯 **Tabbed Interface**: Clean navigation between monitoring categories
- 📱 **Menu Bar Integration**: Compact system status display
- 🖥️ **Desktop Widgets**: 6 beautiful widget styles for any workflow
- ⚡ **Real-time Updates**: Adaptive refresh rates for optimal performance

### Design
- 🎨 **Inspired Design**: Clarity, deference, and depth in every detail
- 🌙 **Adaptive UI**: Seamless light/dark mode integration  
- ✨ **Glass Effects**: Elegant blur backgrounds with subtle borders
- 🎯 **Semantic Colors**: Intuitive color coding (green=energy, blue=computing, purple=memory)

## Widget Styles

### Single Metric Widgets
- **Battery Simple (100×40)**: Just battery percentage with charging indicator
- **CPU Monitor (160×80)**: CPU usage with progress bar and status text
- **Memory Monitor (160×80)**: Memory usage percentage with pressure indicator

### Multi-Metric System Widgets
- **System Glance (160×50)**: Compact view of Battery + CPU + Memory percentages
- **System Status (240×80)**: Three-column layout with icons and percentages for all metrics
- **System Dashboard (240×120)**: Full detailed view with system health, all metrics, battery cycles, and time remaining

## 📦 Installation

### Download (Recommended)

**[⬇️ Download Latest Release](https://github.com/ashwch/microverse/releases/latest)**

1. Download the `Microverse-v1.0.0.dmg` file from releases
2. Open the DMG and drag Microverse to Applications  
3. Launch Microverse from Applications or Spotlight
4. **Important**: See [macOS Security Permissions](#️-important-macos-security-permissions) section below
5. Look for the system monitoring icon in your menu bar

### Building from Source

#### Requirements
- macOS 11.0 or later
- Xcode 13.0+ or Swift 5.9+

#### Quick Build
```bash
git clone https://github.com/ashwch/microverse.git
cd microverse
swift build -c release
```

#### Using Make (if available)
```bash
make install  # Builds and installs to /Applications
```

### ⚠️ Important: macOS Security Permissions

**When you first launch Microverse, macOS will block it because it's not from an identified developer.**

To run Microverse:

1. **First attempt**: Double-click Microverse → You'll see "Microverse can't be opened"
2. **Open System Settings** → Privacy & Security
3. **Scroll down** to see "Microverse was blocked from use because it is not from an identified developer"
4. **Click "Open Anyway"** → Enter your password if prompted
5. **Click "Open"** in the popup dialog

*This is a one-time process. After allowing it once, Microverse will launch normally.*

### First Launch

After granting permission, Microverse will:
- Add a system monitoring icon to your menu bar
- Allow access to system information (battery, CPU, memory)
- Show the tabbed interface when you click the menu bar icon

## Usage

### Menu Bar
- Click the system monitoring icon to open the main interface
- Tabbed navigation: Overview, Battery, CPU, Memory
- Unified settings panel with comprehensive options

### Interface Navigation
- **Overview Tab**: System health dashboard with unified metrics
- **Battery Tab**: Detailed battery monitoring and health insights
- **CPU Tab**: Real-time processor usage and top processes  
- **Memory Tab**: Memory pressure monitoring and usage breakdown

### Settings & Configuration
- **Menu Bar Display**: Show system status or specific metrics
- **Desktop Widgets**: Enable and configure 6 different widget styles
- **System Monitoring**: Toggle CPU/Memory tracking in widgets
- **Launch Controls**: Startup behavior and refresh intervals
- **Widget Positioning**: Drag widgets anywhere on desktop

### Desktop Widgets
- **6 Widget Styles**: From single-metric focused to comprehensive system dashboard
- **Clear Naming**: Each widget clearly indicates its purpose (Battery Simple, CPU Monitor, etc.)
- **Glass Design**: Elegant blur effects with 85% opacity matching macOS aesthetics
- **Always Accessible**: Floating widgets that stay on top for continuous monitoring
- **Instant Switching**: Change widget styles on-the-fly from settings

## Architecture

### Modern Tech Stack
- **SwiftUI** with async/await for responsive UI
- **IOKit & mach** for low-level system monitoring
- **Swift Package Manager** for modular architecture

### Core Modules
- **SystemCore**: CPU and memory monitoring framework
- **BatteryCore**: Advanced battery analytics and health tracking
- **UnifiedDesignSystem**: Elegant design tokens
- **SystemMonitoringService**: Singleton service for efficient data collection

### Key Components
- `TabbedMainView`: Main tabbed interface (Overview/Battery/CPU/Memory)
- `SystemMonitoringService`: Centralized system metrics collection
- `DesktopWidget`: 6 widget styles with unified background system
- `UnifiedDesignSystem`: Semantic color system and typography hierarchy

## Development

### Documentation
- [Current Architecture](docs/CURRENT_ARCHITECTURE.md) - Complete system overview
- [Technical Implementation](docs/TECHNICAL_IMPLEMENTATION.md) - Implementation details
- [Design Mockups](docs/DESIGN_MOCKUPS.md) - Visual design specifications
- [Expansion Plan](docs/EXPANSION_PLAN.md) - Development roadmap

### Design Principles
1. **Design Excellence**: Clarity through hierarchy, purposeful motion, contextual intelligence
2. **Performance First**: Async system calls, efficient polling, minimal CPU impact
3. **Semantic Design**: Green=energy, Blue=computing, Purple=memory
4. **Modular Architecture**: Clean separation between UI, services, and data layers

## 🛠️ Development

### Project Structure
```
Microverse/
├── Sources/
│   ├── Microverse/           # Main app UI and logic
│   ├── BatteryCore/          # Battery monitoring framework  
│   └── SystemCore/           # CPU/Memory monitoring framework
├── docs/                     # Comprehensive documentation
│   ├── CURRENT_ARCHITECTURE.md
│   ├── DESIGN.md
│   ├── ROADMAP.md
│   └── TECHNICAL_DEBT.md
└── .github/workflows/        # Automated CI/CD
```

### Key Technologies
- **SwiftUI** with async/await for responsive UI
- **IOKit & mach** for low-level system monitoring  
- **Swift Package Manager** for modular architecture
- **GitHub Actions** for automated builds and releases

### Performance Metrics
- **CPU Impact**: <1% average system usage
- **Memory Footprint**: <50MB resident memory
- **Update Intervals**: 10s system monitoring, 5s adaptive battery refresh
- **Compatibility**: Universal binary (Intel + Apple Silicon)

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following our design principles
4. Test thoroughly on different macOS versions
5. Submit a pull request with a clear description

### Development Guidelines
- Follow elegant design principles (clarity, deference, depth)
- Maintain <1% CPU impact and <50MB memory usage
- Use semantic color system (green=energy, blue=computing, purple=memory)
- Include comprehensive documentation for new features

## 🏆 Key Features in Detail

### Advanced Battery Analytics
- **Adaptive Refresh Rates**: Intelligent polling (2s critical, 30s when full)
- **Health Tracking**: Cycle count monitoring and degradation analysis
- **Time Estimates**: Machine learning-enhanced battery life predictions
- **Power State Detection**: Charging, plugged, and battery drain analysis

### System Performance Monitoring
- **Real-time CPU Usage**: Per-core utilization with thermal awareness
- **Memory Pressure Tracking**: Available, wired, compressed memory analysis
- **Process Insights**: Top resource consumers with categorization
- **System Health Indicators**: Visual status with predictive warnings

### Desktop Widget System
- **6 Widget Styles**: Single-metric (Battery/CPU/Memory) and multi-metric (Glance/Status/Dashboard)
- **Smart Layouts**: Optimized spacing and typography for each widget size
- **Instant Updates**: Real-time data with smooth animations
- **Drag & Position**: Place widgets anywhere on your desktop
- **Live Style Switching**: Change widget types without closing/reopening

### Developer-Focused Design
- **Menu Bar Integration**: Quick access without window switching
- **Tabbed Interface**: Organized navigation between monitoring categories
- **Performance Optimized**: <1% CPU impact, <50MB memory footprint
- **Extensible Architecture**: Clean separation for future enhancements

## 🚀 Performance Metrics

### System Impact
- **CPU Usage**: <1% average system load
- **Memory Footprint**: <50MB resident memory
- **Battery Impact**: Minimal drain with adaptive refresh rates
- **Startup Time**: <2 seconds to full functionality

### Monitoring Accuracy
- **Battery Information**: Direct IOKit access for precise readings
- **CPU Metrics**: Real-time via mach system calls
- **Memory Data**: Kernel-level statistics for accuracy
- **Update Frequency**: 5-30 second adaptive intervals

## 📋 Development Roadmap

### Immediate (v1.1)
- **Process Monitoring**: Top CPU/Memory consuming applications
- **Smart Categorization**: Development, Creative, System, Background apps
- **Historical Trends**: 24-hour system performance graphs
- **Export Features**: CSV/JSON data export for analysis

### Short Term (v1.5)
- **Network Monitoring**: Bandwidth usage and connection tracking
- **Thermal Management**: Temperature monitoring with fan speed data
- **Custom Alerts**: User-defined thresholds and notifications
- **Dashboard Builder**: Configurable widget layouts

### Long Term (v2.0+)
- **Machine Learning**: Predictive battery life and performance insights
- **Cross-Device Sync**: iCloud integration for multi-Mac monitoring
- **API Integration**: Webhook support and third-party app connections
- **iOS Companion**: Remote monitoring via iPhone/iPad app

See our comprehensive [documentation](docs/) for detailed technical specifications, architecture diagrams, and design guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Free and open source forever.** ✨

## 👨‍💻 Author

**Ashwini Chaudhary** - Creator and maintainer

## 🙏 Acknowledgments

- Built with ❤️ for the macOS development community
- Inspired by the need for elegant, performant system monitoring
- Design philosophy focused on clarity and elegance
- Engineering approach emphasizing performance and efficiency

---

**⭐ If Microverse helps you monitor your system, please star the repository to show your support!**

---

*Latest version includes complete settings UI redesign and full functionality for all toggles and controls.*