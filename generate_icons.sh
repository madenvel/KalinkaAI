#!/usr/bin/env bash
set -euo pipefail

SVG="$(dirname "$0")/kalinka_icon.svg"
R="rsvg-convert"

BG="#080808"

# Render SVG at exact size onto opaque background (legacy icons, iOS, macOS, web).
render() {
  local size=$1 out=$2
  local tmp; tmp="$(mktemp --suffix=.png)"
  $R -w "$size" -h "$size" "$SVG" -o "$tmp"
  mkdir -p "$(dirname "$out")"
  magick -size "${size}x${size}" "xc:${BG}" "$tmp" -gravity Center -composite "$out"
  rm -f "$tmp"
  echo "  $size×$size → $out"
}

# Render SVG transparent — for adaptive foreground layer.
# Icon is scaled to the inner safe zone (72/108 = 2/3 of canvas); outer ring
# stays transparent so the system background colour fills it and the artwork
# is never clipped by the launcher mask shape.
render_fg() {
  local canvas=$1 out=$2
  local safe=$(( canvas * 2 / 3 ))
  local tmp; tmp="$(mktemp --suffix=.png)"
  $R -w "$safe" -h "$safe" "$SVG" -o "$tmp"
  mkdir -p "$(dirname "$out")"
  magick -size "${canvas}x${canvas}" xc:none "$tmp" -gravity Center -composite "$out"
  rm -f "$tmp"
  echo "  ${safe}×${safe} (safe zone) in ${canvas}×${canvas} canvas → $out"
}

echo "=== Android ==="
# Legacy icons (API < 26 fallback)
render 48  android/app/src/main/res/mipmap-mdpi/ic_launcher.png
render 72  android/app/src/main/res/mipmap-hdpi/ic_launcher.png
render 96  android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
render 144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
render 192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
# Adaptive foreground (108dp × density; background = #080808 via values/ic_launcher_background.xml)
render_fg 108 android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png
render_fg 162 android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png
render_fg 216 android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png
render_fg 324 android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png
render_fg 432 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png

echo "=== iOS ==="
render 1024 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
render 20   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
render 40   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
render 60   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
render 29   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
render 58   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
render 87   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
render 40   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
render 80   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
render 120  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
render 120  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
render 180  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
render 76   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
render 152  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
render 167  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png

echo "=== macOS ==="
render 16   macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
render 32   macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
render 64   macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
render 128  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
render 256  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
render 512  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
render 1024 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png

echo "=== Web ==="
render 32  web/favicon.png
render 192 web/icons/Icon-192.png
render 512 web/icons/Icon-512.png
render 192 web/icons/Icon-maskable-192.png
render 512 web/icons/Icon-maskable-512.png

echo "=== Windows ICO ==="
WINTMP=$(mktemp -d)
trap 'rm -rf "$WINTMP"' EXIT
for size in 16 32 48 64 128 256; do
  render "$size" "$WINTMP/win_${size}.png"
done
magick "$WINTMP/win_16.png" "$WINTMP/win_32.png" "$WINTMP/win_48.png" \
       "$WINTMP/win_64.png" "$WINTMP/win_128.png" "$WINTMP/win_256.png" \
       windows/runner/resources/app_icon.ico
echo "  → windows/runner/resources/app_icon.ico"

echo "=== Linux ==="
render 512 linux/kalinka.png

echo ""
echo "Done."
