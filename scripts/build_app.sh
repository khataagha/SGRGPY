#!/usr/bin/env bash
set -euo pipefail

# Build SGRGPY and bundle the official, version-pinned scrcpy macOS static
# distribution (scrcpy, adb, server JAR, support assets and upstream license).
# The official binaries are downloaded at build time; they are not checked in.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SGRGPY"
SCRCPY_VERSION="${SCRCPY_VERSION:-5.0.1}"

case "${SCRCPY_ARCH:-$(uname -m)}" in
  x86_64|amd64)
    ARCH="x86_64"
    SHA256="31a5467a9e907f162b093267cbbab1276b15c6e709c2ea8159566a8d165beb50"
    ;;
  arm64|aarch64)
    ARCH="aarch64"
    SHA256="33611e51977a8289e2e124b220f727895181ef2eb9060e0987a4dc2db9cf0d6b"
    ;;
  *) echo "Unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
esac

[[ "$(uname -s)" == Darwin ]] || { echo "Run this packaging script on macOS." >&2; exit 1; }
command -v swift >/dev/null || { echo "Swift is required; install Xcode Command Line Tools." >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }
command -v tar >/dev/null || { echo "tar is required." >&2; exit 1; }

ASSET="scrcpy-macos-${ARCH}-v${SCRCPY_VERSION}.tar.gz"
URL="https://github.com/Genymobile/scrcpy/releases/download/v${SCRCPY_VERSION}/${ASSET}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sgrgpy.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
ARCHIVE="$WORK_DIR/$ASSET"

printf 'Downloading official scrcpy %s for macOS %s…\n' "$SCRCPY_VERSION" "$ARCH"
curl --fail --location --retry 3 --output "$ARCHIVE" "$URL"
ACTUAL_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$SHA256" ]] || {
  echo "SHA-256 mismatch for $ASSET" >&2
  echo "expected $SHA256" >&2
  echo "actual   $ACTUAL_SHA" >&2
  exit 1
}

mkdir -p "$WORK_DIR/extracted"
tar -xzf "$ARCHIVE" -C "$WORK_DIR/extracted"
RUNTIME_DIR="$(find "$WORK_DIR/extracted" -type f -name scrcpy -print -quit | xargs dirname)"
[[ -n "$RUNTIME_DIR" && -x "$RUNTIME_DIR/scrcpy" ]] || { echo "Official archive did not contain scrcpy." >&2; exit 1; }
[[ -x "$RUNTIME_DIR/adb" ]] || { echo "Official archive did not contain executable adb." >&2; exit 1; }
[[ -f "$RUNTIME_DIR/scrcpy-server" ]] || { echo "Official archive did not contain scrcpy-server." >&2; exit 1; }

swift build --package-path "$ROOT_DIR" --configuration release
BINARY="$ROOT_DIR/.build/release/$APP_NAME"
[[ -x "$BINARY" ]] || { echo "Swift build did not produce $BINARY" >&2; exit 1; }

APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME-${ARCH}.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/scrcpy-runtime"
install -m 755 "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
# Copy the complete upstream distribution, retaining its support files and license.
cp -R "$RUNTIME_DIR/." "$APP_BUNDLE/Contents/Resources/scrcpy-runtime/"
chmod +x "$APP_BUNDLE/Contents/Resources/scrcpy-runtime/scrcpy" "$APP_BUNDLE/Contents/Resources/scrcpy-runtime/adb"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
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
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "Note: app is unsigned. Set CODE_SIGN_IDENTITY to sign it for distribution."
fi

echo "Built all-in-one app: $APP_BUNDLE"
echo "Bundled runtime: scrcpy $SCRCPY_VERSION, $ARCH (scrcpy + adb + scrcpy-server + upstream support files)"
