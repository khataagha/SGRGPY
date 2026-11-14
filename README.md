# SGRGPY

**gui the f outta scrcpy** — an all-in-one macOS app for Android mirroring and control.

The repository contains SGRGPY's SwiftUI app and the official scrcpy macOS release archive used by the Intel build. The offline packaging script verifies the local archive and includes its scrcpy client, ADB, matching scrcpy server, runtime resources, and upstream notices in the generated app bundle. The archive is checked into `vendor/scrcpy/`; no build-time download or external mirror is required.

## Features

- Native SwiftUI interface for macOS 12 Monterey and newer.
- Device discovery and selection using bundled ADB.
- Starts/stops the bundled scrcpy client with resolution, video bitrate, frame-rate, audio, touch, stay-awake, recording, and extended-display controls.
- Recent / Home / Back commands through bundled ADB.
- Light, Dark, and System appearance settings; Preferences via **⌘,**.
- Named presets and recording destination preferences persist locally.

The scrcpy video renderer opens in its own native window. Embedding the live stream inside the SGRGPY dashboard is not implemented.

## Requirements

- macOS 12+ with Swift / Xcode Command Line Tools installed.
- The checked-in x86_64 runtime archive supports Intel Macs, including the mid-2015 MacBook Pro.
- Apple Silicon packaging requires adding the matching official aarch64 archive and its verified checksum; the build fails clearly if it is absent.
- Android device with Developer Options and USB debugging enabled. Accept the authorization prompt on the device.

## Build (offline)

```sh
xcode-select --install
bash ./build_app.sh
open dist/SGRGPY.app
```

The script verifies the locally vendored archive against the official SHA-256, extracts the runtime, compiles the Swift app, and assembles `dist/SGRGPY.app`. It does not download scrcpy, ADB, or other third-party runtime files. SwiftPM has no external package dependencies.

Vendored archive:

```text
vendor/scrcpy/scrcpy-macos-x86_64-v5.0.1.tar.gz
```

Official SHA-256:

```text
31a5467a9e907f162b093dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d
```

The bundle is unsigned unless `CODE_SIGN_IDENTITY` is set to a valid Developer ID Application certificate. Signing and notarization require the developer’s Apple credentials.

## Run

1. Connect the Android device and enable USB debugging.
2. Accept the computer authorization prompt.
3. Open SGRGPY and refresh devices.
4. Select a device, adjust settings, and start mirroring.
5. Use Android navigation controls; video appears in scrcpy's separate window.

Recordings are MKV files written to the selected destination. Changing launch options requires restarting the scrcpy session.

## Screenshots

The SVG files in `assets/` are illustrative mockups, not screenshots captured from a running build.

![Illustrative dashboard](assets/screenshot-main.svg)

![Illustrative preferences](assets/screenshot-preferences.svg)

## Layout

```text
.
├── Package.swift
├── Sources/SGRGPY/main.swift
├── assets/                 # SGRGPY artwork and illustrative UI mockups
├── vendor/scrcpy/          # Official release archive (Intel x86_64)
├── scripts/build_app.sh    # Offline app bundler
├── scripts/fetch_scrcpy.sh # Local archive verifier/extractor
└── build_app.sh            # Root build entry point
```

## Credits

- **scrcpy** — Genymobile and Romain Vimont. Official project, source, releases, and documentation: [github.com/Genymobile/scrcpy](https://github.com/Genymobile/scrcpy). This repository includes the official [scrcpy v5.0.1 macOS x86_64 release archive](https://github.com/Genymobile/scrcpy/releases/tag/v5.0.1); its release license and notices are preserved when packaged.
- **Android Debug Bridge (ADB) / Android SDK Platform-Tools** — Android Open Source Project / Google. [Platform-Tools documentation and downloads](https://developer.android.com/tools/releases/platform-tools).
- **Swift** — Apple Swift project: [swift.org](https://www.swift.org/).
- **SwiftUI and AppKit** — Apple developer frameworks: [SwiftUI](https://developer.apple.com/xcode/swiftui/) and [AppKit](https://developer.apple.com/documentation/appkit).
- **SF Symbols** — Apple system icon set used by the interface: [developer.apple.com/sf-symbols](https://developer.apple.com/sf-symbols/).
- **SGRGPY artwork and UI mockups** — created for this project; SVG mockups are illustrative and are not third-party screenshots.

## Licensing

SGRGPY source is Apache-2.0 licensed; see [LICENSE](LICENSE). The vendored scrcpy archive is a separate upstream distribution and retains its own license/notices in the generated app bundle. A copy of the upstream license is available at [Genymobile/scrcpy LICENSE](https://github.com/Genymobile/scrcpy/blob/master/LICENSE). Android SDK Platform-Tools are distributed under their applicable Android Open Source Project terms; see the [official Platform-Tools page](https://developer.android.com/tools/releases/platform-tools).