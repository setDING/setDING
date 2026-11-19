/// "What's new" notes after an update (ADR-0041): short de-CH/en notes per
/// version, bundled in `assets/whats_new.json` and offered once after an
/// update.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/settings.dart' show sharedPreferencesProvider;
import '../sync/auth_providers.dart';
import '../util/semver.dart';

/// The bundled notes.
const whatsNewAsset = 'assets/whats_new.json';

/// The language whose notes are shown when the app language has none.
const _fallbackLanguage = 'en';

/// Where the version whose notes were last offered is kept.
const whatsNewSeenKey = 'whatsNew.lastSeen';

/// The notes of one version.
class VersionNotes {
  const VersionNotes(this.version, this.notes);

  /// The version, e.g. `0.15.0`.
  final String version;

  /// Language code → notes; an empty list says nothing on purpose.
  final Map<String, List<String>> notes;

  /// The notes in [language], or in English if there are none.
  List<String> inLanguage(String language) =>
      notes[language] ?? notes[_fallbackLanguage] ?? const [];

  bool get isEmpty => notes.values.every((n) => n.isEmpty);
}

/// The notes of all versions, newest first. Throws [FormatException] if
/// [json] is not `{"x.y.z": {"<language>": ["…"]}}`.
List<VersionNotes> parseWhatsNew(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('whats_new: expected an object');
  }
  final versions = [
    for (final MapEntry(key: version, value: languages) in decoded.entries)
      VersionNotes(version, switch (languages) {
        Map<String, dynamic>() => {
          for (final MapEntry(key: language, value: notes) in languages.entries)
            language: switch (notes) {
              List<dynamic>() when notes.every((n) => n is String) =>
                notes.cast<String>(),
              _ => throw FormatException(
                'whats_new: $version/$language is not a list of strings',
              ),
            },
        },
        _ => throw FormatException('whats_new: $version is not an object'),
      }),
  ];
  return versions..sort((a, b) => compareVersions(b.version, a.version));
}

/// The notes to offer after an update to [current], newest first: of the
/// versions after [lastSeen] up to [current]; without [lastSeen] only those
/// of [current]. Versions without notes are left out.
List<VersionNotes> notesSince(
  List<VersionNotes> all, {
  required String? lastSeen,
  required String current,
}) => [
  for (final v in all)
    if (compareVersions(v.version, current) <= 0 &&
        (lastSeen == null
            ? compareVersions(v.version, current) == 0
            : compareVersions(v.version, lastSeen) > 0) &&
        !v.isEmpty)
      v,
];

/// The notes of all versions up to [current] (all if unknown), newest first.
List<VersionNotes> notesUpTo(List<VersionNotes> all, String? current) => [
  for (final v in all)
    if ((current == null || compareVersions(v.version, current) <= 0) &&
        !v.isEmpty)
      v,
];

/// On a new installation the running [version] counts as seen, so its notes
/// are not offered (ADR-0041). Call before anything else is stored: a device
/// that already has settings ran an older version.
Future<void> recordFirstStart(SharedPreferences prefs, String version) async {
  if (prefs.getKeys().isEmpty) await prefs.setString(whatsNewSeenKey, version);
}

/// All bundled notes, newest first.
final whatsNewProvider = FutureProvider<List<VersionNotes>>(
  (ref) async => parseWhatsNew(await rootBundle.loadString(whatsNewAsset)),
);

/// The notes to offer once after an update, or null while they load or if
/// the running version is unknown. Read when the app starts; [markWhatsNewSeen]
/// does not change it.
final pendingWhatsNewProvider = Provider<List<VersionNotes>?>((ref) {
  final current = ref.watch(clientVersionProvider);
  final all = ref.watch(whatsNewProvider).value;
  if (current == null || all == null) return null;
  final lastSeen = ref
      .read(sharedPreferencesProvider)
      .getString(whatsNewSeenKey);
  return notesSince(all, lastSeen: lastSeen, current: current);
});

/// The notes up to the running version were offered.
Future<void> markWhatsNewSeen(WidgetRef ref) async {
  final current = ref.read(clientVersionProvider);
  if (current == null) return;
  await ref.read(sharedPreferencesProvider).setString(whatsNewSeenKey, current);
}
