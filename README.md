# Microverse

A clean, minimalist battery monitoring app for macOS with beautiful desktop widgets.

![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)
![macOS](https://img.shields.io/badge/macOS-11.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

- 🔋 Real-time battery monitoring
- 📊 Clean menu bar display with customizable options
- 🖥️ Four beautiful desktop widget styles
- ⚡ Charging status and time remaining
- 📈 Battery health and cycle count tracking
- 🎨 Minimalist design with blur effects
- 🚀 Lightweight and efficient

## Widget Styles

- **Minimal**: Compact 100×40px display showing just battery percentage
- **Compact**: 160×50px with battery percentage and time remaining
- **Standard**: 180×100px vertical layout with large percentage display
- **Detailed**: 240×120px comprehensive view with all battery statistics

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

2. Build using Swift Package Manager:
```bash
swift build --product Microverse --configuration release
```

3. The built app will be in `.build/release/Microverse`

### Running the App

1. Copy the built binary to Applications folder
2. Launch Microverse from Applications
3. Look for the battery icon in your menu bar

## Usage

### Menu Bar
- Click the battery icon to open the status popover
- Shows current charge percentage, status, cycles, and health
- Access settings to customize display options

### Settings
- **Show percentage in menu bar**: Toggle percentage display next to icon
- **Enable widget**: Show floating desktop widget
- **Widget style**: Choose from Minimal, Compact, Standard, or Detailed
- **Launch at startup**: Automatically start with macOS
- **Refresh interval**: Adjust battery data update frequency

### Desktop Widgets
- Enable from settings and choose your preferred style
- Widget appears in top-right corner by default
- Drag to reposition anywhere on screen
- Always stays on top for easy monitoring

## Architecture

Built with:
- **SwiftUI** for modern UI
- **IOKit** for battery information
- **SPM** for dependency management

Key components:
- `BatteryCore`: Core battery monitoring logic
- `MenuBarApp`: Menu bar application management
- `DesktopWidget`: Floating widget implementation
- `CleanMainView`: Main UI popover

## Development

See [Widget Design Specification](docs/WidgetDesignSpec.md) for detailed implementation guidelines.

### Key Implementation Rules
1. Never use ZStack as root container (causes clipping)
2. Always set explicit frame sizes matching window dimensions
3. Apply backgrounds last in view hierarchy
4. Keep padding inside frames
5. Test with edge cases (100% battery, long time strings)

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
- Thanks to all contributors and users