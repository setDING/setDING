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
