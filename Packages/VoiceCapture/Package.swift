// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VoiceCapture",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "VoiceCapture",
            targets: ["VoiceCapture"]
        ),
    ],
    targets: [
        .target(
            name: "VoiceCapture"
        ),
        .testTarget(
            name: "VoiceCaptureTests",
            dependencies: ["VoiceCapture"]
        ),
    ]
)
