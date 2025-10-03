// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIReels",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        .library(name: "SwiftUIReels", targets: ["SwiftUIReels"]),
//        .executable(name: "CLIExample", targets: ["CLIExample"]),
        .library(name: "VideoViews", targets: ["VideoViews"]),

    ],
    dependencies: [
//        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        .package(url: "https://github.com/shogo4405/HaishinKit.swift.git", branch: "main"),
        .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "1.0.6"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.8.0"),

    ],
    targets: [
        .target(
            name: "SwiftUIReels",
            dependencies: [
                .product(name: "HaishinKit", package: "HaishinKit.swift"),
                .product(name: "RTMPHaishinKit", package: "HaishinKit.swift"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Nuke", package: "Nuke"),
            ],
            path: "Sources/SwiftUIReels",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]),
        .testTarget(
            name: "SwiftUIReelsTests",
            dependencies: ["SwiftUIReels", "VideoViews"]),

//        .executableTarget(
//            name: "CLIExample",
//            dependencies: [
//                "SwiftUIReels",
//                "VideoViews",
//                .product(name: "ArgumentParser", package: "swift-argument-parser"),
//            ],
//            path: "Examples/CLIExample"),

        .target(
            name: "VideoViews",
            dependencies: [
                "SwiftUIReels",
            ],
            path: "Examples/VideoViews",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]),
    ])
