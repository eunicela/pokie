// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PokerTrainer",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "PokerTrainerCore", targets: ["PokerTrainerCore"])
    ],
    targets: [
        .target(name: "PokerTrainerCore"),
        .testTarget(name: "PokerTrainerCoreTests", dependencies: ["PokerTrainerCore"])
    ]
)
