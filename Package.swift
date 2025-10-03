// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MLXTools",
  platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1)],
  products: [
    .library(
      name: "MLXTools",
      targets: ["MLXTools"])
  ],
  dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main")
  ],
  targets: [
    .target(
      name: "MLXTools",
      dependencies: [
        .product(name: "MLXLMCommon", package: "mlx-swift-examples")
      ],
      path: "Sources/MLXTools"
    )
  ]
)
