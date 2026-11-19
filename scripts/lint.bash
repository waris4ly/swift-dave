#!/usr/bin/env bash
set -euo pipefail
swift format lint --strict -r Sources Tests Examples 2>/dev/null || swift format lint --strict -r Sources Tests
