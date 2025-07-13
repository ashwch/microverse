#!/bin/bash

echo "🚀 Building and installing Microverse..."

# Clean any existing builds
echo "Cleaning previous builds..."
rm -rf build/
xcodebuild clean -project Microverse.xcodeproj -configuration Release -quiet

# Build Release version
echo "Building Release version..."
xcodebuild -project Microverse.xcodeproj \
    -scheme Microverse \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    ENABLE_HARDENED_RUNTIME=NO \
    -quiet

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the built app
    APP_PATH="build/Build/Products/Release/Microverse.app"
    
    if [ -d "$APP_PATH" ]; then
        # Kill any running instances
        echo "Stopping any running instances..."
        pkill -f Microverse 2>/dev/null || true
        sleep 1
        
        # Copy to Applications
        echo "Installing to Applications folder..."
        rm -rf /Applications/Microverse.app 2>/dev/null || true
        cp -R "$APP_PATH" /Applications/
        
        # Set proper permissions
        chmod -R 755 /Applications/Microverse.app
        
        # Remove quarantine attribute if present
        xattr -cr /Applications/Microverse.app 2>/dev/null || true
        
        echo "✅ Microverse installed to /Applications"
        echo ""
        echo "To launch the app:"
        echo "1. Open Finder and go to Applications"
        echo "2. Double-click Microverse"
        echo ""
        echo "Or launch from terminal:"
        echo "open /Applications/Microverse.app"
        
        # Ask if user wants to launch now
        read -p "Launch Microverse now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open /Applications/Microverse.app
        fi
    else
        echo "❌ Built app not found at expected location"
    fi
else
    echo "❌ Build failed!"
    echo "Run without -quiet flag to see detailed errors:"
    echo "xcodebuild -project Microverse.xcodeproj -scheme Microverse -configuration Release"
fi