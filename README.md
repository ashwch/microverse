# Microverse

A unified system monitoring application for macOS featuring elegant battery, CPU, and memory monitoring with beautiful desktop widgets. Built with Johnny Ive design principles and John Carmack engineering excellence.

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![macOS](https://img.shields.io/badge/macOS-11.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

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

## Installation

### Requirements
- macOS 11.0 or later
- Xcode 13.0 or later (for building from source)

### Building from Source

1. Clone the repository:
```bash
git clone git@github.com:ashwch/microverse.git
cd microverse
```

2. Build and install using Make:
```bash
make install  # Builds and installs to /Applications (requires admin password)
```

Or for manual control:
```bash
make build    # Build only
make help     # See all available commands
```

### Running the App

After installation with `make install`, the app will automatically launch. You can also:
- Launch from `/Applications/Microverse.app`
- Look for the battery icon in your menu bar

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

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Ashwini Chaudhary** - Initial work and maintenance

## Acknowledgments

- Built with ❤️ for the macOS community
- Inspired by the need for a simple, beautiful battery monitor