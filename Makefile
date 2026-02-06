# Makefile for Microverse - Battery Monitor for macOS

.PHONY: all build build-debug clean install install-debug uninstall run app debug-app benchmark

# Configuration
APP_NAME = Microverse
BUNDLE_ID = com.microverse.app
BUILD_DIR = build
APP_PATH = /Applications/$(APP_NAME).app

# Build settings
SWIFT = swift

all: install

# Build using Swift Package Manager (Release)
build:
	@echo "🔨 Building $(APP_NAME) (Release)..."
	$(SWIFT) build -c release

# Build using Swift Package Manager (Debug)
build-debug:
	@echo "🔨 Building $(APP_NAME) (Debug)..."
	$(SWIFT) build -c debug

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	rm -rf $(BUILD_DIR)
	rm -rf .build
	rm -rf /tmp/$(APP_NAME).app

# Create app bundle and install to /Applications (Release)
install: build app
	@echo "📦 Installing $(APP_NAME) to /Applications..."
	@if sudo -n true 2>/dev/null; then \
		set -e; \
		sudo rm -rf "$(APP_PATH)"; \
		sudo cp -R /tmp/$(APP_NAME).app "$(APP_PATH)"; \
		echo "✅ Installed to $(APP_PATH)"; \
		echo "🚀 Launching $(APP_NAME)..."; \
		open "$(APP_PATH)" >/dev/null 2>&1 || echo "⚠️  Launch failed. Open $(APP_PATH) manually."; \
	elif [ -t 0 ]; then \
		set -e; \
		echo "🔐 sudo required to install to /Applications..."; \
		sudo rm -rf "$(APP_PATH)"; \
		sudo cp -R /tmp/$(APP_NAME).app "$(APP_PATH)"; \
		echo "✅ Installed to $(APP_PATH)"; \
		echo "🚀 Launching $(APP_NAME)..."; \
		open "$(APP_PATH)" >/dev/null 2>&1 || echo "⚠️  Launch failed. Open $(APP_PATH) manually."; \
	else \
		echo "⚠️  sudo not available (no cached credentials / no tty). Skipping /Applications copy."; \
		echo "    Run 'sudo -v' first, or manually:"; \
		echo "    sudo rm -rf \"$(APP_PATH)\" && sudo cp -R /tmp/$(APP_NAME).app \"$(APP_PATH)\""; \
		echo "🚀 Launching from /tmp/$(APP_NAME).app..."; \
		open -n /tmp/$(APP_NAME).app >/dev/null 2>&1 || echo "⚠️  Launch failed. Open /tmp/$(APP_NAME).app manually."; \
	fi

# Create app bundle and install to /Applications (Debug)
install-debug: build-debug debug-app
	@echo "📦 Installing $(APP_NAME) (Debug) to /Applications..."
	@if sudo -n true 2>/dev/null; then \
		set -e; \
		sudo rm -rf "$(APP_PATH)"; \
		sudo cp -R /tmp/$(APP_NAME).app "$(APP_PATH)"; \
		echo "✅ Installed to $(APP_PATH)"; \
		echo "🚀 Launching $(APP_NAME)..."; \
		open "$(APP_PATH)" >/dev/null 2>&1 || echo "⚠️  Launch failed. Open $(APP_PATH) manually."; \
	elif [ -t 0 ]; then \
		set -e; \
		echo "🔐 sudo required to install to /Applications..."; \
		sudo rm -rf "$(APP_PATH)"; \
		sudo cp -R /tmp/$(APP_NAME).app "$(APP_PATH)"; \
		echo "✅ Installed to $(APP_PATH)"; \
		echo "🚀 Launching $(APP_NAME)..."; \
		open "$(APP_PATH)" >/dev/null 2>&1 || echo "⚠️  Launch failed. Open $(APP_PATH) manually."; \
	else \
		echo "⚠️  sudo not available (no cached credentials / no tty). Skipping /Applications copy."; \
		echo "    Run 'sudo -v' first, or manually:"; \
		echo "    sudo rm -rf \"$(APP_PATH)\" && sudo cp -R /tmp/$(APP_NAME).app \"$(APP_PATH)\""; \
		echo "🚀 Launching from /tmp/$(APP_NAME).app..."; \
		open -n /tmp/$(APP_NAME).app >/dev/null 2>&1 || echo "⚠️  Launch failed. Open /tmp/$(APP_NAME).app manually."; \
	fi

# Create app bundle structure (Release)
app: build
	@echo "📦 Creating app bundle..."
	$(eval TEMP_DIR := $(shell mktemp -d))
	@mkdir -p $(TEMP_DIR)/$(APP_NAME).app/Contents/{MacOS,Resources,Frameworks}
	@cp .build/release/$(APP_NAME) $(TEMP_DIR)/$(APP_NAME).app/Contents/MacOS/
	@cp Info.plist $(TEMP_DIR)/$(APP_NAME).app/Contents/
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(TEMP_DIR)/$(APP_NAME).app/Contents/Resources/; fi
	@if [ -d .build/arm64-apple-macosx/release/Sparkle.framework ]; then \
		cp -R .build/arm64-apple-macosx/release/Sparkle.framework $(TEMP_DIR)/$(APP_NAME).app/Contents/Frameworks/; \
		install_name_tool -id "@rpath/Sparkle.framework/Versions/B/Sparkle" $(TEMP_DIR)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle 2>/dev/null || true; \
	fi
	@echo 'APPL????' > $(TEMP_DIR)/$(APP_NAME).app/Contents/PkgInfo
	@chmod +x $(TEMP_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)
	@install_name_tool -add_rpath "@loader_path/../Frameworks" $(TEMP_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME) 2>/dev/null || true
	@rm -rf /tmp/$(APP_NAME).app
	@mv $(TEMP_DIR)/$(APP_NAME).app /tmp/
	@rmdir $(TEMP_DIR)
	@echo "🔏 Ad-hoc code signing /tmp/$(APP_NAME).app (binds Info.plist + stable bundle id)..."
	@codesign --force --deep --sign - /tmp/$(APP_NAME).app
	@echo "✅ App bundle created at /tmp/$(APP_NAME).app"

# Create app bundle structure (Debug)
debug-app: build-debug
	@echo "📦 Creating debug app bundle..."
	$(eval TEMP_DIR := $(shell mktemp -d))
	@mkdir -p $(TEMP_DIR)/$(APP_NAME).app/Contents/{MacOS,Resources,Frameworks}
	@cp .build/debug/$(APP_NAME) $(TEMP_DIR)/$(APP_NAME).app/Contents/MacOS/
	@cp Info.plist $(TEMP_DIR)/$(APP_NAME).app/Contents/
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(TEMP_DIR)/$(APP_NAME).app/Contents/Resources/; fi
	@if [ -d .build/arm64-apple-macosx/debug/Sparkle.framework ]; then \
		cp -R .build/arm64-apple-macosx/debug/Sparkle.framework $(TEMP_DIR)/$(APP_NAME).app/Contents/Frameworks/; \
		install_name_tool -id "@rpath/Sparkle.framework/Versions/B/Sparkle" $(TEMP_DIR)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle 2>/dev/null || true; \
	fi
	@echo 'APPL????' > $(TEMP_DIR)/$(APP_NAME).app/Contents/PkgInfo
	@chmod +x $(TEMP_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)
	@install_name_tool -add_rpath "@loader_path/../Frameworks" $(TEMP_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME) 2>/dev/null || true
	@rm -rf /tmp/$(APP_NAME).app
	@mv $(TEMP_DIR)/$(APP_NAME).app /tmp/
	@rmdir $(TEMP_DIR)
	@echo "🔏 Ad-hoc code signing /tmp/$(APP_NAME).app (binds Info.plist + stable bundle id)..."
	@codesign --force --deep --sign - /tmp/$(APP_NAME).app
	@echo "✅ Debug app bundle created at /tmp/$(APP_NAME).app"

# Uninstall app
uninstall:
	@echo "🗑 Uninstalling $(APP_NAME)..."
	@sudo rm -rf "$(APP_PATH)"
	rm -rf "$$HOME/Library/Preferences/$(BUNDLE_ID).plist"
	rm -rf "$$HOME/Library/Caches/$(BUNDLE_ID)"
	@echo "✅ Uninstalled"

# Run the app directly (for development)
run: build
	@echo "🚀 Running $(APP_NAME)..."
	.build/release/$(APP_NAME)

# Run CLI performance benchmarks.
# Must use -c release to get accurate timings (debug mode disables
# optimizations and adds runtime checks that skew all measurements).
# See Sources/MicroverseBenchmark/main.swift for what's measured and why.
benchmark:
	@echo "⏱  Running benchmarks (release)..."
	$(SWIFT) run -c release MicroverseBenchmark

# Show help
help:
	@echo "Microverse Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make              - Build and install to /Applications (default)"
	@echo "  make install      - Build release and install to /Applications"
	@echo "  make install-debug - Build debug and install to /Applications"
	@echo "  make build        - Build release version only"
	@echo "  make build-debug  - Build debug version only"
	@echo "  make clean        - Clean all build artifacts"
	@echo "  make uninstall    - Remove app and preferences"
	@echo "  make run          - Build and run directly (development)"
	@echo "  make benchmark    - Run release CLI benchmarks"
	@echo ""
	@echo "Note: Installation requires administrator privileges"
