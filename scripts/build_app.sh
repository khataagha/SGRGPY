#!/usr/bin/env bash
set -euo pipefail

# Build SGRGPY and bundle only the checked-in official scrcpy archive.
# This script makes no network requests.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SGRGPY"
SCRCPY_VERSION="5.0.1"

[[ "$(uname -s)" == "Darwin" ]] || { echo "Run this packaging script on macOS." >&2; exit 1; }
command -v swift >/dev/null || { echo "Swift is required; install Xcode Command Line Tools." >&2; exit 1; }
command -v ditto >/dev/null || { echo "ditto is required." >&2; exit 1; }

case "$(uname -m)" in
  x86_64|amd64) ARCH="x86_64" ;;
  arm64|aarch64) ARCH="aarch64" ;;
  *) echo "Unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
esac

ARCHIVE="$ROOT/vendor/scrcpy/scrcpy-macos-${ARCH}-v${SCRCPY_VERSION}.tar.gz"
if [[ ! -f "$ARCHIVE" ]]; then
  echo "Vendored scrcpy archive not found: $ARCHIVE" >&2
  if [[ "$ARCH" == "aarch64" ]]; then
    echo "Only the x86_64 archive is currently in this repository. Add the official aarch64 v${SCRCPY_VERSION} archive before building on Apple Silicon." >&2
  fi
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/sgrgpy-bundle.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
RUNTIME="$WORK/runtime"
bash "$ROOT/scripts/fetch_scrcpy.sh" "$ARCH" "$RUNTIME"

swift build --package-path "$ROOT" --configuration release
BINARY="$ROOT/.build/release/$APP_NAME"
[[ -x "$BINARY" ]] || { echo "Swift build did not produce $BINARY" >&2; exit 1; }

STAGE="$WORK/$APP_NAME.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources/runtime"
install -m 755 "$BINARY" "$STAGE/Contents/MacOS/$APP_NAME"
# Preserve official runtime data and all license/notice files in the release archive.
ditto "$RUNTIME" "$STAGE/Contents/Resources/runtime"
chmod +x "$STAGE/Contents/Resources/runtime/scrcpy" "$STAGE/Contents/Resources/runtime/adb"

cat > "$STAGE/Contents/Info.plist" <<PLIST
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

OUT="$ROOT/dist"
mkdir -p "$OUT"
APP="$OUT/$APP_NAME.app"
rm -rf "$APP"
ditto "$STAGE" "$APP"
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP"
else
  echo "Warning: app is unsigned. Set CODE_SIGN_IDENTITY to a valid Developer ID identity to sign it."
fi

echo "Built all-in-one app: $APP"
echo "Bundled local scrcpy v${SCRCPY_VERSION} runtime ($ARCH): scrcpy, adb, server and upstream resources."
