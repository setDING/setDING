#!/usr/bin/env bash
# Generates every logo image from the SVG sources in app/branding/
# (docs/development/branding.md): the PNGs of the native splash screens
# (Android, iOS, via flutter_native_splash), the web splash images, the
# favicon, the web app icons and the README logo. The results are checked in, so only run
# this after changing the logo.
#
# Needs rsvg-convert (librsvg) and ImageMagick (magick).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
SRC="$APP/branding"
OUT="$SRC/generated"
WEB="$APP/web"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
for tool in rsvg-convert magick; do
  command -v "$tool" >/dev/null || { echo "branding: $tool is missing" >&2; exit 1; }
done

mkdir -p "$OUT" "$WEB/splash" "$WEB/icons"
svg() { rsvg-convert "$@"; }

# Native splash. flutter_native_splash treats the images as 4x:
# mark 128 dp, wordmark 200 dp wide (as SplashScreen in logo.dart).
svg -w 512 -h 512 "$SRC/mark.svg" -o "$OUT/splash-mark.png"
# Android 12+: 288 dp icon, of which the inner 192 dp circle is visible.
magick -size 1152x1152 xc:none "$OUT/splash-mark.png" -gravity center \
  -composite "$OUT/splash-mark-android12.png"
svg -w 800 "$SRC/wordmark.svg" -o "$OUT/splash-wordmark.png"
svg -w 800 "$SRC/wordmark-dark.svg" -o "$OUT/splash-wordmark-dark.png"

# Logo with wordmark for the README.
python3 "$ROOT/tool/branding_lockup.py" "$SRC"

# Web splash (web/index.html) and icons.
cp "$SRC/mark.svg" "$SRC/wordmark.svg" "$SRC/wordmark-dark.svg" "$WEB/splash/"
svg -w 32 -h 32 "$SRC/mark.svg" -o "$WEB/favicon.png"
for size in 192 512; do
  svg -w "$size" -h "$size" "$SRC/mark.svg" -o "$WEB/icons/Icon-$size.png"
  # Maskable: the mark inside the 80 % safe zone on the splash color.
  inner=$((size * 62 / 100))
  svg -w "$inner" -h "$inner" "$SRC/mark.svg" -o "$OUT/mask-$size.png"
  magick -size "${size}x${size}" xc:'#FFFFFF' "$OUT/mask-$size.png" \
    -gravity center -composite "$WEB/icons/Icon-maskable-$size.png"
  rm "$OUT/mask-$size.png"
done

cd "$APP"
dart run flutter_native_splash:create
echo "branding: images generated"
