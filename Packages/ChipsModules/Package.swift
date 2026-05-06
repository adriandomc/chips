// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChipsModules",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChipsModules", targets: ["ChipsModules"]),
    ],
    dependencies: [
        .package(path: "../ChipsEngine"),
    ],
    targets: [
        .target(
            name: "ChipsModules",
            dependencies: [
                .product(name: "ChipsEngine", package: "ChipsEngine"),
            ],
            path: "Sources/ChipsModules",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "ChipsModulesTests",
            dependencies: ["ChipsModules"],
            path: "Tests/ChipsModulesTests"
        ),
    ]
)
