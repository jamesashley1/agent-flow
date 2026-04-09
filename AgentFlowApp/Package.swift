// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentFlow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AgentFlow",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ]
        )
    ]
)
