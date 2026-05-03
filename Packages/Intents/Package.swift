// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Intents",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Intents",
            targets: ["Intents"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(path: "../Core"),
        .package(path: "../Servicing"),
        .package(path: "../APIClient"),
        .package(path: "../Analytics"),
    ],
    targets: [
        .target(
            name: "Intents",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                "Core",
                "Servicing",
                "Analytics",
                .product(name: "ApiClient", package: "APIClient"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "IntentsTests",
            dependencies: ["Intents"]
        ),
    ]
)
