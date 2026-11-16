# Flutter base image for RealChord: Debian with Flutter, used as the base of the
# Linux release build (tool/release/linux.Dockerfile, ADR-0019). Originally the CI
# image; CI now runs on the plain GitHub runner with flutter-action (ADR-0010).
#
# Debian with Node, git, curl, unzip, xz, python3 (from buildpack-deps), clang
# (native assets of dependencies) and Flutter, precached for Linux.
#
# Built locally with `make ci-image` (also done by `make release` when missing);
# the tag is FLUTTER_VERSION from the Makefile.
FROM node:22-bookworm

ARG FLUTTER_VERSION

RUN test -n "$FLUTTER_VERSION" \
 && apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends clang \
 && rm -rf /var/lib/apt/lists/*

# Runners with user namespace remapping cannot chown extracted files.
ENV TAR_OPTIONS=--no-same-owner \
    FLUTTER_ROOT=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH

RUN git clone --quiet --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git /opt/flutter \
 && git config --system --add safe.directory '*' \
 && flutter config --no-analytics --no-cli-animations \
 && dart --disable-analytics \
 && flutter precache --no-android --no-ios --no-web --linux \
 && flutter --version

LABEL org.opencontainers.image.title="realchord-ci" \
      org.opencontainers.image.description="Flutter ${FLUTTER_VERSION} base image for RealChord"
