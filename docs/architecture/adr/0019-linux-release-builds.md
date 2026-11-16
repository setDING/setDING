# ADR-0019: Linux release builds

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Until now the only desktop target in the `Makefile` was `make build`, a Linux
**debug** build for local testing. Copied to another Linux machine, that binary
failed to start:

```
./realchord: CPU ISA level is lower than required
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
  distributable Linux package `app/build/realchord-<version>-<commit>-linux-x64.tar.gz`
  from the **committed** state (`git archive HEAD`); uncommitted changes only cause a
  warning.
- The build runs `flutter build linux --release` inside a **Debian container**
  (`tool/release/linux.Dockerfile`, based on the CI image, plus CMake, Ninja, GTK 3 and
  libsecret). Debian's glibc targets the x86-64 baseline and is older than rolling
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
  distributions). Packaging formats (AppImage, Flatpak) and signing are not covered.
- When CI release builds come (ADR-0010, towards version 1), they should use the same
  container and scripts, so local and CI releases stay identical.

## Decision log

- 2026-11-15: Proposed (#45), after a Linux build from the CachyOS development machine
  failed with "CPU ISA level is lower than required" on another machine. Windows
  release left out on request (not needed yet).
- 2026-11-15: Accepted by the owner.

## Open points

- Windows release (needs a Windows machine or a GitHub Actions Windows runner).
- Packaging (AppImage/Flatpak) and signing.
- Move the release build into CI towards version 1.
