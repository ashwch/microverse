#!/bin/bash

echo "🔍 Diagnosing menu bar issues..."
echo ""

# Check if any menu bar apps are running
echo "1. Checking for Microverse processes:"
ps aux | grep -i microverse | grep -v grep || echo "   No Microverse processes found"
echo ""

# Check system menu bar status
echo "2. System information:"
echo "   macOS version: $(sw_vers -productVersion)"
echo "   Number of displays: $(system_profiler SPDisplaysDataType | grep -c "Resolution:")"
echo ""

# Check if app exists
echo "3. App installation:"
if [ -d "/Applications/Microverse.app" ]; then
    echo "   ✅ App found in Applications"
    echo "   Executable: $(ls -la /Applications/Microverse.app/Contents/MacOS/Microverse)"
    echo "   Info.plist LSUIElement: $(defaults read /Applications/Microverse.app/Contents/Info.plist LSUIElement 2>/dev/null || echo "not set")"
else
    echo "   ❌ App not found in Applications"
fi
echo ""

# Check accessibility permissions
echo "4. Checking permissions:"
echo "   Note: Menu bar apps may need accessibility permissions"
echo ""

# Try to run with explicit logging
echo "5. Running app with console output..."
echo "   (Press Ctrl+C to stop)"
echo ""

# Set environment variable for logging
export CFLOG_FORCE_STDERR=1

# Run the app
/Applications/Microverse.app/Contents/MacOS/Microverse