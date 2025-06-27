// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(
            name: "MLXArguments",
            targets: ["MLXArguments"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/ml-explore/mlx-swift-examples.git",
            branch: "main")
    ],
    targets: [
        .target(
            name: "MLXArguments",
            dependencies: []
        )
    ]
)
