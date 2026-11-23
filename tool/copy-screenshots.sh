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
  drums_phone 11b_live_drums_phone
  live_click 25_live_click
  organization 12_organization
  invite_hint 13a_invite_hint
  invite 13_invite
  invite_band_hint 14a_invite_band_hint
  band 14_band
  settings 15_settings
  settings_musician 16_settings_musician
  settings_voice_hint 16a_settings_voice_hint
  settings_chorus_once 17b_settings_chorus_once
  settings_bass 49_settings_bass
  bass_diagrams 50_bass_diagrams
  settings_general 18_settings_general
  settings_live 19_settings_live
  settings_song_display 20_settings_song_display
  song_display_editor 21_song_display_editor
  set_menu 2b_set_menu
  sets_tools 2c_sets_tools
  new_set_import 2d_new_set_import
  song_picker 2e_song_picker
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
  editor_headings 24d_editor_headings
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
  song_details_key 47_song_details_key
  editor_invalid_key 48_editor_invalid_key
  import_keys 47b_import_keys
  adjustment_offer 42_adjustment_offer
  live_stacked_choruses 4f_live_stacked_choruses
  song_phone_menu 42c_song_phone_menu
  set_language_version 41_set_language_version
  language_versions 40_language_versions
  language_version_picker 40b_language_version_picker
  songs_languages 39_songs_languages
  songs_language_filter 39a_songs_language_filter
  song_language 39b_song_language
  songs_tags 42_songs_tags
  songs_played 42b_songs_played
  no_band 43_no_band
  band_switcher 43b_band_switcher
  settings_auto_backup 43_settings_auto_backup
  overview 44_overview
  overview_readiness 44c_overview_readiness
  page_turner_offer 44d_page_turner_offer
  settings_page_turner 19b_settings_page_turner
  settings_space_beat 19c_settings_space_beat
  songs_trash 45_songs_trash
  songs_trash_menu 45b_songs_trash_menu
  backup_replace_choice 44_backup_replace_choice
  backup_replace 44b_backup_replace
  hide_local_library 45_hide_local_library
  chord_view_chords 46_chord_view_chords
  chord_view_nashville 46_chord_view_nashville
  chord_view_numerals 46_chord_view_numerals
  chord_view_menu 46b_chord_view_menu
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
