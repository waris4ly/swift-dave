# Architecture

This document describes the design, layering, and concurrency model of `swift-dave`.

## System Overview

`swift-dave` bridges Discord's C++ `libdave` library into Swift with an idiomatic, strictly typed, and concurrency-safe architecture.

```
┌────────────────────────────────────────────────────────┐
│                   Public Swift API                     │
│  DaveSession (Actor), DaveOutgoing, DaveProtocolVersion│
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                 Session State Machine                  │
│       TransitionTracker, UserRegistry (Internal)       │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                 Engine Abstraction                     │
│    MLSEngine, FrameEncryptor, FrameDecryptor Protocols │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                Libdave FFI Wrapper                     │
│       NativeHandle, LibdaveSession, LibdaveEncryptor   │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│               Vendored C/C++ Libraries                 │
│      CLibDave (C++) ──► CMLSPP (C++) ──► CBoringSSL    │
└────────────────────────────────────────────────────────┘
```

## Layer Descriptions

### 1. Vendored C/C++ Libraries
- **`CBoringSSL`**: Google's BoringSSL crypto library. All C symbols are prefixed with `CCryptoBoringSSL_` to prevent symbol collisions with system OpenSSL or `swift-crypto`.
- **`CMLSPP`**: Cisco's Messaging Layer Security C++ implementation (RFC 9420), configured without GREASE, with BoringSSL crypto backend.
- **`CLibDave`**: Discord's official E2EE voice protocol library, exposing a pure C API (`dave.h`).

### 2. Libdave FFI Wrapper (`Sources/Dave/Libdave/`)
- Encapsulates raw C pointers inside `NativeHandle<T>` with RAII teardown and idempotent `close()`.
- Maps C return codes into strongly typed Swift errors (`DaveError`).
- Converts raw pointer buffers to Swift `[UInt8]` arrays without leaking memory.

### 3. Engine Abstraction Layer (`Sources/Dave/Engine/`)
- Declares Swift protocols (`MLSEngine`, `FrameEncryptor`, `FrameDecryptor`, `KeyRatchetHandle`).
- Decouples the session state machine from the C++ FFI, allowing table-driven testing with `MockEngine` without invoking C++ binaries.

### 4. Session State Machine Layer (`Sources/Dave/Session/`)
- **`DaveSession`**: A Swift 6 `actor` that coordinates gateway signaling with media encryption.
- **`TransitionTracker`**: Tracks pending transitions and maps transition IDs to protocol versions.
- **`UserRegistry`**: Manages recognized remote participants, their decryptor lifecycles, and key ratchet assignments.

## Concurrency and Thread Safety

- **Actor Isolation**: All mutable session state lives inside `DaveSession`. External callers interact via `async/await`.
- **Thread Sanitizer Clean**: Verified under Thread Sanitizer (TSAN) under heavy concurrent read, write, and transition workloads.
- **Zero Third-Party Dependencies**: The core package relies exclusively on the Swift standard library and system frameworks (`os`, `Foundation`).
