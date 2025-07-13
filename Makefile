# Makefile for Microverse - Battery Monitor for macOS

.PHONY: all build clean install uninstall run

# Configuration
APP_NAME = Microverse
BUNDLE_ID = com.microverse.app
BUILD_DIR = build

# Build settings
SWIFT = swift

all: build

# Build using Swift Package Manager
build:
	@echo "🔨 Building $(APP_NAME)..."
	$(SWIFT) build -c release

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	rm -rf $(BUILD_DIR)
	rm -rf .build

# Install app to /Applications (requires manual app bundle creation)
install: build
	@echo "📦 Installing $(APP_NAME)..."
	@echo "⚠️  Note: SPM doesn't create app bundles. Use Xcode for a proper .app"
	@echo "Built executable at: .build/release/$(APP_NAME)"

# Uninstall app
uninstall:
	@echo "🗑 Uninstalling $(APP_NAME)..."
	rm -rf "/Applications/$(APP_NAME).app"
	rm -rf "$$HOME/Library/Preferences/$(BUNDLE_ID).plist"
	rm -rf "$$HOME/Library/Caches/$(BUNDLE_ID)"
	@echo "✅ Uninstalled"

# Run the app
run: build
	@echo "🚀 Running $(APP_NAME)..."
	.build/release/$(APP_NAME)

# Show help
help:
	@echo "Microverse Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build      - Build the app"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make install    - Install app to /Applications"
	@echo "  make uninstall  - Remove app and preferences"
	@echo "  make run        - Build and run the app"