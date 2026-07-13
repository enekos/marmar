// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "marmar",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "marmar",
            path: "Sources/marmar",
            swiftSettings: [
                // Swift 5 language mode: the new Speech API works fine and we
                // avoid strict-concurrency churn for a small personal tool.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
