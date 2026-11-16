# CI image for RealChord (ADR-0010, docs/development/git-workflow.md section 7).
#
# Debian with Node (for the checkout action), git, curl, unzip, xz, python3
# (from buildpack-deps), clang (native assets of dependencies) and Flutter,
# precached for running the tests on Linux.
#
# Build and push with `make ci-image ci-image-push`; the tag is the Flutter
# version and must match FLUTTER_VERSION in the Makefile and the image in
# .github/workflows/ci.yml.
FROM node:22-bookworm

# Links the image on ghcr.io to the repository, so GitHub Actions may pull it
# with GITHUB_TOKEN.
LABEL org.opencontainers.image.source=https://github.com/tafli/RealChord

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
      org.opencontainers.image.description="Flutter ${FLUTTER_VERSION} CI image for RealChord"
