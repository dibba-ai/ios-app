// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Auth",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Auth",
            targets: ["Auth"]
        ),
    ],
    dependencies: [
        .package(path: "../Navigation"),
        .package(path: "../UI"),
        .package(path: "../Analytics"),
        .package(url: "https://github.com/auth0/Auth0.swift", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Auth",
            dependencies: [
                "Navigation",
                "UI",
                "Analytics",
                .product(name: "Auth0", package: "Auth0.swift"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "AuthTests",
            dependencies: ["Auth"]
        ),
    ]
)
