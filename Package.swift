// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimplePJ",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SimplePJCore", targets: ["SimplePJCore"]),
        .executable(name: "SimplePJ", targets: ["SimplePJ"]),
    ],
    targets: [
        .target(name: "SimplePJCore"),
        .executableTarget(name: "SimplePJ", dependencies: ["SimplePJCore"]),
        .testTarget(name: "SimplePJCoreTests", dependencies: ["SimplePJCore"]),
        .testTarget(name: "SimplePJAppTests", dependencies: ["SimplePJ", "SimplePJCore"]),
    ],
    swiftLanguageModes: [.v5]
)
