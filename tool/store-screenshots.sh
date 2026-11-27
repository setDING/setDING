#!/usr/bin/env bash
# Composes the screenshots of the store listings (docs/store/README.md):
# Google Play (phone, tablet; ADR-0067) and the App Store (iPhone, iPad,
# Mac). Each screen rendered by app/test_screenshots/store_screenshots_test.dart
# is put into a drawn device frame on the brand blue, under a two-line
# headline from docs/store/captions/<locale>.txt ("regular|bold", one line per
# screen). The tablet screens are also composed without the headline for the
# cards of the website's landing page (docs/screenshots/why_<n>[_de].png).
# The screens alternate between the light and the dark theme; the first and
# the last are split diagonally into both. Run by tool/copy-screenshots.sh
# after `make screenshots`.
#
# Needs ImageMagick (magick).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/app/build/screenshots"
STORE="$ROOT/docs/store"
FONTS="$ROOT/app/assets/fonts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ImageMagick without date chunks, so unchanged images stay byte-identical.
magick() { command magick "${@:1:$#-1}" -define png:exclude-chunks=date,time "${@: -1}"; }
# Integer arithmetic for the layout values.
calc() { python3 -c "print(round($1))"; }

# The screens in the order of the listing and the theme each one shows.
screens=(1_live 2_set 3_editor 4_style 5_overview 6_songs 7_drums 8_server)
themes=(split light dark light dark light dark split)

# compose <device> <output file below docs/, with {locale} for the locale,
#         {de} for "_de" in German and {n} for the screen's number> <canvas w>
#         <canvas h> <screen w> <bezel> <radius> <top> <font size, 0 for no
#         headline>
# The screen runs off the bottom edge below the headline.
compose() {
  local device=$1 file=$2 W=$3 H=$4 SW=$5 BEZEL=$6 R=$7 TOP=$8 FS=$9
  command magick -size "${W}x${H}" -define gradient:angle=160 \
    gradient:'#3D7BFF-#1A2F8F' "$TMP/bg.png"
  for pair in de-DE:de en-US:en; do
    local locale=${pair%%:*} lang=${pair#*:}
    local suffix=_de i=0 regular bold
    [ "$lang" = de ] || suffix=
    local pattern=${file//\{locale\}/$locale}
    pattern=${pattern//\{de\}/$suffix}
    while IFS='|' read -r regular bold; do
      local name=${screens[i]} theme=${themes[i]}
      i=$((i + 1))
      local light="$SRC/${lang}_light_store_${device}_$name.png"
      local dark="$SRC/${lang}_dark_store_${device}_$name.png"
      [ -e "$light" ] && [ -e "$dark" ] || continue
      local out="$ROOT/docs/${pattern//\{n\}/$i}"
      mkdir -p "$(dirname "$out")"
      local sh
      sh=$(command magick identify -format '%h' "$light")
      sh=$(calc "$sh * $SW / $(command magick identify -format '%w' "$light")")
      command magick "$light" -resize "${SW}x${sh}!" "$TMP/light.png"
      command magick "$dark" -resize "${SW}x${sh}!" "$TMP/dark.png"
      case $theme in
        light) cp "$TMP/light.png" "$TMP/screen.png" ;;
        dark) cp "$TMP/dark.png" "$TMP/screen.png" ;;
        split)
          # Light above, dark below a diagonal from the top right to the
          # bottom left, marked by a line in the bell's brass.
          command magick "$TMP/light.png" \
            \( "$TMP/dark.png" \( -size "${SW}x${sh}" xc:black -fill white \
              -draw "polygon $SW,0 $SW,$sh 0,$sh" \) \
              -alpha off -compose CopyOpacity -composite \) \
            -compose over -composite \
            -stroke '#FFD34D' -strokewidth "$(calc "$SW / 160")" \
            -draw "line $SW,0 0,$sh" "$TMP/screen.png"
          ;;
      esac
      # Rounded corners for the screen.
      command magick -size "${SW}x${sh}" xc:none -fill white \
        -draw "roundrectangle 0,0 $((SW - 1)),$((sh - 1)) $((R - BEZEL)),$((R - BEZEL))" \
        "$TMP/mask.png"
      command magick "$TMP/screen.png" "$TMP/mask.png" -alpha off \
        -compose CopyOpacity -composite "$TMP/screen.png"
      # The device: a dark body around the screen, with a soft shadow.
      local pw=$((SW + 2 * BEZEL)) ph=$((sh + 2 * BEZEL))
      command magick -size "${pw}x${ph}" xc:none -fill '#121417' \
        -draw "roundrectangle 0,0 $((pw - 1)),$((ph - 1)) $R,$R" \
        "$TMP/screen.png" -geometry +"$BEZEL"+"$BEZEL" -composite "$TMP/device.png"
      command magick "$TMP/device.png" \
        \( +clone -background '#0A1440' -shadow 60x30+0+24 \) \
        +swap -background none -layers merge +repage "$TMP/device.png"
      # The headline: a regular and a bold line, the bold one in brass.
      # Without one (the website), 8 bits per channel keep the files small.
      local headline=(-depth 8)
      [ "$FS" = 0 ] || headline=(
        -font "$FONTS/NotoSans-Regular.ttf" -pointsize "$FS" -fill white
        -annotate +0+"$(calc "$FS * 1.4")" "$regular"
        -font "$FONTS/NotoSans-Bold.ttf" -pointsize "$(calc "$FS * 1.15")"
        -fill '#FFD34D' -annotate +0+"$(calc "$FS * 2.7")" "$bold")
      magick "$TMP/bg.png" \
        "$TMP/device.png" -gravity north -geometry +0+"$((TOP - 30))" -composite \
        "${headline[@]}" -crop "${W}x${H}+0+0" +repage -alpha off "$out"
      count=$((count + 1))
    done < "$STORE/captions/$locale.txt"
  done
}

count=0
# Google Play: phone 1080×1920 (9:16) and tablet 2560×1600 (16:10), the
# tablet images used for 7" and 10" tablets.
compose phone "store/play/{locale}/images/phoneScreenshots/{n}.png" 1080 1920 820 24 68 470 84
compose tablet "store/play/{locale}/images/tenInchScreenshots/{n}.png" 2560 1600 1900 40 90 460 120
# App Store: iPhone 6.9" 1320×2868, iPad 13" 2752×2064 (landscape) and
# Mac 2880×1800.
compose iphone "store/app-store/{locale}/images/iphone/{n}.png" 1320 2868 1000 30 90 600 100
compose ipad "store/app-store/{locale}/images/ipad/{n}.png" 2752 2064 2040 44 100 540 130
compose mac "store/app-store/{locale}/images/mac/{n}.png" 2880 1800 2000 44 60 560 120
# The website's landing page: the tablet screens without the headline, in the
# cards of "Why setDING?" (website/src/content/docs/index.mdx).
compose tablet "screenshots/why_{n}{de}.png" 1120 700 900 20 44 70 0
echo "Composed $count store and website screenshots in docs/store and docs/screenshots"
