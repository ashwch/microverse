# Microverse

A unified system monitoring application for macOS featuring elegant battery, CPU, and memory monitoring with beautiful desktop widgets. Built with Johnny Ive design principles and John Carmack engineering excellence.

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
- 🎨 **Johnny Ive Inspired**: Clarity, deference, and depth in every detail
- 🌙 **Adaptive UI**: Seamless light/dark mode integration  
- ✨ **Glass Effects**: Elegant blur backgrounds with subtle borders
- 🎯 **Semantic Colors**: Intuitive color coding (green=energy, blue=computing, purple=memory)

## Widget Styles

### Battery Focused
- **Minimal (100×40)**: Battery percentage only
- **Compact (160×50)**: Battery + time remaining  
- **Standard (180×100)**: Large percentage with status
- **Detailed (240×120)**: Complete battery statistics

### System Monitoring
- **CPU (160×80)**: Dedicated CPU usage monitoring
- **Memory (160×80)**: Memory pressure and usage
- **System (240×100)**: Unified overview of all metrics

## 📦 Installation

### Download (Recommended)

**[⬇️ Download Latest Release](https://github.com/ashwch/microverse/releases/latest)**

1. Download the `Microverse-v1.0.0.dmg` file from releases
2. Open the DMG and drag Microverse to Applications  
3. Launch Microverse from Applications or Spotlight
4. Look for the system monitoring icon in your menu bar

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

### First Launch

After installation, Microverse will:
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
- **System-aware**: Automatically show system information when enabled
- **Adaptive Content**: Different metrics based on widget style
- **Glass Design**: Elegant blur effects matching macOS design language
- **Always Accessible**: Stay on top for continuous monitoring

## Architecture

### Modern Tech Stack
- **SwiftUI** with async/await for responsive UI
- **IOKit & mach** for low-level system monitoring
- **Swift Package Manager** for modular architecture

### Core Modules
- **SystemCore**: CPU and memory monitoring framework
- **BatteryCore**: Advanced battery analytics and health tracking
- **UnifiedDesignSystem**: Johnny Ive-inspired design tokens
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
- [Expansion Plan](docs/EXPANSION_PLAN.md) - Future roadmap

### Design Principles
1. **Johnny Ive Approach**: Clarity through hierarchy, purposeful motion, contextual intelligence
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
- Follow Johnny Ive design principles (clarity, deference, depth)
- Maintain <1% CPU impact and <50MB memory usage
- Use semantic color system (green=energy, blue=computing, purple=memory)
- Include comprehensive documentation for new features

## 📋 Roadmap

**Near Term (Next Release)**
- Process monitoring with smart app categorization  
- Historical trend tracking and analytics
- Advanced network and thermal monitoring

**Future Vision**
- Custom dashboard builder
- Machine learning for predictive insights
- Export capabilities and API integration
- iOS companion app for remote monitoring

See [ROADMAP.md](docs/ROADMAP.md) for detailed technical specifications.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Free and open source forever.** ✨

## 👨‍💻 Author

**Ashwini Chaudhary** - Creator and maintainer

## 🙏 Acknowledgments

- Built with ❤️ for the macOS development community
- Inspired by the need for elegant, performant system monitoring
- Design philosophy influenced by Johnny Ive's principles
- Engineering approach inspired by John Carmack's performance focus

---

**⭐ If Microverse helps you monitor your system, please star the repository to show your support!**