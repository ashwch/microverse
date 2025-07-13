#!/bin/bash

echo "🔨 Building Microverse..."
swift build -c release

echo "📦 Creating app bundle..."
mkdir -p Microverse.app/Contents/MacOS
mkdir -p Microverse.app/Contents/Resources

# Copy executable
cp .build/release/Microverse Microverse.app/Contents/MacOS/

# Copy Info.plist
cp Info.plist Microverse.app/Contents/

# Create minimal icon
touch Microverse.app/Contents/Resources/AppIcon.icns

echo "🚀 Installing to Applications..."
rm -rf /Applications/Microverse.app
cp -R Microverse.app /Applications/

echo "✅ Installation complete!"
echo ""
echo "Run the app with: open /Applications/Microverse.app"