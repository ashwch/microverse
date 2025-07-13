# Makefile for Microverse - Battery Manager for macOS

.PHONY: all build test clean install uninstall release

# Configuration
APP_NAME = Microverse
BUNDLE_ID = com.microverse.app
BUILD_DIR = build
RELEASE_DIR = release
SCHEME = Microverse
CONFIGURATION = Release

# Build settings
XCODEBUILD = xcodebuild
SWIFT = swift
CODESIGN_IDENTITY = ""
DEVELOPMENT_TEAM = ""

# Detect if running in CI
ifdef CI
	CODE_SIGN_ARGS = CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
else
	CODE_SIGN_ARGS = CODE_SIGN_IDENTITY="$(CODESIGN_IDENTITY)" DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)"
endif

all: build

# Build using xcodebuild
build:
	@echo "🔨 Building $(APP_NAME)..."
	$(XCODEBUILD) build \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		$(CODE_SIGN_ARGS) \
		ONLY_ACTIVE_ARCH=NO

# Build using Swift Package Manager
build-spm:
	@echo "🔨 Building with Swift Package Manager..."
	$(SWIFT) build -c release

# Run tests
test:
	@echo "🧪 Running tests..."
	$(XCODEBUILD) test \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		$(CODE_SIGN_ARGS)

# Run Swift PM tests
test-spm:
	@echo "🧪 Running Swift PM tests..."
	$(SWIFT) test

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	rm -rf $(BUILD_DIR)
	rm -rf $(RELEASE_DIR)
	rm -rf .build
	$(XCODEBUILD) clean -project $(APP_NAME).xcodeproj -scheme $(SCHEME)

# Install app to /Applications
install: build
	@echo "📦 Installing $(APP_NAME)..."
	@APP_PATH=$$(find $(BUILD_DIR) -name "$(APP_NAME).app" -type d | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ Error: Could not find built app"; \
		exit 1; \
	fi; \
	echo "Installing from: $$APP_PATH"; \
	rm -rf "/Applications/$(APP_NAME).app"; \
	cp -R "$$APP_PATH" "/Applications/"; \
	echo "✅ Installed to /Applications/$(APP_NAME).app"

# Uninstall app
uninstall:
	@echo "🗑 Uninstalling $(APP_NAME)..."
	rm -rf "/Applications/$(APP_NAME).app"
	rm -rf "$$HOME/Library/Preferences/$(BUNDLE_ID).plist"
	rm -rf "$$HOME/Library/Caches/$(BUNDLE_ID)"
	launchctl unload "/Library/LaunchDaemons/com.microverse.helper.plist" 2>/dev/null || true
	rm -f "/Library/LaunchDaemons/com.microverse.helper.plist"
	rm -f "/Library/PrivilegedHelperTools/com.microverse.helper"
	@echo "✅ Uninstalled"

# Create release build
release: clean build
	@echo "📦 Creating release..."
	mkdir -p $(RELEASE_DIR)
	./Scripts/build_installer.sh

# Archive for distribution
archive:
	@echo "📦 Creating archive..."
	$(XCODEBUILD) archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-archivePath $(BUILD_DIR)/$(APP_NAME).xcarchive \
		$(CODE_SIGN_ARGS)

# Export archive
export: archive
	@echo "📤 Exporting archive..."
	$(XCODEBUILD) -exportArchive \
		-archivePath $(BUILD_DIR)/$(APP_NAME).xcarchive \
		-exportPath $(BUILD_DIR)/export \
		-exportOptionsPlist ExportOptions.plist

# Run the app
run: build
	@echo "🚀 Running $(APP_NAME)..."
	@APP_PATH=$$(find $(BUILD_DIR) -name "$(APP_NAME).app" -type d | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ Error: Could not find built app"; \
		exit 1; \
	fi; \
	open "$$APP_PATH"

# Show help
help:
	@echo "Microverse Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build      - Build the app"
	@echo "  make test       - Run tests"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make install    - Install app to /Applications"
	@echo "  make uninstall  - Remove app and preferences"
	@echo "  make release    - Create release build with installer"
	@echo "  make run        - Build and run the app"
	@echo ""
	@echo "Swift Package Manager:"
	@echo "  make build-spm  - Build using Swift PM"
	@echo "  make test-spm   - Run Swift PM tests"
	@echo ""
	@echo "Environment Variables:"
	@echo "  CODESIGN_IDENTITY - Code signing identity (optional)"
	@echo "  DEVELOPMENT_TEAM  - Development team ID (optional)"