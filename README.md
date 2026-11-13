# SGRGPY

**gui the f outta scrcpy** — an all-in-one macOS desktop app for Android mirroring and control.

SGRGPY is a native SwiftUI application packaged with the matching official scrcpy macOS runtime. The generated `.app` includes the SGRGPY UI, upstream `scrcpy`, `adb`, the matching scrcpy server, and the upstream release resources/notices. The exact upstream archive is downloaded at packaging time and SHA-256 verified before use; third-party binaries are not committed into this source repository.

## What the app does

- Native macOS window with standard traffic-light controls.
- Detects and selects authorized Android devices through bundled ADB.
- Launches bundled scrcpy with adjustable resolution, video bitrate, frame rate, audio, touch display, stay-awake, recording, and extended-display settings.
- Recent / Home / Back buttons send Android key events using the bundled ADB.
- System, Light, and Dark appearance options; preferences via **⌘,**.
- Named presets persist alongside settings in `~/Library/Application Support/SGRGPY/settings.json`.
- Recording destination can be chosen in Preferences.

The control window is not the video renderer: scrcpy opens its own native video window. Embedding the actual video stream into SGRGPY is not implemented.

## Requirements

- macOS 12 Monterey or newer.
- Swift 5.9+ / Xcode Command Line Tools.
- Network access during packaging to fetch the official scrcpy release archive.

No separate Homebrew installation of scrcpy or ADB is required by the generated bundle. Android device setup still requires Developer Options and USB debugging enabled, and you must accept the computer authorization prompt on the phone.

## Build the all-in-one app

On the Mac you intend to run the app on, from the repository root:

```sh
xcode-select --install
bash ./build_app.sh
open dist/SGRGPY.app
```

The script selects the host architecture (`x86_64` for the mid-2015 Intel MacBook Pro, `arm64` for Apple Silicon), downloads official scrcpy v5.0.1, verifies the published SHA-256, compiles SGRGPY, and assembles `dist/SGRGPY.app/Contents/Resources/runtime/` with the official scrcpy client, ADB, server, and release resources.

To package a later upstream release, set `SCRCPY_VERSION` only after updating the corresponding official archive checksums in `build_app.sh`:

```sh
SCRCPY_VERSION=v5.0.1 bash ./build_app.sh
```

The bundle is unsigned by default for local development. For distribution, set `CODE_SIGN_IDENTITY` to a valid Developer ID Application certificate name before building. Notarization and stapling require Apple signing credentials and are not automated here.

## Controls and use

1. Connect the Android phone by USB and enable USB debugging.
2. Accept the debugging authorization prompt on the phone.
3. Launch SGRGPY and click **Refresh devices**.
4. Select the device, adjust stream settings, then click **Start mirroring**.
5. The scrcpy video window opens separately. Use the dashboard’s Recent, Home, and Back buttons as needed.
6. Stop the session from SGRGPY before changing launch-time stream parameters.

A recording is written as an MKV file in the selected destination. The destination setting applies to recordings, not to `adb pull`.

## Screenshots

The SVG assets are design mockups, not runtime screenshots from a built release.

![Illustrative SGRGPY dashboard](assets/screenshot-main.svg)

![Illustrative preferences](assets/screenshot-preferences.svg)

## Troubleshooting

- **No devices:** enable USB debugging, authorize the host on the phone, check the USB cable, then refresh.
- **App reports incomplete bundled runtime:** rebuild with `bash ./build_app.sh`; packaging checks for the official client, ADB, and server.
- **Recording fails:** choose an existing writable directory in Preferences.
- **Gatekeeper warning:** local builds are unsigned. Sign/notarize for distribution or use the normal local macOS override for software you built and trust.

## Repository structure

```text
.
├── Package.swift
├── Sources/SGRGPY/main.swift
├── assets/                 # App icon and illustrative mockups
├── build_app.sh            # Fetches, verifies, and bundles upstream runtime
├── LICENSE                 # SGRGPY source license
├── NOTICE
└── README.md
```

## Third-party components and licenses

SGRGPY is independent and is not affiliated with Genymobile or the scrcpy maintainers. The packaging script fetches the official macOS release from [Genymobile/scrcpy](https://github.com/Genymobile/scrcpy/releases) and verifies the pinned release checksum. The official archive's runtime files and license/notices are included in the app bundle. scrcpy is Apache-2.0 licensed; see the upstream [LICENSE](https://github.com/Genymobile/scrcpy/blob/master/LICENSE). Android Debug Bridge is part of Android SDK Platform Tools; consult the [Android Platform Tools license and terms](https://developer.android.com/tools/releases/platform-tools). Do not remove upstream notices when redistributing.

SGRGPY source is licensed under Apache License 2.0; see [LICENSE](LICENSE).