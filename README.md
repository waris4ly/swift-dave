[![Swift Version](https://img.shields.io/badge/Swift-6.0%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgrey.svg)](Package.swift)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![swift-dave Version](https://img.shields.io/github/v/tag/waris4ly/swift-dave?label=release)](https://github.com/waris4ly/swift-dave/releases/latest)

# swift-dave

swift-dave is a library that provides Swift bindings for [libdave](https://github.com/discord/libdave) and provides a generic DAVE interface allowing for different implementations in the future.

## Summary

1. [Installation](#installation)
   1. [Supported Platforms](#supported-platforms)
2. [Example Usage](#example-usage)
3. [The Hold Rule](#the-hold-rule)
4. [Documentation](#documentation)
5. [Vendored Code & Performance](#vendored-code--performance)
6. [License](#license)

## Installation

This library vendors `libdave`, `mlspp`, and `boringssl` directly into SwiftPM, compiling entirely from source with zero external system dependencies (no Homebrew, CMake, or vcpkg required).

Add `swift-dave` to your package dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/waris4ly/swift-dave.git", from: "0.1.0")
]
```

Add `Dave` to your target dependencies:

```swift
.target(
    name: "MyVoiceClient",
    dependencies: [
        .product(name: "Dave", package: "swift-dave")
    ]
)
```

### Supported Platforms

| Platform | Minimum | Tested With |
| :--- | :--- | :--- |
| macOS | 13.0+ | macOS 14, 15 (arm64, x86_64) |
| iOS | 16.0+ | iOS 16, 17, 18 |
| tvOS | 16.0+ | tvOS 16, 17, 18 |
| watchOS | 9.0+ | watchOS 9, 10, 11 |
| Linux | Ubuntu 22.04+ | Swift 6.2+ (aarch64, x86_64) |

## Example Usage

For a complete standalone simulated client and gateway pipeline, see the [Examples/LoopbackDemo](Examples/LoopbackDemo) or the [Integration Guide](Docs/INTEGRATION.md).

```swift
import Dave

// initialize a session for user and channel
let session = try DaveSession(
    userID: 123_456_789,
    channelID: 987_654_321
)

// consume outgoing voice gateway messages in a background task
Task {
    for await message in await session.outgoing {
        switch message {
        case .keyPackage(let data):
            // send Opcode 26 (Key Package)
            break
        case .commitAndWelcome(let data):
            // send Opcode 28 (Commit + Welcome)
            break
        case .readyForTransition(let transitionID):
            // send Opcode 23 (Ready for Transition)
            break
        case .invalidCommitWelcome(let transitionID):
            // send Opcode 31 (Invalid Commit/Welcome)
            break
        }
    }
}

// acknowledge protocol version when discord voice gateway connects
try await session.acknowledgeProtocolVersion(.disabled)
try await session.prepareTransition(transitionID: 0, protocolVersion: .disabled)
try await session.executeTransition(transitionID: 0)

// configure outgoing ssrc for audio
try await session.assignSSRC(1001, codec: .opus)

// encrypt audio frame (enforcing the hold rule)
guard await session.isReady else {
    return
}

let audioFrame = [UInt8](repeating: 0x42, count: 80)
let encrypted = try await session.encrypt(frame: audioFrame, ssrc: 1001)

// decrypt incoming audio frames from remote users
try await session.addUser(userID: 222_333_444)
let decrypted = try await session.decrypt(frame: encrypted, userID: 222_333_444)

await session.close()
```

## The Hold Rule

> [!NOTE]
> Never transmit unencrypted audio or video frames over UDP when `session.isReady` is `false`.
>
> While transitions occur (such as initial MLS group setup or ciphersuite changes), `isReady` returns `false`. Calling `session.encrypt(frame:ssrc:)` while unready throws `DaveError.notReady`. Audio queues must hold or discard frames until `isReady` transitions to `true`.

## Documentation

Full DocC articles and architecture guides:
* [Getting Started](Sources/Dave/Documentation.docc/GettingStarted.md)
* [Integrating with a Voice Library](Sources/Dave/Documentation.docc/IntegratingWithAVoiceLibrary.md)
* [Protocol Flow](Sources/Dave/Documentation.docc/ProtocolFlow.md)
* [Voice Integration Guide](Docs/INTEGRATION.md)

Generate local documentation with:
```bash
scripts/build-docs.sh
```

## Vendored Code & Performance

`swift-dave` vendors all C/C++ dependencies (`libdave`, `mlspp`, `boringssl`) directly into the repository to avoid external package managers or CMake build steps:
* Total source tree size: **~16.4 MB** (`CBoringSSL`: ~14.4 MB, `CMLSPP`: ~1.5 MB, `CLibDave`: ~344 KB, `Dave`: ~128 KB, `CDaveTestSupport`: ~20 KB).
* Git repository pack size: **~2.82 MB**.
* Clean build time from scratch: **~11.6 seconds** (Apple Silicon M-series).

## License

Distributed under the [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE). See `LICENSE` and `THIRD_PARTY_NOTICES.md` for more information.
