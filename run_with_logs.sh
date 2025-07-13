#!/bin/bash

echo "Building and running Microverse with logging..."

# Build the app
swift build

# Get the executable path
EXECUTABLE=".build/debug/Microverse"

if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: Executable not found at $EXECUTABLE"
    exit 1
fi

echo "Running Microverse..."
echo "Watching logs with: log stream --predicate 'subsystem == \"com.microverse.app\"'"
echo "Press Ctrl+C to stop"
echo "---"

# Run the app in background and capture its PID
$EXECUTABLE &
APP_PID=$!

# Give it a moment to start
sleep 1

# Stream logs
log stream --predicate 'subsystem == "com.microverse.app"' --style compact

# Kill the app when script exits
trap "kill $APP_PID 2>/dev/null" EXIT