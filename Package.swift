// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkRequest",
    products: [
        .library(
            name: "NetworkRequest",
            targets: ["NetworkRequest"]
        ),
    ],
    targets: [
        .target(
            name: "NetworkRequest"
        ),
        .testTarget(
            name: "NetworkRequestTests",
            dependencies: ["NetworkRequest"]
        ),
    ]
)
