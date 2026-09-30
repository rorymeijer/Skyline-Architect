#!/usr/bin/env bash
# Checks that the iOS build shows its Documents folder (the mods folder) in the Files app:
# the built Info.plist must carry UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace.
# Usage: Scripts/check-files-app.sh   (after Scripts/build-app.sh --ipad; macOS, Xcode 16+).
set -euo pipefail
cd "$(dirname "$0")/.."
PLIST="build/DerivedData/Build/Products/Debug-iphonesimulator/SkylineArchitect.app/Info.plist"
[ -f "$PLIST" ] || { echo "iOS app not built at $PLIST" >&2; exit 1; }
status=0
for key in UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace; do
  value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" 2>/dev/null || echo missing)"
  echo "$key = $value"
  [ "$value" = "true" ] || status=1
done
[ "$status" -eq 0 ] || echo "The Files app will not show the mods folder" >&2
exit "$status"
