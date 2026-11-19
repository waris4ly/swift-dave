#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/dave-vendor-XXXXXX)"

trap 'rm -rf "$WORK"' EXIT

echo "=== Vendoring libdave, mlspp, boringssl, nlohmann/json ==="

git clone --depth 1 --branch "v1.3.0/cpp" https://github.com/discord/libdave.git "$WORK/libdave"

git clone https://github.com/cisco/mlspp.git "$WORK/mlspp"
(cd "$WORK/mlspp" && git checkout 1cc50a124a3bc4e143a787ec934280dc70c1034d)

git clone --depth 1 --branch 5.1.1 https://github.com/apple/swift-crypto.git "$WORK/swift-crypto"

mkdir -p "$WORK/nlohmann"
curl -sL "https://github.com/nlohmann/json/releases/download/v3.12.0/json.hpp" -o "$WORK/nlohmann/json.hpp"

echo "Vendoring sources fetched. Targets in Sources/ are maintained with documented patches in Vendor/PATCHES.md."
