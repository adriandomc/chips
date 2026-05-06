// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChipsCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChipsCore", targets: ["ChipsCore"]),
    ],
    targets: [
        .target(
            name: "ChipsCore",
            path: "Sources/ChipsCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "ChipsCoreTests",
            dependencies: ["ChipsCore"],
            path: "Tests/ChipsCoreTests"
        ),
    ]
)
