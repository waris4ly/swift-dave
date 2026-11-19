// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LoopbackDemo",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    dependencies: [
        .package(name: "swift-dave", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "LoopbackDemo",
            dependencies: [
                .product(name: "Dave", package: "swift-dave")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
