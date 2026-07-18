// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShelfUI",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "ShelfUI", targets: ["ShelfUI"])
    ],
    targets: [
        .target(
            name: "ShelfUI",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
