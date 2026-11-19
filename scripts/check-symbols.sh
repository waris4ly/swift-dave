#!/usr/bin/env bash
set -euo pipefail

OBJECTS=$(find .build -name "*.o" -path "*/CBoringSSL-t.build/*" 2>/dev/null || true)

if [ -z "$OBJECTS" ]; then
    echo "No CBoringSSL objects found. Run swift build first."
    exit 1
fi

# ignore compiler intrinsics and c++ mangled names
UNPREFIXED=$(echo "$OBJECTS" | xargs nm -gU 2>/dev/null \
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
