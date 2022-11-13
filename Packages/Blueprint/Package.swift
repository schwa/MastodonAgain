// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Blueprint",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Blueprint", targets: ["Blueprint"])
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything.git", branch: "main"),
    ],
    targets: [
        .target(name: "Blueprint", dependencies: ["Everything"]),
        .testTarget(
            name: "BlueprintTests",
            dependencies: ["Blueprint"]),
    ]
)
