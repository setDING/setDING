import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_copy.dart';
import '../../data/band_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../widgets/dialogs.dart';
import 'band_labels.dart';

final bandCopyProvider = Provider<BandCopyService>(
  (ref) => BandCopyService(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
  ),
);

/// A song library songs can be copied to: the local library or an
/// organization's library (ADR-0017).
typedef _Library = ({String id, String label, bool isLocal});

Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required Widget Function(T option) tile,
}) {
  if (options.isEmpty) {
    showMessage(context, AppLocalizations.of(context).copyToBandNoTarget);
    return Future.value();
  }
  return showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final o in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, o),
            child: tile(o),
          ),
      ],
    ),
  );
}

/// Copies songs into another song library the user may edit: an
/// organization's library (shared by its bands) or the local library.
Future<void> copySongsToBand(
  BuildContext context,
  WidgetRef ref,
  List<String> songIds,
) async {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(currentBandProvider);
  final libraries = <String, _Library>{};
  for (final b in ref.read(bandsProvider).value ?? const <BandView>[]) {
    if (b.libraryId == current.libraryId || !b.canEditSongs) continue;
    libraries[b.libraryId] = (
      id: b.libraryId,
      label: b.isLocal ? l10n.bandLocal : b.organizationName,
      isLocal: b.isLocal,
    );
  }
  final target = await _pick<_Library>(
    context,
    title: l10n.copyToLibraryTitle,
    options: libraries.values.toList(),
    tile: (l) => ListTile(
      leading: Icon(l.isLocal ? Icons.phone_android : Icons.domain),
      title: Text(l.label),
      subtitle: Text(l.isLocal ? l10n.bandLocalHint : l10n.orgSongsShared),
    ),
  );
  if (target == null || !context.mounted) return;
  await ref.read(bandCopyProvider).copySongs(songIds, target.id);
  if (context.mounted) {
    showMessage(context, l10n.copiedSongs(songIds.length, target.label));
  }
}

/// Copies a set into another band the user may manage sets of; its songs go
/// into that band's song library (unless it is the current one).
Future<void> copySetToBand(
  BuildContext context,
  WidgetRef ref,
  String setId,
) async {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(currentBandProvider);
  final targets = [
    for (final b in ref.read(bandsProvider).value ?? const <BandView>[])
      if (b.id != current.id && b.canManageSets) b,
  ];
  final target = await _pick<BandView>(
    context,
    title: l10n.copyToBandTitle,
    options: targets,
    tile: (b) => ListTile(
      leading: Icon(b.isLocal ? Icons.phone_android : Icons.groups_outlined),
      title: Text(bandLabel(l10n, b)),
      subtitle: Text(bandSubtitle(l10n, b)),
    ),
  );
  if (target == null || !context.mounted) return;
  await ref
      .read(bandCopyProvider)
      .copySet(
        setId,
        targetBandId: target.id,
        targetLibraryId: target.libraryId,
        copySongs: target.libraryId != current.libraryId,
      );
  if (context.mounted) {
    showMessage(context, l10n.copiedSet(bandLabel(l10n, target)));
  }
}
