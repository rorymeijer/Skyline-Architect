#!/usr/bin/env bash
# Launches the Debug iOS build in an iPad or iPhone simulator in screenshot-capture mode and
# copies the captures out of the app's container.
# Usage: Scripts/capture-simulator.sh ipad|iphone|ipad-13|iphone-69 <output-dir> [tour|store]
# ipad-13 and iphone-69 are the App Store's screenshot sizes (13" iPad Pro, 6.9" iPhone Pro Max).
# (build first: Scripts/build-app.sh --ipad; one build runs on both). macOS with Xcode only.
set -euo pipefail
cd "$(dirname "$0")/.."
KIND="${1:-ipad}"
OUT="${2:-ci-output/screenshots-$KIND}"
SET="${3:-tour}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
APP="build/DerivedData/Build/Products/Debug-iphonesimulator/SkylineArchitect.app"
BUNDLE="app.skylinearchitect.SkylineArchitect"
[ -d "$APP" ] || { echo "iOS app not built at $APP — run Scripts/build-app.sh --ipad first" >&2; exit 1; }

# iPad: an 11-inch iPad Pro or an iPad Air. iPhone: a standard-size iPhone (not Plus/Max/mini),
# the smallest common landscape height.
DEVICE=$(xcrun simctl list devices available -j | KIND="$KIND" python3 -c '
import json, os, sys
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds]
kind = os.environ["KIND"]
def number(name):
    digits = "".join(c if c.isdigit() else " " for c in name).split()
    return -int(digits[0]) if digits else 0
if kind == "iphone-69":
    pick = sorted([d for d in devices if d["name"].startswith("iPhone") and "Pro Max" in d["name"]], key=lambda d: number(d["name"]))
elif kind == "ipad-13":
    pick = [d for d in devices if d["name"].startswith("iPad Pro") and ("13-inch" in d["name"] or "12.9-inch" in d["name"])]
    pick.sort(key=lambda d: (0 if "13-inch" in d["name"] else 1, d["name"]))
elif kind == "iphone":
    phones = [d for d in devices if d["name"].startswith("iPhone")]
    phones.sort(key=lambda d: (any(w in d["name"] for w in ("Plus", "Max", "mini", "SE", "Air")), "Pro" in d["name"], d["name"]))
    pick = phones
else:
    ipads = [d for d in devices if d["name"].startswith("iPad")]
    ipads.sort(key=lambda d: (0 if "Pro 11" in d["name"] else 1 if "Air" in d["name"] else 2, d["name"]))
    pick = ipads
print(pick[0]["udid"] if pick else "")')
[ -n "$DEVICE" ] || { echo "no $KIND simulator available" >&2; xcrun simctl list devices available; exit 1; }
echo "$KIND simulator: $(xcrun simctl list devices | grep "$DEVICE")"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
DATA=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)
DIR="$DATA/Documents/captures"
rm -rf "$DIR"
xcrun simctl launch --terminate-running-process "$DEVICE" "$BUNDLE" --capture-screenshots "$DIR" --capture-set "$SET"

# The app exits after writing capture-report.json.
STATUS=1
for _ in $(seq 1 210); do
  if [ -f "$DIR/capture-report.json" ]; then STATUS=0; break; fi
  sleep 2
done
[ "$STATUS" = 0 ] || echo "$KIND capture timed out" >&2
cp -R "$DIR"/. "$OUT"/ 2>/dev/null || true
xcrun simctl shutdown "$DEVICE" || true
ls -la "$OUT"
[ -f "$OUT/capture-report.json" ] && cat "$OUT/capture-report.json"
exit "$STATUS"
