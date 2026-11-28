// swift-tools-version: 6.4
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
        .target(name: "Uploads", dependencies: ["Core"]),
        .target(name: "AppFeature", dependencies: ["Core", "Uploads"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "UploadsTests", dependencies: ["Uploads", "Core"]),
    ]
)
