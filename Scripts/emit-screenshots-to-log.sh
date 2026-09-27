#!/usr/bin/env bash
# Prints each screenshot as a base64 JPEG between markers so the images can be recovered
# from the CI job log when artifact storage is unreachable (e.g. restricted cloud sessions).
# Decode with: Scripts/decode-screenshots-from-log.py <log> <out-dir>
set -euo pipefail
DIR="${1:-ci-output/screenshots}"
TMP="$(mktemp -d)"
for f in "$DIR"/*.png; do
  name="$(basename "$f" .png)"
  sips -s format jpeg -s formatOptions 72 "$f" --out "$TMP/$name.jpg" >/dev/null
  echo "=====BEGIN-SCREENSHOT $name.jpg====="
  base64 -i "$TMP/$name.jpg" | fold -w 16000
  echo "=====END-SCREENSHOT $name.jpg====="
done
[ -f "$DIR/capture-report.json" ] && { echo "=====BEGIN-REPORT====="; cat "$DIR/capture-report.json"; echo; echo "=====END-REPORT====="; }
rm -rf "$TMP"
