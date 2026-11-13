#!/usr/bin/env bash
set -euo pipefail

# Fetch the official scrcpy release and verify the checksum before extraction.
# Usage: scripts/fetch_scrcpy.sh [x86_64|aarch64] [output-directory]
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="${1:-$(uname -m)}"
OUT_DIR="${2:-$ROOT_DIR/.build/scrcpy-runtime}"
VERSION="${SCRCPY_VERSION:-5.0.1}"
case "$ARCH" in
  amd64|x86_64) ARCH=x86_64; SHA="31a5467a9e907f162b093267cbbab1276b15c6e709c2ea8159566a8d165beb50" ;;
  arm64|aarch64) ARCH=aarch64; SHA="33611e51977a8289e2e124b220f727895181ef2eb9060e0987a4dc2db9cf0d6b" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sgrgpy-runtime.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
ASSET="scrcpy-macos-${ARCH}-v${VERSION}.tar.gz"
curl --fail --location --retry 3 --output "$TMP/$ASSET" "https://github.com/Genymobile/scrcpy/releases/download/v${VERSION}/${ASSET}"
ACTUAL="$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')"
[[ "$ACTUAL" == "$SHA" ]] || { echo "Checksum mismatch: $ACTUAL" >&2; exit 1; }
mkdir -p "$TMP/unpacked" "$OUT_DIR"
tar -xzf "$TMP/$ASSET" -C "$TMP/unpacked"
SRC="$(find "$TMP/unpacked" -type f -name scrcpy -print -quit | xargs dirname)"
[[ -x "$SRC/scrcpy" && -x "$SRC/adb" && -f "$SRC/scrcpy-server" ]] || { echo "Incomplete official runtime archive" >&2; exit 1; }
rm -rf "$OUT_DIR"/*
cp -R "$SRC/." "$OUT_DIR/"
echo "Verified scrcpy $VERSION ($ARCH) runtime at $OUT_DIR"
