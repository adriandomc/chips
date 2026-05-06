// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChipsUIKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChipsUIKit", targets: ["ChipsUIKit"]),
    ],
    targets: [
        .target(
            name: "ChipsUIKit",
            path: "Sources/ChipsUIKit",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "ChipsUIKitTests",
            dependencies: ["ChipsUIKit"],
            path: "Tests/ChipsUIKitTests"
        ),
    ]
)
