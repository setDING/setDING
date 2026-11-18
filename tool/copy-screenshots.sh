#!/usr/bin/env bash
# Copies the screenshots used by the README and the website from
# app/build/screenshots (make screenshots) to docs/screenshots.
# English files are rendered in the dark theme, *_de files in German and the
# light theme. The list below is the single source; docs/screenshots/README.md
# explains it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/app/build/screenshots"
DST="$ROOT/docs/screenshots"

# <file in docs/screenshots without .png> <rendered name without language and .png>
map=(
  live 7_diagrams
  set 2_set
  sets 1_sets
  song 3_song
  songs 3_songs
  sequence 10_set_sequence
  editor 9_editor
  drums 11_live_drums
  organization 12_organization
  invite 13_invite
  band 14_band
  settings 15_settings
  settings_musician 16_settings_musician
  settings_general 18_settings_general
  settings_live 19_settings_live
  settings_song_display 20_settings_song_display
  song_display_editor 21_song_display_editor
  set_menu 2b_set_menu
  live_controls 4b_live_controls
  annotations 17_annotations
  annotations_live 17b_annotations_live
)

for ((i = 0; i < ${#map[@]}; i += 2)); do
  name="${map[i]}" shot="${map[i + 1]}"
  cp "$SRC/en_$shot.png" "$DST/$name.png"
  cp "$SRC/de_$shot.png" "$DST/${name}_de.png"
done
echo "Copied ${#map[@]} screenshots to docs/screenshots"
