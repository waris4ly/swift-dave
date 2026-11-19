# Getting Started with Dave

Add DAVE end-to-end encryption to your Swift Discord voice integration.

## Overview

Discord voice channels mandate the DAVE protocol for end-to-end encryption. The `Dave` package encapsulates MLS group key negotiation, key ratchet progression, and AES-128-GCM frame encryption into a single actor: ``DaveSession``.

## Adding the Dependency

In your `Package.swift`, add `swift-dave` as a dependency:

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

## Basic Usage

### 1. Initialize a Session

Create a ``DaveSession`` with your bot or user ID and the target voice channel ID:

```swift
import Dave

let session = try DaveSession(
    userID: 123456789012345678,
    channelID: 987654321098765432
)
```

### 2. Monitor Outgoing Messages

Consume `session.outgoing` in a background task and forward the messages over the Discord Voice Gateway:

```swift
Task {
    for await message in await session.outgoing {
        switch message {
        case .keyPackage(let data):
            // send Opcode 26 (Key Package) to Discord Voice Gateway
            break
        case .commitAndWelcome(let data):
            // send Opcode 28 (Commit + Welcome) to Discord Voice Gateway
            break
        case .readyForTransition(let transitionID):
            // send Opcode 23 (Ready for Transition) with transitionID
            break
        case .invalidCommitWelcome(let transitionID):
            // send Opcode 31 (Invalid Commit/Welcome) with transitionID
            break
        }
    }
}
```

### 3. Encrypting and Decrypting Audio Frames

Map your outgoing RTP SSRC to Opus codec, verify ``DaveSession/isReady``, and encrypt outbound frames:

```swift
// map SSRC before sending
try await session.assignSSRC(1001, codec: .opus)

// verify session readiness
guard await session.isReady else {
    // hold rule: hold audio frames until the session is ready
    return
}

let ciphertext = try await session.encrypt(frame: opusPacket, ssrc: 1001)
// send ciphertext over Voice UDP
```

When receiving encrypted audio packets from remote members:

```swift
let plaintext = try await session.decrypt(
    frame: receivedPacket,
    userID: remoteSenderUserID
)
// feed plaintext to Opus decoder
```
