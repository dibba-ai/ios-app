// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Dashboard",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "Dashboard",
            targets: ["Dashboard"]
        ),
    ],
    dependencies: [
        .package(path: "../Navigation"),
        .package(path: "../Feed"),
        .package(path: "../Profile"),
        .package(path: "../Auth"),
        .package(path: "../Servicing"),
        .package(path: "../Debug"),
        .package(path: "../Paywall"),
        .package(path: "../Analytics"),
        .package(path: "../FloatingMic"),
        .package(path: "../VoiceAgent"),
    ],
    targets: [
        .target(
            name: "Dashboard",
            dependencies: [
                "Navigation",
                "Feed",
                "Profile",
                "Auth",
                "Servicing",
                "Debug",
                "Paywall",
                "Analytics",
                "FloatingMic",
                "VoiceAgent",
            ]
        ),
        .testTarget(
            name: "DashboardTests",
            dependencies: ["Dashboard"]
        ),
    ]
)
