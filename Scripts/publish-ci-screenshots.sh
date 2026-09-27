#!/usr/bin/env bash
# CI only: copies the latest captures as compressed JPEGs (+ report) into
# Development/Screenshots/_ci-latest/ and commits them to the pushed branch with
# [skip ci]. Lets restricted development sessions inspect real in-game screenshots via git.
set -euo pipefail
SRC="${1:-ci-output/screenshots}"
DEST="Development/Screenshots/_ci-latest"
[ -d "$SRC" ] || { echo "no screenshots"; exit 0; }
rm -rf "$DEST"
mkdir -p "$DEST"
for f in "$SRC"/*.png; do
  sips -s format jpeg -s formatOptions 80 "$f" --out "$DEST/$(basename "$f" .png).jpg" >/dev/null
done
cp "$SRC"/capture-report.json "$DEST/" 2>/dev/null || true
cat > "$DEST/README.md" <<README
# Latest CI captures (automatic)

Real in-game screenshots from the Debug build's screenshot director, captured by CI run
${GITHUB_RUN_ID:-local} for commit ${GITHUB_SHA:-unknown}. JPEG-compressed copies of the PNG
artifact. Overwritten on every CI run of a development branch; curated per-phase
screenshots live in \`Development/Screenshots/Phase-XX/\`.
README
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "$DEST"
if git diff --cached --quiet; then echo "screenshots unchanged"; exit 0; fi
git commit -q -m "chore(ci): latest in-game screenshots [skip ci]"
git push origin "HEAD:${GITHUB_REF_NAME}" || echo "branch moved on; skipping screenshot commit"
