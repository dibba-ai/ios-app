// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Feed",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Feed",
            targets: ["Feed"]
        ),
    ],
    dependencies: [
        .package(path: "../Servicing"),
        .package(path: "../ApiClient"),
        .package(path: "../Database"),
    ],
    targets: [
        .target(
            name: "Feed",
            dependencies: ["Servicing", "ApiClient", "Database"]
        ),
        .testTarget(
            name: "FeedTests",
            dependencies: ["Feed"]
        ),
    ]
)
