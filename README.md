# SGRGPY

**gui the f outta scrcpy** — a native macOS app that includes the upstream scrcpy runtime in its `.app` bundle.

## This is an all-in-one bundle

SGRGPY is not a GUI that requires Homebrew-installed scrcpy or ADB after packaging. The build downloads the **official, version-pinned Genymobile macOS release archive**, verifies its SHA-256, and copies the full distribution into `SGRGPY.app/Contents/Resources/scrcpy-runtime/`. The bundle includes the matching `scrcpy`, `adb`, `scrcpy-server`, support files, and upstream license. Runtime binaries are generated into the app at build time and are not committed to this source repository.

The main SGRGPY window controls the bundled runtime; scrcpy currently renders its live video in scrcpy’s own native video window. The preview panel in SGRGPY is a device/status panel, not an embedded video surface. Embedding the video renderer directly into the SGRGPY window is a separate integration task and is not claimed here.

## Features

- Native SwiftUI app for macOS 12 Monterey and newer, with standard macOS window chrome.
- Bundled official scrcpy and ADB runtime; no Homebrew install required for the packaged app.
- Device discovery and selection, including multiple authorized Android devices.
- Resolution, bitrate, and FPS sliders with editable numeric fields.
- Start/stop, audio, touches, stay-awake, recording and mirror/extended-display options.
- Recent / Home / Back controls sent to the selected device through bundled ADB.
- System / Light / Dark appearance and named reusable presets.
- Preferences shortcut: **⌘,**.
- Settings stored in `~/Library/Application Support/SGRGPY/settings.json`.

## Build the app on macOS

Requirements: macOS, Swift 5.9+ (Xcode Command Line Tools), `curl`, `tar`, and `shasum`. Internet access is needed to fetch the official scrcpy archive during packaging.

```sh
./build_app.sh
open dist/SGRGPY-x86_64.app  # Intel Macs, including the 2015 MacBook Pro
# or: open dist/SGRGPY-aarch64.app  # Apple Silicon
```

The script selects the current machine's architecture automatically. To explicitly select an architecture:

```sh
SCRCPY_ARCH=x86_64 ./build_app.sh
SCRCPY_ARCH=aarch64 ./build_app.sh
```

The generated `.app` is architecture-specific, unsigned by default, and not notarized. To sign locally with a Developer ID identity:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build_app.sh
```

A signed release should also be notarized before distribution. The build script checks the pinned upstream archive hash before extraction; do not replace that check with an unverified download.

## Upstream dependency and licensing

- scrcpy release and source: [Genymobile/scrcpy](https://github.com/Genymobile/scrcpy)
- Pinned version: [v5.0.1](https://github.com/Genymobile/scrcpy/releases/tag/v5.0.1)
- Intel archive: `scrcpy-macos-x86_64-v5.0.1.tar.gz`
- Apple Silicon archive: `scrcpy-macos-aarch64-v5.0.1.tar.gz`
- The build script verifies the official SHA-256 sums documented by upstream.
- The upstream archive's license and supporting resources are included in the app's runtime directory.
- SGRGPY is independent and is not affiliated with Genymobile or the scrcpy maintainers. See `LICENSE` for this repository's license and the bundled upstream license for scrcpy terms.

## Troubleshooting

- **No devices:** enable Android developer options and USB debugging, connect the device, accept its authorization dialog, then refresh devices.
- **App opens but cannot start scrcpy:** rebuild the bundle; check that `Contents/Resources/scrcpy-runtime/` contains executable `scrcpy`, executable `adb`, and `scrcpy-server`.
- **Recording fails:** choose an existing writable destination folder in Preferences. The destination is for recordings, not `adb pull`.
- **Gatekeeper warning:** unsigned builds are intended for local use. Sign and notarize builds for distribution.

## Screenshots

The SVG assets are illustrative design mockups, not captured screenshots from a running build.

![Illustrative main window](assets/screenshot-main.svg)

![Illustrative preferences](assets/screenshot-preferences.svg)

## Repository contents

```text
.
├── Package.swift
├── Sources/SGRGPY/main.swift
├── scripts/build_app.sh
├── build_app.sh
├── assets/
├── LICENSE
└── NOTICE
```
