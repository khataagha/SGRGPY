#!/usr/bin/env bash
set -euo pipefail

# Assemble SGRGPY plus the official upstream scrcpy macOS release and its
# runtime files. Build/run this script on macOS; it packages the host CPU arch.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${SCRCPY_VERSION:-v5.0.1}"
OUT="$ROOT/dist"
WORK="$ROOT/.build/bundle-work"
APP="$OUT/SGRGPY.app"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64|aarch64)
    ASSET_ARCH="aarch64"
    SHA256="33611e51977a8289e2e124b220f727895181ef2eb9060e0987a4dc2db9cf0d6b"
    ;;
  x86_64)
    ASSET_ARCH="x86_64"
    SHA256="31a5467a9e907f162b093267cbbab1276b15c6e709c2ea8159566a8d165beb50"
    ;;
  *) echo "Unsupported Mac architecture: $ARCH" >&2; exit 1 ;;
esac

[[ "$(uname -s)" == "Darwin" ]] || { echo "Run this packaging script on macOS." >&2; exit 1; }
command -v swift >/dev/null || { echo "Install Xcode Command Line Tools (xcode-select --install)." >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }
command -v tar >/dev/null || { echo "tar is required." >&2; exit 1; }

ARCHIVE="scrcpy-macos-${ASSET_ARCH}-${VERSION}.tar.gz"
URL="https://github.com/Genymobile/scrcpy/releases/download/${VERSION}/${ARCHIVE}"
rm -rf "$WORK"
mkdir -p "$WORK/upstream" "$OUT"
echo "Downloading official scrcpy ${VERSION} for ${ASSET_ARCH}…"
curl --fail --location --retry 3 "$URL" --output "$WORK/$ARCHIVE"
ACTUAL_SHA="$(shasum -a 256 "$WORK/$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$SHA256" ]] || {
  echo "Checksum mismatch for $ARCHIVE" >&2
  echo "Expected $SHA256, got $ACTUAL_SHA" >&2
  exit 1
}
tar -xzf "$WORK/$ARCHIVE" -C "$WORK/upstream"

# Keep the entire official distribution together: the portable scrcpy client
# locates its server and data relative to its runtime directory.
RUNTIME_SOURCE="$(find "$WORK/upstream" -type f -name scrcpy -perm -111 -print -quit)"
[[ -n "$RUNTIME_SOURCE" ]] || { echo "Official archive did not contain scrcpy." >&2; exit 1; }
RUNTIME_DIR="$(dirname "$RUNTIME_SOURCE")"
[[ -x "$RUNTIME_DIR/adb" ]] || { echo "Official archive did not contain executable adb." >&2; exit 1; }
[[ -f "$RUNTIME_DIR/scrcpy-server" ]] || { echo "Official archive did not contain scrcpy-server." >&2; exit 1; }

swift build --package-path "$ROOT" --configuration release
BINARY="$ROOT/.build/release/SGRGPY"
[[ -x "$BINARY" ]] || { echo "Swift build did not produce $BINARY" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/runtime"
install -m 755 "$BINARY" "$APP/Contents/MacOS/SGRGPY"
# Include all upstream release resources, including their license and notices.
ditto "$RUNTIME_DIR" "$APP/Contents/Resources/runtime"
chmod +x "$APP/Contents/Resources/runtime/scrcpy" "$APP/Contents/Resources/runtime/adb"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>SGRGPY</string>
<key>CFBundleIdentifier</key><string>com.khataagha.SGRGPY</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>SGRGPY</string>
<key>CFBundleDisplayName</key><string>SGRGPY</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP"
else
  echo "Warning: app is unsigned. Set CODE_SIGN_IDENTITY to a valid Developer ID identity to sign it."
fi
echo "Built all-in-one bundle: $APP"
echo "Included runtime: scrcpy $VERSION, ADB, scrcpy server, upstream release resources and notices."
