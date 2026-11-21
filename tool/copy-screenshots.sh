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
  live_click 25_live_click
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
  marker_dialog 2c_marker_dialog
  live_marker 4c_live_marker
  live_controls 4b_live_controls
  annotations 17_annotations
  annotations_live 17b_annotations_live
  settings_midi 22_settings_midi
  live_midi 22b_live_midi
  editor_labels 23_editor_labels
  import_labels 23b_import_labels
  editor_ccli 24_editor_ccli
  sync_hint 26_sync_hint
  set_export 27_set_export
  set_import 27b_set_import
  set_import_result 27c_set_import_result
  set_pdf_exported 28_set_pdf_exported
  lilypond 29_lilypond
  shortcuts 30_shortcuts
)

for ((i = 0; i < ${#map[@]}; i += 2)); do
  name="${map[i]}" shot="${map[i + 1]}"
  cp "$SRC/en_$shot.png" "$DST/$name.png"
  cp "$SRC/de_$shot.png" "$DST/${name}_de.png"
done
echo "Copied ${#map[@]} screenshots to docs/screenshots"
