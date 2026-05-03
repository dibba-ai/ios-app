// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Servicing",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Servicing",
            targets: ["Servicing"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
        .package(path: "../APIClient"),
        .package(path: "../Database"),
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Servicing",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "ApiClient", package: "APIClient"),
                "Database",
                "Core",
            ]
        ),
        .testTarget(
            name: "ServicingTests",
            dependencies: ["Servicing"]
        ),
    ]
)
