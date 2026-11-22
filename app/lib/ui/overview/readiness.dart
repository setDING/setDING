import 'package:flutter/foundation.dart';

import '../../data/auto_backup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_connection.dart';
import '../../settings/settings.dart';
import '../../sync/sync_controller.dart';
import '../../platform/input_devices.dart';
import '../live/page_turner.dart';
import '../settings_screen.dart' show SettingsCategory, instrumentLabel;

/// How a line of the readiness tile stands (#911).
enum ReadinessLevel {
  /// Ready.
  ok,

  /// Worth knowing, nothing to fix before the gig.
  info,

  /// Should be fixed before the gig; always shown.
  warning,
}

/// The checks of the readiness tile, in the order of their lines.
enum ReadinessCheck { musician, midi, offline, sync, pageTurner, backup }

/// One line of the readiness tile: where it stands and where a tap leads,
/// a settings [category] or the next set ([setId]).
@immutable
class ReadinessItem {
  const ReadinessItem({
    required this.check,
    required this.level,
    required this.title,
    this.detail,
    this.category,
    this.setId,
  });

  final ReadinessCheck check;
  final ReadinessLevel level;
  final String title;
  final String? detail;
  final SettingsCategory? category;
  final String? setId;

  @override
  String toString() => 'ReadinessItem(${check.name}, ${level.name}, $title)';
}

/// Formats a point in time for a line, e.g. "22.11.26 20:15".
typedef ReadinessTime = String Function(DateTime time);

/// Instrument and voice or role (ADR-0012): no instrument is worth knowing,
/// not a problem. The voice or role is optional and only shown when set
/// (#939): most musicians need none, the instrument already counts.
ReadinessItem musicianReadiness(AppLocalizations l10n, AppSettings s) {
  final instrument = s.instrument.trim();
  final name = s.userName.trim();
  final who = [
    instrument.isEmpty
        ? l10n.readinessNoInstrument
        : instrumentLabel(l10n, instrument),
    if (name.isNotEmpty) name,
  ].join(' · ');
  return ReadinessItem(
    check: ReadinessCheck.musician,
    level: instrument.isEmpty ? ReadinessLevel.info : ReadinessLevel.ok,
    title: l10n.readinessMusician(who),
    category: SettingsCategory.musician,
  );
}

/// The MIDI keyboard (ADR-0039), only while MIDI program changes are on:
/// a keyboard that is not connected sends no programs on stage.
ReadinessItem? midiReadiness(
  AppLocalizations l10n,
  AppSettings s,
  MidiStatus status,
) {
  if (!s.midiActive) return null;
  final profile = switch (s.midiProfile) {
    MidiProfileKind.generic => l10n.midiProfileGeneric,
    MidiProfileKind.nordStage3 => l10n.midiProfileNordStage3,
    MidiProfileKind.motifXf => l10n.midiProfileMotifXf,
  };
  return ReadinessItem(
    check: ReadinessCheck.midi,
    level: status.connected ? ReadinessLevel.ok : ReadinessLevel.warning,
    title: status.connected
        ? l10n.readinessMidiConnected(status.deviceName ?? s.midiOutputName)
        : s.midiOutputName.isEmpty
        ? l10n.readinessMidiNoOutput
        : l10n.readinessMidiNotConnected,
    detail: l10n.readinessMidiProfile(profile),
    category: SettingsCategory.midi,
  );
}

/// The songs of the next set on this device (ADR-0001), only with a next
/// set and where the app promises offline use ([missing] is null on the
/// web client, ADR-0018). A tap opens the set.
ReadinessItem? offlineReadiness(
  AppLocalizations l10n, {
  required String? nextSetId,
  required int? missing,
}) {
  if (nextSetId == null || missing == null) return null;
  return ReadinessItem(
    check: ReadinessCheck.offline,
    level: missing == 0 ? ReadinessLevel.ok : ReadinessLevel.warning,
    title: missing == 0
        ? l10n.readinessOfflineReady
        : l10n.readinessOfflineMissing(missing),
    setId: nextSetId,
  );
}

/// The sync with the server (ADR-0004, #744), only when signed in and not
/// on the web client: stale data or unsent changes are a warning, a manual
/// sync mode is worth knowing.
ReadinessItem? syncReadiness(
  AppLocalizations l10n,
  ReadinessTime time, {
  required bool synced,
  required SyncMode mode,
  required DateTime? lastSync,
  required SyncStaleness? staleness,
}) {
  if (!synced) return null;
  if (staleness != null) {
    final last = staleness.lastSync;
    return ReadinessItem(
      check: ReadinessCheck.sync,
      level: ReadinessLevel.warning,
      title: l10n.readinessSyncStale,
      detail: [
        if (staleness.stale)
          last == null ? l10n.syncStaleNever : l10n.syncStale(time(last)),
        if (staleness.unsent > 0) l10n.syncUnsent(staleness.unsent),
      ].join('\n'),
      category: SettingsCategory.account,
    );
  }
  final manual = mode == SyncMode.manual;
  return ReadinessItem(
    check: ReadinessCheck.sync,
    level: manual ? ReadinessLevel.info : ReadinessLevel.ok,
    title: lastSync == null
        ? l10n.readinessSyncNever
        : l10n.readinessSynced(time(lastSync)),
    detail: manual ? l10n.readinessSyncManual : null,
    category: manual ? SettingsCategory.general : SettingsCategory.account,
  );
}

/// The page turner (#911): whether the paired one is connected (ADR-0057,
/// #913) or that none is paired (#928); where pairing is not possible,
/// whether it responded to the test on the overview or
/// when it was last used, and how it turns. On iOS only whether a keyboard
/// is connected; a missing one is a warning once a page turner was used.
ReadinessItem pageTurnerReadiness(
  AppLocalizations l10n,
  ReadinessTime time, {
  required PageTurnMode mode,
  required PageTurnerState state,
  InputDeviceInfo? paired,
  PageTurnerConnection connection = PageTurnerConnection.unknown,
}) {
  final last = state.lastUsed;
  final modeLabel = switch (mode) {
    PageTurnMode.full => l10n.pageTurnFull,
    PageTurnMode.half => l10n.pageTurnHalf,
  };
  final turns = l10n.readinessPageTurnerDetail(modeLabel);
  final used = state.responded
      ? l10n.readinessPageTurnerResponds
      : last == null
      ? l10n.readinessPageTurnerNever
      : l10n.readinessPageTurnerLastUsed(time(last));
  ReadinessItem item(ReadinessLevel level, String title, String detail) =>
      ReadinessItem(
        check: ReadinessCheck.pageTurner,
        level: level,
        title: title,
        detail: detail,
        category: SettingsCategory.live,
      );
  final name = paired?.name ?? '';
  switch (connection) {
    // Without a pairing a key from any keyboard would count, so no quick
    // test and no last use: the line asks to pair it (#928).
    case PageTurnerConnection.notPaired:
      return item(
        ReadinessLevel.info,
        l10n.readinessPageTurnerNotPaired,
        l10n.readinessPageTurnerPairDetail(modeLabel),
      );
    case PageTurnerConnection.connected:
      return item(
        ReadinessLevel.ok,
        state.responded
            ? l10n.readinessPageTurnerResponds
            : l10n.readinessPageTurnerConnected(name),
        turns,
      );
    case PageTurnerConnection.notConnected:
      return item(
        ReadinessLevel.warning,
        l10n.readinessPageTurnerNotConnected(name),
        turns,
      );
    case PageTurnerConnection.noKeyboard when last != null:
      return item(
        ReadinessLevel.warning,
        l10n.readinessKeyboardNotConnected,
        turns,
      );
    case PageTurnerConnection.keyboardConnected:
      return item(
        ReadinessLevel.ok,
        used,
        '${l10n.readinessKeyboardConnected}\n$turns',
      );
    case PageTurnerConnection.noKeyboard || PageTurnerConnection.unknown:
      return item(
        state.responded || last != null
            ? ReadinessLevel.ok
            : ReadinessLevel.info,
        used,
        turns,
      );
  }
}

/// The automatic backup of the local library (ADR-0054), only when it is
/// on. Its age is no warning: it writes only after changes.
ReadinessItem? backupReadiness(
  AppLocalizations l10n,
  ReadinessTime time,
  AutoBackupState? backup,
) {
  if (backup == null || !backup.enabled) return null;
  ReadinessItem item(ReadinessLevel level, String title, [String? detail]) =>
      ReadinessItem(
        check: ReadinessCheck.backup,
        level: level,
        title: title,
        detail: detail,
        category: SettingsCategory.about,
      );
  if (backup.location == null) {
    return item(ReadinessLevel.warning, l10n.readinessBackupNoFolder);
  }
  if (backup.error case final error?) {
    return item(
      ReadinessLevel.warning,
      l10n.readinessBackupFailed,
      switch (error) {
        AutoBackupError.unavailable => l10n.autoBackupErrorUnavailable,
        AutoBackupError.permission => l10n.autoBackupErrorPermission,
        AutoBackupError.failed => l10n.autoBackupErrorFailed,
      },
    );
  }
  final last = backup.lastAt;
  return last == null
      ? item(ReadinessLevel.info, l10n.autoBackupNever)
      : item(ReadinessLevel.ok, l10n.autoBackupLast(time(last)));
}
