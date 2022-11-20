// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [
        .macOS("13.0"),
        .iOS("16.0"),
    ],
    products: [
        .library(name: "Storage", targets: ["Storage"])
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.0.3"),
    ],
    targets: [
        .target(name: "Storage", dependencies: [
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            "Everything"
        ]),
        .executableTarget(name: "CLI", dependencies: ["Storage"]),
        .testTarget(name: "StorageTests", dependencies: ["Storage"]),
    ]
)
