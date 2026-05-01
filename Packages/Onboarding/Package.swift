// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Onboarding",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Onboarding",
            targets: ["Onboarding"]
        ),
    ],
    dependencies: [
        .package(path: "../Navigation"),
        .package(path: "../Core"),
        .package(path: "../Analytics"),
        .package(path: "../ApiClient"),
        .package(path: "../Servicing"),
        .package(path: "../UI"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: [
                "Navigation",
                "Core",
                "Analytics",
                "ApiClient",
                "Servicing",
                "UI",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "OnboardingTests",
            dependencies: ["Onboarding"]
        ),
    ]
)
