// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VoiceAgentCallKit",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "VoiceAgentCallKit",
            targets: ["VoiceAgentCallKit"]
        ),
    ],
    dependencies: [
        .package(path: "../ApiClient"),
        .package(path: "../Core"),
        .package(path: "../VoiceAgent"),
    ],
    targets: [
        .target(
            name: "VoiceAgentCallKit",
            dependencies: [
                "ApiClient",
                "Core",
                "VoiceAgent",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
