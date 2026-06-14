#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT_DIR="$REPO_ROOT/native/qt-qml"
BUILD_DIR="$PROJECT_DIR/build/macos-arm64"
RELEASE_DIR="$REPO_ROOT/release-native"
QT_ROOT="${QT_ROOT:-/Users/kele/Qt/aqt/6.12.0/macos}"
APP_PATH="$BUILD_DIR/FloatingCountdown.app"
ZIP_PATH="$RELEASE_DIR/FloatingCountdown-darwin-arm64-qt.zip"

if [[ ! -f "$QT_ROOT/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
  echo "Qt6Config.cmake not found under: $QT_ROOT" >&2
  exit 1
fi

if [[ ! -x "$QT_ROOT/bin/macdeployqt" ]]; then
  echo "macdeployqt not found under: $QT_ROOT/bin" >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$QT_ROOT" \
  -DQt6_DIR="$QT_ROOT/lib/cmake/Qt6" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

cmake --build "$BUILD_DIR" --config Release

if [[ ! -d "$APP_PATH" ]]; then
  echo "FloatingCountdown.app not found in $BUILD_DIR" >&2
  exit 1
fi

"$QT_ROOT/bin/macdeployqt" "$APP_PATH" -qmldir="$PROJECT_DIR/qml" -verbose=1

# The app does not use Qt SQL. macdeployqt may copy SQL drivers that reference
# optional local database libraries, which makes dependency checks noisy and can
# break launches on clean machines.
rm -rf "$APP_PATH/Contents/PlugIns/sqldrivers"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

SIZE_MB=$(python3 - <<PY
from pathlib import Path
p = Path('$ZIP_PATH')
print(round(p.stat().st_size / 1024 / 1024, 2))
PY
)
echo "Created $ZIP_PATH (${SIZE_MB} MB)"
