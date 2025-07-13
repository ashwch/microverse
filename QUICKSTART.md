# Quick Start Guide - Building Microverse

## Prerequisites
- macOS 11.0 or later
- Xcode 13.0 or later

## Building with Xcode (GUI)

1. **Open the project**
   ```bash
   cd /Users/monty/work/diversio/Microverse
   open Microverse.xcodeproj
   ```

2. **In Xcode:**
   - Select "Microverse" scheme (top left)
   - Select your Mac as destination
   - Press ⌘+B to build
   - Press ⌘+R to run

## Building from Terminal

1. **After installing Xcode, run:**
   ```bash
   # Set Xcode path
   sudo xcode-select -s /Applications/Xcode.app
   
   # Build the app
   ./build_local.sh
   ```

2. **Or use make:**
   ```bash
   make build
   make run
   ```

3. **Or use xcodebuild directly:**
   ```bash
   xcodebuild -project Microverse.xcodeproj -scheme Microverse build
   ```

## If Build Fails

1. **Accept Xcode license:**
   ```bash
   sudo xcodebuild -license accept
   ```

2. **Reset Xcode:**
   ```bash
   sudo xcode-select --reset
   ```

3. **Clean and rebuild:**
   ```bash
   make clean
   make build
   ```

## Installing the App

```bash
# Option 1: Using make
make install

# Option 2: Manual copy
cp -R build/Build/Products/Debug/Microverse.app /Applications/

# Option 3: Open and drag
open build/Build/Products/Debug/
# Then drag Microverse.app to Applications
```

## First Run

1. **You'll see a security warning** (unsigned app)
2. Go to System Settings > Privacy & Security
3. Click "Open Anyway" for Microverse
4. Grant permissions when prompted

## Troubleshooting

- **"xcrun: error: invalid active developer path"**
  ```bash
  xcode-select --install
  sudo xcode-select -s /Applications/Xcode.app
  ```

- **"Command CodeSign failed"**
  - Build with: `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  - Or disable code signing in Xcode project settings

- **"No such module 'BatteryCore'"**
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData
  make clean build
  ```