#!/usr/bin/env bash
# Capture a screenshot from the connected Android device.
#
#   scripts/screenshot.sh                # ./screenshot-20260612-134501.png
#   scripts/screenshot.sh out.png        # explicit filename
#   scripts/screenshot.sh shots/         # auto-named file inside a directory
set -euo pipefail

ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"

OUT="${1:-screenshot-$(date +%Y%m%d-%H%M%S).png}"
if [ -d "${OUT}" ]; then
    OUT="${OUT%/}/screenshot-$(date +%Y%m%d-%H%M%S).png"
fi

"${ADB}" exec-out screencap -p > "${OUT}"
echo "Saved ${OUT}"
