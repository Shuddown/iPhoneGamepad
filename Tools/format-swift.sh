#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  "") action=(format --in-place) ;;
  --check) action=(lint --strict) ;;
  *) echo "Usage: $0 [--check]" >&2; exit 2 ;;
esac

xcrun swift-format "${action[@]}" --configuration .swift-format --recursive iPhoneGamepad Tests Tools
