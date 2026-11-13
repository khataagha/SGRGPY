#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$ROOT_DIR/dist"
APP_NAME="SGRGPY"

mkdir -p "$OUT_DIR"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is required but not found in PATH. Install Xcode Command Line Tools first."
  exit 1
fi

swift build --package-path "$ROOT_DIR" --configuration release

APP_BUNDLE="$OUT_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

BINARY_PATH="$ROOT_DIR/.build/release/SGRGPY"
if [ ! -f "$BINARY_PATH" ]; then
  echo "Expected binary not found at $BINARY_PATH"
  exit 1
fi

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/SGRGPY"
chmod +x "$APP_BUNDLE/Contents/MacOS/SGRGPY"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>SGRGPY</string>
  <key>CFBundleIdentifier</key>
  <string>com.khataagha.SGRGPY</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>SGRGPY</string>
  <key>CFBundleDisplayName</key>
  <string>SGRGPY</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026</string>
</dict>
</plist>
EOF

if [ -f "$ROOT_DIR/assets/icon.svg" ]; then
  cp "$ROOT_DIR/assets/icon.svg" "$APP_BUNDLE/Contents/Resources/icon.svg"
fi

echo "Built app bundle at $APP_BUNDLE"
