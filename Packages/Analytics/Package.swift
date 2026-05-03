// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Analytics",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Analytics",
            targets: ["Analytics"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/PostHog/posthog-ios.git", from: "3.56.0"),
    ],
    targets: [
        .target(
            name: "Analytics",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "PostHog", package: "posthog-ios"),
            ]
        ),
        .testTarget(
            name: "AnalyticsTests",
            dependencies: ["Analytics"]
        ),
    ]
)
