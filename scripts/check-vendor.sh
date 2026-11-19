#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAIL=0

check_file() {
    if [ ! -f "$ROOT/$1" ]; then
        echo "MISSING: $1"
        FAIL=1
    fi
}

check_file "Sources/CBoringSSL/LICENSE"
check_file "Sources/CBoringSSL/include/module.modulemap"
check_file "Sources/CMLSPP/LICENSE"
check_file "Sources/CMLSPP/include/namespace.h"
check_file "Sources/CLibDave/LICENSE"
check_file "Sources/CLibDave/include/dave.h"
check_file "Sources/CLibDave/include/module.modulemap"
check_file "THIRD_PARTY_NOTICES.md"
check_file "Vendor/VERSIONS.md"
check_file "Vendor/PATCHES.md"

if [ $FAIL -ne 0 ]; then
    echo "Vendor check failed."
    exit 1
fi

echo "Vendor check passed."
exit 0
