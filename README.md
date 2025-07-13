# Microverse - Open Source Battery Manager for macOS

Microverse is an open-source alternative to AlDente for managing MacBook battery health with intelligent automatic management.

## Features

- **Charge Limiting**: Set maximum charge percentage (e.g., 80%)
- **Sailing Mode**: Force discharge while connected to power
- **Heat Protection**: Pause charging when battery is too warm
- **Calibration Mode**: Full charge/discharge cycle for battery calibration
- **Low Power Mode**: Automatic low power mode triggering
- **Menu Bar Interface**: Clean, native macOS interface

## Architecture

### Core Components

1. **SMC Manager**: Handles reading/writing to System Management Controller
2. **Battery Monitor**: Tracks battery state and statistics
3. **Charge Controller**: Implements charge limiting logic
4. **UI Layer**: SwiftUI-based menu bar app

### Technical Requirements

- macOS 11.0+
- Xcode 13+
- Administrator privileges for SMC access

## Building

```bash
git clone https://github.com/yourusername/microverse
cd microverse
xcodebuild -scheme Microverse -configuration Release
```

## License

MIT License