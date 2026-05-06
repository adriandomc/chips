// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChipsMIDI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChipsMIDI", targets: ["ChipsMIDI"]),
    ],
    targets: [
        .target(
            name: "ChipsMIDI",
            path: "Sources/ChipsMIDI",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "ChipsMIDITests",
            dependencies: ["ChipsMIDI"],
            path: "Tests/ChipsMIDITests"
        ),
    ]
)
