// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Dashboard",
    platforms: [
        .iOS(.v17)
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
            ]
        ),
        .testTarget(
            name: "DashboardTests",
            dependencies: ["Dashboard"]
        ),
    ]
)
