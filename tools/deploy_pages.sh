#!/usr/bin/env bash
# Publish a test build to GitHub Pages (branch gh-pages).
# Uses a debug export: it shows the screen-scale line in Settings and supports ?autoplay.
# The Yandex SDK is absent there, so ads are granted instantly and the leaderboard is offline.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
OUT=build/pages
rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-debug "Yandex Web" "$OUT/index.html" 2>&1 | grep -E "ERROR" || true
touch "$OUT/.nojekyll"
REMOTE=$(git remote get-url origin)
cd "$OUT"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C ../.. config user.name || echo deploy)" -c user.email="$(git -C ../.. config user.email || echo deploy@localhost)" \
  commit -q -m "Test build $(date -u +%Y-%m-%dT%H:%MZ)"
git push -q -f "$REMOTE" gh-pages
echo "pushed to gh-pages"
