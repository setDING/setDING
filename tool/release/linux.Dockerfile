# Build environment for the Linux release (make release-linux, ADR-0019).
#
# Based on the CI image (tool/ci/Dockerfile: Debian bookworm, clang, Flutter), plus
# the toolchain and libraries `flutter build linux` needs. Debian's glibc targets
# the x86-64 baseline, so the release runs on any x86-64 CPU, independent of the
# distribution and CPU of the machine that runs make. Built locally on demand.
ARG CI_IMAGE
FROM ${CI_IMAGE}

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev liblzma-dev binutils \
 && rm -rf /var/lib/apt/lists/*

# AppImage tooling (ADR-0038), pinned by version and checksum: appimagetool
# (MIT) and the type-2 runtime (MIT; contains libfuse, LGPL-2.1, statically)
# that becomes the start of every AppImage. appimagetool is an AppImage itself;
# extracted, so it runs without FUSE inside the container.
# Pinned: appimagetool 1.9.1, type2-runtime 20251108 (newest releases).
ARG APPIMAGETOOL_VERSION=1.9.1
ARG APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
ARG APPIMAGE_RUNTIME_VERSION=20251108
ARG APPIMAGE_RUNTIME_SHA256=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends curl ca-certificates file \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/appimage \
 && cd /opt/appimage \
 && curl -fsSL -o appimagetool.AppImage \
      "https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage" \
 && echo "${APPIMAGETOOL_SHA256}  appimagetool.AppImage" | sha256sum -c - \
 && curl -fsSL -o runtime-x86_64 \
      "https://github.com/AppImage/type2-runtime/releases/download/${APPIMAGE_RUNTIME_VERSION}/runtime-x86_64" \
 && echo "${APPIMAGE_RUNTIME_SHA256}  runtime-x86_64" | sha256sum -c - \
 && curl -fsSL -o runtime-LICENSE \
      "https://raw.githubusercontent.com/AppImage/type2-runtime/${APPIMAGE_RUNTIME_VERSION}/LICENSE" \
 && chmod +x appimagetool.AppImage \
 && ./appimagetool.AppImage --appimage-extract >/dev/null \
 && mv squashfs-root appimagetool \
 && rm appimagetool.AppImage

# Recorded in the AppImage SBOM (ADR-0037).
ENV APPIMAGE_RUNTIME_VERSION=${APPIMAGE_RUNTIME_VERSION}
