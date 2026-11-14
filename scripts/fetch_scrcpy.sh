#!/usr/bin/env bash
set -euo pipefail

# Offline extraction/verification helper for the checked-in official archive.
# Usage: scripts/fetch_scrcpy.sh [x86_64|aarch64] [output-directory]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="${1:-$(uname -m)}"
OUT="${2:-$ROOT/.build/scrcpy-runtime}"
VERSION="5.0.1"
case "$ARCH" in
  amd64|x86_64) ARCH=x86_64; SHA="31a5467a9e907f162b093dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d" ;;
  arm64|aarch64) ARCH=aarch64; SHA="33611e51977a8289e2e124b220f727895181ef2eb9060e0987a4dc2db9cf0d6b" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
ARCHIVE="$ROOT/vendor/scrcpy/scrcpy-macos-${ARCH}-v${VERSION}.tar.gz"
[[ -f "$ARCHIVE" ]] || { echo "Vendored archive not found: $ARCHIVE" >&2; exit 1; }
ACTUAL="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL" == "$SHA" ]] || { echo "SHA-256 mismatch: $ACTUAL" >&2; exit 1; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sgrgpy-runtime.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/unpacked"
tar -xzf "$ARCHIVE" -C "$TMP/unpacked"
SCRCPY="$(find "$TMP/unpacked" -type f -name scrcpy -print -quit)"
[[ -n "$SCRCPY" ]] || { echo "Archive is missing scrcpy." >&2; exit 1; }
SRC="$(dirname "$SCRCPY")"
[[ -x "$SRC/scrcpy" && -x "$SRC/adb" && -f "$SRC/scrcpy-server" ]] || { echo "Incomplete official runtime archive." >&2; exit 1; }
rm -rf "$OUT"
mkdir -p "$OUT"
ditto "$SRC" "$OUT"
echo "Verified and extracted locally vendored scrcpy $VERSION ($ARCH) runtime to $OUT"
