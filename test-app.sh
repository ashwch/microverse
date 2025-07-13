#!/bin/bash

echo "=== Microverse App Testing Script ==="
echo ""

# Function to check if app is running
check_app_running() {
    pgrep -x "Microverse" > /dev/null
    return $?
}

# Kill any existing instances
echo "1. Killing any existing Microverse instances..."
killall Microverse 2>/dev/null || echo "   No existing instances found"
sleep 2

# Launch the app
echo "2. Launching Microverse..."
open /Applications/Microverse.app
sleep 3

# Check if running
echo "3. Checking if app is running..."
if check_app_running; then
    echo "   ✓ App is running!"
    echo "   Process ID: $(pgrep -x Microverse)"
else
    echo "   ✗ App is not running!"
    echo "   Checking for crash logs..."
    find ~/Library/Logs/DiagnosticReports -name "Microverse*.crash" -mtime -1 -exec echo "   Found crash log: {}" \;
    exit 1
fi

# Check menu bar
echo ""
echo "4. UI/UX Testing Checklist:"
echo ""
echo "Menu Bar Icon:"
echo "   [ ] Battery icon appears in menu bar"
echo "   [ ] Icon shows correct charge level color (green/yellow/red)"
echo "   [ ] Percentage is displayed next to icon"
echo "   [ ] Lightning bolt appears when charging"
echo ""
echo "Popover Window (click menu bar icon):"
echo "   [ ] Popover opens when clicking menu bar icon"
echo "   [ ] Large battery percentage is displayed"
echo "   [ ] Battery bar shows correct fill level"
echo "   [ ] Status shows 'Charging' or 'AC Power' or 'On Battery'"
echo "   [ ] Cycle count is displayed"
echo "   [ ] Health percentage is shown"
echo "   [ ] Architecture (Apple Silicon/Intel) is correct"
echo ""
echo "Battery Control Card:"
echo "   [ ] Shows 'Admin access required' message"
echo "   [ ] 'Enable' button is present"
echo "   [ ] Explains that admin is needed for charge control"
echo ""
echo "Settings Window:"
echo "   [ ] Settings button opens settings window"
echo "   [ ] General tab shows menu bar options"
echo "   [ ] Battery tab shows battery information"
echo "   [ ] About tab shows app information"
echo "   [ ] About tab clearly shows what's real vs fake"
echo ""
echo "Refresh:"
echo "   [ ] Refresh button updates battery info"
echo "   [ ] Battery percentage updates periodically"
echo ""

# Test console output
echo "5. Checking console output..."
echo "   Run this command in another terminal to see logs:"
echo "   log stream --predicate 'subsystem == \"com.microverse.app\"'"
echo ""

# Summary
echo "6. Summary:"
echo "   - App should be running in menu bar"
echo "   - All features should be clearly marked as real or requiring admin"
echo "   - No fake features (calibration, temperature control)"
echo "   - Clear separation between readable info and control features"
echo ""
echo "Press Ctrl+C to exit when testing is complete."

# Keep script running
while true; do
    if ! check_app_running; then
        echo "App stopped running!"
        exit 1
    fi
    sleep 5
done