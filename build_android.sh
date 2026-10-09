#!/usr/bin/env bash
# Debug APK for testing on a phone: build/android/bizarre-gems-debug.apk
# Installs it right away when a phone with USB debugging is connected.
set -euo pipefail
cd "$(dirname "$0")"
GODOT=${GODOT:-godot}
ADB=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
mkdir -p build/android
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/test_logic.gd
"$GODOT" --headless --path . --export-debug "Android" build/android/bizarre-gems-debug.apk 2>&1 | grep -E "ERROR" || true
ls -lh build/android/bizarre-gems-debug.apk
if "$ADB" get-state >/dev/null 2>&1; then
  "$ADB" install -r build/android/bizarre-gems-debug.apk
  "$ADB" shell monkey -p com.electrocrem.bizarregems -c android.intent.category.LAUNCHER 1 >/dev/null
  echo "installed and launched"
else
  echo "no phone connected: copy the APK to the phone or connect it with USB debugging on"
fi
