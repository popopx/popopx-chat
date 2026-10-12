// swift-tools-version: 5.9
// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import PackageDescription

let package = Package(
    name: "BitLogger",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BitLogger",
            targets: ["BitLogger"]
        )
    ],
    targets: [
        .target(
            name: "BitLogger",
            path: "Sources"
        ),
        .testTarget(
            name: "BitLoggerTests",
            dependencies: ["BitLogger"]
        )
    ]
)
