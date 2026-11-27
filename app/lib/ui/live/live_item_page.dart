import 'package:chordpro/chordpro.dart' hide Key;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../sync/sync_controller.dart';
import '../../data/attachment_lookup.dart';
import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/song_providers.dart';
import '../../data/song_repository.dart';
import '../../data/storage_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../annotations/annotated_page.dart';
import '../annotations/annotation_editor.dart';
import '../platform/stored_file_view.dart';
import '../render/render_cache.dart';
import '../sets/set_item_label.dart';
import 'live_preparation.dart';
import 'pdf_spread_view.dart';
import 'live_chordpro_page.dart';
import 'song_page_controller.dart';
import 'live_item.dart';

/// One item of the set on stage: a song as ChordPro or PDF, or a marker.
class LiveItemPage extends ConsumerWidget {
  const LiveItemPage({
    super.key,
    required this.item,
    required this.index,
    required this.scrollController,
    required this.pdfController,
    required this.spreadController,
    required this.fitController,
    required this.songPageController,
    required this.preparation,
    required this.onTap,
    required this.annotations,
  });

  final LiveItem item;

  /// Position of the item in the set.
  final int index;
  final ScrollController scrollController;
  final PdfViewerController pdfController;

  /// How far the page is built (issue #296).
  final PagePreparation preparation;

  /// Position when the PDF is shown as two pages side by side (landscape).
  final PdfSpreadController spreadController;

  /// Tap at a position of the page; the viewer of a PDF handles taps itself,
  /// so it forwards them to the tap zones of the live screen.
  final ValueChanged<Offset> onTap;

  /// Measures the font scale that fits the song to the page.
  final LiveFitController fitController;

  /// Page of a song split into pages.
  final SongPageController songPageController;

  /// Drawing mode for freehand annotations (ADR-0032).
  final AnnotationEditor annotations;

  /// Freehand annotations on page [number] of the PDF [attachmentId].
  Widget _pdfAnnotations(
    String songId,
    String attachmentId,
    int number, {
    required bool hidden,
  }) => AnnotatedPage(
    key: ValueKey(('pdf-annotations', attachmentId, number)),
    songId: songId,
    target: attachmentId,
    page: number,
    editor: annotations,
    hidden: hidden,
    child: const SizedBox.expand(),
  );

  /// Portrait: one page at a time, fit to width.
  /// The background around the pages follows the stage appearance.
  Widget _portraitPdf(
    StoredFile file,
    Key key,
    Color background, {
    required Widget Function(int pageNumber) pageOverlay,
  }) => storedPdfViewer(
    file,
    key: key,
    controller: pdfController,
    params: PdfViewerParams(
      backgroundColor: background,
      // No text selection on stage: drags and long presses would
      // select text instead of moving the sheet.
      textSelectionParams: const PdfTextSelectionParams(enabled: false),
      onGeneralTap: (context, controller, details) {
        if (details.type != PdfViewerGeneralTapType.tap) return false;
        onTap(details.localPosition);
        return true;
      },
      pageOverlaysBuilder: (context, pageRect, page) => [
        Positioned.fill(child: pageOverlay(page.pageNumber)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = item.song;
    if (song == null) return _MarkerPage(item: item);

    final overlay =
        ref.watch(overlayProvider(song.id)).value ??
        SongRepository.defaultOverlay(song.id);
    final attachments =
        ref.watch(attachmentsProvider(song.id)).value ??
        const <AttachmentEntry>[];
    final parsed = parseChordProCached(
      song.chordproSource,
      selectors: ref.watch(selectorsProvider),
    );

    // Set again below when the song is shown as ChordPro.
    fitController.fontScale = null;
    final pdf = livePdfFor(
      attachments,
      item.attachmentId ?? overlay.liveView,
      hasChordPro: parsed.hasContent,
    );
    if (pdf != null) {
      songPageController.attach(1);
      var file = ref.watch(attachmentStorageProvider).file(pdf.fileName);
      if (!file.existsSync()) {
        // The web client loads the PDF now (ADR-0018); the apps show it
        // once the sync has downloaded it (ADR-0009).
        final fetched = ref.watch(attachmentFileProvider(pdf.id));
        if (fetched.isLoading) {
          return const Center(
            key: Key('pdf-loading'),
            child: CircularProgressIndicator(),
          );
        }
        if (fetched.value case final loaded?) {
          file = loaded;
        } else {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                fetched.hasError ? l10n.pdfLoadFailed : l10n.pdfMissing,
                key: const Key('pdf-missing'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          );
        }
      }
      // Landscape: two pages side by side, fitted to the screen (ADR-0009).
      final stored = file;
      final pdfKey = ValueKey(pdf.id);
      Widget annotationsOn(int number) => _pdfAnnotations(
        song.id,
        pdf.id,
        number,
        hidden: overlay.hideAnnotations,
      );
      return LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth > constraints.maxHeight
            ? PdfSpreadView(
                key: pdfKey,
                documentRef: storedPdfDocumentRef(stored),
                controller: spreadController,
                pageOverlay: annotationsOn,
              )
            : _portraitPdf(
                stored,
                pdfKey,
                Theme.of(context).colorScheme.surfaceContainerHighest,
                pageOverlay: annotationsOn,
              ),
      );
    }
    // The parts outside the sequence are shown dimmed or, as a personal
    // setting, hidden; which ones are hidden is shown in the header.
    final sequence =
        item.setSequence ??
        item.arrangement?.sequence ??
        parsed.metaValue('x_sequence');
    final keepOutside = ref.watch(
      settingsProvider.select((s) => s.showOutsideSequence),
    );
    final selection = sequence == null
        ? SequenceSelection(parsed, const [])
        : filterBySequenceCached(parsed, sequence, keepOutside: keepOutside);
    // Drummer mode (ADR-0026): the parts as played instead of the chords.
    final chorusOnce = ref.watch(
      settingsProvider.select((s) => s.repeatedChorusOnce),
    );
    final map = ref.watch(settingsProvider.select((s) => s.showSongMap))
        ? songMap(
            parsed,
            parseSequence(sequence ?? parsed.metaValue('x_sequence') ?? ''),
          )
        : null;
    final storage = ref.watch(attachmentStorageProvider);
    return LiveChordProPage(
      index: index,
      annotations: annotations,
      // With the parts outside, the layout is that of the whole song.
      shownSequence: keepOutside ? '' : sequence ?? '',
      songMap: map,
      song: song,
      // Choruses written out again left out (#955); chords in the first
      // shown verse only (#518) or the shown verses stacked (#521), and
      // stacked choruses (#953).
      parsed: songForDisplay(
        selection.song,
        overlay.verseChords,
        stackedChoruses: overlay.stackedChoruses,
        repeatedChorusOnce: chorusOnce,
      ),
      chorusOnce: chorusOnce,
      hiddenParts: selection.hidden,
      dimSection: selection.outside.isEmpty ? null : selection.isOutside,
      overlay: overlay,
      setTranspose: item.bandTranspose + item.setTranspose,
      setSequence: item.setSequence,
      bandSequence: item.arrangement?.sequence,
      bandTempo: item.arrangement?.tempo,
      scrollController: scrollController,
      fitController: fitController,
      songPageController: songPageController,
      preparation: preparation,
      attachments: attachments,
      imageLookup: (src) {
        final image = imageAttachmentFor(attachments, src);
        return image == null ? null : storage.file(image.fileName);
      },
    );
  }
}

class _MarkerPage extends StatelessWidget {
  const _MarkerPage({required this.item});

  final LiveItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              markerIconData(item.icon),
              size: 72,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              item.title(AppLocalizations.of(context)),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}
