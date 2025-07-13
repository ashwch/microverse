#!/bin/bash

echo "🔍 Checking Microverse app state..."

# Kill all existing instances
echo "Stopping all instances..."
pkill -f Microverse 2>/dev/null
pkill -f debug_menubar 2>/dev/null
sleep 2

# Launch the app in background
echo "Launching Microverse..."
/Users/monty/Library/Developer/Xcode/DerivedData/Microverse-gkzpyycjkjnpjqeatlqolcnuzizp/Build/Products/Debug/Microverse.app/Contents/MacOS/Microverse &

# Give it time to start
sleep 3

# Check if running
if ps aux | grep -v grep | grep -q "Microverse.app"; then
    echo "✅ App is running"
    echo ""
    echo "💡 Testing instructions:"
    echo "1. Look for the battery percentage in your menu bar (top right)"
    echo "2. Click on the percentage - a popover should appear"
    echo "3. If clicking doesn't work, try:"
    echo "   - Right-click"
    echo "   - Click and hold"
    echo "   - Make sure no other app is capturing mouse events"
    echo ""
    echo "If the popover still doesn't appear, the app might need accessibility permissions."
else
    echo "❌ App failed to start"
fi