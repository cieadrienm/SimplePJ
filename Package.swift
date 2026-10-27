// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimplePJ",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SimplePJCore", targets: ["SimplePJCore"]),
        .library(name: "SimplePJMCPCore", targets: ["SimplePJMCPCore"]),
        .executable(name: "SimplePJ", targets: ["SimplePJ"]),
        .executable(name: "simplepj-mcp", targets: ["simplepj-mcp"]),
    ],
    targets: [
        .target(name: "SimplePJCore"),
        .executableTarget(name: "SimplePJ", dependencies: ["SimplePJCore"]),
        .target(name: "SimplePJMCPCore"),
        .executableTarget(name: "simplepj-mcp", dependencies: ["SimplePJMCPCore"]),
        .testTarget(name: "SimplePJCoreTests", dependencies: ["SimplePJCore"]),
        .testTarget(name: "SimplePJAppTests", dependencies: ["SimplePJ", "SimplePJCore", "SimplePJMCPCore"]),
    ],
    swiftLanguageModes: [.v5]
)
