// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mastodon",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "Mastodon", targets: ["Mastodon"]),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.0.3"),
        .package(path: "../Blueprint"),
        .package(path: "../Storage"),
        .package(path: "../Support"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.3"),
    ],
    targets: [
        .target(
            name: "Mastodon",
            dependencies: [
                "Blueprint",
                "Everything",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                "Storage",
                "Support",
                "SwiftSoup",
            ]
        ),
        .testTarget(
            name: "MastodonTests",
            dependencies: ["Mastodon"]
        ),
    ]
)
