#!/usr/bin/env bash
set -euo pipefail
swift format format -i -r Sources Tests Examples 2>/dev/null || swift format format -i -r Sources Tests
