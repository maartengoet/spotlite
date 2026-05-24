// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Spotlite",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spotlite", targets: ["Spotlite"])
    ],
    targets: [
        .executableTarget(
            name: "Spotlite",
            path: "Sources/Spotlite"
        )
    ]
)
