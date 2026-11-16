# Linux release builds

How to build a distributable Linux package of the app (ADR-0019). Android uses
`make apk` (sideloading); Windows, iOS and store releases are not covered yet.

```bash
make release
```

The result is `app/build/realchord-<version>-<commit>-linux-x64.tar.gz`
(`make release-linux` does the same). It is built from the **committed** state
(`HEAD`); commit first, uncommitted changes only print a warning and are not included.

## Requirements

Docker (`DOCKER=podman` works too). make first builds the Flutter base image
`realchord-ci:<flutter-version>` from `tool/ci/Dockerfile` if it is missing
(`make ci-image` does that by hand), then a local image
`realchord-release-linux:<flutter-version>` with the Linux build dependencies and
runs `flutter build linux --release` in it. Pub packages are cached in the Docker
volume `realchord-release-pub-cache`.

## Why a container

A binary linked on the development machine (CachyOS with `znver4` repositories) is
marked as requiring x86-64-v4 and does not start on CPUs without AVX-512 ("CPU ISA
level is lower than required"). The Debian container links against a baseline glibc.
`tool/release/check-isa.sh` fails the build if any file in the bundle requires more
than x86-64-v2; it can also check any bundle by hand:

```bash
tool/release/check-isa.sh app/build/linux/x64/debug/bundle
```

## Installing

Unpack the archive on the target machine and run `realchord` in the unpacked folder.
Requires GTK 3 and libsecret, which desktop distributions include.
