import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/song_review.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../sync/sync_controller.dart';
import '../widgets/dialogs.dart';
import 'song_attention.dart';

/// Shown on a song that waits for a check or has open mistake reports
/// (ADR-0060). People who may approve the song see why and can approve
/// it; everyone else sees a short hint.
class ReviewBanner extends ConsumerWidget {
  const ReviewBanner({
    super.key,
    required this.song,
    required this.canApprove,
    this.onShowReports,
  });

  final SongEntry song;

  /// The person may approve the song and resolve its reports (whoever may
  /// edit it, ADR-0023).
  final bool canApprove;

  /// Opens the reports of the song; null hides *Show*.
  final VoidCallback? onShowReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reports =
        ref.watch(songReportsProvider(song.id)).value ??
        const <SongReportRow>[];
    final open = reports.where((r) => r.isOpen).length;
    final toReview = song.reviewState != null;
    if (!toReview && open == 0) return const SizedBox.shrink();

    if (!canApprove) {
      // A short hint: the song may not be right yet.
      return Padding(
        key: const Key('review-hint'),
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(
              open > 0 ? songReportedIcon : songToReviewIcon,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                open > 0 ? l10n.songReportedHint : l10n.songToReviewHint,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    final reason = song.reviewReason;
    return Card(
      key: const Key('review-banner'),
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  open > 0 ? songReportedIcon : songToReviewIcon,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (toReview)
                        Text(
                          reason == null
                              ? l10n.attentionToReview
                              : l10n.reviewBannerToReview(reason),
                          style: TextStyle(color: scheme.onSecondaryContainer),
                        ),
                      if (open > 0)
                        Text(
                          l10n.reviewBannerReports(open),
                          style: TextStyle(color: scheme.onSecondaryContainer),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (open > 0 && onShowReports != null)
                  TextButton(
                    key: const Key('review-show-reports'),
                    onPressed: onShowReports,
                    child: Text(l10n.showReports),
                  ),
                if (toReview)
                  FilledButton.tonal(
                    key: const Key('review-approve'),
                    onPressed: () => approveSong(context, ref, song.id),
                    child: Text(l10n.approveSong),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Approves [songId] (ADR-0060); with open reports, offers to resolve them
/// in the same step.
Future<void> approveSong(
  BuildContext context,
  WidgetRef ref,
  String songId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final review = ref.read(songReviewRepositoryProvider);
  final open = (await review.openReports(songId)).length;
  var resolve = false;
  if (open > 0) {
    if (!context.mounted) return;
    resolve = await confirm(
      context,
      title: l10n.resolveReportsTitle,
      message: l10n.resolveReportsMessage(open),
      action: l10n.resolveReports,
      destructive: false,
    );
  }
  await review.approve(songId, resolveReports: resolve);
  showMessageOn(messenger, l10n.songApproved);
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
}

/// Sets [songId] to wait for a check (ADR-0060), with a reason asked for.
Future<void> setSongToReview(
  BuildContext context,
  WidgetRef ref,
  String songId,
) async {
  final l10n = AppLocalizations.of(context);
  final reason = await askText(
    context,
    title: l10n.setToReviewTitle,
    label: l10n.reviewReasonLabel,
    hint: l10n.reviewReasonHint,
    allowEmpty: true,
  );
  if (reason == null) return;
  await ref
      .read(songReviewRepositoryProvider)
      .setToReview(songId, reason: reason);
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
}
