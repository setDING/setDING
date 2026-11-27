import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../data/band_providers.dart';
import '../../data/change_log.dart';
import '../../data/database.dart';
import '../../data/person_name.dart';
import '../../data/storage_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart'
    show nameFormatProvider, sharedPreferencesProvider;
import '../sets/sets_screen.dart' show openSet;
import '../routes.dart';

/// When this device last showed the overview (ADR-0045): a device
/// setting, never synced. Null on a new installation. The overview marks
/// it when it is left ([markShown]), so the recent changes stay visible
/// while the person looks at them.
class OverviewLastShownNotifier extends Notifier<DateTime?> {
  static const key = 'overviewLastShown';

  @override
  DateTime? build() {
    final ms = ref.watch(sharedPreferencesProvider).getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// The overview was shown until [now].
  Future<void> markShown([DateTime? now]) async {
    final at = now ?? DateTime.now();
    state = at;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(key, at.millisecondsSinceEpoch);
  }
}

final overviewLastShownProvider =
    NotifierProvider<OverviewLastShownNotifier, DateTime?>(
      OverviewLastShownNotifier.new,
    );

final changeLogProvider = Provider<ChangeLogRepository>(
  (ref) => ChangeLogRepository(ref.watch(databaseProvider)),
);

/// The changes by other people in the current band and its organization
/// (ADR-0045), one per song or set, newest first: since the overview was
/// last shown, or all of them ([all], the last 30 days).
final recentChangesProvider = StreamProvider.autoDispose
    .family<List<RecentChange>, bool>((ref, all) {
      final band = ref.watch(currentBandProvider);
      if (band.isLocal) return Stream.value(const <RecentChange>[]);
      return ref.watch(changeLogProvider).watch([
        band.id,
        ?band.organizationId,
      ], since: all ? null : ref.watch(overviewLastShownProvider));
    });

/// Names of the people of the current band and its organization by user
/// ID, from the members stored on this device; a person without a name is
/// shown by their e-mail address.
final personNamesProvider = Provider.autoDispose<Map<String, String>>((ref) {
  final band = ref.watch(currentBandProvider);
  final format = ref.watch(nameFormatProvider);
  String name(PersonName person, String? email) {
    final shown = person.format(format);
    return shown.isNotEmpty ? shown : (email ?? '');
  }

  final org = band.organizationId;
  return {
    if (org != null)
      for (final m
          in ref.watch(orgMembersProvider(org)).value ??
              const <OrgMembershipEntry>[])
        m.userId: name(m.person, m.userEmail),
    for (final m
        in ref.watch(bandMembersProvider(band.id)).value ??
            const <MembershipEntry>[])
      m.userId: name(m.person, m.userEmail),
  }..removeWhere((_, n) => n.isEmpty);
});

/// Entries the overview card shows at most; *Show all* lists all of them.
const recentChangesOnCard = 10;

/// What changed, e.g. "2 songs added, 1 removed, sequence of "Song"
/// changed".
String describeChange(AppLocalizations l10n, RecentChange change) {
  final d = change.details;
  final text = switch (change.kind) {
    ChangeKind.songAdded => l10n.changeSongAdded,
    ChangeKind.songChanged =>
      d.text && d.pdf
          ? l10n.changeSongTextAndPdf
          : d.pdf
          ? l10n.changeSongPdf
          : l10n.changeSongText,
    ChangeKind.setAdded => l10n.changeNewSet,
    ChangeKind.setChanged => [
      if (d.added > 0) l10n.changeSetAdded(d.added),
      if (d.removed > 0)
        d.added > 0
            ? l10n.changeSetAlsoRemoved(d.removed)
            : l10n.changeSetRemoved(d.removed),
      if (d.sequences.isNotEmpty)
        l10n.changeSetSequence(
          d.sequences.map((t) => l10n.changeQuoted(t)).join(', '),
        ),
    ].join(', '),
  };
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

/// One change: the song or set, what changed and who changed it. Opens
/// the song or set.
class RecentChangeTile extends ConsumerWidget {
  const RecentChangeTile(this.change, {super.key, this.showDate = false});

  final RecentChange change;

  /// With the date of the change (the full list).
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = ref.watch(
      personNamesProvider.select((names) => names[change.userId]),
    );
    final subtitle = [
      describeChange(l10n, change),
      if (name != null) l10n.changeBy(name),
      if (showDate)
        MaterialLocalizations.of(context).formatShortDate(change.at),
    ].join(' · ');
    final isSet = change.kind.isSet;
    return ListTile(
      key: ValueKey('recent-change-${change.recordId}'),
      leading: Icon(switch (change.kind) {
        ChangeKind.songAdded => Icons.library_add_outlined,
        ChangeKind.songChanged => Icons.edit_note,
        ChangeKind.setChanged => Icons.queue_music,
        ChangeKind.setAdded => Icons.playlist_add,
      }),
      title: Text(change.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      onTap: () => isSet
          ? openSet(context, ref, change.recordId, wide: false)
          : context.push<void>(AppPaths.song(change.recordId)),
    );
  }
}

/// All changes by other people of the last 30 days (*Show all*).
class RecentChangesScreen extends ConsumerWidget {
  const RecentChangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final changes = ref.watch(recentChangesProvider(true)).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.overviewRecentChanges)),
      body: changes == null
          ? const SizedBox.shrink()
          : changes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.recentChangesEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              key: const Key('recent-changes-list'),
              itemCount: changes.length,
              itemBuilder: (context, i) =>
                  RecentChangeTile(changes[i], showDate: true),
            ),
    );
  }
}
