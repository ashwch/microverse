#!/bin/bash

echo "🔨 Creating new Xcode project with correct paths..."

# Backup old project
mv Microverse.xcodeproj Microverse.xcodeproj.backup 2>/dev/null || true

# Use xcodegen to create a proper project file
cat > project.yml << 'EOF'
name: Microverse
options:
  bundleIdPrefix: com.microverse
  deploymentTarget:
    macOS: "11.0"
settings:
  CODE_SIGN_IDENTITY: ""
  CODE_SIGNING_REQUIRED: NO
  CODE_SIGN_ENTITLEMENTS: Microverse.entitlements
  PRODUCT_BUNDLE_IDENTIFIER: com.microverse.app
  INFOPLIST_FILE: Info.plist
  
targets:
  Microverse:
    type: application
    platform: macOS
    sources:
      - Sources
    settings:
      PRODUCT_NAME: Microverse
      MACOSX_DEPLOYMENT_TARGET: "11.0"
      SWIFT_VERSION: "5.0"
      ENABLE_HARDENED_RUNTIME: YES
EOF

# Check if xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "✅ Using xcodegen..."
    xcodegen
else
    echo "⚠️  xcodegen not found, creating manual project..."
    
    # Create a minimal xcodeproj manually
    mkdir -p Microverse.xcodeproj
    
    # Create the main project.pbxproj with correct paths
    cat > Microverse.xcodeproj/project.pbxproj << 'PBXPROJ'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		1A1A1A1A1A1A1A1A1A1A1A1A /* MenuBarApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A2A /* MenuBarApp.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A1B /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A2B /* ContentView.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A1C /* BatteryViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A2C /* BatteryViewModel.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A1D /* LaunchAtStartup.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A2D /* LaunchAtStartup.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A1E /* BatteryController.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A2E /* BatteryController.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A1F /* AutomaticManagement.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A2F /* AutomaticManagement.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A20 /* HeatProtection.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A30 /* HeatProtection.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A21 /* MLUsagePredictor.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A31 /* MLUsagePredictor.swift */; };
		1A1A1A1A1A1A1A1A1A1A1A22 /* SMC.swift in Sources */ = {isa = PBXBuildFile; fileRef = 2A2A2A2A2A2A2A2A2A2A2A32 /* SMC.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		1A1A1A1A1A1A1A1A1A1A1A00 /* Microverse.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Microverse.app; sourceTree = BUILT_PRODUCTS_DIR; };
		2A2A2A2A2A2A2A2A2A2A2A2A /* MenuBarApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MenuBarApp.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A2B /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A2C /* BatteryViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BatteryViewModel.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A2D /* LaunchAtStartup.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LaunchAtStartup.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A2E /* BatteryController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BatteryController.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A2F /* AutomaticManagement.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AutomaticManagement.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A30 /* HeatProtection.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HeatProtection.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A31 /* MLUsagePredictor.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MLUsagePredictor.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A32 /* SMC.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SMC.swift; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A33 /* Microverse.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Microverse.entitlements; sourceTree = "<group>"; };
		2A2A2A2A2A2A2A2A2A2A2A34 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		1A1A1A1A1A1A1A1A1A1A1A02 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		1A1A1A1A1A1A1A1A1A1A1A03 = {
			isa = PBXGroup;
			children = (
				2A2A2A2A2A2A2A2A2A2A2A33 /* Microverse.entitlements */,
				2A2A2A2A2A2A2A2A2A2A2A34 /* Info.plist */,
				1A1A1A1A1A1A1A1A1A1A1A06 /* Sources */,
				1A1A1A1A1A1A1A1A1A1A1A05 /* Products */,
			);
			sourceTree = "<group>";
		};
		1A1A1A1A1A1A1A1A1A1A1A05 /* Products */ = {
			isa = PBXGroup;
			children = (
				1A1A1A1A1A1A1A1A1A1A1A00 /* Microverse.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		1A1A1A1A1A1A1A1A1A1A1A06 /* Sources */ = {
			isa = PBXGroup;
			children = (
				1A1A1A1A1A1A1A1A1A1A1A07 /* Microverse */,
				1A1A1A1A1A1A1A1A1A1A1A08 /* BatteryCore */,
				1A1A1A1A1A1A1A1A1A1A1A09 /* SMCKit */,
			);
			path = Sources;
			sourceTree = "<group>";
		};
		1A1A1A1A1A1A1A1A1A1A1A07 /* Microverse */ = {
			isa = PBXGroup;
			children = (
				2A2A2A2A2A2A2A2A2A2A2A2A /* MenuBarApp.swift */,
				2A2A2A2A2A2A2A2A2A2A2A2B /* ContentView.swift */,
				2A2A2A2A2A2A2A2A2A2A2A2C /* BatteryViewModel.swift */,
				2A2A2A2A2A2A2A2A2A2A2A2D /* LaunchAtStartup.swift */,
			);
			path = Microverse;
			sourceTree = "<group>";
		};
		1A1A1A1A1A1A1A1A1A1A1A08 /* BatteryCore */ = {
			isa = PBXGroup;
			children = (
				2A2A2A2A2A2A2A2A2A2A2A2E /* BatteryController.swift */,
				2A2A2A2A2A2A2A2A2A2A2A2F /* AutomaticManagement.swift */,
				2A2A2A2A2A2A2A2A2A2A2A30 /* HeatProtection.swift */,
				2A2A2A2A2A2A2A2A2A2A2A31 /* MLUsagePredictor.swift */,
			);
			path = BatteryCore;
			sourceTree = "<group>";
		};
		1A1A1A1A1A1A1A1A1A1A1A09 /* SMCKit */ = {
			isa = PBXGroup;
			children = (
				2A2A2A2A2A2A2A2A2A2A2A32 /* SMC.swift */,
			);
			path = SMCKit;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		1A1A1A1A1A1A1A1A1A1A1A01 /* Microverse */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 1A1A1A1A1A1A1A1A1A1A1A11 /* Build configuration list for PBXNativeTarget "Microverse" */;
			buildPhases = (
				1A1A1A1A1A1A1A1A1A1A1A10 /* Sources */,
				1A1A1A1A1A1A1A1A1A1A1A02 /* Frameworks */,
				1A1A1A1A1A1A1A1A1A1A1A12 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Microverse;
			productName = Microverse;
			productReference = 1A1A1A1A1A1A1A1A1A1A1A00 /* Microverse.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		1A1A1A1A1A1A1A1A1A1A1A13 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1430;
				LastUpgradeCheck = 1430;
				TargetAttributes = {
					1A1A1A1A1A1A1A1A1A1A1A01 = {
						CreatedOnToolsVersion = 14.3;
					};
				};
			};
			buildConfigurationList = 1A1A1A1A1A1A1A1A1A1A1A14 /* Build configuration list for PBXProject "Microverse" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 1A1A1A1A1A1A1A1A1A1A1A03;
			productRefGroup = 1A1A1A1A1A1A1A1A1A1A1A05 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				1A1A1A1A1A1A1A1A1A1A1A01 /* Microverse */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		1A1A1A1A1A1A1A1A1A1A1A12 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		1A1A1A1A1A1A1A1A1A1A1A10 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				1A1A1A1A1A1A1A1A1A1A1A1A /* MenuBarApp.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A1B /* ContentView.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A1C /* BatteryViewModel.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A1D /* LaunchAtStartup.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A1E /* BatteryController.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A1F /* AutomaticManagement.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A20 /* HeatProtection.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A21 /* MLUsagePredictor.swift in Sources */,
				1A1A1A1A1A1A1A1A1A1A1A22 /* SMC.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		1A1A1A1A1A1A1A1A1A1A1A15 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 11.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		1A1A1A1A1A1A1A1A1A1A1A16 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 11.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Release;
		};
		1A1A1A1A1A1A1A1A1A1A1A17 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Microverse.entitlements;
				CODE_SIGN_IDENTITY = "";
				CODE_SIGN_STYLE = Manual;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = NO;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.microverse.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				PROVISIONING_PROFILE_SPECIFIER = "";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		1A1A1A1A1A1A1A1A1A1A1A18 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Microverse.entitlements;
				CODE_SIGN_IDENTITY = "";
				CODE_SIGN_STYLE = Manual;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = NO;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.microverse.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				PROVISIONING_PROFILE_SPECIFIER = "";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		1A1A1A1A1A1A1A1A1A1A1A11 /* Build configuration list for PBXNativeTarget "Microverse" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				1A1A1A1A1A1A1A1A1A1A1A17 /* Debug */,
				1A1A1A1A1A1A1A1A1A1A1A18 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		1A1A1A1A1A1A1A1A1A1A1A14 /* Build configuration list for PBXProject "Microverse" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				1A1A1A1A1A1A1A1A1A1A1A15 /* Debug */,
				1A1A1A1A1A1A1A1A1A1A1A16 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 1A1A1A1A1A1A1A1A1A1A1A13 /* Project object */;
}
PBXPROJ
fi

echo "✅ New project created!"
echo "🔨 Building..."

./build_local.sh