// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Paywall",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Paywall",
            targets: ["Paywall"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Paywall",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
                .product(name: "RevenueCatUI", package: "purchases-ios-spm"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "PaywallTests",
            dependencies: ["Paywall"]
        ),
    ]
)
