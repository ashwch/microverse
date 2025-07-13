// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Microverse",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "Microverse", targets: ["Microverse"]),
        .executable(name: "HelperTool", targets: ["HelperTool"]),
        .library(name: "SMCKit", targets: ["SMCKit"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "Microverse",
            dependencies: ["SMCKit", "BatteryCore"]
        ),
        .executableTarget(
            name: "HelperTool",
            dependencies: ["SMCKit", "BatteryCore"],
            path: "Sources/HelperTool"
        ),
        .target(
            name: "SMCKit",
            dependencies: [],
            path: "Sources/SMCKit"
        ),
        .target(
            name: "BatteryCore",
            dependencies: ["SMCKit"],
            path: "Sources/BatteryCore"
        ),
        .testTarget(
            name: "MicroverseTests",
            dependencies: ["Microverse", "BatteryCore", "SMCKit"],
            path: "Tests/MicroverseTests"
        )
    ]
)