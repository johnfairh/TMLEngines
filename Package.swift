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
    .executable(
        name: "DemoApp",
        targets: ["DemoApp"]),
    ],
    dependencies: [
    ],
    targets: [
      .target(
        name: "MetalEngine",
        dependencies: []),
      .testTarget(
        name: "MetalEngineTests",
        dependencies: ["MetalEngine"]),
      .executableTarget(
        name: "Demo",
        dependencies: ["MetalEngine"]),
      .executableTarget(
        name: "DemoApp",
        dependencies: ["MetalEngine"],
        exclude: ["Assets.xcassets", "Preview Content", "DemoApp.entitlements"])
    ]
)
