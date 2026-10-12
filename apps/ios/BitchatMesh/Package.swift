// swift-tools-version: 5.9
// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import PackageDescription

let package = Package(
    name: "BitchatMesh",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BitchatMesh",
            targets: ["BitchatMesh"]
        ),
    ],
    dependencies: [
        .package(path: "../BitFoundation"),
        .package(path: "../BitLogger"),
        .package(path: "../swift-secp256k1"),
    ],
    targets: [
        .target(
            name: "BitchatMesh",
            dependencies: [
                .product(name: "BitFoundation", package: "BitFoundation"),
                .product(name: "BitLogger", package: "BitLogger"),
                .product(name: "P256K", package: "swift-secp256k1"),
            ],
            path: "Sources/BitchatMesh"
        ),
        .testTarget(
            name: "BitchatMeshTests",
            dependencies: [
                "BitchatMesh",
                .product(name: "BitFoundation", package: "BitFoundation"),
            ],
            path: "Tests/BitchatMeshTests",
            exclude: [
                "Info.plist",
                "README.md",
                "Performance/perf-floors.json"
            ],
            resources: [
                .process("Localization"),
                .process("Noise/NoiseTestVectors.json"),
                .process("Nostr/Fixtures")
            ]
        ),
    ]
)
