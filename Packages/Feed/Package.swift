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
        .package(path: "../Core"),
        .package(path: "../Analytics"),
    ],
    targets: [
        .target(
            name: "Feed",
            dependencies: ["Servicing", "ApiClient", "Database", "Core", "Analytics"]
        ),
        .testTarget(
            name: "FeedTests",
            dependencies: ["Feed"]
        ),
    ]
)
