# Testing swift-dave

Testing strategy, test suites, and coverage verification for `swift-dave`.

## Overview

The test suite is built on Apple's Swift Testing framework (`import Testing`) and is designed to run completely offline without external network or voice servers.

### Principles

- **Deterministic**: Tests do not use real-time sleeps, timers, or network sockets.
- **Fail-safe**: No forced unwraps (`!`), `try!`, or `as!` in test code; assertions use `#expect` and `try #require`.
- **Sanitizer Validated**: Every phase runs under ASAN, UBSAN, and TSAN.

## Test Suites

| Suite | File | Focus |
| :--- | :--- | :--- |
| **Toolchain** | `ToolchainSmokeTests.swift` | Basic constants and pipeline verification. |
| **BoringSSL** | `BoringSSLLinkTests.swift` | Prefixed BoringSSL link and SHA-256 test vectors. |
| **Libdave Smoke** | `LibdaveSmokeTests.swift` | C API versioning and handle create/destroy. |
| **Native Handle** | `NativeHandleTests.swift` | Safe ownership, idempotent close, use-after-close errors. |
| **Session FFI** | `LibdaveSessionTests.swift` | Two-party loopback using real `libdave` C API. |
| **Frames** | `LibdaveFrameTests.swift` | AES-128-GCM frame encryption, tamper resistance, passthrough. |
| **Key Ratchet** | `KeyRatchetTests.swift` | Ratchet transitions, generation gaps, nonces. |
| **Log Sink** | `LogSinkTests.swift` | Native log callback bridge thread safety. |
| **Process Exit** | `ProcessExitTests.swift` | Static destructor ordering with live native objects in subprocess. |
| **State Machine** | `SessionStateMachineTests.swift` | Table-driven state machine tests with `MockEngine`. |
| **Scenarios** | `SessionScenarioTests.swift` | Real `libdave` two-party negotiation via public `DaveSession` actor. |
| **Concurrency** | `SessionConcurrencyTests.swift` | High concurrency stress test across actors (TSAN validated). |
| **README Example** | `ReadmeExampleTests.swift` | Verifies that the public README usage example compiles and runs. |

## Test Support Utilities

Located in `Tests/DaveTests/Support/`:
- **`TestFrames.swift`**: Generates synthetic Opus audio and video test frames.
- **`TestExternalSender.swift`**: Swift wrapper over `external_sender.cpp` for simulated Discord voice gateway proposals.
- **`TestGroup.swift`**: Orchestrates multi-party MLS groups in memory.
- **`MockEngine.swift`**: Thread-safe `OSAllocatedUnfairLock`-backed mock implementation of all engine protocols.

## Measuring Code Coverage

To generate and view line-by-line coverage metrics:

```bash
swift test --enable-code-coverage
```

Targeting the `Session` subsystem using `llvm-cov`:

```bash
xcrun llvm-cov report \
    .build/out/Products/Debug/DaveTests.xctest/Contents/MacOS/DaveTests \
    -instr-profile=.build/out/Products/Debug/codecov/default.profdata \
    Sources/Dave/Session
```
