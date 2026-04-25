#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.1.0"
APP_PATH="$ROOT/dist/MatrixTetris.app"
RELEASE_DIR="$ROOT/release"
ZIP_PATH="$RELEASE_DIR/MatrixTetris-v${VERSION}-macOS.zip"

APP_BUILT="$("$ROOT/scripts/build_app.sh")"
if [[ "$APP_BUILT" != "$APP_PATH" ]]; then
  echo "Unexpected app path: $APP_BUILT" >&2
  exit 1
fi

plutil -lint "$APP_PATH/Contents/Info.plist"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_PATH"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_PATH"
  codesign --verify --deep --verbose=2 "$APP_PATH"
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
(
  cd "$ROOT/dist"
  zip -qry "$ZIP_PATH" MatrixTetris.app -x "*.DS_Store" "*/.DS_Store"
)

echo "$ZIP_PATH"
