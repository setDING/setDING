#!/usr/bin/env bash
# Builds the Linux release inside the release container (make release-linux,
# ADR-0019), with tool/release mounted at /release. Expects the committed sources
# as a tar archive on stdin and writes the packed bundle to /out/<name>.tar.gz and
# the same bundle as an AppImage to /out/<name>.AppImage (ADR-0038), each with
# its CycloneDX SBOM (<file>.cdx.json, ADR-0037).
# BUILD_NUMBER (optional, set by CI) overrides the build number of pubspec.yaml;
# COMMIT (optional) is recorded in the SBOMs.
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
# DART_DEFINES (optional, set by CI): extra build arguments, e.g. the staging
# server of a pre-release (ADR-0069).
if [ -n "${DART_DEFINES:-}" ]; then
  read -ra defines <<<"$DART_DEFINES"
  build_args+=("${defines[@]}")
fi
# The instruction sizes name the packages compiled into the app (SBOM).
sizes="$src/app/build/instruction-sizes.json"
flutter build linux --release "${build_args[@]}" \
  --extra-gen-snapshot-options=--print-instructions-sizes-to="$sizes"

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

# SBOMs (ADR-0037). The AppImage ships the bundle of the tar.gz plus the
# AppImage runtime at its start.
runtime_json="$staging/appimage-runtime.json"
cat >"$runtime_json" <<JSON
[
  {
    "type": "application",
    "bom-ref": "appimage/type2-runtime@${APPIMAGE_RUNTIME_VERSION}",
    "name": "type2-runtime",
    "version": "${APPIMAGE_RUNTIME_VERSION}",
    "description": "AppImage runtime at the start of the AppImage",
    "purl": "pkg:github/AppImage/type2-runtime@${APPIMAGE_RUNTIME_VERSION}",
    "hashes": [{"alg": "SHA-256", "content": "$(sha256sum /opt/appimage/runtime-x86_64 | cut -d' ' -f1)"}],
    "licenses": [{"license": {"id": "MIT"}}],
    "externalReferences": [{"type": "vcs", "url": "https://github.com/AppImage/type2-runtime"}],
    "components": [
      {
        "type": "library",
        "bom-ref": "appimage/type2-runtime/libfuse",
        "name": "libfuse",
        "description": "linked statically into the AppImage runtime",
        "licenses": [{"license": {"name": "GNU LGPL 2.1", "url": "https://github.com/libfuse/libfuse/blob/master/LGPL2.txt"}}]
      }
    ]
  }
]
JSON
version="$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' "$src/app/pubspec.yaml")"
sbom_args=(--platform linux-x64 --app "$src/app" --contents "/out/$name.tar.gz"
  --instruction-sizes "$sizes")
if [ -n "${BUILD_NUMBER:-}" ]; then sbom_args+=(--build "$BUILD_NUMBER"); fi
if [ -n "${COMMIT:-}" ]; then sbom_args+=(--commit "$COMMIT"); fi
"$src/tool/sbom.sh" generate "${sbom_args[@]}" --artifact "/out/$name.tar.gz"
"$src/tool/sbom.sh" generate "${sbom_args[@]}" --artifact "/out/$name.AppImage" \
  --extra-components "$runtime_json"
for file in "/out/$name.tar.gz" "/out/$name.AppImage"; do
  "$src/tool/sbom.sh" check --sbom "$file.cdx.json" --artifact "$file" --version "$version"
done
chown "${HOST_UID:-0}:${HOST_GID:-0}" "/out/$name.tar.gz.cdx.json" "/out/$name.AppImage.cdx.json"
