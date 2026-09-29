#!/usr/bin/env bash
# CI only (store-screenshots.yml): copies the App Store captures as high-quality JPEGs, at
# their exact pixel size, into Development/Screenshots/AppStore/ and commits them with
# [skip ci]. The PNG originals are the workflow's artifact.
set -euo pipefail
SRC="${1:-ci-output}"
DEST="Development/Screenshots/AppStore"
rm -rf "$DEST"
for pair in "mac:$SRC/store-mac" "iphone-6.9:$SRC/store-iphone" "ipad-13:$SRC/store-ipad"; do
  name="${pair%%:*}"; dir="${pair#*:}"
  ls "$dir"/*.png >/dev/null 2>&1 || { echo "no $name captures"; continue; }
  mkdir -p "$DEST/$name"
  for f in "$dir"/*.png; do
    sips -s format jpeg -s formatOptions 92 "$f" --out "$DEST/$name/$(basename "$f" .png).jpg" >/dev/null
  done
  cp "$dir"/capture-report.json "$DEST/$name/" 2>/dev/null || true
  echo "$name: $(sips -g pixelWidth -g pixelHeight "$DEST/$name"/01-*.jpg | awk '/pixel/ {printf "%s ", $2}')"
done
cat > "$DEST/README.md" <<README
# App Store screenshots (automatic)

Real captures from the Debug build's screenshot director (\`--capture-set store\`), taken by
the *App Store screenshots* workflow, run ${GITHUB_RUN_ID:-local}, for commit ${GITHUB_SHA:-unknown}.
The Demo Plaza is built by the developer blueprint and leased by the developer tool; the
weather is set to clear by the script. Everything else is the game as it runs.

| Folder | App Store slot | Size (landscape) |
|--------|----------------|------------------|
| \`mac/\` | Mac | 1440 × 900 |
| \`iphone-6.9/\` | iPhone 6.9" | 2868 × 1320 (iPhone 16 Pro Max simulator) |
| \`ipad-13/\` | iPad 13" | 2752 × 2064 (iPad Pro 13-inch simulator) |

JPEG quality 92 at the exact pixel size; the PNG originals are the workflow run's artifact.
Each folder's \`capture-report.json\` gives the true pixel size of every file.
README
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "$DEST"
if git diff --cached --quiet; then echo "screenshots unchanged"; exit 0; fi
git commit -q -m "chore(store): App Store screenshots [skip ci]"
# The CI workflow may have pushed its own captures meanwhile: rebase onto them first.
for _ in 1 2 3; do
  git pull -q --rebase origin "${GITHUB_REF_NAME}" && git push -q origin "HEAD:${GITHUB_REF_NAME}" && exit 0
  sleep 5
done
echo "could not push the screenshots; they are in the artifact"
