// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ConflictCheck",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(name: "swift-dave", path: "../.."),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "5.1.1"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.6"),
    ],
    targets: [
        .executableTarget(
            name: "ConflictCheck",
            dependencies: [
                .product(name: "Dave", package: "swift-dave"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ]
        )
    ]
)
