// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Profile",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Profile",
            targets: ["Profile"]
        ),
    ],
    dependencies: [
        .package(path: "../Auth"),
        .package(path: "../Core"),
        .package(path: "../Servicing"),
        .package(path: "../ApiClient"),
        .package(path: "../UI"),
        .package(path: "../Paywall"),
        .package(path: "../Analytics"),
    ],
    targets: [
        .target(
            name: "Profile",
            dependencies: ["Auth", "Core", "Servicing", "ApiClient", "UI", "Paywall", "Analytics"]
        ),
        .testTarget(
            name: "ProfileTests",
            dependencies: ["Profile"]
        ),
    ]
)
