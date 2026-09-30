#!/usr/bin/env bash
# CI only: copies the latest captures as compressed JPEGs (+ report) into
# Development/Screenshots/_ci-latest/ and commits them to the pushed branch with
# [skip ci]. Lets restricted development sessions inspect real in-game screenshots via git.
set -euo pipefail
SRC="${1:-ci-output/screenshots}"
IPAD="${2:-ci-output/screenshots-ipad}"
IPHONE="${3:-ci-output/screenshots-iphone}"
DEST="Development/Screenshots/_ci-latest"
[ -d "$SRC" ] || { echo "no screenshots"; exit 0; }
rm -rf "$DEST"
mkdir -p "$DEST"
for f in "$SRC"/*.png; do
  sips -s format jpeg -s formatOptions 80 "$f" --out "$DEST/$(basename "$f" .png).jpg" >/dev/null
done
cp "$SRC"/capture-report.json "$DEST/" 2>/dev/null || true
for pair in "ipad:$IPAD" "iphone:$IPHONE"; do
  name="${pair%%:*}"; dir="${pair#*:}"
  if [ -d "$dir" ] && ls "$dir"/*.png >/dev/null 2>&1; then
    mkdir -p "$DEST/$name"
    for f in "$dir"/*.png; do
      sips -s format jpeg -s formatOptions 80 "$f" --out "$DEST/$name/$(basename "$f" .png).jpg" >/dev/null
    done
    cp "$dir"/capture-report.json "$DEST/$name/" 2>/dev/null || true
  fi
done
cat > "$DEST/README.md" <<README
# Latest CI captures (automatic)

Real in-game screenshots from the Debug build's screenshot director, captured by CI run
${GITHUB_RUN_ID:-local} for commit ${GITHUB_SHA:-unknown}. JPEG-compressed copies of the PNG
artifact; \`ipad/\` and \`iphone/\` hold the simulators' captures. Overwritten on every CI run of a development branch; curated per-phase
screenshots live in \`Development/Screenshots/Phase-XX/\`.
README
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "$DEST"
if git diff --cached --quiet; then echo "screenshots unchanged"; exit 0; fi
git commit -q -m "chore(ci): latest in-game screenshots [skip ci]"
# The App Store screenshot workflow, or an earlier run finishing late, may have pushed
# meanwhile: rebase onto it. Those commits only touch bot-owned captures, so on a conflict
# this run's captures win (-X theirs is the commit being replayed), and a failed attempt is
# aborted before the next one.
for _ in 1 2 3; do
  if git pull -q --rebase -X theirs origin "${GITHUB_REF_NAME}" && git push -q origin "HEAD:${GITHUB_REF_NAME}"; then exit 0; fi
  git rebase --abort 2>/dev/null || true
  sleep 5
done
echo "branch moved on; skipping screenshot commit"
