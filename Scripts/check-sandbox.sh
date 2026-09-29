#!/usr/bin/env bash
# Builds the macOS Release app with ad-hoc signing and checks that the signature carries the
# App Sandbox entitlement the Mac App Store requires (DECISIONS D-061).
# Usage: Scripts/check-sandbox.sh   (macOS, Xcode 16+). Output: build/SandboxCheck.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project SkylineArchitect.xcodeproj -scheme SkylineArchitect \
  -configuration Release -destination "platform=macOS" -derivedDataPath build/SandboxCheck \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  build | grep -E "error:|\*\* BUILD" || true
APP="build/SandboxCheck/Build/Products/Release/SkylineArchitect.app"
[ -d "$APP" ] || { echo "Release app not built at $APP" >&2; exit 1; }
ENTITLEMENTS="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)"
echo "$ENTITLEMENTS"
if echo "$ENTITLEMENTS" | tr -d ' \t\n' | grep -q "<key>com.apple.security.app-sandbox</key><true/>"; then
  echo "App Sandbox: enabled"
else
  echo "App Sandbox entitlement missing from the signed app" >&2
  exit 1
fi
