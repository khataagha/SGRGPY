# SGRGPY

**gui the f outta scrcpy** — an all-in-one macOS app for Android mirroring and control.

The repository vendors the official scrcpy macOS release archive used for the Intel build. Packaging is offline: no network downloads or mirrors are needed. The generated app includes the SGRGPY UI and the matching scrcpy client, ADB, server, and upstream release resources/notices.

## Features

- Native SwiftUI interface for macOS 12 Monterey and newer.
- Device discovery and selection using bundled ADB.
- Starts/stops the bundled scrcpy client with resolution, video bitrate, frame-rate, audio, touch, stay-awake, recording, and extended-display controls.
- Recent / Home / Back commands through the bundled ADB.
- Light, Dark, and System appearance settings; Preferences via **⌘,**.
- Named presets and recording destination preferences persist locally.

The scrcpy video renderer opens in its own native window. Embedding the live stream inside the SGRGPY dashboard is not implemented.

## Requirements

- macOS 12+ with Swift/Xcode Command Line Tools installed.
- The checked-in x86_64 runtime archive supports the Intel Mac build (including the mid-2015 MacBook Pro).
- Apple Silicon packaging requires adding the matching official aarch64 archive and its verified checksum; the build will fail clearly if it is absent.
- Android device with Developer Options and USB debugging enabled. Accept the authorization prompt on the device.

## Build (offline)

```sh
xcode-select --install
bash ./build_app.sh
open dist/SGRGPY.app
```

The packaging script verifies the local archive against the official SHA-256, extracts the runtime, compiles the Swift app, and assembles `dist/SGRGPY.app`. It does not download scrcpy, ADB, or the server during the build. For an Intel Mac, the vendored file is:

```text
vendor/scrcpy/scrcpy-macos-x86_64-v5.0.1.tar.gz
```

The corresponding SHA-256 is `31a5467a9e907f162b093dbcbab1276b15c6e709c2ea8159566a8d165beb50`. If an archive verification fails, do not bypass the check; compare it with the original official release checksum.

The bundle is unsigned unless `CODE_SIGN_IDENTITY` is set to a valid Developer ID Application certificate. Signing and notarization require the developer’s Apple credentials.

## Run

1. Connect the Android device and enable USB debugging.
2. Accept the computer authorization prompt.
3. Open SGRGPY and refresh devices.
4. Select a device, adjust settings, and start mirroring.
5. Use the Android navigation controls; video appears in scrcpy's separate window.

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
├── assets/                 # SGRGPY icon and illustrative mockups
├── vendor/scrcpy/          # Official release archive (Intel x86_64)
├── scripts/build_app.sh    # Offline app bundler
├── scripts/fetch_scrcpy.sh # Local archive verifier/extractor
└── build_app.sh            # Root build entry point
```

## Credits

- **scrcpy** — Genymobile and Romain Vimont; official source, releases, and documentation: [github.com/Genymobile/scrcpy](https://github.com/Genymobile/scrcpy). The bundled macOS runtime is the unmodified official v5.0.1 x86_64 release archive, verified by SHA-256. Its license and notices are retained in the app bundle.
- **Android Debug Bridge (ADB) / Android SDK Platform-Tools** — Android Open Source Project / Google: [developer.android.com/tools](https://developer.android.com/tools) and [Platform-Tools releases](https://developer.android.com/tools/releases/platform-tools). ADB is included from the official scrcpy macOS distribution; refer to upstream license notices.
- **Swift and SwiftUI** — Apple: [swift.org](https://www.swift.org/) and [developer.apple.com/xcode/swiftui](https://developer.apple.com/xcode/swiftui/).
- **SF Symbols** — Apple: [developer.apple.com/sf-symbols](https://developer.apple.com/sf-symbols/). The interface uses system-provided symbols.
- **SGRGPY visual mockups and app artwork** — created for this project; they are illustrative assets and are not third-party screenshots.

## Licensing

SGRGPY source is Apache-2.0 licensed; see [LICENSE](LICENSE). The vendored scrcpy archive is a separate upstream distribution and retains its own license/notices when extracted into the app. A copy of the scrcpy upstream license is available at [Genymobile/scrcpy/LICENSE](https://github.com/Genymobile/scrcpy/blob/master/LICENSE). Review the licenses/notices included with all bundled upstream components before redistributing the generated app.
