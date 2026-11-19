# ``Dave``

End-to-End Encryption for Discord voice and video.

## Overview

`Dave` provides a pure Swift wrapper and state machine over Discord's official C++ `libdave` library, implementing the Discord Audio/Video End-to-End Encryption (DAVE) protocol. It enables Swift Discord bot and client libraries to integrate E2EE voice without external package dependencies.

### Key Features

- **Self-contained**: Vendors `libdave`, `mlspp`, and `boringssl` via SwiftPM without external system dependencies.
- **Strict Concurrency**: Built as a Swift 6 actor (`DaveSession`) ensuring thread-safe state management.
- **Zero Third-Party Swift Dependencies**: Clean integration for consumer libraries.
- **Fail-safe Hold Rule**: Enforces that frames are held and never sent in plaintext when the session is not ready.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:IntegratingWithAVoiceLibrary>
- <doc:ProtocolFlow>

### Core Types

- ``DaveSession``
- ``DaveOutgoing``
- ``DaveProtocolVersion``
- ``DaveConfiguration``
- ``DaveCodec``
- ``DaveError``
- ``DaveLogLevel``
- ``setDaveLogSink(_:)``
