#!/usr/bin/env bash
# Launches the Debug iPad build in an iPad simulator in screenshot-capture mode and copies
# the captures out of the app's container. Usage: Scripts/capture-ipad.sh <output-dir>
# (build first: Scripts/build-app.sh --ipad). macOS with Xcode only.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-ci-output/screenshots-ipad}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
APP="build/DerivedData/Build/Products/Debug-iphonesimulator/SkylineArchitect.app"
BUNDLE="app.skylinearchitect.SkylineArchitect"
[ -d "$APP" ] || { echo "iPad app not built at $APP — run Scripts/build-app.sh --ipad first" >&2; exit 1; }

# The first available iPad, preferring an 11-inch iPad Pro or an iPad Air.
DEVICE=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds]
ipads = [d for d in devices if d["name"].startswith("iPad")]
ipads.sort(key=lambda d: (0 if "Pro 11" in d["name"] else 1 if "Air" in d["name"] else 2, d["name"]))
print(ipads[0]["udid"] if ipads else "")')
[ -n "$DEVICE" ] || { echo "no iPad simulator available" >&2; xcrun simctl list devices available; exit 1; }
echo "iPad simulator: $(xcrun simctl list devices | grep "$DEVICE")"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
DATA=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)
DIR="$DATA/Documents/captures"
rm -rf "$DIR"
xcrun simctl launch --terminate-running-process "$DEVICE" "$BUNDLE" --capture-screenshots "$DIR"

# The app exits after writing capture-report.json.
STATUS=1
for _ in $(seq 1 210); do
  if [ -f "$DIR/capture-report.json" ]; then STATUS=0; break; fi
  sleep 2
done
[ "$STATUS" = 0 ] || echo "iPad capture timed out" >&2
cp -R "$DIR"/. "$OUT"/ 2>/dev/null || true
xcrun simctl shutdown "$DEVICE" || true
ls -la "$OUT"
[ -f "$OUT/capture-report.json" ] && cat "$OUT/capture-report.json"
exit "$STATUS"
