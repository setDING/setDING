# ADR-0019: Linux release builds

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Until now the only desktop target in the `Makefile` was `make build`, a Linux
**debug** build for local testing. Copied to another Linux machine, that binary
failed to start:

```
./setding: CPU ISA level is lower than required
```

The development machine runs CachyOS with the `znver4` repositories. Its glibc ships
`Scrt1.o` with the GNU property *x86 ISA needed: x86-64-v4*, and the linker copies the
property into every executable linked there. The loader of another machine refuses to
start the program unless its CPU supports AVX-512, even though the code itself uses
no AVX instructions. Any binary linked on a machine with an optimized toolchain can
carry such a marker, and its system libraries may be newer than those of the target.

The CI release build described in ADR-0010 (section 10 of the git workflow) does not
exist yet, and CI is manual-only during early development.

## Decision

- **`make release`** (currently the same as `make release-linux`) builds the
  distributable Linux package `app/build/setding-<version>-<commit>-linux-x64.tar.gz`
  from the **committed** state (`git archive HEAD`); uncommitted changes only cause a
  warning.
- The build runs `flutter build linux --release` inside a **Debian container**
  (`tool/release/linux.Dockerfile`, based on the Flutter image `tool/ci/Dockerfile`, plus CMake, Ninja, GTK 3,
  libsecret and Debian's clang 19 as the compiler). Debian's glibc targets the x86-64 baseline and is older than rolling
  distributions, so the bundle runs on every x86-64 CPU and on current distributions.
- **ISA check:** `tool/release/check-isa.sh` fails the release if any ELF file in the
  bundle requires an ISA level above x86-64-v2.
- **No Windows release for now.** It is not needed yet; Flutter cannot cross-compile
  Windows apps, so it will need a Windows machine or runner when it comes.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Strip the ISA note from the binary (`objcopy`) after a host build | Fast, no container | Treats the symptom; the binary still depends on the host's (possibly newer) glibc and libraries; easy to forget |
| Linker flag to override the ISA marker | No extra step | Not supported reliably: the linker merges the markers of all input objects |
| Debian container (chosen) | Reproducible, baseline glibc, same toolchain as CI | Docker needed; first build downloads packages |

## Consequences

- Distributable Linux builds no longer depend on the development machine's distribution
  or CPU. `make build` / `make start` stay debug builds for local testing only.
- The bundle still needs GTK 3 and libsecret on the target system (standard on desktop
  distributions). Packaging formats and signing are not covered here; the AppImage
  next to the tar.gz comes with ADR-0038.
- When CI release builds come (ADR-0010, towards version 1), they should use the same
  container and scripts, so local and CI releases stay identical.

## Decision log

- 2026-11-15: Proposed (#45), after a Linux build from the CachyOS development machine
  failed with "CPU ISA level is lower than required" on another machine. Windows
  release left out on request (not needed yet).
- 2026-11-15: Accepted by the owner.
- 2026-11-16: The base image `tool/ci/Dockerfile` is no longer the CI image on `ghcr.io`
  (CI uses flutter-action, ADR-0010, #135); `make release` builds it locally as
  `realchord-ci:<flutter-version>` when it is missing.
- 2026-11-16: Windows release and the CI release build come with ADR-0021 (accepted,
  #137): a `vX.Y.Z` tag runs `make release-linux` on GitHub Actions (same container
  and ISA check), with `RELEASE_NAME` without the commit and `BUILD_NUMBER` set to the
  run number; Windows is built on a GitHub Windows runner.

- 2026-11-18: The open point "Packaging (AppImage/Flatpak)" is taken up by ADR-0038
  (accepted, #503): the same container build also packs an AppImage that updates
  itself.

## Open points

- Flatpak and signing.
- 2026-11-27: The release container compiles with Debian bookworm's clang 19 instead
  of its default clang 14, which cannot build the C++20 of flutter_zxing's native build
  hook (#1133); glibc and libstdc++ stay bookworm's, so the baseline is unchanged.
  `make release-gate` builds the Linux release (`make sbom`).
