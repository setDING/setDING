#!/usr/bin/env bash
# Composes the phone and tablet screenshots of the Google Play listing
# (ADR-0067, docs/store/play/README.md): each screen rendered by
# app/test_screenshots/play_store_screenshots_test.dart is put into a drawn
# device frame on the brand blue, under a two-line headline from
# docs/store/play/<locale>/captions.txt ("regular|bold", one line per screen).
# The screens alternate between the light and the dark theme; the first and
# the last are split diagonally into both. Run by tool/copy-screenshots.sh
# after `make screenshots`.
#
# Needs ImageMagick (magick).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/app/build/screenshots"
PLAY="$ROOT/docs/store/play"
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

# compose <device> <output folder> <canvas w> <canvas h> <screen w> <bezel>
#         <radius> <top> <font size>
# The screen runs off the bottom edge below the headline.
compose() {
  local device=$1 folder=$2 W=$3 H=$4 SW=$5 BEZEL=$6 R=$7 TOP=$8 FS=$9
  command magick -size "${W}x${H}" -define gradient:angle=160 \
    gradient:'#3D7BFF-#1A2F8F' "$TMP/bg.png"
  for pair in de-DE:de en-US:en; do
    local locale=${pair%%:*} lang=${pair#*:}
    local out="$PLAY/$locale/images/$folder" i=0 regular bold
    while IFS='|' read -r regular bold; do
      local name=${screens[i]} theme=${themes[i]}
      i=$((i + 1))
      local light="$SRC/${lang}_light_play_${device}_$name.png"
      local dark="$SRC/${lang}_dark_play_${device}_$name.png"
      [ -e "$light" ] && [ -e "$dark" ] || continue
      mkdir -p "$out"
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
      magick "$TMP/bg.png" \
        "$TMP/device.png" -gravity north -geometry +0+"$((TOP - 30))" -composite \
        -font "$FONTS/NotoSans-Regular.ttf" -pointsize "$FS" -fill white \
        -annotate +0+"$(calc "$FS * 1.4")" "$regular" \
        -font "$FONTS/NotoSans-Bold.ttf" -pointsize "$(calc "$FS * 1.15")" \
        -fill '#FFD34D' -annotate +0+"$(calc "$FS * 2.7")" "$bold" \
        -crop "${W}x${H}+0+0" +repage -alpha off "$out/$i.png"
      count=$((count + 1))
    done < "$PLAY/$locale/captions.txt"
  done
}

count=0
# Phone 1080×1920 (9:16): the screen 820 px wide.
compose phone phoneScreenshots 1080 1920 820 24 68 470 84
# Tablet 2560×1600 (16:10), used for 7" and 10" tablets: the screen 1960 px.
compose tablet tenInchScreenshots 2560 1600 1900 40 90 460 120
echo "Composed $count store screenshots in docs/store/play"
