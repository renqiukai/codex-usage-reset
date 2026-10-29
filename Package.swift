// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsage",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexUsage", targets: ["CodexUsage"])],
    targets: [
        .executableTarget(name: "CodexUsage"),
        .testTarget(name: "CodexUsageTests", dependencies: ["CodexUsage"])
    ],
    swiftLanguageModes: [.v5]
)
