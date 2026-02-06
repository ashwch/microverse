// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Microverse",
    platforms: [
        // DynamicNotchKit requires macOS 13+
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Microverse", targets: ["Microverse"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        // Vendored DynamicNotchKit so we can add a notch decoration hook for the glow.
        .package(path: "Packages/DynamicNotchKit")
    ],
    targets: [
        .executableTarget(
            name: "Microverse",
            dependencies: ["BatteryCore", "SystemCore", "Sparkle", "DynamicNotchKit"],
            resources: [
                .copy("Resources/AppIcon.icns")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "BatteryCore",
            dependencies: [],
            path: "Sources/BatteryCore"
        ),
        .target(
            name: "SystemCore",
            dependencies: [],
            path: "Sources/SystemCore"
        ),
        // CLI benchmark tool for validating performance optimization patterns.
        // Run with: `make benchmark` (builds in release mode for accurate timings).
        // Depends on SystemCore only — no SwiftUI/AppKit, runs as a pure CLI tool.
        .executableTarget(
            name: "MicroverseBenchmark",
            dependencies: ["SystemCore"],
            path: "Sources/MicroverseBenchmark"
        )
    ]
)
