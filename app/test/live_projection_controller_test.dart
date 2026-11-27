import 'package:chordpro/chordpro.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/database.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/live/live_projection.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'projection_controller_test.dart' show FakeProjectionHost;

// The projection coordination of live mode, extracted from live_screen.dart
// (#1202).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SongEntry song(String id, String source, {String? language}) => SongEntry(
    id: id,
    libraryId: 'l',
    chordproSource: source,
    title: id,
    chordproProblems: 0,
    chordproConversions: 0,
    revision: 0,
    updatedAt: DateTime(2026),
    deleted: false,
    purged: false,
    language: language,
  );

  const verses =
      '{start_of_verse: V1}\nOne\n{end_of_verse}\n'
      '{start_of_verse: V2}\nTwo\n{end_of_verse}\n';

  late FakeProjectionHost host;
  late AppSettings settings;
  late List<SongEntry> versions;
  late List<String> tokens;
  int? section;

  LiveProjection make(List<LiveItem> items) {
    final projection = LiveProjection(
      host: () => host,
      items: items,
      settings: () => settings,
      l10n: () => lookupAppLocalizations(const Locale('en')),
      token: () => 'token',
      renewToken: () {
        tokens.add('renewed');
        return 'renewed';
      },
      languageVersions: (_) async => versions,
      parse: parseChordPro,
      section: (_) => section,
      template: () async => '<html></html>',
    );
    addTearDown(projection.dispose);
    return projection;
  }

  setUp(() {
    host = FakeProjectionHost();
    settings = const AppSettings();
    versions = const [];
    tokens = [];
    section = null;
  });

  test('starts with the token and shows the items of live mode', () async {
    final projection = make([
      LiveItem.song(song('a', verses)),
      const LiveItem.marker(null, 'Break'),
    ]);
    var notified = 0;
    projection.addListener(() => notified++);
    expect(projection.running, isFalse);
    projection.show(0);
    expect(host.sent, isEmpty, reason: 'not started');

    await projection.start(lang: 'en');
    expect(projection.running, isTrue);
    expect(host.tokens, ['token']);
    projection.show(0);
    expect(host.last['lines'], ['One']);
    expect(notified, greaterThan(0));

    projection.show(1);
    expect(host.last['blank'], isTrue, reason: 'markers blank by default');

    await projection.renew();
    expect(tokens, ['renewed']);
    expect(host.tokens.last, 'renewed');
  });

  test('pairs the song with its version in the second language', () async {
    settings = const AppSettings(projectionSecondLanguage: 'de');
    versions = [
      song('b', '{start_of_verse}\nEins\n{end_of_verse}\n', language: 'de'),
    ];
    final projection = make([LiveItem.song(song('a', verses, language: 'en'))]);
    await projection.start(lang: 'en');
    projection.show(0);
    await pumpEventQueue();
    expect(host.last['second'], ['Eins']);
  });

  test('page turns move the slides when the setting is on (#1181)', () async {
    final projection = make([LiveItem.song(song('a', verses))]);
    await projection.start(lang: 'en');
    projection.show(0);
    expect(projection.turnSlide(forward: true), isFalse, reason: 'off');

    settings = const AppSettings(projectionTurnsSlides: true);
    expect(projection.turnSlide(forward: true), isTrue);
    expect(host.last['lines'], ['Two']);
    expect(projection.turnSlide(forward: true), isFalse, reason: 'last');

    // Turning back into the song ends at its last slide.
    projection.itemShown(0, back: true);
    expect(host.last['lines'], ['Two']);
    projection.itemShown(0, back: false);
    expect(host.last['lines'], ['One']);
  });

  test('a new second language shows the item again', () async {
    final projection = make([LiveItem.song(song('a', verses))]);
    projection.settingsChanged(null, settings, 0);
    expect(host.sent, isEmpty, reason: 'not started');
    await projection.start(lang: 'en');
    final sent = host.sent.length;
    projection.settingsChanged(
      settings,
      settings.copyWith(projectionSecondLanguage: 'fr'),
      0,
    );
    expect(host.sent.length, greaterThan(sent));
  });
}
