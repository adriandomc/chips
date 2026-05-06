// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChipsEngine",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChipsEngine", targets: ["ChipsEngine"]),
    ],
    targets: [
        .target(
            name: "ChipsEngineCxx",
            path: "Sources/ChipsEngineCxx",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .define("CHIPS_ENGINE_VERSION", to: "\"0.0.1-m0\""),
                .unsafeFlags([
                    "-fno-exceptions",
                    "-fno-rtti",
                    "-Wall",
                    "-Wextra",
                    "-Wpedantic",
                ], .when(configuration: .release)),
            ]
        ),
        .target(
            name: "ChipsEngine",
            dependencies: ["ChipsEngineCxx"],
            path: "Sources/ChipsEngine",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "ChipsEngineTests",
            dependencies: ["ChipsEngine"],
            path: "Tests/ChipsEngineTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
