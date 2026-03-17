#!/usr/bin/env bash
set -euo pipefail

SVG="$(dirname "$0")/kalinka_branding.svg"
R="rsvg-convert"

render() {
  local size=$1 out=$2
  mkdir -p "$(dirname "$out")"
  $R -w "$size" -h "$size" "$SVG" -o "$out"
  echo "  $size×$size → $out"
}

echo "=== Android ==="
# Legacy icons (API < 26 fallback)
render 48  android/app/src/main/res/mipmap-mdpi/ic_launcher.png
render 72  android/app/src/main/res/mipmap-hdpi/ic_launcher.png
render 96  android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
render 144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
render 192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
# Adaptive foreground (108dp × density; artwork confined to inner 72dp safe zone via ic_launcher_foreground.svg)
# background = #C2394B via values/ic_launcher_background.xml
FG_SVG="$(dirname "$0")/ic_launcher_foreground.svg"
$R -w 108 -h 108 "$FG_SVG" -o android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png
$R -w 162 -h 162 "$FG_SVG" -o android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png
$R -w 216 -h 216 "$FG_SVG" -o android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png
$R -w 324 -h 324 "$FG_SVG" -o android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png
$R -w 432 -h 432 "$FG_SVG" -o android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png

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
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
for size in 16 32 48 64 128 256; do
  render "$size" "$TMPDIR/win_${size}.png"
done
magick "$TMPDIR/win_16.png" "$TMPDIR/win_32.png" "$TMPDIR/win_48.png" \
       "$TMPDIR/win_64.png" "$TMPDIR/win_128.png" "$TMPDIR/win_256.png" \
       windows/runner/resources/app_icon.ico
echo "  → windows/runner/resources/app_icon.ico"

echo "=== Linux ==="
render 512 linux/kalinka.png

echo ""
echo "Done."
