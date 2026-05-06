// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChipsAudioHost",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChipsAudioHost", targets: ["ChipsAudioHost"]),
    ],
    dependencies: [
        .package(path: "../ChipsEngine"),
    ],
    targets: [
        .target(
            name: "ChipsAudioHost",
            dependencies: [
                .product(name: "ChipsEngine", package: "ChipsEngine"),
            ],
            path: "Sources/ChipsAudioHost",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "ChipsAudioHostTests",
            dependencies: ["ChipsAudioHost"],
            path: "Tests/ChipsAudioHostTests"
        ),
    ]
)
