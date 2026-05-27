// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pokie",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "PokieCore", targets: ["PokieCore"])
    ],
    targets: [
        .target(name: "PokieCore"),
        .testTarget(name: "PokieCoreTests", dependencies: ["PokieCore"])
    ]
)
