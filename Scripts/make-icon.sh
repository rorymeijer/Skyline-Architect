#!/usr/bin/env bash
# Regenerates the app icon from the game's own drawing code (IconArt, Phase 20).
# Needs a Swift toolchain and rsvg-convert (apt-get install librsvg2-bin / brew install librsvg).
# Usage: Scripts/make-icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=App/Assets.xcassets/AppIcon.appiconset
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
(cd Packages/SkylineKit && swift build -c release --product skyline-snapshot >/dev/null)
SNAP=Packages/SkylineKit/.build/release/skyline-snapshot
"$SNAP" --icon "$TMP/mac.svg" --size 1024 >/dev/null
"$SNAP" --icon "$TMP/ios.svg" --size 1024 --flat >/dev/null
mkdir -p "$OUT"
for px in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$px" -h "$px" "$TMP/mac.svg" -o "$OUT/mac-$px.png"
done
rsvg-convert -w 1024 -h 1024 -b '#14213D' "$TMP/ios.svg" -o "$OUT/ios-1024.png"
echo "icon written to $OUT"
