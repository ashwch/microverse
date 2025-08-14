// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Microverse",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "Microverse", targets: ["Microverse"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Microverse",
            dependencies: ["BatteryCore", "SystemCore", "Sparkle"],
            resources: [
                .copy("Resources/AppIcon.icns")
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
        )
    ]
)