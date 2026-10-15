// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LocalFlow",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "LocalFlow",
            dependencies: [.product(name: "WhisperKit", package: "WhisperKit")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
