# Matrix Tetris

Matrix Tetris is a native macOS menu-bar Tetris dropdown. It opens as a compact floating panel with Matrix-style rendering, remappable controls, saved-game resume, high score and stats persistence, ghost pieces, sound effects, subtle animations, and global shortcuts.

Made with Codex.

## Features

- Native Swift/AppKit menu-bar app.
- Dropdown panel that can open from a toggle shortcut, hold shortcut, menu-bar icon, mouse position, or configured screen position.
- Basic Tetris mechanics: 10x20 board, tetromino queue, gravity, rotation, hard drop, soft drop, line clears, scoring, levels, pause, restart, and game over.
- Ghost piece projection.
- Matrix visual style with code rain, green glitch outlines, subtle line-clear/hard-drop/soft-drop/spawn animations, and Matrix-styled buttons.
- Original sound effects with Matrix Minimal and Arcade Punchy themes.
- Settings for gameplay controls, movement sensitivity, soft-drop speed, optional speed scaling, sound, ghost opacity, per-animation intensity, animation mode, global shortcuts, and dropdown location.
- Pieces spawn above the visible grid and fall through a Matrix-styled spawn lane.
- Automatic resume for unfinished games.
- First-run setup, About/version UI, in-app changelog, GitHub update link, and Matrix-styled game-over flow.
- Click-out auto-hide that saves and suspends the current session without breaking shortcuts.
- Local high score, stats, settings, saved game, and app-meta persistence via `UserDefaults`.

## Install

Download the app from the latest GitHub release:

[Matrix Tetris Releases](https://github.com/sickpancake/matrix-tetris/releases/latest)

Supported download target: Apple Silicon Macs running macOS 13 or newer.

1. Download `MatrixTetris-v1.2.0-macOS.zip`.
2. Unzip it.
3. Drag `MatrixTetris.app` to Applications if you want it installed there.
4. Open `MatrixTetris.app`.
5. The menu-bar item appears as `MT`.

This app is ad-hoc signed, not notarized through the Mac App Store. If macOS blocks the first launch, right-click `MatrixTetris.app`, choose `Open`, then confirm. After that, it should open normally.

## Update

Download the newest zip from the release page, quit Matrix Tetris, then replace the old `MatrixTetris.app` with the new one. Your settings, stats, high score, and unfinished saved game are stored locally with `UserDefaults`, so replacing the app bundle does not delete them.

Inside the app, open `About` and choose `Check Updates` to jump to the latest GitHub release.

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

Open `Settings` in the dropdown to remap controls, adjust movement sensitivity, adjust soft-drop speed, toggle optional speed scaling, choose sound theme/volume, tune ghost opacity, adjust each animation effect, toggle animations, change app shortcuts, reset the saved game, reset settings, or change the dropdown location.

## Build Locally

Requirements:

- Apple Silicon Mac running macOS 13 or newer
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
release/MatrixTetris-v1.2.0-macOS.zip
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
- AVFoundation for local sound playback
- Carbon global hotkeys
- Standard macOS command-line tools used by the scripts

## Troubleshooting

- If shortcuts do not work, open Settings from the `MT` menu-bar item and remap the toggle or hold shortcut.
- If the app does not launch after downloading, use right-click > Open because the app is not notarized.
- If a rebuilt app does not appear to change, run `./scripts/run_app.sh`; it restarts any existing `MatrixTetris` process before opening the new build.
- If the dropdown disappears after clicking outside it, that is expected; use the menu-bar item or shortcut to reopen it.

## License

MIT. See `LICENSE`.
