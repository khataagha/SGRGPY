# SGRGPY

SGRGPY is a macOS-first desktop GUI for scrcpy. It keeps the upstream Android mirroring tool as the engine, but wraps it in a cleaner, more approachable native app shell that feels right at home on Monterey and newer Macs.

The project is intentionally designed around the workflow you asked for:
- native macOS window chrome and standard controls
- minimal neutral palette with one bright accent color
- mirrors and extended display modes
- sliders plus keyboard-editable values for resolution, bitrate, and FPS
- Android-style bottom navigation for Recent, Home, and Back
- preferences via `Command + ,`
- profile presets for common sessions
- configurable pull destination and recording output

## Tagline

`gui the f outta scrcpy`

## Features

- macOS 12+ support
- device mirror and extended display modes
- slider + text-entry controls for main parameters
- profile presets and persistent settings
- light/dark/system appearance support
- configurable pull destination for recordings
- audio, fullscreen, stay-awake, and touch toggle support
- clickable `.app` generation via the bundled build script

## Screenshots

![Main window](assets/screenshot-main.svg)

![Preferences](assets/screenshot-preferences.svg)

## Requirements

- macOS 12 Monterey or newer
- Xcode Command Line Tools
- scrcpy installed and visible on PATH, or set `SCRCPY_BIN`

Install `scrcpy`:

```bash
brew install --cask android-platform-tools
brew install scrcpy
```

If needed:

```bash
export SCRCPY_BIN=/opt/homebrew/bin/scrcpy
```

## Build

```bash
./build_app.sh
```

This generates:

```text
dist/SGRGPY.app
```

## Project structure

```text
.
├── Package.swift
├── README.md
├── build_app.sh
├── .gitignore
├── Sources/
│   └── SGRGPY/
│       └── main.swift
├── assets/
│   ├── icon.svg
│   ├── screenshot-main.svg
│   └── screenshot-preferences.svg
└── dist/
    └── SGRGPY.app
```

## Design notes

The interface takes inspiration from modern design systems like Tabler and the tabler-icons style, but the app remains intentionally minimal and neutral. The goal is to feel polished and native without becoming visually noisy.

## Notes

This app is a shell for the upstream `scrcpy` binary. It does not reimplement device mirroring logic, which keeps things aligned with the official project and preserves future compatibility.

## License

This project is intended as a macOS desktop front-end for `scrcpy` and is meant to complement the upstream tool rather than replace it.
