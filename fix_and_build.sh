#!/bin/bash

echo "🔧 Fixing project and building..."

# Create a simple Swift Package Manager project instead
cat > Package.swift << 'EOF'
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Microverse",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "Microverse", targets: ["Microverse"])
    ],
    targets: [
        .executableTarget(
            name: "Microverse",
            dependencies: [],
            path: "Sources"
        )
    ]
)
EOF

# Build with Swift PM
echo "🔨 Building with Swift Package Manager..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📍 Binary at: .build/release/Microverse"
    echo ""
    echo "Creating app bundle..."
    
    # Create minimal app bundle
    mkdir -p Microverse.app/Contents/MacOS
    cp .build/release/Microverse Microverse.app/Contents/MacOS/
    cp Info.plist Microverse.app/Contents/
    
    echo "✅ App bundle created: Microverse.app"
    echo "Run with: open Microverse.app"
else
    echo "❌ Build failed. Opening in Xcode..."
    open Microverse.xcodeproj
fi