import 'dart:async';

import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/song_review.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../../sync/auth_providers.dart';
import '../../sync/sync_controller.dart';
import '../overview/recent_changes.dart' show personNamesProvider;
import '../widgets/dialogs.dart';
import '../live/page_turner.dart' show isPageTurnKey;
import '../widgets/side_panel.dart';
import 'song_attention.dart';

/// Name of [category] in the person's language.
String reportCategoryLabel(
  AppLocalizations l10n,
  SongReportCategory category,
) => switch (category) {
  SongReportCategory.chords => l10n.reportCategoryChords,
  SongReportCategory.lyrics => l10n.reportCategoryLyrics,
  SongReportCategory.key => l10n.reportCategoryKey,
  SongReportCategory.sequence => l10n.reportCategorySequence,
  SongReportCategory.tempo => l10n.reportCategoryTempo,
  SongReportCategory.formatting => l10n.reportCategoryFormatting,
  SongReportCategory.sheetMusic => l10n.reportCategorySheetMusic,
  SongReportCategory.other => l10n.reportCategoryOther,
};

/// Where in the song, in words, or null.
String? reportLocationText(
  AppLocalizations l10n,
  SongReportLocation? location,
) {
  if (location == null) return null;
  final parts = [
    if (location.section case final s?)
      (location.occurrence ?? 1) > 1 ? '$s (${location.occurrence})' : s,
    if (location.attachmentPage case final p?)
      l10n.reportLocationPdfPage(p)
    else if (location.page case final p?)
      l10n.reportLocationPage(p),
    if (location.section == null)
      if (location.line case final l?) l10n.reportLocationLine(l + 1),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Asks for a mistake report of [songId] (ADR-0060): category, comment
/// and where in the song the person was ([location]). Stored on the device
/// and synced later, so it works offline and does not stop a set in live
/// mode. Returns whether a report was sent.
Future<bool> reportMistake(
  BuildContext context,
  WidgetRef ref, {
  required String songId,
  SongReportLocation? location,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await showModalBottomSheet<_ReportDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ReportSheet(location: location),
  );
  if (result == null) return false;
  await ref
      .read(songReviewRepositoryProvider)
      .report(
        songId,
        category: result.category,
        comment: result.comment,
        location: location,
      );
  showMessageOn(messenger, l10n.reportSent);
  // Outside live mode the report goes out at once (paused in live mode).
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  return true;
}

typedef _ReportDraft = ({SongReportCategory category, String comment});

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({this.location});

  final SongReportLocation? location;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  SongReportCategory? _category;
  final _comment = TextEditingController();
  final _commentFocus = FocusNode();

  @override
  void dispose() {
    _comment.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  /// A page turner (pedal) closes the sheet on stage (ADR-0060): it sends
  /// the report once a category is chosen, otherwise it cancels. Not while
  /// the comment is typed, where the same keys move the cursor.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        _commentFocus.hasFocus ||
        !isPageTurnKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (_category == null) {
      Navigator.pop(context);
    } else {
      _send();
    }
    return KeyEventResult.handled;
  }

  void _send() {
    final category = _category;
    if (category == null) return;
    Navigator.pop<_ReportDraft>(context, (
      category: category,
      comment: _comment.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final place = reportLocationText(l10n, widget.location);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        key: const Key('report-sheet'),
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportMistake, style: theme.textTheme.titleLarge),
            if (place != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.reportLocation(place),
                key: const Key('report-location'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in SongReportCategory.values)
                  ChoiceChip(
                    key: ValueKey('report-category-${c.serverName}'),
                    label: Text(reportCategoryLabel(l10n, c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('report-comment'),
              controller: _comment,
              focusNode: _commentFocus,
              minLines: 2,
              maxLines: 5,
              maxLength: maxReportTextLength,
              decoration: InputDecoration(
                labelText: l10n.reportComment,
                hintText: l10n.reportCommentHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  key: const Key('report-send'),
                  onPressed: _category == null ? null : _send,
                  child: Text(l10n.reportSend),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The mistake reports of a song (ADR-0060), in a side panel: open ones
/// first, resolved and withdrawn ones folded away as history. The author
/// withdraws an open report; whoever may approve the song resolves it
/// with an answer, or opens it again. Members only get their own reports
/// from the server.
class SongReportsPanel extends ConsumerWidget {
  const SongReportsPanel({
    super.key,
    required this.song,
    required this.canResolve,
  });

  final SongEntry song;

  /// The person may resolve reports (whoever may edit the song).
  final bool canResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reports =
        ref.watch(songReportsProvider(song.id)).value ??
        const <SongReportRow>[];
    final open = [
      for (final r in reports)
        if (r.isOpen) r,
    ];
    final closed = [
      for (final r in reports)
        if (!r.isOpen) r,
    ];
    return SidePanel(
      key: const Key('song-reports'),
      icon: songReportedIcon,
      title: l10n.reportsTitle,
      children: [
        FilledButton.tonalIcon(
          key: const Key('reports-add'),
          icon: const Icon(Icons.add),
          label: Text(l10n.reportMistake),
          onPressed: () => reportMistake(context, ref, songId: song.id),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          Text(l10n.reportsEmpty)
        else ...[
          for (final r in open) _ReportCard(report: r, canResolve: canResolve),
          if (closed.isNotEmpty)
            ExpansionTile(
              key: const Key('reports-closed'),
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.reportsClosed(closed.length)),
              children: [
                for (final r in closed)
                  _ReportCard(report: r, canResolve: canResolve),
              ],
            ),
        ],
      ],
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report, required this.canResolve});

  final SongReportRow report;
  final bool canResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final review = ref.read(songReviewRepositoryProvider);
    final me = ref.watch(authProvider.select((u) => u?.id)) ?? localOwnerId;
    final names = ref.watch(personNamesProvider);
    final mine = report.authorId == me;
    final author = mine
        ? l10n.reportByYou
        : switch (names[report.authorId]) {
            final name? => l10n.reportBy(name),
            null => null,
          };
    final place = reportLocationText(l10n, report.locationValue);
    final status = report.statusValue;
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);

    Future<void> act(Future<void> Function() action, String message) async {
      final messenger = ScaffoldMessenger.of(context);
      await action();
      showMessageOn(messenger, message);
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    }

    return Card(
      key: ValueKey('report-${report.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reportCategoryLabel(l10n, report.categoryValue),
              style: theme.textTheme.titleSmall,
            ),
            if (report.comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(report.comment),
            ],
            const SizedBox(height: 4),
            Text(
              [
                ?author,
                ?place,
                formatReportDate(context, report.createdAt),
                if (status == SongReportStatus.withdrawn) l10n.reportWithdrawn,
              ].join(' · '),
              style: muted,
            ),
            if (status == SongReportStatus.resolved) ...[
              const SizedBox(height: 4),
              Text(
                report.resolution == null
                    ? l10n.reportResolvedNoAnswer
                    : l10n.reportAnswer(report.resolution!),
                key: const Key('report-answer'),
              ),
            ],
            if (report.isOpen && (mine || canResolve) ||
                status == SongReportStatus.resolved && canResolve)
              Wrap(
                spacing: 8,
                children: [
                  if (report.isOpen && mine)
                    TextButton(
                      key: const Key('report-withdraw'),
                      onPressed: () => act(
                        () => review.withdraw(report.id),
                        l10n.reportWithdrawnMessage,
                      ),
                      child: Text(l10n.reportWithdraw),
                    ),
                  if (report.isOpen && canResolve)
                    TextButton(
                      key: const Key('report-resolve'),
                      onPressed: () async {
                        final answer = await askText(
                          context,
                          title: l10n.resolveReport,
                          label: l10n.reportAnswerLabel,
                          hint: l10n.reportAnswerHint,
                          multiline: true,
                          allowEmpty: true,
                        );
                        if (answer == null || !context.mounted) return;
                        await act(
                          () => review.resolve(report.id, resolution: answer),
                          l10n.reportResolvedMessage,
                        );
                      },
                      child: Text(l10n.resolveReports),
                    ),
                  if (status == SongReportStatus.resolved && canResolve)
                    TextButton(
                      key: const Key('report-reopen'),
                      onPressed: () => act(
                        () => review.reopen(report.id),
                        l10n.reportReopenedMessage,
                      ),
                      child: Text(l10n.reportReopen),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The date of a report, short.
String formatReportDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatShortDate(date);

/// Preference with the reports whose answer the person has seen.
const _seenAnswersKey = 'seenReportAnswers';

/// After a sync (not in live mode): tells the person once that a report of
/// theirs was resolved by someone else, with the answer (ADR-0060). On the
/// first run on a device, answers already there count as seen. Call from
/// the home screen's `build`.
void listenForReportAnswers(BuildContext context, WidgetRef ref) {
  ref.listen(syncControllerProvider, (previous, next) async {
    final report = next.lastReport;
    if (report == null ||
        identical(report, previous?.lastReport) ||
        next.afterLive) {
      return;
    }
    final me = ref.read(authProvider)?.id;
    if (me == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final prefs = ref.read(sharedPreferencesProvider);
    final answers = await ref
        .read(songReviewRepositoryProvider)
        .answeredReports(me);
    final stored = prefs.getStringList(_seenAnswersKey);
    final seen = {...?stored};
    final fresh = [
      for (final a in answers)
        if (!seen.contains(a.report.id)) a,
    ];
    if (fresh.isEmpty) return;
    await prefs.setStringList(_seenAnswersKey, [
      ...seen,
      for (final a in fresh) a.report.id,
    ]);
    if (stored == null) return; // first run: nothing new to tell
    final message = fresh.length > 1
        ? l10n.reportsAnswered(fresh.length)
        : switch (fresh.single) {
            (report: final r, title: final title) when r.resolution != null =>
              l10n.reportAnswered(title, r.resolution!),
            (report: _, title: final title) => l10n.reportAnsweredNoText(title),
          };
    showMessageOn(
      messenger,
      message,
      key: const Key('report-answered'),
      duration: const Duration(seconds: 10),
    );
  });
}
