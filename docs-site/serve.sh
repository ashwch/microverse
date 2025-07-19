#!/bin/bash

echo "=== Microverse Docs Local Preview ==="
echo

# Check if bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "❌ Bundler is not installed. Please install it first:"
    echo "   gem install bundler"
    exit 1
fi

# Install dependencies if needed
if [ ! -f "Gemfile.lock" ] || [ ! -d "vendor" ]; then
    echo "📦 Installing Jekyll dependencies (this may take a few minutes)..."
    echo "   This uses the same versions as GitHub Pages for consistency."
    echo
    bundle install --path vendor/bundle
    
    if [ $? -ne 0 ]; then
        echo
        echo "❌ Installation failed. If you see eventmachine errors, try:"
        echo "   1. gem install eventmachine -v '1.2.7' -- --with-openssl-dir=$(brew --prefix openssl)"
        echo "   2. Then run this script again"
        exit 1
    fi
fi

# Serve the site locally
echo
echo "🚀 Starting Jekyll server..."
echo "📍 Site will be available at http://localhost:4000"
echo "🛑 Press Ctrl+C to stop the server"
echo

bundle exec jekyll serve --watch