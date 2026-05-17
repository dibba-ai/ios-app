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
    dependencies: [
        .package(path: "../ApiClient"),
        .package(
            url: "https://github.com/livekit/webrtc-xcframework",
            from: "144.7559.06"
        ),
    ],
    targets: [
        .target(
            name: "VoiceAgent",
            dependencies: [
                "ApiClient",
                .product(name: "LiveKitWebRTC", package: "webrtc-xcframework"),
            ]
        ),
        .testTarget(
            name: "VoiceAgentTests",
            dependencies: ["VoiceAgent"]
        ),
    ]
)
