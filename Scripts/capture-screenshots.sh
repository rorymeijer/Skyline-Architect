#!/usr/bin/env bash
# Launches the Debug macOS build in screenshot-capture mode and waits for it to exit.
# Usage: Scripts/capture-screenshots.sh <output-dir>   (build first: Scripts/build-app.sh)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-ci-output/screenshots}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
APP="build/DerivedData/Build/Products/Debug/SkylineArchitect.app"
if [ ! -x "$APP/Contents/MacOS/SkylineArchitect" ]; then
  echo "App not built at $APP — run Scripts/build-app.sh first" >&2
  exit 1
fi
"$APP/Contents/MacOS/SkylineArchitect" --capture-screenshots "$OUT" &
PID=$!
( sleep 420; kill "$PID" 2>/dev/null && echo "capture timed out" >&2 ) &
WATCHDOG=$!
STATUS=0
wait "$PID" || STATUS=$?
kill "$WATCHDOG" 2>/dev/null || true
ls -la "$OUT"
[ -f "$OUT/capture-report.json" ] && cat "$OUT/capture-report.json"
exit "$STATUS"
