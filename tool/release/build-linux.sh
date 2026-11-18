#!/usr/bin/env bash
# Builds the Linux release inside the release container (make release-linux,
# ADR-0019), with tool/release mounted at /release. Expects the committed sources
# as a tar archive on stdin and writes the packed bundle to /out/<name>.tar.gz and
# the same bundle as an AppImage to /out/<name>.AppImage (ADR-0038).
# BUILD_NUMBER (optional, set by CI) overrides the build number of pubspec.yaml.
#
#   git archive HEAD | docker run -i ... build-linux.sh <name>
set -euo pipefail

name="${1:?usage: build-linux.sh <name>}"
src=/tmp/setding

mkdir -p "$src"
tar -C "$src" -xf -

cd "$src/app"
flutter config --no-analytics >/dev/null
flutter pub get
build_args=()
if [ -n "${BUILD_NUMBER:-}" ]; then
  build_args+=(--build-number "$BUILD_NUMBER")
fi
flutter build linux --release "${build_args[@]}"

bundle="$src/app/build/linux/x64/release/bundle"
/release/check-isa.sh "$bundle"

staging="$(mktemp -d)"
cp -a "$bundle" "$staging/$name"
tar -C "$staging" -czf "/out/$name.tar.gz" "$name"
chown "${HOST_UID:-0}:${HOST_GID:-0}" "/out/$name.tar.gz"

# AppImage (ADR-0038): the same bundle with a start script, the desktop entry
# and the icon at the top, as appimagetool expects. The app updates this one
# file itself, so it carries no update information for other tools.
appdir="$staging/AppDir"
cp -a "$bundle" "$appdir"
cat >"$appdir/AppRun" <<'APPRUN'
#!/bin/sh
exec "$(dirname "$(readlink -f "$0")")/setding" "$@"
APPRUN
chmod +x "$appdir/AppRun"
sed 's|^Exec=.*|Exec=setding|' "$src/app/linux/packaging/app.setding.desktop.in" \
  >"$appdir/app.setding.desktop"
cp "$bundle/data/app_icon.png" "$appdir/app.setding.png"
ln -s app.setding.png "$appdir/.DirIcon"
mkdir -p "$appdir/licenses"
cp /opt/appimage/runtime-LICENSE "$appdir/licenses/appimage-runtime.txt"
ARCH=x86_64 /opt/appimage/appimagetool/AppRun --no-appstream \
  --runtime-file /opt/appimage/runtime-x86_64 "$appdir" "/out/$name.AppImage"
chown "${HOST_UID:-0}:${HOST_GID:-0}" "/out/$name.AppImage"
