// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChipsTesting",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChipsTesting", targets: ["ChipsTesting"]),
    ],
    targets: [
        .target(
            name: "ChipsTesting",
            path: "Sources/ChipsTesting",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
