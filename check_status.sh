#!/bin/bash

echo "🔍 Checking Microverse status..."
echo ""

# Check if running
if ps aux | grep -i "/Applications/Microverse.app" | grep -v grep > /dev/null; then
    echo "✅ Microverse is running from Applications"
    echo ""
    echo "Process details:"
    ps aux | grep -i "/Applications/Microverse.app" | grep -v grep
else
    echo "❌ Microverse is not running"
fi

echo ""
echo "📍 Look for the battery percentage in your menu bar (top-right corner)"
echo "   It should show something like '85%' or similar"
echo ""
echo "If you don't see it:"
echo "1. Try restarting the app: killall Microverse && open /Applications/Microverse.app"
echo "2. Check if you have too many menu bar items (might be hidden)"
echo "3. Try clicking on the menu bar area to see if it appears"