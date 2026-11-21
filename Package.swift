// swift-tools-version: 6.0
import PackageDescription

/// All app code lives in this package so it builds and tests with `swift test`
/// (fast, no simulator). `App/MachineRound.xcodeproj` is a thin iOS shell that
/// depends on the `MachineRoundKit` product.
let package = Package(
    name: "MachineRound",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MachineRoundKit", targets: ["AppFeature"]),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Auth", dependencies: ["Core"]),
        .target(name: "AppFeature", dependencies: ["Core", "Auth"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "AuthTests", dependencies: ["Auth", "Core"]),
    ]
)
