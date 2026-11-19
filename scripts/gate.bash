#!/usr/bin/env bash
set -euo pipefail

PHASE="${SWIFT_DAVE_PHASE:-0}"

echo "=== gate: phase $PHASE ==="

echo "--- format check ---"
bash scripts/lint.bash

echo "--- banned patterns ---"
bash scripts/check-banned.bash

echo "--- build ---"
swift build -Xswiftc -warnings-as-errors

echo "--- tests ---"
swift test -Xswiftc -warnings-as-errors

if [ "$PHASE" -ge 1 ]; then
    echo "--- vendor check ---"
    bash scripts/check-vendor.bash

    echo "--- symbol prefix check ---"
    bash scripts/check-symbols.bash
fi

if [ "$PHASE" -ge 2 ]; then
    echo "--- asan ---"
    swift test --sanitize=address -Xswiftc -warnings-as-errors

    echo "--- ubsan ---"
    UBSAN_FLAGS=()
    if [[ "$(uname -s)" == "Darwin" ]]; then
        TOOLCHAIN_PATH="$(swiftc -print-target-info | grep -o '/.*swift.*\.xctoolchain' | head -1 || true)"
        if [ -n "$TOOLCHAIN_PATH" ]; then
            UBSAN_DYLIB="$(find "$TOOLCHAIN_PATH" -name "libclang_rt.ubsan_osx_dynamic.dylib" 2>/dev/null | head -1 || true)"
            if [ -n "$UBSAN_DYLIB" ]; then
                UBSAN_FLAGS+=("-Xlinker" "$UBSAN_DYLIB")
            fi
        fi
    fi
    swift test --sanitize=undefined -Xswiftc -warnings-as-errors "${UBSAN_FLAGS[@]}"

    echo "--- tsan ---"
    swift test --sanitize=thread -Xswiftc -warnings-as-errors
fi

if [ "$PHASE" -ge 4 ]; then
    echo "--- docs build ---"
    bash scripts/build-docs.bash

    echo "--- loopback demo ---"
    (cd Examples/LoopbackDemo && swift build -Xswiftc -warnings-as-errors && swift run LoopbackDemo)
fi

echo "=== gate: all green ==="
