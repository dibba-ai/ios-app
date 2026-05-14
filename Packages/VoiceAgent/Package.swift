// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VoiceAgent",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "VoiceAgent",
            targets: ["VoiceAgent"]
        ),
    ],
    targets: [
        .target(
            name: "VoiceAgent"
        ),
        .testTarget(
            name: "VoiceAgentTests",
            dependencies: ["VoiceAgent"]
        ),
    ]
)
