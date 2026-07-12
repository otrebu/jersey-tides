// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TidesCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "TidesCore", targets: ["TidesCore"])
    ],
    targets: [
        .target(name: "TidesCore"),
        .testTarget(name: "TidesCoreTests", dependencies: ["TidesCore"])
    ]
)
