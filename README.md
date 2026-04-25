# Matrix Tetris

Matrix Tetris is a native macOS menu-bar Tetris dropdown. It opens as a compact floating panel with Matrix-style rendering, remappable controls, high score persistence, ghost pieces, subtle animations, and global shortcuts.

## Features

- Native Swift/AppKit menu-bar app.
- Dropdown panel that can open from a toggle shortcut, hold shortcut, menu-bar icon, mouse position, or configured screen position.
- Basic Tetris mechanics: 10x20 board, tetromino queue, gravity, rotation, hard drop, soft drop, line clears, scoring, levels, pause, restart, and game over.
- Ghost piece projection.
- Matrix visual style with code rain, green glitch outlines, subtle line-clear/hard-drop/spawn animations, and Matrix-styled buttons.
- Settings for gameplay controls, movement sensitivity, soft-drop speed, animation mode, global shortcuts, and dropdown location.
- Local high score and settings persistence via `UserDefaults`.

## Install

Download the app from the latest GitHub release:

[Matrix Tetris Releases](https://github.com/sickpancake/matrix-tetris/releases/latest)

1. Download `MatrixTetris-v0.2-macOS.zip`.
2. Unzip it.
3. Open `MatrixTetris.app`.
4. The menu-bar item appears as `MT`.

This app is ad-hoc signed, not notarized through the Mac App Store. If macOS blocks the first launch, right-click `MatrixTetris.app`, choose `Open`, then confirm. After that, it should open normally.

## Shortcuts

Default app shortcuts:

- `Opt+Shift+~`: open or close the dropdown.
- Hold `Opt+~`: show the dropdown only while held.

Default gameplay controls:

- Left / Right: move piece
- Up: rotate clockwise
- Z: rotate counterclockwise
- Down: soft drop
- Space: hard drop
- P: pause
- R: restart

Open `Settings` in the dropdown to remap controls, adjust movement sensitivity, adjust soft-drop speed, toggle animations, change app shortcuts, reset settings, or change the dropdown location.

## Build Locally

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools
- Swift compiler from the macOS toolchain

Build the app bundle:

```sh
./scripts/build_app.sh
```

The app bundle is created at:

```text
dist/MatrixTetris.app
```

Package a release zip:

```sh
./scripts/package_release.sh
```

The release zip is created at:

```text
release/MatrixTetris-v0.2-macOS.zip
```

Run locally from the repo:

```sh
./scripts/run_app.sh
```

## Tests

```sh
./scripts/test_core.sh
```

The repository includes a `Package.swift`, but this machine's installed Command Line Tools currently fail to compile SwiftPM manifests. The scripts use direct `swiftc` invocations plus a temporary VFS overlay that works around the duplicate `SwiftBridging` module map in the local CLT install.

## Dependencies

No third-party dependencies are required.

The app uses:

- Swift / Foundation
- AppKit
- Carbon global hotkeys
- Standard macOS command-line tools used by the scripts

## Troubleshooting

- If shortcuts do not work, open Settings from the `MT` menu-bar item and remap the toggle or hold shortcut.
- If the app does not launch after downloading, use right-click > Open because the app is not notarized.
- If a rebuilt app does not appear to change, run `./scripts/run_app.sh`; it restarts any existing `MatrixTetris` process before opening the new build.

## License

MIT. See `LICENSE`.
