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

- **CycloneDX** (JSON, specification 1.6, the newest version `cyclonedx-cli`
  validates) is the only SBOM format.
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
- **Packages that ship assets** (fonts, shaders, images) are listed if their files
  are in the shipped archive (`flutter_assets/packages/<name>/`).
- **Native plugins:** listed for the platform only if `.flutter-plugins-dependencies`
  of the build names them for that platform and they are not dev dependencies.
- **Native libraries of build hooks** (e.g. SQLite of `sqlite3`, PDFium of
  `pdfium_dart`, the Xiph codecs of `flutter_soloud`): listed from the build's
  `native_assets.json` as a component per shipped file, with the SHA-256 of the
  file in the archive and the providing package (property `setding:provided-by`,
  dependency of that package); the build hooks report no version or licence, so
  the SBOM has none for them.
- **Windows:** the Visual C++ runtime DLLs shipped next to the app (version and
  hash from the files) and, in the setup's SBOM, Inno Setup.
- **AppImage** (ADR-0038): the bundle of the tar.gz plus the AppImage type-2
  runtime (version and hash of the pinned file, MIT) with the libfuse linked
  into it (LGPL 2.1).
- **Android:** the Gradle dependencies of `releaseRuntimeClasspath` only (no test
  or debug configurations), `pkg:maven/…`, with licences and hashes, generated in
  the Android job where Gradle already resolves them. Removed from it: the Gradle
  projects of the Flutter plugins (they are their Dart packages, which take over
  their dependencies), the `io.flutter` artifacts (the Flutter component; the
  engine jars of other ABIs are not in the arm64 APK) and `type=pom` entries
  (BOMs and Kotlin multiplatform root modules without code).
- **Flutter:** one component for the engine, the framework and the Dart runtime
  (`pkg:github/flutter/flutter@<version>`, licence BSD-3-Clause, version of the
  building SDK); the SDK packages (`flutter`, `flutter_localizations`, …) are
  part of it.
- Versions, `purl` (`pkg:pub/…`) and archive hashes of the Dart packages come
  from `pubspec.lock`, their licences from pub.dev (see below); the path packages
  under `packages/` are first-party components (MIT). The dependency graph
  (`flutter pub deps`, Gradle) is kept for the listed components.

The SBOM step fails instead of guessing when something does not fit these rules:
a shipped package that is not in `pubspec.lock`, a native asset that is not in
the archive, an unsupported package source, a package without a licence or a
licence missing from the SPDX table.

### Generation

- **Own Dart tool `tool/sbom`** (`tool/sbom.sh generate|check`, tested in
  `make check`): reads `pubspec.lock`, the instruction sizes,
  `.flutter-plugins-dependencies`, `native_assets.json`, `flutter pub deps` and
  the shipped archive itself (APK, zip, tar.gz; the setup uses the zip's
  contents), applies the rules above and writes the whole document, so neither
  the components nor the metadata depend on a generator's defaults.
- **Licences of Dart packages** from pub.dev's analysis (the `license:` tags of
  the version's score, mapped to SPDX ids by a table in the tool).
- **Android:** the official **CycloneDX Gradle plugin**, applied to `:app` by an
  init script (`tool/sbom/gradle/cyclonedx.init.gradle`) without touching the
  build files; the tool merges its document.
- **Linux:** generated inside the release container (`tool/release/build-linux.sh`),
  so `make release-linux` produces the same SBOM locally; `make sbom` also
  validates it.
- **Validation:** the official **cyclonedx-cli** (`tool/sbom/validate.sh`)
  validates every SBOM against the schema in the `sbom` job of the release
  workflow, also for test builds.
- External tools are used in their newest version (owner rule); `make check`
  fails on an outdated Gradle plugin, `validate.sh` takes the newest
  cyclonedx-cli release. They run in the release jobs and in `make sbom`, not
  inside the app.

### Evaluation on GitHub

The SBOMs are for the people who receive a release. The ongoing evaluation runs on
GitHub on the same data, from the repository:

- **Dependency graph and Dependabot alerts** (to be switched on by the owner in the
  repository settings; free for public repositories) report known vulnerabilities
  of the Dart packages from `pubspec.lock`; once they are on, the Android Gradle
  dependencies are submitted with `gradle/actions/dependency-submission`.
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

- Every release carries four additional JSON assets; the release workflow gets
  SBOM steps in the build jobs and an `sbom` job that validates them.
- The SBOM step needs pub.dev (licences) and the Gradle plugin portal; a release
  build fails if they are unreachable.
- The tool is ours to maintain: a new kind of shipped component (another package
  source, a new licence, a new platform such as iOS) needs a deliberate change.
- Vulnerabilities and licences are evaluated on GitHub (Dependabot, dependency
  review), not by our own tooling.
- The release build writes the instruction-size file in addition; the tool
  depends on its format (a Dart VM option), which may change with a Flutter
  upgrade; the tool fails if the file names no packages, which makes such a
  change visible.
- Native libraries of build hooks have no version or licence in the SBOM, only
  their hash and the package that ships them.
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
- 2026-11-18: Implementation (#505): an own Dart tool instead of cdxgen, agreed
  with the owner after a search for existing tools. cdxgen, Syft and Trivy read
  `pubspec.lock` without licences (cdxgen also wrote local paths into the SBOM),
  sbomify-action adds licences but no filtering; none can tell what is shipped,
  which the tool has to do anyway. Licences come from pub.dev, Android
  dependencies from the CycloneDX Gradle plugin, validation from cyclonedx-cli.
  Native libraries of build hooks and the Windows runtime and installer are
  listed as components; specification 1.6; Gradle dependency submission waits
  for the dependency graph.
- 2026-11-18: The Linux AppImage (ADR-0038, #504) is a release asset too and gets
  its own SBOM with the AppImage runtime.

- 2026-11-26: Server SBOMs (#1062, ADR-0063): every server bundle gets `setding-server-<version>-linux-<arch>.tar.gz.cdx.json` (platform `server-linux-<arch>`): the web client's Dart packages from the source map of its `main.dart.js` (built with source maps, which are not shipped), its asset packages and `sqlite3.wasm`, PocketBase (`pkg:golang/…`, hash of the binary) with the Go modules of its build information and the Go runtime, licences of Go modules from deps.dev (unknown ids fail, like on pub.dev), and Flutter. The server image gets an SBOM of its own (`type: container`, the image digest as hash, both bundles' SBOMs and the distroless base) that is **attested to the image on ghcr.io** with `actions/attest-sbom` instead of a release asset (owner, 2026-11-26), since the image is pushed after the GitHub Release.
## Open points

- Owner: switch on the dependency graph and Dependabot alerts in the repository
  settings; then submit the Android Gradle dependencies
  (`gradle/actions/dependency-submission`).
- Versions and licences of the native libraries of build hooks (SQLite, PDFium,
  Xiph codecs), if the hooks start to report them.
- Attesting the SBOMs (`actions/attest-sbom`).
- iOS, once there is an iOS build.
- The Linux AppImage (ADR-0038, #504) is a fifth release asset: it needs its own
  SBOM (`setding-<version>-linux-x64.AppImage.cdx.json`) with the components of the
  tar.gz plus the AppImage type-2 runtime (which contains libfuse).
