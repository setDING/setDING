#!/usr/bin/env bash
# Copies the screenshots used by the README and the website from
# app/build/screenshots (make screenshots) to docs/screenshots.
# With --partial (make screenshots ONLY=…) it copies only the screenshots that
# were rendered and skips the others; without it every one must exist.
# English files are rendered in the dark theme, *_de files in German and the
# light theme. The list below is the single source; docs/screenshots/README.md
# explains it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/app/build/screenshots"
DST="$ROOT/docs/screenshots"
partial=0
[ "${1:-}" = --partial ] && partial=1

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
  songs_selected 3c_songs_selected
  editor_ccli 24_editor_ccli
  editor_songselect 24b_editor_songselect
  editor_ccli_footer 24c_editor_ccli_footer
  sync_hint 26_sync_hint
  set_export 27_set_export
  set_import 27b_set_import
  set_import_result 27c_set_import_result
  set_pdf_exported 28_set_pdf_exported
  lilypond 29_lilypond
  shortcuts 30_shortcuts
  editor_auto_close 31_editor_auto_close
  editor_chorus_labels 33_editor_chorus_labels
  editor_save 32_editor_save
  offline_status 34_offline_status
  account 35_account
  change_password 35b_change_password
  delete_account 36_delete_account
  song_export 37_song_export
  song_import 37b_song_import
  songs_conversions 38_songs_conversions
  adjustment_offer 42_adjustment_offer
  set_language_version 41_set_language_version
  language_versions 40_language_versions
  language_version_picker 40b_language_version_picker
  songs_languages 39_songs_languages
  songs_language_filter 39a_songs_language_filter
  song_language 39b_song_language
  songs_tags 42_songs_tags
  songs_played 42b_songs_played
)

copied=0
copy() {
  if [ "$partial" = 1 ] && [ ! -e "$SRC/$1.png" ]; then return; fi
  cp "$SRC/$1.png" "$DST/$2.png"
  copied=$((copied + 1))
}
for ((i = 0; i < ${#map[@]}; i += 2)); do
  name="${map[i]}" shot="${map[i + 1]}"
  copy "en_$shot" "$name"
  copy "de_$shot" "${name}_de"
done
if [ "$copied" = 0 ]; then
  echo "No screenshot of the list was rendered" >&2
  exit 1
fi
echo "Copied $copied screenshots to docs/screenshots"
