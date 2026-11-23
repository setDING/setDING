import 'package:chordpro/chordpro.dart'
    show ChordNotation, ChordView, NumeralSpelling;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/outbox.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Personal settings synced with the account (ADR-0027).
void main() {
  group('scopes', () {
    test('every setting has a scope', () {
      // Choices that follow the instrument until set (ADR-0026) are left
      // out of the JSON while unset; set, they need a scope too.
      const all = AppSettings(
        beatDisplay: true,
        edgeFlash: true,
        click: true,
        clickStart: ClickStart.manual,
        songMap: true,
      );
      expect(all.toJson().keys.toSet(), AppSettings.scopes.keys.toSet());
      expect(
        AppSettings.scopes.keys.toSet(),
        containsAll(const AppSettings().toJson().keys),
      );
    });

    test('screen, audio and network settings stay on the device', () {
      for (final key in [
        'fontSize',
        'columns',
        'autoFit',
        'pageTurn',
        'liveAppearance',
        'serverUrl',
        'syncMode',
      ]) {
        expect(AppSettings.scopes[key], SettingSyncScope.device, reason: key);
      }
      for (final key in [
        'instrument',
        'bassStrings',
        'userName',
        'notation',
        'language',
        'songDisplay',
      ]) {
        expect(AppSettings.scopes[key], SettingSyncScope.personal, reason: key);
      }
    });

    test('JSON round trip; unknown values give the default', () {
      const s = AppSettings(
        notation: ChordNotation.german,
        instrument: 'bass',
        bassStrings: 5,
        fontSize: 30,
      );
      expect(AppSettings.fromJson(s.toJson()).toJson(), s.toJson());
      final odd = AppSettings.fromJson({
        'notation': 'klingon',
        'nashville': 'yes',
        'chordView': 'klingon',
        'fontSize': 99,
        'bassStrings': 7,
      });
      expect(odd.notation, ChordNotation.international);
      expect(odd.chordView, ChordView.chords);
      expect(odd.fontSize, AppSettings.maxFontSize);
      expect(odd.bassStrings, 4);
    });

    test('the chord view keeps the Nashville flag of older versions in step '
        '(ADR-0055)', () {
      AppSettings read(Map<String, Object?> json) => AppSettings.fromJson(json);
      // Settings of an older version: only the flag.
      expect(read({'nashville': true}).chordView, ChordView.nashville);
      expect(read({'nashville': false}).chordView, ChordView.chords);
      // Written by this version: the view, and the flag for older ones.
      final numerals = const AppSettings(chordView: ChordView.numerals)
          .toJson();
      expect(numerals['chordView'], 'numerals');
      expect(numerals['nashville'], isTrue);
      expect(read(numerals).chordView, ChordView.numerals);
      expect(const AppSettings().toJson()['nashville'], isFalse);
      // An older version switched the flag off: chord names.
      expect(
        read({'chordView': 'numerals', 'nashville': false}).chordView,
        ChordView.chords,
      );
      // An older version switched the flag on: Nashville numbers.
      expect(
        read({'chordView': 'chords', 'nashville': true}).chordView,
        ChordView.nashville,
      );
    });

    test('numeral spelling: case by default, synced with the person '
        '(ADR-0059)', () {
      expect(const AppSettings().numeralSpelling, NumeralSpelling.casing);
      expect(AppSettings.fromJson({}).numeralSpelling, NumeralSpelling.casing);
      expect(
        AppSettings.fromJson({'numeralSpelling': 'klingon'}).numeralSpelling,
        NumeralSpelling.casing,
      );
      const on = AppSettings(numeralSpelling: NumeralSpelling.chordSymbol);
      expect(on.toJson()['numeralSpelling'], 'chordSymbol');
      expect(
        AppSettings.fromJson(on.toJson()).numeralSpelling,
        NumeralSpelling.chordSymbol,
      );
      expect(AppSettings.scopes['numeralSpelling'], SettingSyncScope.personal);
    });

    test('a repeated chorus is shown again unless switched on', () {
      expect(const AppSettings().repeatedChorusOnce, isFalse);
      expect(AppSettings.fromJson({}).repeatedChorusOnce, isFalse);
      const on = AppSettings(repeatedChorusOnce: true);
      expect(AppSettings.fromJson(on.toJson()).repeatedChorusOnce, isTrue);
      expect(
        AppSettings.scopes['repeatedChorusOnce'],
        SettingSyncScope.personal,
      );
    });

    test('parts outside the sequence are shown unless switched off', () {
      expect(const AppSettings().showOutsideSequence, isTrue);
      expect(AppSettings.fromJson({}).showOutsideSequence, isTrue);
      const off = AppSettings(showOutsideSequence: false);
      expect(AppSettings.fromJson(off.toJson()).showOutsideSequence, isFalse);
      expect(
        AppSettings.scopes['showOutsideSequence'],
        SettingSyncScope.personal,
      );
    });
  });

  test('developer mode is off unless switched on, and personal (#559)', () {
    expect(const AppSettings().developerMode, isFalse);
    expect(AppSettings.fromJson({}).developerMode, isFalse);
    const on = AppSettings(developerMode: true);
    expect(AppSettings.fromJson(on.toJson()).developerMode, isTrue);
    expect(AppSettings.scopes['developerMode'], SettingSyncScope.personal);
  });

  test('MIDI is in use only for keyboard players (#578)', () {
    const on = AppSettings(midiEnabled: true, instrument: 'keyboard');
    expect(on.isKeyboard, isTrue);
    expect(on.midiActive, isTrue);
    expect(on.copyWith(instrument: ' Keyboard ').midiActive, isTrue);
    expect(on.copyWith(instrument: 'guitar').midiActive, isFalse);
    expect(on.copyWith(midiEnabled: false).midiActive, isFalse);
    // The device setting itself is kept for another instrument.
    expect(on.copyWith(instrument: 'guitar').midiEnabled, isTrue);
  });

  test('MIDI settings: defaults, round trip, device only (ADR-0039)', () {
    const d = AppSettings();
    expect(d.midiEnabled, isFalse);
    expect(d.midiOutputName, '');
    expect(d.midiProfile, MidiProfileKind.nordStage3);
    expect(d.midiChannel, 1);
    const s = AppSettings(
      midiEnabled: true,
      midiOutputName: 'Nord Stage 3 MIDI',
      midiProfile: MidiProfileKind.generic,
      midiChannel: 16,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
    expect(back.midiChannel, 16);
    expect(back.midiProfile, MidiProfileKind.generic);
    final odd = AppSettings.fromJson({
      'midiProfile': 'moog',
      'midiChannel': 17,
      'midiEnabled': 'yes',
    });
    expect(odd.midiProfile, MidiProfileKind.nordStage3);
    expect(odd.midiChannel, 16);
    expect(odd.midiEnabled, isFalse);
    expect(AppSettings.fromJson({'midiChannel': 0}).midiChannel, 1);
    for (final key in [
      'midiEnabled',
      'midiOutputName',
      'midiProfile',
      'midiChannel',
    ]) {
      expect(AppSettings.scopes[key], SettingSyncScope.device, reason: key);
    }
  });

  group('store', () {
    late AppDatabase db;
    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    test(
      'the first start moves the personal settings out of the device settings',
      () async {
        SharedPreferences.setMockInitialValues({
          'notation': 'german',
          'instrument': 'bass',
          'fontSize': 28.0,
        });
        final prefs = await SharedPreferences.getInstance();
        final store = await UserSettingsStore.open(db, prefs);
        expect(store.data(localOwnerId), {
          'notation': 'german',
          'instrument': 'bass',
        });
        expect(prefs.getString('notation'), isNull);
        // Device settings stay where they are.
        expect(prefs.getDouble('fontSize'), 28.0);

        // Stored: a second start finds them in the database.
        await store.flush();
        final again = await UserSettingsStore.open(db, prefs);
        expect(again.data(localOwnerId)['instrument'], 'bass');
      },
    );
  });

  group('settings per owner', () {
    testWidgets(
      'signing in switches to the person, signing out back; changes of a '
      'person are synced, device settings are not',
      (tester) async {
        final app = await TestApp.create(
          prefs: {'language': 'en', 'notation': 'german'},
        );
        final container = ProviderContainer(overrides: app.overrides);
        addTearDown(container.dispose);
        AppSettings read() => container.read(settingsProvider);

        expect(read().notation, ChordNotation.german);
        app.backend.accounts['ann@example.test'] = 'secret';
        await app.backend.signIn(email: 'ann@example.test', password: 'secret');
        await tester.pump();
        // A copy of the signed-out settings until the sync knows better.
        expect(read().notation, ChordNotation.german);

        await container
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(instrument: 'ukulele', fontSize: 30));
        final user = container.read(settingsOwnerProvider);
        expect(user, isNot(localOwnerId));
        expect(app.personal(user)['instrument'], 'ukulele');
        expect(app.userSettings.get(user)!.dirty, {'instrument'});
        expect(app.personal(user).containsKey('fontSize'), isFalse);
        expect(app.prefs.getDouble('fontSize'), 30);
        final outbox = await app.db.select(app.db.syncOutbox).get();
        expect(outbox.single.collection, SyncCollection.userSettings);
        expect(outbox.single.recordId, user);

        await app.backend.signOut();
        await tester.pump();
        expect(read().instrument, 'guitar'); // the signed-out value
        expect(read().fontSize, 30); // the device's
        container.dispose();
        await app.dispose(tester);
      },
    );
  });

  group('sync', () {
    late AppDatabase db;
    late FakeSyncBackend server;
    late UserSettingsStore settings;
    late SyncEngine engine;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({'instrument': 'bass'});
      settings = await UserSettingsStore.open(
        db,
        await SharedPreferences.getInstance(),
      );
      server = FakeSyncBackend(user: _ann);
      engine = SyncEngine(
        db,
        server,
        BandService(db, server),
        settings: settings,
      );
    });
    tearDown(() => db.close());

    test('the first device brings its settings along', () async {
      final report = await engine.sync();
      expect(report.settingsTakenOver, isFalse);
      expect(server.userSettings['ann']!.data, {'instrument': 'bass'});
      final mine = settings.get('ann')!;
      expect(mine.adopting, isFalse);
      expect(mine.dirty, isEmpty);
      expect(mine.revision, server.userSettings['ann']!.revision);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    });

    test('on a new device the settings of the account win', () async {
      server.putUserSettings('ann', {'instrument': 'keyboard'});
      final changes = <String>[];
      settings.changes.listen(changes.add);

      final report = await engine.sync();
      expect(report.settingsTakenOver, isTrue);
      expect(settings.data('ann'), {'instrument': 'keyboard'});
      expect(changes, contains('ann'));
      // Nothing pushed back.
      expect(server.pushCount, 0);
      // The signed-out settings stay as they were.
      expect(settings.data(localOwnerId), {'instrument': 'bass'});
    });

    test('last writer wins per key', () async {
      await engine.sync();
      // Another device changes the notation, this one the instrument.
      server.putUserSettings('ann', {'notation': 'german'});
      await settings.change('ann', {'instrument': 'ukulele'});

      await engine.sync();
      expect(server.userSettings['ann']!.data, {
        'instrument': 'ukulele',
        'notation': 'german',
      });
      expect(settings.data('ann'), {
        'instrument': 'ukulele',
        'notation': 'german',
      });
      expect(settings.get('ann')!.dirty, isEmpty);
    });

    test('keys of a newer app version are kept', () async {
      server.putUserSettings('ann', {'instrument': 'bass', 'x_future': 3});
      await engine.sync();
      await settings.change('ann', {'nashville': true});
      await engine.sync();
      expect(settings.data('ann')['x_future'], 3);
      expect(server.userSettings['ann']!.data['x_future'], 3);
    });

    test('another person\'s change waits until they sync', () async {
      await settings.change('bob', {'instrument': 'drums'});
      await engine.sync();
      expect(server.userSettings.containsKey('bob'), isFalse);
      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox.map((o) => o.recordId), contains('bob'));
    });
  });
}
