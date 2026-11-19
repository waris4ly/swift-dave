// swift-tools-version: 6.1

import Foundation
import PackageDescription

let package = Package(
    name: "swift-dave",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "Dave", targets: ["Dave"])
    ],
    targets: [
        .target(
            name: "CBoringSSL",
            path: "Sources/CBoringSSL",
            exclude: [
                "CMakeLists.txt",
                "hash.txt",
                "PrivacyInfo.xcprivacy",
                // networking files not needed (safe to exclude on all platforms)
                "crypto/bio/connect.cc",
                "crypto/bio/socket_helper.cc",
                "crypto/bio/socket.cc",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("_HAS_EXCEPTIONS", to: "0", .when(platforms: [.windows])),
                .define("WIN32_LEAN_AND_MEAN", .when(platforms: [.windows])),
                .define("NOMINMAX", .when(platforms: [.windows])),
            ],
            cxxSettings: []
        ),

        .target(
            name: "CMLSPP",
            dependencies: ["CBoringSSL"],
            path: "Sources/CMLSPP",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("WITH_BORINGSSL"),
                .define("DISABLE_GREASE"),
                .define("MLS_NAMESPACE", to: "mlspp"),
                // find our openssl/ shims (rooted at CBoringSSL's public include)
                .headerSearchPath("include"),
                // private headers within src subdirectories
                .headerSearchPath("src/mls"),
                .headerSearchPath("src/hpke"),
            ]
        ),

        .target(
            name: "CLibDave",
            dependencies: ["CMLSPP"],
            path: "Sources/CLibDave",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("DAVE_STATIC"),
                .define("WITH_BORINGSSL"),
                // libdave includes its own src/ headers via relative paths
                .headerSearchPath("src"),
            ]
        ),

        .target(
            name: "Dave",
            dependencies: ["CLibDave"],
            path: "Sources/Dave",
            swiftSettings: swiftSettings
        ),

        .target(
            name: "CDaveTestSupport",
            dependencies: [
                "CLibDave",
                "CMLSPP",
                "CBoringSSL",
            ],
            path: "Sources/CDaveTestSupport",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("DAVE_STATIC"),
                .define("WITH_BORINGSSL"),
                .headerSearchPath("src"),
                .headerSearchPath("../CLibDave/src"),
                .headerSearchPath("../CMLSPP/include"),
                .headerSearchPath("../CBoringSSL/include"),
            ]
        ),

        .testTarget(
            name: "DaveTests",
            dependencies: [
                "Dave",
                "CLibDave",
                "CBoringSSL",
                "CDaveTestSupport",
            ],
            path: "Tests/DaveTests",
            swiftSettings: swiftSettings
        ),

        .testTarget(
            name: "DaveIntegrationTests",
            dependencies: [
                "Dave",
            ],
            path: "Tests/DaveIntegrationTests",
            swiftSettings: swiftSettings
        ),
    ],
    cxxLanguageStandard: .cxx17
)

private let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

if ProcessInfo.processInfo.environment["SWIFT_DAVE_DOCS"] == "1" {
    package.dependencies.append(
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3")
    )
}
