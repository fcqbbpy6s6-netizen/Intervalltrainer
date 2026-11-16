// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IntervalCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "IntervalCore", targets: ["IntervalCore"])
    ],
    targets: [
        .target(name: "IntervalCore"),
        .testTarget(name: "IntervalCoreTests", dependencies: ["IntervalCore"])
    ]
)
