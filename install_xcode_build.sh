#!/bin/bash

echo "🔨 Installing Xcode build to Applications..."

# Check if Xcode build exists
if [ -d "build/Build/Products/Debug/Microverse.app" ]; then
    echo "Found Debug build"
    BUILD_PATH="build/Build/Products/Debug/Microverse.app"
elif [ -d "build/Build/Products/Release/Microverse.app" ]; then
    echo "Found Release build"
    BUILD_PATH="build/Build/Products/Release/Microverse.app"
else
    echo "❌ No Xcode build found. Please build in Xcode first."
    exit 1
fi

# Kill any running instance
echo "Stopping any running instances..."
killall Microverse 2>/dev/null || true

# Remove old installation
echo "Removing old installation..."
rm -rf /Applications/Microverse.app

# Copy new build
echo "Installing new build..."
cp -R "$BUILD_PATH" /Applications/

echo "✅ Installation complete!"
echo ""
echo "To run the app:"
echo "open /Applications/Microverse.app"
echo ""
echo "If the app doesn't start, check Console.app for error messages."