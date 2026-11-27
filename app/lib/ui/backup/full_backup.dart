import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../data/import_export.dart' show ImportFile;
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../../sync/sync_controller.dart';
import '../sets/sets_screen.dart' show formatGigDate;
import '../widgets/dialogs.dart';
import '../widgets/file_actions.dart';
import 'backup_actions.dart';
import '../routes.dart';
import 'replace_local.dart' show confirmLocalReplace;

export '../../data/auto_backup.dart' show lastBackupKey;

// Full backup in the settings (#639, ADR-0043): every library the person may
// back up, their own adjustments of the other organizations, and their
// settings, in one archive; restoring it; the reminder for the local library.

/// When the reminder was last shown (ISO 8601), at most every 7 days.
const backupReminderKey = 'backupReminderAt';

/// After how long without a backup the local library is due.
const backupReminderAfter = Duration(days: 30);

/// The last backup of the local library on this device, or null.
DateTime? lastBackupAt(WidgetRef ref) => DateTime.tryParse(
  ref.read(sharedPreferencesProvider).getString(lastBackupKey) ?? '',
);

/// Records a saved backup of the local library.
Future<void> recordBackup(WidgetRef ref) => ref
    .read(sharedPreferencesProvider)
    .setString(lastBackupKey, DateTime.now().toIso8601String());

/// Days since the local library's oldest change that is not in a backup,
/// when that is more than [backupReminderAfter] ago; else null. The demo
/// song alone does not count. Not on the web client (no local library).
final backupReminderProvider = FutureProvider.autoDispose<int?>((ref) async {
  if (ref.watch(webClientProvider)) return null;
  // Not while the local library is hidden (ADR-0054).
  if (!ref.watch(localLibraryShownProvider)) return null;
  // Not while automatic backups succeed (ADR-0054).
  if (ref.watch(
    autoBackupProvider.select(
      (s) => s.active && s.error == null && s.lastAt != null,
    ),
  )) {
    return null;
  }
  final prefs = ref.watch(sharedPreferencesProvider);
  final last = DateTime.tryParse(prefs.getString(lastBackupKey) ?? '');
  final oldest = await ref
      .watch(backupServiceProvider)
      .oldestLocalChange(since: last);
  if (oldest == null) return null;
  final age = DateTime.now().difference(last ?? oldest);
  return age > backupReminderAfter ? age.inDays : null;
});

/// Whether the reminder may be shown now (at most every 7 days); marks it
/// shown.
bool takeBackupReminder(WidgetRef ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final shown = DateTime.tryParse(prefs.getString(backupReminderKey) ?? '');
  if (shown != null &&
      DateTime.now().difference(shown) < const Duration(days: 7)) {
    return false;
  }
  unawaited(
    prefs.setString(backupReminderKey, DateTime.now().toIso8601String()),
  );
  return true;
}

/// The settings for the archive: personal and device settings, without the
/// server.
({Map<String, Object?> personal, Map<String, Object?> device}) _settingsOf(
  AppSettings settings,
) {
  final personal = <String, Object?>{}, device = <String, Object?>{};
  for (final MapEntry(:key, :value) in settings.toJson().entries) {
    if (key == 'serverUrl') continue;
    (AppSettings.scopes[key] == SettingSyncScope.personal
            ? personal
            : device)[key] =
        value;
  }
  return (personal: personal, device: device);
}

/// Saves a full backup (#639): the local library and every organization the
/// person may back up in full, their own adjustments and annotations of the
/// other organizations, and their settings. Signed in, a sync runs first.
Future<void> exportFullBackup(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final web = ref.read(webClientProvider);
  // Also the local library when it is hidden (ADR-0054).
  final libraries =
      ref.read(allLibrariesProvider).value ??
      (web ? const <LibraryView>[] : const [LibraryView.local]);
  final full = [
    for (final l in libraries)
      if (l.canExportLibrary) l,
  ];
  final personalOnly = [
    for (final l in libraries)
      if (!l.canExportLibrary) l,
  ];
  final organizations = libraries.any((l) => !l.isLocal);
  final service = ref.read(backupServiceProvider);
  final fetcher = ref.read(attachmentFetcherProvider);
  await runBackupExport(
    context,
    ref,
    sync: organizations,
    check: () async {
      for (final l in full) {
        final blocker = await service.blocker(l.id, checkFiles: !web);
        if (blocker != null) return blocker;
      }
      // Pending changes of the other organizations, e.g. adjustments.
      if (personalOnly.isNotEmpty) {
        return service.blocker(personalOnly.first.id, checkFiles: false);
      }
      return null;
    },
    build: () {
      final settings = _settingsOf(ref.read(settingsProvider));
      String name(LibraryView l) => l.isLocal ? l10n.bandLocal : l.name;
      return service.exportAll(
        libraries: [for (final l in full) (id: l.id, name: name(l))],
        personalOnly: [for (final l in personalOnly) (id: l.id, name: name(l))],
        personalSettings: settings.personal,
        deviceSettings: settings.device,
        readFile: web
            ? (a) async => (await fetcher.fetch(a.id))?.readAsBytes()
            : null,
      );
    },
    fileName: BackupService.fileName(l10n.backupAllName, DateTime.now()),
    recordLocal: full.any((l) => l.isLocal),
  );
}

/// Restores a backup chosen with [pick]: a full backup with its own dialog,
/// the archive of one library into the current library (ADR-0043).
Future<void> restoreBackup(
  BuildContext context, {
  Future<List<ImportFile>> Function({List<String>? extensions}) pick =
      pickFiles,
}) async {
  final files = await pick(extensions: const ['zip']);
  if (files.isEmpty || !context.mounted) return;
  await openBackup(context, files.single.bytes);
}

/// Opens a backup archive: the restore dialog of a full backup, or the
/// import of one library into the current library.
Future<void> openBackup(BuildContext context, Uint8List zip) async {
  final l10n = AppLocalizations.of(context);
  final FullBackup backup;
  try {
    backup = await BackupService.readFull(zip);
  } on BackupFormatException catch (e) {
    if (context.mounted) {
      showMessage(
        context,
        e.newerVersion == null ? l10n.backupInvalid : l10n.backupNewer,
      );
    }
    return;
  }
  if (!context.mounted) return;
  if (!backup.isFull) {
    await importBackup(context, zip);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _FullRestoreDialog(backup: backup),
  );
}

/// The tiles of the *Backup* section of *Storage & info*: back up
/// everything and restore (#891).
class BackupTiles extends ConsumerWidget {
  const BackupTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final web = ref.watch(webClientProvider);
    final last = lastBackupAt(ref);
    final due = ref.watch(backupReminderProvider).value != null;
    return Column(
      children: [
        ListTile(
          key: const Key('backup-all'),
          leading: Icon(
            due ? Icons.warning_amber_rounded : Icons.backup_outlined,
          ),
          title: Text(l10n.backupAll),
          subtitle: Text(
            [
              l10n.backupAllHint,
              if (!web)
                last == null
                    ? l10n.backupNever
                    : l10n.backupLast(formatGigDate(context, last)),
            ].join('\n'),
          ),
          onTap: () async {
            await exportFullBackup(context, ref);
            ref.invalidate(backupReminderProvider);
          },
        ),
        ListTile(
          key: const Key('backup-restore'),
          leading: const Icon(Icons.restore),
          title: Text(l10n.backupRestore),
          subtitle: Text(l10n.backupRestoreHint),
          onTap: () => restoreBackup(context),
        ),
      ],
    );
  }
}

class _FullRestoreDialog extends ConsumerStatefulWidget {
  const _FullRestoreDialog({required this.backup});

  final FullBackup backup;

  @override
  ConsumerState<_FullRestoreDialog> createState() => _FullRestoreDialogState();
}

class _FullRestoreDialogState extends ConsumerState<_FullRestoreDialog> {
  /// Library of the backup (by index) -> target library (null: skip).
  final _targets = <int, String?>{};
  bool _personal = true;
  bool _settings = false;
  BackupDuplicates _duplicates = BackupDuplicates.keepExisting;
  bool _busy = false;
  _RestoreResult? _result;

  /// Replace the local library by the backup's local library (ADR-0054).
  bool _replaceLocal = false;

  /// Whether the library [index] of the backup replaces the local library.
  bool _replaces(int index) =>
      _replaceLocal &&
      _targets[index] == localBandId &&
      BackupService.isLocalArchive(widget.backup.libraries[index]);

  /// Libraries the person may import songs into.
  List<LibraryView> _libraries() => [
    for (final l
        in ref.watch(librariesProvider).value ??
            (ref.watch(localLibraryShownProvider)
                ? const [LibraryView.local]
                : const <LibraryView>[]))
      if (l.canCreateSongs) l,
  ];

  String? _defaultTarget(BackupContents library, List<LibraryView> targets) {
    final source = library.manifest['source'] as Map?;
    final id = source?['id'];
    return targets.where((t) => t.id == id).firstOrNull?.id;
  }

  /// Archive band -> a band of [libraryId] whose sets the person manages:
  /// the same name, else the only one, else the first.
  Map<String, String?> _bandsFor(BackupContents library, String libraryId) {
    final bands = [
      for (final b in ref.read(bandsProvider).value ?? const <BandView>[])
        if ((libraryId == localBandId
                ? b.isLocal
                : b.organizationId == libraryId) &&
            b.canManageSets)
          b,
    ];
    return {
      for (final b in library.bands)
        b['id'] as String:
            bands
                .where(
                  (t) =>
                      t.name.trim().toLowerCase() ==
                      (b['name'] as String? ?? '').trim().toLowerCase(),
                )
                .firstOrNull
                ?.id ??
            bands.firstOrNull?.id,
    };
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    // The preview and the safety backup first (ADR-0054).
    final replaced = [
      for (final (index, library) in widget.backup.libraries.indexed)
        if (_replaces(index)) library,
    ].firstOrNull;
    if (replaced != null && !await confirmLocalReplace(context, replaced)) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final results = <BackupImportResult>[];
      for (final (index, library) in widget.backup.libraries.indexed) {
        final target = _targets[index];
        if (target == null) continue;
        if (_replaces(index)) {
          results.add(await service.replaceLocal(library));
          ref.invalidate(backupReminderProvider);
          continue;
        }
        results.add(
          await service.import(
            library,
            libraryId: target,
            bands: _bandsFor(library, target),
            duplicates: _duplicates,
          ),
        );
      }
      var personal = 0;
      if (_personal) {
        for (final p in widget.backup.personal) {
          personal += await service.restorePersonal(p);
        }
      }
      if (_settings) {
        final restored = {
          ...widget.backup.personalSettings,
          ...widget.backup.deviceSettings,
        }..remove('serverUrl');
        await ref
            .read(settingsProvider.notifier)
            .update(
              (s) => AppSettings.fromJson({
                ...s.toJson(),
                ...restored,
                'serverUrl': s.serverUrl,
              }),
            );
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _result = _RestoreResult(results, personal, _settings);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, l10n.errorGeneric('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result case final result?) return _report(context, result);
    final l10n = AppLocalizations.of(context);
    final backup = widget.backup;
    final targets = _libraries();
    for (final (index, library) in backup.libraries.indexed) {
      if (!_targets.containsKey(index) && targets.isNotEmpty) {
        _targets[index] = _defaultTarget(library, targets);
      }
    }
    final personal = backup.personal.where((p) => p.songs > 0).toList();
    return AlertDialog(
      key: const Key('backup-full-restore'),
      title: Text(l10n.backupRestoreTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.backupImportCopyHint),
              for (final (index, library) in backup.libraries.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DropdownButtonFormField<String?>(
                    key: Key('backup-library-$index'),
                    initialValue: _targets[index],
                    decoration: InputDecoration(
                      labelText: l10n.backupLibraryTo(
                        library.sourceName,
                        library.songs.length,
                        library.sets.length,
                      ),
                    ),
                    items: [
                      for (final t in targets)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(t.isLocal ? l10n.bandLocal : t.name),
                        ),
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.backupSkipSets),
                      ),
                    ],
                    onChanged: (v) => setState(() => _targets[index] = v),
                  ),
                ),
              // The local library of the backup can replace this one's.
              for (final (index, library) in backup.libraries.indexed)
                if (_targets[index] == localBandId &&
                    BackupService.isLocalArchive(library))
                  CheckboxListTile(
                    key: const Key('backup-restore-replace-local'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _replaceLocal,
                    onChanged: (v) =>
                        setState(() => _replaceLocal = v ?? false),
                    title: Text(l10n.backupModeReplace),
                    subtitle: Text(l10n.backupModeReplaceHint),
                  ),
              const SizedBox(height: 12),
              Text(l10n.backupImportDifferingAll),
              RadioGroup<BackupDuplicates>(
                groupValue: _duplicates,
                onChanged: (v) => setState(() => _duplicates = v!),
                child: Column(
                  children: [
                    RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: BackupDuplicates.keepExisting,
                      title: Text(l10n.backupKeepExisting),
                    ),
                    RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: BackupDuplicates.addAll,
                      title: Text(l10n.backupAddAll),
                    ),
                  ],
                ),
              ),
              if (personal.isNotEmpty)
                CheckboxListTile(
                  key: const Key('backup-restore-personal'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _personal,
                  onChanged: (v) => setState(() => _personal = v ?? false),
                  title: Text(l10n.backupRestorePersonal),
                  subtitle: Text(
                    personal
                        .map((p) => l10n.backupPersonalOf(p.name, p.songs))
                        .join('\n'),
                  ),
                ),
              if (backup.hasSettings)
                CheckboxListTile(
                  key: const Key('backup-restore-settings'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _settings,
                  onChanged: (v) => setState(() => _settings = v ?? false),
                  title: Text(l10n.backupRestoreSettings),
                  subtitle: Text(l10n.backupRestoreSettingsHint),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('backup-full-restore-start'),
          onPressed: _busy ? null : _restore,
          child: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.backupRestoreStart),
        ),
      ],
    );
  }

  Widget _report(BuildContext context, _RestoreResult result) {
    final l10n = AppLocalizations.of(context);
    final additional = [for (final r in result.libraries) ...r.additional];
    int sum(int Function(BackupImportResult) f) =>
        result.libraries.fold(0, (n, r) => n + f(r));
    return AlertDialog(
      key: const Key('backup-full-restore-result'),
      title: Text(l10n.backupRestoreDone),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  l10n.backupResultSongs(sum((r) => r.imported)),
                  if (sum((r) => r.identical) > 0)
                    l10n.backupResultIdentical(sum((r) => r.identical)),
                  if (sum((r) => r.keptExisting) > 0)
                    l10n.backupResultKept(sum((r) => r.keptExisting)),
                  l10n.backupResultSets(sum((r) => r.sets)),
                  if (sum((r) => r.files) > 0)
                    l10n.backupResultFiles(sum((r) => r.files)),
                  if (result.personal > 0)
                    l10n.backupResultPersonal(result.personal),
                  if (result.settings) l10n.backupResultSettings,
                ].join('\n'),
              ),
              if (additional.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.backupResultAdditional(additional.length)),
                for (final song in additional)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.library_music_outlined),
                    title: Text(song.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push<void>(AppPaths.song(song.id)),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _RestoreResult {
  const _RestoreResult(this.libraries, this.personal, this.settings);

  final List<BackupImportResult> libraries;
  final int personal;
  final bool settings;
}
