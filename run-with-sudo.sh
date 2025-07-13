#\!/bin/bash

# Script to run Microverse with admin privileges while maintaining GUI access
# This is needed for battery control on macOS

echo "🔋 Starting Microverse with administrator privileges..."
echo "This will allow battery control features to work."
echo ""

# Kill any running instance first
echo "Stopping existing Microverse instances..."
killall Microverse 2>/dev/null || true
sleep 1

echo "Starting Microverse with admin privileges..."
echo "You may see permission dialogs - please allow them."
echo ""

# Run with proper environment for GUI access
sudo -E /Applications/Microverse.app/Contents/MacOS/Microverse &

echo "✅ Microverse started with admin privileges\!"
echo ""
echo "If you see any permission dialogs, click 'Allow'."
echo "Battery control features should now work."
echo ""
echo "To stop: killall Microverse"
EOF < /dev/null