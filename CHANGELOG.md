# Changelog

## v1.2.0

- Added original Matrix Minimal and Arcade Punchy sound themes.
- Added sound settings for mute, master volume, theme selection, and test playback.
- Added gameplay and UI sound cues for movement, rotation, drops, line clears, special chained Tetris clears, game over, buttons, and dropdown open/close.
- Fixed piece spawning so new pieces start above the visible 10x20 grid and fall through a Matrix-styled spawn lane.
- Updated release packaging and app bundle version to `1.2.0` / build `120`.

## v1.1.0

- Fixed dropdown reopening after clicking outside by auto-hiding and preserving global shortcuts.
- Added soft-drop trails, landing feedback, and movement pulse animations.
- Added optional speed scaling, defaulting off for steadier falling speed.
- Added per-animation intensity sliders, ghost opacity, reset saved game, duplicate-control warnings, and clearer settings labels.
- Refreshed the menu-bar icon, About/install wording, release packaging, and app bundle version to `1.1.0` / build `110`.

## v1.0.0

- Added automatic saved-game resume for unfinished games.
- Added visible version information, About, first-run setup, and in-app What's New.
- Added local stats for games played, best score, best lines, total lines, line-clear events, total play time, and last played.
- Improved game-over and restart flow with a Matrix-styled result panel.
- Added a GitHub Releases update button and clearer install/update packaging.
- Updated app bundle version to `1.0.0` / build `100`.

## v0.2

- Improved gameplay timing with a 60 Hz loop, catch-up gravity, and more responsive held-key repeat.
- Added a separate soft-drop speed setting for the down key.
- Added subtle Matrix-style animations for line clears, hard drops, and new piece spawns.
- Restyled app buttons to match the Matrix visual theme.
- Changed default app shortcuts to `Opt+Shift+~` for toggle and `Opt+~` for hold-to-open.
- Preserved existing high score, gameplay bindings, dropdown location, and custom shortcuts where possible.

## v0.1

- Initial Matrix Tetris dropdown app.
- Added basic Tetris mechanics, ghost pieces, high score persistence, settings, remappable controls, global toggle shortcut, hold-to-open shortcut, dropdown positions, and Matrix-style rendering.
