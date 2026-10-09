#!/usr/bin/env bash
# Build the Yandex Games upload: build/bizarre-gems-yandex.zip (index.html at the zip root).
set -euo pipefail
cd "$(dirname "$0")"
GODOT=${GODOT:-godot}
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/test_logic.gd
"$GODOT" --headless --path . --export-release "Yandex Web" build/web/index.html
rm -f build/bizarre-gems-yandex.zip
(cd build/web && zip -qr9 ../bizarre-gems-yandex.zip .)
ls -lh build/bizarre-gems-yandex.zip
