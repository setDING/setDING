#!/bin/sh
# Adds RealChord to the application menu of the desktop (for the current user)
# and installs its icon. Under Wayland the window only shows the RealChord
# icon with this entry: the compositor looks the icon up through the .desktop
# file named after the app ID (app.realchord).
#
# Usage: ./install-desktop-entry.sh [--hidden] [--if-missing] [--uninstall]
#   --hidden      only for the icon lookup, not listed in the menu (test builds)
#   --if-missing  do nothing if an entry is already installed
#   --uninstall   remove the entry and the icon
set -eu

id=app.realchord
dir=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
entry="$data/applications/$id.desktop"
icons="$data/icons/hicolor"

hidden=false
if_missing=false
uninstall=false
for arg in "$@"; do
  case "$arg" in
    --hidden) hidden=true ;;
    --if-missing) if_missing=true ;;
    --uninstall) uninstall=true ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

refresh() {
  # Let the desktop pick up the change (each tool is optional).
  command -v update-desktop-database >/dev/null 2>&1 &&
    update-desktop-database -q "$data/applications" 2>/dev/null || true
  for tool in kbuildsycoca6 kbuildsycoca5; do
    if command -v "$tool" >/dev/null 2>&1; then
      "$tool" >/dev/null 2>&1 || true
      break
    fi
  done
}

if $uninstall; then
  rm -f "$entry" "$icons/256x256/apps/$id.png" "$icons/scalable/apps/$id.svg"
  refresh
  echo "RealChord removed from the application menu."
  exit 0
fi

if $if_missing && [ -f "$entry" ]; then
  exit 0
fi

mkdir -p "$data/applications" "$icons/256x256/apps" "$icons/scalable/apps"
cp "$dir/data/app_icon.png" "$icons/256x256/apps/$id.png"
cp "$dir/data/app_icon.svg" "$icons/scalable/apps/$id.svg"
sed "s|@EXEC@|$dir/realchord|" "$dir/$id.desktop.in" > "$entry.tmp"
if $hidden; then
  echo "NoDisplay=true" >> "$entry.tmp"
fi
mv "$entry.tmp" "$entry"
refresh
echo "RealChord installed: $entry"
