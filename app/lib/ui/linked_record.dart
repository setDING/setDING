import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/band_providers.dart';
import '../data/database.dart';
import '../data/set_repository.dart' show watchAnySet;
import '../data/song_repository.dart' show watchAnySong;
import '../data/storage_providers.dart';
import '../l10n/generated/app_localizations.dart';
import '../sync/auth_providers.dart';
import '../sync/sync_controller.dart';
import 'routes.dart';
import 'widgets/dialogs.dart';
import 'widgets/logo.dart' show SplashScreen;

/// A set on this device by its id, deleted ones too.
final _linkedSetProvider = StreamProvider.autoDispose
    .family<SetlistEntry?, String>((ref, id) {
      return watchAnySet(ref.watch(databaseProvider), id);
    });

/// A song on this device by its id, deleted ones too.
final _linkedSongProvider = StreamProvider.autoDispose
    .family<SongEntry?, String>((ref, id) {
      return watchAnySong(ref.watch(databaseProvider), id);
    });

/// A set or a song opened by its path, e.g. from a link (ADR-0065 §3):
///
/// - on this device, in a band (a library) of the person other than the
///   current one: switches to it with a hint, so the screen shows it with
///   that band's rights and arrangements;
/// - on this device otherwise (e.g. a substitute's set, ADR-0061): shown as
///   it is;
/// - not on this device (not synced yet, deleted, or no access): *Not
///   available on this device* with *Sync now*; still missing after the
///   sync, it says so without naming the record, which the device does not
///   know.
class LinkedRecord extends ConsumerStatefulWidget {
  const LinkedRecord.set({super.key, required this.id, required this.child})
    : isSet = true;

  const LinkedRecord.song({super.key, required this.id, required this.child})
    : isSet = false;

  final String id;
  final bool isSet;

  /// The set's or the song's screen.
  final Widget child;

  @override
  ConsumerState<LinkedRecord> createState() => _LinkedRecordState();
}

class _LinkedRecordState extends ConsumerState<LinkedRecord> {
  /// The band or library was selected once; never again, so a choice the
  /// app does not keep cannot loop.
  bool _switched = false;

  /// A sync ran while the record was missing.
  bool _synced = false;

  /// The band or library to switch to, its name, and whether it is the
  /// current one already; null when the record is not in one of the
  /// person's bands or libraries.
  ({String name, bool current, Future<void> Function() select})? _target(
    AppLocalizations l10n,
    Object record,
  ) {
    if (record is SetlistEntry) {
      final band = (ref.watch(bandsProvider).value ?? const [])
          .where((b) => b.id == record.bandId)
          .firstOrNull;
      if (band == null) return null;
      return (
        name: band.isLocal ? l10n.bandLocal : band.name,
        current: ref.watch(currentBandProvider).id == band.id,
        select: () => ref.read(selectedBandIdProvider.notifier).select(band.id),
      );
    }
    final song = record as SongEntry;
    final library = (ref.watch(librariesProvider).value ?? const [])
        .where((l) => l.id == song.libraryId)
        .firstOrNull;
    if (library == null) return null;
    return (
      name: library.isLocal ? l10n.bandLocal : library.name,
      current: ref.watch(currentLibraryProvider).id == library.id,
      select: () =>
          ref.read(selectedLibraryIdProvider.notifier).select(library.id),
    );
  }

  void _switch(String name, Future<void> Function() select) {
    _switched = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await select();
      if (!mounted) return;
      showMessage(context, AppLocalizations.of(context).linkSwitchedTo(name));
    });
  }

  Future<void> _sync() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
    if (mounted) setState(() => _synced = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final AsyncValue<Object?> value = widget.isSet
        ? ref.watch(_linkedSetProvider(widget.id))
        : ref.watch(_linkedSongProvider(widget.id));
    if (!value.hasValue) return const Scaffold(body: SplashScreen(busy: true));
    final record = value.value;
    final deleted = switch (record) {
      SetlistEntry(:final deleted) => deleted,
      SongEntry(:final deleted) => deleted,
      _ => false,
    };
    if (record == null || deleted) {
      return _NotAvailable(synced: _synced || deleted, onSync: _sync);
    }
    final target = _target(l10n, record);
    if (target != null && !target.current && !_switched) {
      _switch(target.name, target.select);
    }
    // Until the switch is done, so the screen never shows the record with
    // the rights of another band.
    if (target != null && !target.current) {
      return const Scaffold(body: SplashScreen(busy: true));
    }
    return widget.child;
  }
}

/// *Not available on this device*: never the title, which the device does
/// not know (or must not show, for a deleted record).
class _NotAvailable extends ConsumerWidget {
  const _NotAvailable({required this.synced, required this.onSync});

  /// A sync ran (or the record is deleted): it is not just missing yet.
  final bool synced;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authProvider) != null;
    final syncing = ref.watch(syncControllerProvider.select((s) => s.running));
    final String message;
    final Widget? action;
    if (!signedIn) {
      message = l10n.linkSignInMessage;
      action = FilledButton(
        key: const Key('link-sign-in'),
        onPressed: () => context.push(AppPaths.signIn),
        child: Text(l10n.accountSignIn),
      );
    } else if (synced) {
      message = l10n.linkNoAccessMessage;
      action = null;
    } else {
      message = l10n.linkNotAvailableMessage;
      action = FilledButton.icon(
        key: const Key('link-sync'),
        icon: syncing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        onPressed: syncing ? null : onSync,
        label: Text(l10n.syncNow),
      );
    }
    return Scaffold(
      key: const Key('link-not-available'),
      appBar: AppBar(title: Text(l10n.linkNotAvailableTitle)),
      body: EmptyState(icon: Icons.link_off, message: message, action: action),
    );
  }
}
