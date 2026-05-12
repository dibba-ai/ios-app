// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FloatingMic",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FloatingMic",
            targets: ["FloatingMic"]
        ),
    ],
    targets: [
        .target(
            name: "FloatingMic"
        ),
        .testTarget(
            name: "FloatingMicTests",
            dependencies: ["FloatingMic"]
        ),
    ]
)
