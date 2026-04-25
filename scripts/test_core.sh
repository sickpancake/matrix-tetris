#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/tests"
SDK="$(xcrun --show-sdk-path)"
OVERLAY="$BUILD/swift-vfs-overlay.yaml"
EMPTY_MODULEMAP="$BUILD/empty-swift-bridging.modulemap"
RUNNER="$BUILD/TestRunner.swift"

mkdir -p "$BUILD"
: > "$EMPTY_MODULEMAP"
cat > "$OVERLAY" <<EOF
{"version":0,"case-sensitive":"false","roots":[{"type":"file","name":"/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap","external-contents":"$EMPTY_MODULEMAP"}]}
EOF

cat > "$RUNNER" <<'EOF'
@main
struct TestRunner {
    static func main() throws {
        try CoreLogicTests.runAll()
        print("Core logic tests passed")
    }
}
EOF

swiftc \
  -vfsoverlay "$OVERLAY" \
  -sdk "$SDK" \
  -parse-as-library \
  -emit-library \
  -emit-module \
  -module-name MatrixTetrisCore \
  "$ROOT/Sources/MatrixTetrisCore/GameTypes.swift" \
  "$ROOT/Sources/MatrixTetrisCore/SeededGenerator.swift" \
  "$ROOT/Sources/MatrixTetrisCore/GameEngine.swift" \
  "$ROOT/Sources/MatrixTetrisCore/SettingsStore.swift" \
  -emit-module-path "$BUILD/MatrixTetrisCore.swiftmodule" \
  -Xlinker -install_name \
  -Xlinker @rpath/libMatrixTetrisCore.dylib \
  -o "$BUILD/libMatrixTetrisCore.dylib"

swiftc \
  -vfsoverlay "$OVERLAY" \
  -sdk "$SDK" \
  -I "$BUILD" \
  -L "$BUILD" \
  -lMatrixTetrisCore \
  -Xlinker -rpath \
  -Xlinker "$BUILD" \
  "$ROOT/Tests/MatrixTetrisCoreTests/CoreLogicTests.swift" \
  "$RUNNER" \
  -o "$BUILD/CoreLogicTests"

"$BUILD/CoreLogicTests"

