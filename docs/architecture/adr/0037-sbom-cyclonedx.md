# ADR-0037: SBOM in CycloneDX per release artifact

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

A release publishes several distributions on GitHub (ADR-0021, ADR-0035): the
Linux `tar.gz`, the Android `apk`, the Windows `zip` and the Windows `setup.exe`.
Nobody can currently tell from a release which third-party components, in which
versions and under which licences, are inside a given file. That is needed to
answer "are we affected?" when a vulnerability in a dependency becomes known, to
check the licence rule of AGENTS.md (MIT-compatible dependencies only) and to be
prepared for supply-chain requirements such as the EU Cyber Resilience Act.

A Software Bill of Materials (SBOM) answers this. It is only useful if it
identifies the application and the exact file it describes: an SBOM saying
"some setDING" is worthless.

The distributions share most of their components:

- **Dart packages** from `app/pubspec.lock` (including the path packages under
  `packages/`) are the same on every platform. `pubspec.lock` also lists the
  platform implementations of federated plugins (`*_android`, `*_windows`, …) for
  all platforms.
- **Android** adds Gradle/Maven dependencies (AndroidX, Kotlin, the Android parts
  of the plugins).
- **Windows** adds the native plugin DLLs and the Inno Setup installer stub;
  **Linux** the native plugin libraries (GTK and other system libraries are not
  shipped).
- Every app contains the **Flutter engine** (Skia, ICU, …) in the Flutter version
  pinned in the `Makefile`; no scanner detects it.

Binary scanning does not work well here: the Dart AOT snapshot and the dex files
of the APK carry no package metadata. The SBOM is therefore derived from the lock
files of the build, in the build job of each artifact.

## Decision

### Format and scope

- **CycloneDX** (JSON, current specification version) is the only SBOM format.
- **One SBOM per release asset**, named after the asset:
  `setding-<version>-android.apk.cdx.json`,
  `setding-<version>-linux-x64.tar.gz.cdx.json`,
  `setding-<version>-windows-x64.zip.cdx.json`,
  `setding-<version>-windows-x64-setup.exe.cdx.json`.
- The SBOMs are published as assets of the same GitHub Release and are thereby
  covered by `SHA256SUMS`.

### Identification of the application (`metadata`)

Every SBOM carries in `metadata.component`:

| Field | Value |
|---|---|
| `type` | `application` |
| `name` | `setDING` |
| `version` | the release version from the tag (`vX.Y.Z` → `X.Y.Z`), which the release workflow already checks against `app/pubspec.yaml` |
| `purl` | `pkg:github/tafli/setDING@vX.Y.Z` |
| `bom-ref` | unique per asset (contains the platform) |
| `supplier` | the setDING project with `https://setding.app` |
| `licenses` | `MIT` |
| `externalReferences` | website, repository (`vcs`), the GitHub Release |
| `hashes` | **SHA-256 of exactly the asset** the SBOM belongs to |
| `properties` | `setding:platform` (`android`, `linux-x64`, `windows-x64`), `setding:artifact` (file name), `setding:build` (run number), `setding:commit` |

`metadata.timestamp`, `metadata.tools` and a random `serialNumber` are set as
usual. The hash binds the SBOM to one file; without it, the SBOM would only
describe "a setDING X.Y.Z".

### Components: only what is shipped

An SBOM lists **only components that are in its file**. `pubspec.lock` alone is
not enough: it lists dev dependencies and the plugin implementations of every
platform. The components of an asset are therefore determined from its own build:

- **Dart packages compiled into the app:** the release build writes the sizes of
  the compiled code per library (`--extra-gen-snapshot-options=--print-instructions-sizes-to=<file>`,
  the data behind `flutter build --analyze-size`); a package is listed if code
  from it is in the AOT snapshot. Packages the compiler drops (dev dependencies,
  code behind conditional imports for other platforms, unused packages) do not
  appear.
- **Packages that ship assets** (fonts, images) are listed if their files are in
  the bundle (`flutter_assets/packages/<name>/`).
- **Native plugins:** listed for the platform only if `.flutter-plugins-dependencies`
  of the build names them for that platform.
- **Android:** the Gradle dependencies of `releaseRuntimeClasspath` only (no test
  or debug configurations), `pkg:maven/…`, generated in the Android job where
  Gradle already resolves them.
- **Flutter engine:** an explicit component (`pkg:github/flutter/flutter@<version>`,
  licence BSD-3-Clause) with the version from the `Makefile`, in every app.
- Versions, `purl` (`pkg:pub/…`), licences and hashes of the Dart packages come
  from `pubspec.lock` and the generator; the path packages under `packages/` are
  first-party components. The dependency graph is kept for the listed components.

If a package cannot be attributed (neither code, assets nor a native part), the
SBOM step fails instead of guessing, so the rules are extended deliberately.

### Generation

- **cdxgen** (CycloneDX project, Apache-2.0) generates the Dart part (`-t dart`)
  and the Gradle part (`-t gradle`); **cyclonedx-cli** merges them for Android.
- A script in `tool/sbom/` then removes the Dart components that are not shipped
  (rules above), sets `metadata` as above and adds the Flutter engine, so neither
  the components nor the metadata depend on the generator's defaults (directory
  name `app`, no version, every package in the lock file).
- The tools are used in their newest version (owner rule); they run in the
  release jobs and in `make sbom`, not inside the app.

### Evaluation on GitHub

The SBOMs are for the people who receive a release. The ongoing evaluation runs on
GitHub on the same data, from the repository:

- **Dependency graph and Dependabot alerts** (to be switched on by the owner in the
  repository settings; free for public repositories) report known vulnerabilities
  of the Dart packages from `pubspec.lock`; the Android Gradle dependencies are
  submitted with `gradle/actions/dependency-submission` in the Android job.
- **Licence check:** `actions/dependency-review-action` with an allow list of
  MIT-compatible licences, once CI runs on pull requests again (ADR-0010).

### Checks

- After generating, the release workflow **fails** if `metadata.component.name`
  is not `setDING`, `metadata.component.version` is not the tag version, the
  hash does not match the asset that is uploaded, or the document is not valid
  CycloneDX (`cyclonedx-cli validate`).
- `make sbom` produces and checks the same SBOMs locally for a local build.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **CycloneDX** (chosen) | Owner's choice; security-oriented, widely supported by scanners (Dependency-Track, grype, osv-scanner); good support for hashes, properties and dependency graphs | – |
| SPDX | ISO standard, strong on licences | Not wanted; a second format would double the work |
| One SBOM per release (all platforms) | One file | Cannot be bound to one file by hash; Android-only Gradle components would appear on every platform |
| Scanning the built binaries (syft on APK/zip) | Describes what is really in the file | Dart AOT snapshot and dex carry no package metadata; misses almost all components |
| No SBOM | No work | No answer to "are we affected?", no licence overview |

## Consequences

- Every release carries four additional small JSON assets; the release workflow
  gets one step per build job plus a check.
- Vulnerabilities and licences are evaluated on GitHub (Dependabot, dependency
  review), not by our own tooling.
- The release build writes the instruction-size file in addition; the SBOM
  script depends on its format (a Dart VM option), which may change with a
  Flutter upgrade; the failing check above makes such a change visible.
- The SBOMs are precise at package level: a listed package may contribute only
  part of its code, but no package is listed that is not in the file.
- The SBOMs describe the dependencies, not the exact build environment (Flutter
  SDK tooling, Gradle, Inno Setup compiler); that is not their purpose.

## Decision log

- 2026-11-18: Proposed (#505) on the owner's request; the owner chose CycloneDX
  and asked for correct application data (name, version) in every SBOM.
- 2026-11-18: The owner asked that an SBOM lists as little as possible that is not
  shipped: components are taken from the asset's build (compiled code, assets,
  native plugins per platform, Gradle release classpath) instead of the whole
  lock file. Evaluation (vulnerabilities, licences) runs on GitHub. No server SBOM
  while the server is not released.
- 2026-11-18: Accepted by the owner.

## Open points

- Server SBOM (PocketBase, web client): later, once the server is released as an
  artifact of its own.
- Owner: switch on the dependency graph and Dependabot alerts in the repository
  settings.
- Attesting the SBOMs (`actions/attest-sbom`).
- iOS, once there is an iOS build.
