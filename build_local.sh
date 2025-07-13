#!/bin/bash

# Local build script for Microverse
set -e

echo "🚀 Building Microverse locally..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for Xcode
echo "Checking for Xcode..."
if xcodebuild -version 2>&1 | grep -q "requires Xcode"; then
    echo -e "${RED}❌ Error: Full Xcode is not installed${NC}"
    echo ""
    echo "You have Command Line Tools but need the full Xcode app."
    echo ""
    echo "Please install Xcode from:"
    echo "1. App Store (search for 'Xcode') - Recommended"
    echo "2. https://developer.apple.com/xcode/"
    echo ""
    echo "After installing Xcode:"
    echo "1. Open Xcode once to accept the license"
    echo "2. Run: sudo xcode-select -s /Applications/Xcode.app"
    echo "3. Run this script again"
    echo ""
    echo "Alternative: Use GitHub Actions to build:"
    echo "./setup_github_build.sh"
    exit 1
fi

# Show Xcode version
echo -e "${GREEN}✓ Found Xcode:${NC}"
xcodebuild -version

# Clean previous builds
echo ""
echo "🧹 Cleaning previous builds..."
rm -rf build/
rm -rf ~/Library/Developer/Xcode/DerivedData/Microverse-*

# Build the app
echo ""
echo "🔨 Building Microverse..."
xcodebuild build \
    -project Microverse.xcodeproj \
    -scheme Microverse \
    -configuration Debug \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    ONLY_ACTIVE_ARCH=YES

# Find the built app
APP_PATH=$(find build -name "Microverse.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Build successful!${NC}"
echo "📍 App location: $APP_PATH"
echo ""
echo "What would you like to do?"
echo "1. Run the app now"
echo "2. Copy to Applications folder"
echo "3. Open in Finder"
echo "4. Exit"
echo ""
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo "🚀 Launching Microverse..."
        open "$APP_PATH"
        ;;
    2)
        echo "📦 Installing to Applications..."
        rm -rf /Applications/Microverse.app
        cp -R "$APP_PATH" /Applications/
        echo -e "${GREEN}✅ Installed to /Applications/Microverse.app${NC}"
        open /Applications/Microverse.app
        ;;
    3)
        echo "📂 Opening in Finder..."
        open -R "$APP_PATH"
        ;;
    4)
        echo "👋 Done!"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac