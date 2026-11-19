#!/usr/bin/env bash
set -euo pipefail

OBJECTS=$(find .build -name "*.o" -path "*CBoringSSL*" 2>/dev/null || true)

if [ -z "$OBJECTS" ]; then
    echo "No CBoringSSL objects found. Building CBoringSSL..."
    swift build -Xswiftc -warnings-as-errors --target CBoringSSL
    OBJECTS=$(find .build -name "*.o" -path "*CBoringSSL*" 2>/dev/null || true)
fi

if [ -z "$OBJECTS" ]; then
    echo "ERROR: No CBoringSSL objects found in .build"
    exit 1
fi

NM_FLAGS=("-g")
if [[ "$(uname -s)" == "Darwin" ]]; then
    NM_FLAGS+=("-U")
else
    NM_FLAGS+=("--defined-only")
fi

# ignore compiler intrinsics and c++ mangled names
UNPREFIXED=$(echo "$OBJECTS" | xargs nm "${NM_FLAGS[@]}" 2>/dev/null \
    | grep -E " T _" \
    | grep -v " _CCryptoBoringSSL_" \
    | grep -v " __Z" \
    | grep -v " ___" \
    || true)

if [ -n "$UNPREFIXED" ]; then
    echo "ERROR: Found unprefixed BoringSSL symbols in CBoringSSL objects:"
    echo "$UNPREFIXED"
    exit 1
fi

echo "All BoringSSL C symbols are properly prefixed."
exit 0
