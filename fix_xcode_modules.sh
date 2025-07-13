#!/bin/bash

echo "🔨 Fixing Xcode project structure..."

# Clean any existing build artifacts
echo "Cleaning build artifacts..."
rm -rf .build
rm -rf build
rm -rf DerivedData

# Generate Xcode project from Package.swift
echo "Generating Xcode project from Package.swift..."
swift package generate-xcodeproj

# Check if generation was successful
if [ -d "Microverse.xcodeproj" ]; then
    echo "✅ Xcode project generated successfully!"
    echo ""
    echo "Open the project with:"
    echo "open Microverse.xcodeproj"
    echo ""
    echo "Or open Package.swift directly in Xcode (recommended):"
    echo "open Package.swift"
else
    echo "❌ Failed to generate Xcode project"
    echo ""
    echo "Try opening Package.swift directly in Xcode:"
    echo "open Package.swift"
fi