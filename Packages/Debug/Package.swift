// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Debug",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "Debug",
            targets: ["Debug"]
        ),
    ],
    dependencies: [
        .package(path: "../Auth"),
        .package(path: "../ApiClient"),
        .package(path: "../Servicing"),
        .package(path: "../VoiceAgentCallKit"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Debug",
            dependencies: [
                "Auth",
                "ApiClient",
                "Servicing",
                "VoiceAgentCallKit",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "DebugTests",
            dependencies: ["Debug"]
        ),
    ]
)
