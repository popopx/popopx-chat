// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CactusEngine",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "CactusEngine", targets: ["CactusEngine"]),
    ],
    targets: [
        .target(
            name: "CactusEngine",
            path: "Sources/CactusEngine",
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreML"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalPerformanceShaders"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("CFNetwork"),
                .linkedFramework("Foundation"),
            ]
        ),
    ]
)
