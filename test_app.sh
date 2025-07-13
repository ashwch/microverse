#!/bin/bash

echo "🧪 Testing Microverse app..."

# Kill any existing instances
echo "Stopping existing instances..."
killall Microverse 2>/dev/null || true
sleep 1

# Launch the app
echo "Launching Microverse..."
open /Users/monty/Library/Developer/Xcode/DerivedData/Microverse-gkzpyycjkjnpjqeatlqolcnuzizp/Build/Products/Debug/Microverse.app

# Wait for it to start
sleep 3

# Check if running
if ps aux | grep -i "[M]icroverse.app" > /dev/null; then
    echo "✅ App is running"
    
    # Check for menu bar items
    echo "Checking menu bar..."
    osascript -e 'tell application "System Events" to get title of every menu bar item of menu bar 1 of process "SystemUIServer"' 2>/dev/null | grep -E "[0-9]+%" && echo "✅ Battery percentage found in menu bar" || echo "❌ Battery percentage NOT found in menu bar"
else
    echo "❌ App is NOT running"
fi

echo ""
echo "💡 If you don't see the menu bar item:"
echo "   1. Check the right side of your menu bar"
echo "   2. Try clicking on the time/date area"
echo "   3. Check if it's hidden under the notch (on newer MacBooks)"
echo "   4. Try Command+Drag menu bar items to rearrange"