# Building swift-dave

Instructions for building, formatting, and generating documentation for `swift-dave`.

## Prerequisites

- **Swift**: 6.1 or higher.
- **macOS**: macOS 13 (Ventura) or higher, with Xcode Command Line Tools.
- **Linux**: Ubuntu 22.04+ with official Swift toolchain.
- No external package managers (Homebrew, CMake, vcpkg) are required.

## Building the Package

### Standard Debug Build

```bash
swift build
```

### Build with Warnings as Errors

The project adheres to a zero-warning policy:

```bash
swift build -Xswiftc -warnings-as-errors
```

### Running Tests

Run the full Swift Testing test suite:

```bash
swift test -Xswiftc -warnings-as-errors
```

## Sanitizer Builds

Sanitizers verify memory safety and concurrency invariants:

### Address Sanitizer (ASAN)

Checks for memory leaks, buffer overflows, and use-after-free bugs:

```bash
swift test --sanitize=address -Xswiftc -warnings-as-errors
```

### Undefined Behavior Sanitizer (UBSAN)

Checks for undefined behavior, integer overflows, and misaligned pointer arithmetic:

```bash
swift test --sanitize=undefined -Xswiftc -warnings-as-errors
```

### Thread Sanitizer (TSAN)

Verifies data race freedom across actor and thread boundaries:

```bash
swift test --sanitize=thread -Xswiftc -warnings-as-errors
```

## Documentation Build

Build DocC documentation with zero warnings:

```bash
scripts/build-docs.bash
```

Compiled documentation is written to `.build/docs/`.

## Code Hygiene and Linting

Format source code:

```bash
scripts/format.bash
```

Verify formatting strictness:

```bash
scripts/lint.bash
```

Check for banned patterns:

```bash
scripts/check-banned.bash
```

## Verification Gate

Run the complete gate suite (linting, banned checks, compilation, tests, symbol checks, vendor checks, and sanitizers):

```bash
SWIFT_DAVE_PHASE=4 bash scripts/gate.bash
```
