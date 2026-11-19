#!/usr/bin/env bash
set -euo pipefail

DIRS=("Sources/Dave" "Tests" "Package.swift")
if [ -d "Examples" ]; then
    DIRS+=("Examples")
fi

ALLOWLIST="scripts/banned-allowlist.txt"

BANNED=(
    'try!'
    'as!'
    'fatalError('
    'preconditionFailure('
    'unsafeBitCast'
    'print('
    'debugPrint('
    'dump('
    'TODO'
    'FIXME'
    'swift-format-ignore'
    'DispatchQueue'
    'Task\.detached'
    'unsafeFlags'
    'XCTSkip'
    '\.disabled('
    'withKnownIssue'
    'MARK:'
)

EXIT=0

for PATTERN in "${BANNED[@]}"; do
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        PATTERN="${PATTERN//$line/}"
    done < "$ALLOWLIST" 2>/dev/null || true

    HITS=$(grep -rn --include='*.swift' --exclude-dir='.build' --exclude-dir='.swiftpm' -E "$PATTERN" "${DIRS[@]}" 2>/dev/null || true)

    if [ -n "$HITS" ]; then
        FILTERED="$HITS"
        if [ -f "$ALLOWLIST" ]; then
            while IFS= read -r allow || [[ -n "$allow" ]]; do
                [[ -z "$allow" || "$allow" == \#* ]] && continue
                FILTERED=$(echo "$FILTERED" | grep -v "$allow" || true)
            done < "$ALLOWLIST"
        fi
        if [ -n "$FILTERED" ]; then
            echo "BANNED pattern '$PATTERN' found:"
            echo "$FILTERED"
            EXIT=1
        fi
    fi
done

# verify concurrency escape hatches only exist in reviewed files
UNSAFE_HITS=$(grep -rn --include='*.swift' --exclude-dir='.build' --exclude-dir='.swiftpm' \
    -E '(@unchecked Sendable|nonisolated\(unsafe\))' \
    "${DIRS[@]}" 2>/dev/null \
    | grep -v 'Sources/Dave/Libdave/NativeHandle\.swift' \
    | grep -v 'Sources/Dave/Libdave/LibdaveLogging\.swift' \
    || true)

if [ -f "$ALLOWLIST" ]; then
    while IFS= read -r allow || [[ -n "$allow" ]]; do
        [[ -z "$allow" || "$allow" == \#* ]] && continue
        UNSAFE_HITS=$(echo "$UNSAFE_HITS" | grep -v "$allow" || true)
    done < "$ALLOWLIST"
fi

if [ -n "$UNSAFE_HITS" ]; then
    echo "BANNED: @unchecked Sendable / nonisolated(unsafe) outside allowed files:"
    echo "$UNSAFE_HITS"
    EXIT=1
fi

exit $EXIT
