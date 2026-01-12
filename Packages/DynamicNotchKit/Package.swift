// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DynamicNotchKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DynamicNotchKit",
            targets: ["DynamicNotchKit"]
        )
    ],
    targets: [
        .target(
            name: "DynamicNotchKit",
            path: "Sources/DynamicNotchKit"
        )
    ]
)
