// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "TMLEngines",
  platforms: [
    .macOS("12.0"),
  ],
  products: [
    .library(
      name: "MetalEngine",
      targets: ["MetalEngine"]),
    .executable(
        name: "Demo",
        targets: ["Demo"]),
    ],
    dependencies: [
    ],
    targets: [
      .target(
        name: "MetalEngine",
        dependencies: [],
        exclude: ["Metal/Shaders.metal"],
        resources: [.process("Metal/default.metallib")]),
      .testTarget(
        name: "MetalEngineTests",
        dependencies: ["MetalEngine"]),
      .executableTarget(
        name: "Demo",
        dependencies: ["MetalEngine"],
        exclude: ["Assets.xcassets", "Demo.entitlements"])
    ]
)
