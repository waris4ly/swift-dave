#!/usr/bin/env bash
set -euo pipefail

echo "=== building docc documentation ==="

DOCS_DIR="${PWD}/.build/docs"
SYMBOL_GRAPH_DIR="${PWD}/.build/symbol-graphs"
mkdir -p "$DOCS_DIR" "$SYMBOL_GRAPH_DIR"

echo "--- extracting symbol graphs ---"
touch Sources/Dave/Dave.swift
swift build -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir -Xswiftc "$SYMBOL_GRAPH_DIR"

DOCC_BIN=""
if command -v xcrun >/dev/null 2>&1; then
    DOCC_BIN="$(xcrun --find docc 2>/dev/null || true)"
fi
if [ -z "$DOCC_BIN" ] && command -v docc >/dev/null 2>&1; then
    DOCC_BIN="$(command -v docc)"
fi

if [ -n "$DOCC_BIN" ]; then
    echo "--- compiling docc archive ---"
    "$DOCC_BIN" convert Sources/Dave/Documentation.docc \
        --additional-symbol-graph-dir "$SYMBOL_GRAPH_DIR" \
        --output-path "$DOCS_DIR" \
        --warnings-as-errors
else
    echo "--- compiling docc via package plugin ---"
    export SWIFT_DAVE_DOCS=1
    swift package --allow-writing-to-directory "$DOCS_DIR" \
        generate-documentation \
        --target Dave \
        --output-path "$DOCS_DIR"
fi

echo "=== docs build clean ==="
