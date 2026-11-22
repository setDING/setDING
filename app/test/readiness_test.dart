import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/auto_backup.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/midi/midi_connection.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/sync_controller.dart';
import 'package:setding/ui/live/page_turner.dart';
import 'package:setding/ui/overview/readiness.dart';
import 'package:setding/ui/settings_screen.dart' show SettingsCategory;

/// The checks of the overview's readiness tile (#911).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  String time(DateTime t) => '${t.day}.${t.month}. ${t.hour}:${t.minute}';
  final at = DateTime(2026, 11, 20, 20, 15);

  group('musician', () {
    test('instrument and name are ok', () {
      final item = musicianReadiness(
        l10n,
        const AppSettings(instrument: 'keyboard', userName: 'Andi'),
      );
      expect(item.level, ReadinessLevel.ok);
      expect(item.title, 'Musician: Keyboard · Andi');
      expect(item.detail, isNull);
      expect(item.category, SettingsCategory.musician);
    });

    // The voice or role is optional (#939): without it, the musician line is
    // ok; it only nudged people to type their instrument there.
    test('no voice or role is ok, a missing instrument worth knowing', () {
      final noName = musicianReadiness(
        l10n,
        const AppSettings(instrument: 'banjo'),
      );
      expect(noName.level, ReadinessLevel.ok);
      expect(noName.title, 'Musician: banjo');
      expect(noName.detail, isNull);

      final none = musicianReadiness(
        l10n,
        const AppSettings(instrument: ' ', userName: 'Andi'),
      );
      expect(none.level, ReadinessLevel.info);
      expect(none.title, 'Musician: No instrument chosen · Andi');
    });
  });

  group('MIDI', () {
    const keyboard = AppSettings(
      instrument: 'keyboard',
      midiEnabled: true,
      midiOutputName: 'Nord Stage 3 MIDI',
      midiProfile: MidiProfileKind.nordStage3,
    );

    test('only while MIDI program changes are on', () {
      expect(midiReadiness(l10n, const AppSettings(), MidiStatus.off), isNull);
      // On, but not a keyboard player (ADR-0039).
      expect(
        midiReadiness(
          l10n,
          keyboard.copyWith(instrument: 'guitar'),
          MidiStatus.notConnected,
        ),
        isNull,
      );
    });

    test('a connected keyboard is ok, with its profile', () {
      final item = midiReadiness(
        l10n,
        keyboard,
        const MidiStatus.connected('1', 'Nord Stage 3 MIDI'),
      )!;
      expect(item.level, ReadinessLevel.ok);
      expect(item.title, 'MIDI: Nord Stage 3 MIDI connected');
      expect(item.detail, 'Profile: Nord Stage 3');
      expect(item.category, SettingsCategory.midi);
    });

    test('a keyboard that is not connected is a warning', () {
      final item = midiReadiness(l10n, keyboard, MidiStatus.notConnected)!;
      expect(item.level, ReadinessLevel.warning);
      expect(item.title, l10n.readinessMidiNotConnected);

      final none = midiReadiness(
        l10n,
        keyboard.copyWith(midiOutputName: ''),
        MidiStatus.notConnected,
      )!;
      expect(none.title, l10n.readinessMidiNoOutput);
    });
  });

  group('offline', () {
    test('only with a next set and an offline promise', () {
      expect(offlineReadiness(l10n, nextSetId: null, missing: 0), isNull);
      // The web client makes no offline promise (ADR-0018).
      expect(offlineReadiness(l10n, nextSetId: 's', missing: null), isNull);
    });

    test('missing songs are a warning; a tap opens the set', () {
      final ok = offlineReadiness(l10n, nextSetId: 's', missing: 0)!;
      expect(ok.level, ReadinessLevel.ok);
      expect(ok.title, l10n.readinessOfflineReady);
      expect(ok.setId, 's');
      expect(ok.category, isNull);

      final missing = offlineReadiness(l10n, nextSetId: 's', missing: 2)!;
      expect(missing.level, ReadinessLevel.warning);
      expect(
        missing.title,
        '2 songs of the next set are not available offline',
      );
    });
  });

  group('sync', () {
    ReadinessItem? sync({
      bool synced = true,
      SyncMode mode = SyncMode.automatic,
      DateTime? last,
      SyncStaleness? staleness,
    }) => syncReadiness(
      l10n,
      time,
      synced: synced,
      mode: mode,
      lastSync: last,
      staleness: staleness,
    );

    test('nothing when nothing is synced', () {
      expect(sync(synced: false, last: at), isNull);
    });

    test('up to date is ok, with the last sync', () {
      final item = sync(last: at)!;
      expect(item.level, ReadinessLevel.ok);
      expect(item.title, 'Synced: ${time(at)}');
      expect(item.category, SettingsCategory.account);
    });

    test('manual sync is worth knowing', () {
      final item = sync(mode: SyncMode.manual, last: at)!;
      expect(item.level, ReadinessLevel.info);
      expect(item.detail, l10n.readinessSyncManual);
      expect(item.category, SettingsCategory.general);
    });

    test('stale data and unsent changes are a warning', () {
      final item = sync(
        last: at,
        staleness: SyncStaleness(lastSync: at, stale: true, unsent: 3),
      )!;
      expect(item.level, ReadinessLevel.warning);
      expect(item.title, l10n.readinessSyncStale);
      expect(item.detail, '${l10n.syncStale(time(at))}\n${l10n.syncUnsent(3)}');
    });
  });

  group('page turner', () {
    ReadinessItem turner(PageTurnerState state) =>
        pageTurnerReadiness(l10n, time, mode: PageTurnMode.half, state: state);

    test('never used is worth knowing, with how to test it', () {
      final item = turner(const PageTurnerState());
      expect(item.level, ReadinessLevel.info);
      expect(item.title, l10n.readinessPageTurnerNever);
      expect(item.detail, 'Turns: Half page · press the pedal here to test it');
      expect(item.category, SettingsCategory.live);
    });

    test('last used and responding are ok', () {
      expect(
        turner(PageTurnerState(lastUsed: at)).title,
        'Page turner: last used ${time(at)}',
      );
      final responds = turner(PageTurnerState(lastUsed: at, responded: true));
      expect(responds.level, ReadinessLevel.ok);
      expect(responds.title, l10n.readinessPageTurnerResponds);
    });
  });

  group('backup', () {
    test('only when the automatic backup is on', () {
      expect(backupReadiness(l10n, time, null), isNull);
      expect(backupReadiness(l10n, time, const AutoBackupState()), isNull);
    });

    test('no folder or a failed backup is a warning', () {
      final noFolder = backupReadiness(
        l10n,
        time,
        const AutoBackupState(enabled: true),
      )!;
      expect(noFolder.level, ReadinessLevel.warning);
      expect(noFolder.title, l10n.readinessBackupNoFolder);

      final failed = backupReadiness(
        l10n,
        time,
        AutoBackupState(
          enabled: true,
          location: 'f',
          lastAt: at,
          error: AutoBackupError.permission,
        ),
      )!;
      expect(failed.level, ReadinessLevel.warning);
      expect(failed.detail, l10n.autoBackupErrorPermission);
      expect(failed.category, SettingsCategory.about);
    });

    test('the last backup is ok, also when it is old', () {
      final item = backupReadiness(
        l10n,
        time,
        AutoBackupState(enabled: true, location: 'f', lastAt: DateTime(2025)),
      )!;
      expect(item.level, ReadinessLevel.ok);
      expect(item.title, l10n.autoBackupLast(time(DateTime(2025))));

      final never = backupReadiness(
        l10n,
        time,
        const AutoBackupState(enabled: true, location: 'f'),
      )!;
      expect(never.level, ReadinessLevel.info);
      expect(never.title, l10n.autoBackupNever);
    });
  });
}
