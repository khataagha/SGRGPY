# SGRGPY

**gui the f outta scrcpy** — a native macOS control panel for scrcpy, with device selection, quality controls, profiles, and quick Android navigation.

> **Architecture:** SGRGPY is a GUI front-end, not a fork or a reimplementation of scrcpy. It launches the separately installed upstream `scrcpy` and `adb` programs. The full upstream C/Java source tree is deliberately not copied into this repository: that code has its own build system, bundled Android server, dependencies, and release process. Installing scrcpy is currently required.

## Features

- Native SwiftUI app targeting macOS 12 Monterey and newer; standard macOS window chrome and traffic lights.
- Detects authorized Android devices using `adb devices -l`, with selection when multiple devices are connected.
- Starts and stops upstream scrcpy with Resolution, Bitrate, FPS, audio, touches, stay-awake, recording, and extended-display options.
- Android Recent / Home / Back buttons send the corresponding key events through ADB.
- Preferences with System / Light / Dark appearance, recording directory selection, and reusable presets.
- Preferences keyboard shortcut: **⌘,**.
- Settings persist under `~/Library/Application Support/SGRGPY/settings.json`.

The preview in the control window is an honest placeholder/status panel: the actual video stream is rendered in scrcpy's own native window. Embedding the video stream into SGRGPY is not implemented.

## Requirements

- macOS 12 or later.
- Xcode Command Line Tools with Swift 5.9 or later (`xcode-select --install`).
- Upstream `scrcpy` and Android Platform Tools (`adb`).
- Android device with Developer options and USB debugging enabled; authorize the Mac on the device.

Install dependencies with Homebrew:

```sh
brew install scrcpy android-platform-tools
```

The app checks common Apple Silicon, Intel Homebrew, MacPorts, and `PATH` locations. For a custom scrcpy executable, launch with `SCRCPY_BIN=/absolute/path/to/scrcpy` in the environment. macOS GUI apps do not reliably inherit interactive shell PATH settings, so the common package-manager paths are checked explicitly.

## Build and run

```sh
swift build -c release
```

To build a double-clickable app bundle:

```sh
bash ./build_app.sh
open dist/SGRGPY.app
```

The script compiles for the architecture of the Mac running it. It does not codesign, notarize, bundle third-party executables, or create a universal binary. For sharing the app outside your Mac, sign and notarize it and review the licensing/distribution requirements of the separately installed dependencies.

## Troubleshooting

- **ADB not found:** install `android-platform-tools`, then relaunch SGRGPY.
- **No device listed:** check the USB cable, enable USB debugging, accept the device authorization prompt, and use Refresh devices.
- **scrcpy not found:** install it with Homebrew or set `SCRCPY_BIN` before launching the app.
- **Recording fails:** choose an existing writable folder. Recordings are MKV files; the Preferences destination applies to recordings, not `adb pull`.
- **A setting does not apply to a running session:** stop and restart mirroring. scrcpy options are supplied when its process starts.

## Screenshots

The SVGs in `assets/` are illustrative UI mockups, not captured screenshots of a compiled app. This distinction is kept explicit so they are not mistaken for verified runtime output.

![Illustrative main-window mockup](assets/screenshot-main.svg)

![Illustrative preferences mockup](assets/screenshot-preferences.svg)

## Project layout

```text
.
├── Package.swift
├── Sources/SGRGPY/main.swift
├── assets/                 # App artwork and illustrative UI mockups
├── build_app.sh
└── README.md
```

## Credits and licensing

- SGRGPY is an independent GUI project and is not affiliated with Genymobile or the scrcpy maintainers.
- scrcpy is maintained by Genymobile / Romain Vimont. See the [official scrcpy repository](https://github.com/Genymobile/scrcpy) for source, releases, documentation, and license.
- Android Platform Tools are distributed by Google. See the [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools) page.
- SGRGPY's Swift source is currently provided under the Apache License 2.0; see [LICENSE](LICENSE).
