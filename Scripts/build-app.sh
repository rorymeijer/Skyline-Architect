#!/usr/bin/env bash
# Builds the app with xcodebuild. Usage: Scripts/build-app.sh [--ipad] [--release]
# Output: build/DerivedData. Requires Xcode 16+.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=Debug
DEST="platform=macOS"
for arg in "$@"; do
  case "$arg" in
    --ipad) DEST="generic/platform=iOS Simulator" ;;
    --release) CONFIG=Release ;;
  esac
done
xcodebuild -project SkylineArchitect.xcodeproj -scheme SkylineArchitect \
  -configuration "$CONFIG" -destination "$DEST" -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
