#!/usr/bin/env bash
set -euo pipefail

# Verify and unpack the checked-in official scrcpy macOS release archive.
# Usage: scripts/fetch_scrcpy.sh [x86_64|aarch64] [output-directory]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="${1:-$(uname -m)}"
OUT="${2:-$ROOT/.build/scrcpy-runtime}"
VERSION="5.0.1"

case "$ARCH" in
  amd64|x86_64)
    ARCH="x86_64"
    SHA256="31a5467a9e907f162b093dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d"
    ;;
  arm64|aarch64)
    ARCH="aarch64"
    SHA256="33611e51977a8289e2e124b220f727895181ef2eb9060e0987a4dc2db9cf0d6b"
    ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

command -v shasum >/dev/null || { echo "shasum is required to verify the vendored archive." >&2; exit 1; }
command -v tar >/dev/null || { echo "tar is required to extract the vendored archive." >&2; exit 1; }
command -v ditto >/dev/null || { echo "ditto is required to preserve macOS file metadata." >&2; exit 1; }

ARCHIVE="$ROOT/vendor/scrcpy/scrcpy-macos-${ARCH}-v${VERSION}.tar.gz"
[[ -f "$ARCHIVE" ]] || { echo "Vendored archive not found: $ARCHIVE" >&2; exit 1; }
ACTUAL_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$SHA256" ]] || {
  echo "SHA-256 mismatch for $ARCHIVE" >&2
  echo "Expected: $SHA256" >&2
  echo "Actual:   $ACTUAL_SHA" >&2
  exit 1
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sgrgpy-runtime.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/unpacked"
tar -xzf "$ARCHIVE" -C "$TMP/unpacked"
SCRCPY_PATH="$(find "$TMP/unpacked" -type f -name scrcpy -print -quit)"
[[ -n "$SCRCPY_PATH" ]] || { echo "Official archive is missing scrcpy." >&2; exit 1; }
SOURCE_DIR="$(dirname "$SCRCPY_PATH")"
[[ -x "$SOURCE_DIR/scrcpy" ]] || { echo "scrcpy is not executable." >&2; exit 1; }
[[ -x "$SOURCE_DIR/adb" ]] || { echo "Official archive is missing executable adb." >&2; exit 1; }
[[ -f "$SOURCE_DIR/scrcpy-server" ]] || { echo "Official archive is missing scrcpy-server." >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
ditto "$SOURCE_DIR" "$OUT"
echo "Verified and extracted locally vendored scrcpy $VERSION ($ARCH) runtime to $OUT"
