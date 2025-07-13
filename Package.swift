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
    ],
    targets: [
        .executableTarget(
            name: "Microverse",
            dependencies: ["BatteryCore", "SystemCore"]
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