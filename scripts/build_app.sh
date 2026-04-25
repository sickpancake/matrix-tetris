#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/manual"
DIST="$ROOT/dist"
APP="$DIST/MatrixTetris.app"
SDK="$(xcrun --show-sdk-path)"
OVERLAY="$BUILD/swift-vfs-overlay.yaml"
EMPTY_MODULEMAP="$BUILD/empty-swift-bridging.modulemap"

mkdir -p "$BUILD" "$DIST"
: > "$EMPTY_MODULEMAP"
cat > "$OVERLAY" <<EOF
{"version":0,"case-sensitive":"false","roots":[{"type":"file","name":"/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap","external-contents":"$EMPTY_MODULEMAP"}]}
EOF

CORE_SOURCES=(
  "$ROOT/Sources/MatrixTetrisCore/GameTypes.swift"
  "$ROOT/Sources/MatrixTetrisCore/SeededGenerator.swift"
  "$ROOT/Sources/MatrixTetrisCore/GameEngine.swift"
  "$ROOT/Sources/MatrixTetrisCore/SettingsStore.swift"
)

APP_SOURCES=(
  "$ROOT/Sources/MatrixTetris/AppMain.swift"
  "$ROOT/Sources/MatrixTetris/AppDelegate.swift"
  "$ROOT/Sources/MatrixTetris/Shortcut+AppKit.swift"
  "$ROOT/Sources/MatrixTetris/HotKeyManager.swift"
  "$ROOT/Sources/MatrixTetris/DropdownController.swift"
  "$ROOT/Sources/MatrixTetris/MatrixButton.swift"
  "$ROOT/Sources/MatrixTetris/MatrixInfoPanel.swift"
  "$ROOT/Sources/MatrixTetris/MatrixRootView.swift"
  "$ROOT/Sources/MatrixTetris/TetrisBoardView.swift"
  "$ROOT/Sources/MatrixTetris/SettingsView.swift"
)

swiftc \
  -vfsoverlay "$OVERLAY" \
  -sdk "$SDK" \
  -Osize \
  -parse-as-library \
  -emit-library \
  -emit-module \
  -module-name MatrixTetrisCore \
  "${CORE_SOURCES[@]}" \
  -emit-module-path "$BUILD/MatrixTetrisCore.swiftmodule" \
  -Xlinker -install_name \
  -Xlinker @rpath/libMatrixTetrisCore.dylib \
  -o "$BUILD/libMatrixTetrisCore.dylib"

swiftc \
  -vfsoverlay "$OVERLAY" \
  -sdk "$SDK" \
  -Osize \
  -I "$BUILD" \
  -L "$BUILD" \
  -lMatrixTetrisCore \
  -framework AppKit \
  -framework Carbon \
  -Xlinker -rpath \
  -Xlinker @executable_path/../Frameworks \
  "${APP_SOURCES[@]}" \
  -o "$BUILD/MatrixTetris"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp "$BUILD/MatrixTetris" "$APP/Contents/MacOS/MatrixTetris"
cp "$BUILD/libMatrixTetrisCore.dylib" "$APP/Contents/Frameworks/libMatrixTetrisCore.dylib"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>MatrixTetris</string>
  <key>CFBundleIdentifier</key>
  <string>local.matrix-tetris.dropdown</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Matrix Tetris</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.1.0</string>
  <key>CFBundleVersion</key>
  <string>110</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

chmod +x "$APP/Contents/MacOS/MatrixTetris"
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1
fi
echo "$APP"
