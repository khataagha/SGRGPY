#!/usr/bin/env bash
set -euo pipefail

# Root entry point for building the bundled macOS app.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$ROOT/scripts/build_app.sh" "$@"
