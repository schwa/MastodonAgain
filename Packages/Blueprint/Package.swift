// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Blueprint",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "Blueprint", targets: ["Blueprint"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/schwa/Everything", branch: "main"),
    ],
    targets: [
        .target(name: "Blueprint", dependencies: [
            "Everything",
            .product(name: "Algorithms", package: "swift-algorithms"),
        ]),
        .testTarget(
            name: "BlueprintTests",
            dependencies: [
                "Blueprint",
            ]
        ),
    ]
)
