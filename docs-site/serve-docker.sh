#!/bin/bash

echo "=== Microverse Docs Local Preview (Docker) ==="
echo

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker Desktop first:"
    echo "   https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

echo "🐳 Starting Jekyll in Docker container..."
echo "📍 Site will be available at http://localhost:4000"
echo "🛑 Press Ctrl+C to stop the server"
echo

# Run with docker-compose
docker-compose up --build