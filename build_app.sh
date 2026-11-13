#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="SGRGPY"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script packages a macOS application and must be run on macOS." >&2
  exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is required. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

swift build --package-path "$ROOT_DIR" --configuration release
BINARY="$ROOT_DIR/.build/release/$APP_NAME"
[[ -x "$BINARY" ]] || { echo "Swift build did not produce $BINARY" >&2; exit 1; }

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
install -m 755 "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
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

if [[ -f "$ROOT_DIR/assets/icon.icns" ]]; then
  cp "$ROOT_DIR/assets/icon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP_BUNDLE/Contents/Info.plist"
fi

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "Note: app is unsigned. Set CODE_SIGN_IDENTITY to sign it for distribution."
fi

echo "Built $APP_BUNDLE"
