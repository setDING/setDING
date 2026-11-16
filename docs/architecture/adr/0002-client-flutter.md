# ADR-0002: Flutter as client framework

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

The app must run on tablets with **Android, iOS and Windows**. Requirements:
precise control over text layout (chords exactly above the right syllable),
full screen, wakelock, keyboard/pedal events, a local database and smooth
page turning. The team should maintain **a single code base** if possible.

## Decision

The client is implemented with **Flutter (Dart)**.

Suggested libraries (to be verified during project setup):

| Purpose | Candidate |
|---|---|
| Local DB | `drift` (SQLite, type-safe, reactive queries) |
| State management | `riverpod` |
| Keep screen on | `wakelock_plus` |
| Backend client | official `pocketbase` Dart SDK (see ADR-0004) |
| Routing | `go_router` |
| Localization | `flutter_localizations` + `intl` with ARB files (see ADR-0008) |
| PDF rendering | `pdfrx` (see ADR-0009) |

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Flutter** (chosen) | Android, iOS, Windows (+ macOS, Linux, web) from one code base; own rendering engine → pixel-exact, identical layout on all platforms; good keyboard event support | Dart as an additional language; web build rather heavy |
| .NET MAUI | C#, good Windows integration | Rendering differences between Windows and iOS, smaller ecosystem, mixed stability |
| React Native | Large ecosystem, TypeScript | Windows support only via a separate Microsoft project, less mature |
| PWA (web app) | No app store, very easy to distribute | iOS: storage can be evicted by the system, limited wakelock/full-screen support → risk for the offline goal |
| Tauri/Capacitor (web UI in a native shell) | Reuse of web skills | Two shell technologies for mobile/desktop, layout differences between WebViews |

## Consequences

- The ChordPro parser is written as a **pure Dart package** (no Flutter dependency) and can also be used server-side or in CLI tools if needed.
- Distribution via App Store (iOS), Play Store or APK (Android) and MSIX/installer (Windows). An Apple Developer account is required for iOS (including TestFlight).
- A Flutter web build can later serve as a management UI on the PC.

## Decision log

- 2026-11-14: Flutter accepted. Existing team experience with other technologies is not a factor in this decision.
- 2026-11-14: Linux desktop added to the Flutter project as a **development and test target only** (quick local runs without a device). It is not a release platform.
- 2026-11-16: **Web** is a release platform for management (ADR-0018): `app/web`, built by `make web` and in `make check`, served by PocketBase at `app.realchord.app` (#27).

## Open points

- Which tablets are actually used (minimum Android/iOS version, Windows Surface)?
