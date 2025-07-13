#!/bin/bash

# Simple build test for Microverse
echo "🧪 Testing Microverse build..."

cd "$(dirname "$0")"

# Check if we can use swift build
if command -v swift &> /dev/null; then
    echo "✅ Swift found, attempting build..."
    swift build --product Microverse 2>&1 | tee build.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✅ Build successful!"
    else
        echo "❌ Build failed. Check build.log for details."
        exit 1
    fi
else
    echo "❌ Swift not found. Please install Xcode or Swift toolchain."
    exit 1
fi

# Run tests if build succeeded
echo "🧪 Running tests..."
swift test 2>&1 | tee test.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "⚠️  Some tests failed. Check test.log for details."
fi

echo "✨ Build and test complete!"