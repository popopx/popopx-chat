// swift-tools-version: 5.9
// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import PackageDescription

let package = Package(
    name: "BitFoundation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BitFoundation",
            targets: ["BitFoundation"]
        )
    ],
    dependencies: [
        .package(path: "../BitLogger")
    ],
    targets: [
        .target(
            name: "BitFoundation",
            dependencies: [
                .product(name: "BitLogger", package: "BitLogger")
            ],
            path: "Sources/BitFoundation"
        ),
        .testTarget(
            name: "BitFoundationTests",
            dependencies: ["BitFoundation"],
        )
    ]
)
