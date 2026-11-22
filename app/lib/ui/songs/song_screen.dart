import 'dart:math' as math;

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:chordpro/chordpro.dart' as cp show Key, Song;
import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../sync_hints.dart';
import '../../data/annotation.dart' show LayoutFingerprint, textHash;
import '../../data/attachment_lookup.dart';
import '../../data/attachment_storage.dart';
import '../../data/database.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../annotations/annotated_page.dart';
import '../live/live_play_button.dart';
import '../live/live_screen.dart';
import '../render/chord_diagram.dart';
import '../render/render_cache.dart';
import '../render/song_header.dart';
import '../render/song_image.dart';
import '../render/song_view.dart';
import '../widgets/app_bar_actions.dart';
import '../widgets/app_shortcuts.dart';
import '../widgets/dialogs.dart';
import 'song_archive_dialogs.dart';
import '../widgets/file_actions.dart';
import '../widgets/key_picker.dart';
import '../widgets/chord_view_picker.dart';
import '../widgets/click_pickers.dart';
import '../widgets/verse_chords_picker.dart';
import '../widgets/scope_info.dart';
import '../widgets/side_panel.dart';
import '../bands/copy_to_band.dart';
import '../../sync/sync_controller.dart';
import 'chordpro_problems_badge.dart';
import 'conflict_banner.dart';
import 'image_attachment_view.dart';
import 'midi_program_field.dart';
import 'band_arrangement_panel.dart';
import 'play_history_panel.dart';
import 'song_editor_screen.dart';
import 'adjustment_offer.dart';
import 'language_versions.dart';
import 'song_language.dart';
import 'song_links_panel.dart';
import '../widgets/menu_action.dart';

/// Shows a song. The band arrangement, the personal adjustments, the
/// sources and the attachments open in side panels from the app bar, so the
/// song itself gets the screen.
class SongScreen extends ConsumerStatefulWidget {
  const SongScreen({
    super.key,
    required this.songId,
    this.pickPdfOnOpen = false,
    this.setSongs,
    this.setIndex = 0,
  });

  final String songId;
  final bool pickPdfOnOpen;

  /// The songs of the set the song was opened from, in order, and the
  /// song's place among them: ← and → open the previous and next one (#729).
  final List<String>? setSongs;
  final int setIndex;

  @override
  ConsumerState<SongScreen> createState() => _SongScreenState();
}

/// The side panels of the song screen.
enum _Panel { band, played, personal, attachments, links }

class _SongScreenState extends ConsumerState<SongScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  _Panel? _panel;

  void _open(_Panel panel) {
    setState(() => _panel = panel);
    // The end drawer exists only after the rebuild with the new panel.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scaffold.currentState?.openEndDrawer(),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.pickPdfOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addAttachment());
    }
  }

  SongRepository get _repo => ref.read(songRepositoryProvider);

  /// Opens the song [delta] places away in the set, in place of this one.
  void Function()? _setSibling(int delta) {
    final songs = widget.setSongs;
    final index = widget.setIndex + delta;
    if (songs == null || index < 0 || index >= songs.length) return null;
    return () => Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SongScreen(songId: songs[index], setSongs: songs, setIndex: index),
      ),
    );
  }

  Future<void> _updateOverlay(SongOverlay Function(SongOverlay) change) =>
      _repo.updateOverlay(widget.songId, change);

  Future<void> _addAttachment() async {
    final l10n = AppLocalizations.of(context);
    final files = await pickFiles(extensions: ['pdf', ...imageExtensions]);
    for (final file in files) {
      if (file.bytes.length > maxAttachmentBytes) {
        if (mounted) showMessage(context, l10n.attachmentTooLarge);
        continue;
      }
      final extension = p.extension(file.name).replaceFirst('.', '');
      final pdf = isPdfFile(file.name);
      await _repo.addAttachment(
        widget.songId,
        // Images keep their file name so {image: src="…"} finds them.
        name: pdf ? p.basenameWithoutExtension(file.name) : file.name,
        bytes: file.bytes,
        pages: pdf ? await countPdfPages(file.bytes) : null,
        extension: extension,
      );
    }
  }

  /// Opens the editor; with [showProblem], the first ChordPro problem is
  /// selected (#314).
  Future<void> _editSource(SongEntry song, {bool showProblem = false}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SongEditorScreen(
            songId: song.id,
            initialSource: song.chordproSource,
            selectFirstProblem: showProblem,
          ),
        ),
      );

  /// Sets the language of [song] by hand or back to the detected one
  /// (ADR-0053).
  Future<void> _chooseLanguage(SongEntry song) async {
    final repo = ref.read(songRepositoryProvider);
    final detected = await repo.detectedLanguage(song.id);
    if (!mounted) return;
    final choice = await chooseSongLanguage(
      context,
      current: song.language,
      detected: detected,
    );
    if (choice == null) return;
    await repo.setLanguage(song.id, choice.language);
  }

  Future<void> _editTitle(SongEntry song) async {
    final l10n = AppLocalizations.of(context);
    final title = await askText(
      context,
      title: l10n.editTitle,
      initial: song.title,
      label: l10n.title,
    );
    if (title == null || !mounted) return;
    final artist = await askText(
      context,
      title: l10n.artist,
      initial: song.artist ?? '',
      label: l10n.artist,
      allowEmpty: true,
    );
    await _repo.updateTitleArtist(song.id, title, artist ?? song.artist);
  }

  Future<void> _delete(SongEntry song) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSongTitle,
      message: l10n.deleteSongMessage(song.title),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = _repo;
    final deleted = await repo.deleteSong(song.id);
    if (mounted) Navigator.pop(context);
    showUndo(
      messenger,
      l10n.songDeleted(song.title.isEmpty ? l10n.untitled : song.title),
      undoLabel: l10n.undo,
      onUndo: () => repo.restoreSong(deleted),
      onGone: () => repo.purgeFiles(deleted.attachments),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Someone else changed or deleted the song (#691).
    listenForSyncHints(
      context,
      ref,
      recordId: widget.songId,
      isSet: false,
      onDeleted: () => closeRoute(context),
    );
    final songValue = ref.watch(songProvider(widget.songId));
    final overlay =
        ref.watch(overlayProvider(widget.songId)).value ??
        SongRepository.defaultOverlay(widget.songId);
    final attachments =
        ref.watch(attachmentsProvider(widget.songId)).value ?? const [];
    final settings = ref.watch(settingsProvider);

    return AsyncBody(
      value: songValue,
      data: (song) {
        if (song == null) return const Scaffold();
        // Permissions of the song's library, wherever it was opened from.
        final library = ref.watch(libraryProvider(song.libraryId));
        // The arrangement of the band chosen on the sets tab (ADR-0025):
        // shown and edited in its own card only; the song itself is shown
        // as written.
        final band = ref.watch(arrangementBandProvider(song.libraryId));
        final arrangement = band == null
            ? null
            : ref
                  .watch(arrangementProvider((band: band.id, song: song.id)))
                  .value;
        final parsed = parseChordProCached(
          song.chordproSource,
          selectors: ref.watch(selectorsProvider),
        );
        final formatter = ChordFormatter.forSong(
          parsed,
          transpose: overlay.transpose,
          capo: overlay.capoFret,
          notation: settings.notation,
          view: overlay.chordView ?? settings.chordView,
          style: settings.chordStyle,
          superscript: settings.chordSuperscript,
        );
        final hasSourceTitle = parsed.title != null;
        // Band leaders edit only their own songs (ADR-0023).
        final canEdit = library.canEditSong(song);
        final hasVersions =
            (ref.watch(languageVersionsProvider(song.id)).value?.length ?? 0) >
            1;

        // Sources (`{x_link}`): recordings to listen to.
        final links = parsed.links;
        // Shown when there is something to see, change or choose (#556).
        final showBand =
            band != null &&
            (arrangement != null ||
                band.canManageSets ||
                ref.watch(arrangementBandsProvider(song.libraryId)).length > 1);
        // The play history (ADR-0046) of the band's arrangement, or of the
        // local library's sets for a song of the local library.
        final current = ref.watch(currentBandProvider);
        final historyBand =
            band ??
            (current.isLocal && current.libraryId == song.libraryId
                ? current
                : null);
        final plays = historyBand == null
            ? 0
            : ref
                      .watch(
                        songPlaysProvider((
                          band: historyBand.id,
                          song: song.id,
                        )),
                      )
                      .value
                      ?.total ??
                  0;
        // Plays of the other bands of the organization (ADR-0046).
        final otherPlays = historyBand == null || historyBand.isLocal
            ? 0
            : ref
                      .watch(
                        otherBandPlaysProvider((
                          song: song.id,
                          exceptBand: historyBand.id,
                        )),
                      )
                      .value
                      ?.length ??
                  0;
        // Songs without ChordPro content show their attachments in the body.
        final attachmentsInPanel =
            parsed.hasContent && (canEdit || attachments.isNotEmpty);
        Widget attachmentsCard({required bool inPanel}) => _AttachmentsCard(
          attachments: attachments,
          overlay: overlay,
          hasChordPro: parsed.hasContent,
          inPanel: inPanel,
          onAdd: canEdit ? _addAttachment : null,
          canRename: canEdit,
          canDelete: library.canDeleteSongs,
          onLiveView: (id) =>
              _updateOverlay((o) => o.copyWith(liveView: Value(id))),
          onOpen: (a) => isPdfFile(a.fileName)
              ? LiveScreen.openSong(context, song.id, attachmentId: a.id)
              : showImageAttachment(context, a),
        );

        void transpose(int delta) => _updateOverlay(
          (o) => o.copyWith(transpose: normalizeSemitones(o.transpose + delta)),
        );
        return PageShortcuts(
          bindings: {
            editShortcut: canEdit
                ? () =>
                      _editSource(song, showProblem: song.chordproProblems > 0)
                : null,
            liveShortcut: () => LiveScreen.openSong(context, song.id),
            for (final a in transposeUpShortcuts) a: () => transpose(1),
            for (final a in transposeDownShortcuts) a: () => transpose(-1),
            previousSongShortcut: _setSibling(-1),
            nextSongShortcut: _setSibling(1),
          },
          child: Scaffold(
            key: _scaffold,
            // The song stays readable behind a side panel.
            drawerScrimColor: Colors.black12,
            endDrawerEnableOpenDragGesture: false,
            endDrawer: switch (_panel) {
              _Panel.band when band != null => BandArrangementPanel(
                band: band,
                song: song,
                parsed: parsed,
                arrangement: arrangement,
              ),
              _Panel.played when historyBand != null => PlayHistoryPanel(
                band: historyBand,
                song: song,
                parsed: parsed,
              ),
              _Panel.personal => SidePanel(
                key: const Key('personal-adjustments'),
                icon: Icons.person_outline,
                title: l10n.personalAdjustments,
                scope: SettingScope.personal,
                children: [
                  _AdjustmentsBar(
                    songKey: parsed.key,
                    formatter: formatter,
                    songCapo: parsed.capoFret,
                    notation: settings.notation,
                    overlay: overlay,
                    deviceChordView: settings.chordView,
                    hasKey: parsed.key != null,
                    song: parsed,
                    beatEnabled: settings.beatEnabled,
                    playClick: settings.playClick,
                    subdivisionSetting: settings.clickSubdivision,
                    onChanged: _updateOverlay,
                  ),
                  // The keyboard programs per profile (ADR-0039, ADR-0042).
                  if (SongRepository.midiProgramsOf(
                        overlay,
                        settings.midiDeviceProfile.id,
                      )
                      case final programs
                      when MidiProgramField.visible(
                        keyboard: settings.isKeyboard,
                        midiEnabled: settings.midiEnabled,
                        programs: programs,
                      )) ...[
                    const SizedBox(height: 16),
                    MidiProgramField(songId: song.id, programs: programs),
                  ],
                  const SizedBox(height: 16),
                  _AnnotationsSection(
                    songId: song.id,
                    overlay: overlay,
                    onChanged: _updateOverlay,
                  ),
                ],
              ),
              _Panel.links => SongLinksPanel(
                links: links,
                onAdd: canEdit
                    ? (url, label) => _repo.updateSource(
                        song.id,
                        addSourceLink(song.chordproSource, url, label: label),
                      )
                    : null,
                onChange: canEdit
                    ? (index, url, label) => _repo.updateSource(
                        song.id,
                        replaceSourceLink(
                          song.chordproSource,
                          index,
                          url,
                          label: label,
                        ),
                      )
                    : null,
              ),
              _Panel.attachments => SidePanel(
                key: const Key('song-attachments'),
                icon: Icons.attach_file,
                title: l10n.attachments,
                children: [attachmentsCard(inPanel: true)],
              ),
              _ => null,
            },
            appBar: AppBar(
              title: Text(song.title.isEmpty ? l10n.untitled : song.title),
              actions: [
                if (canEdit) ...[
                  // Editing is a key function: its own button rather than an
                  // overflow menu entry (#600). ChordPro problems show as its
                  // badge and open the editor at the first one (#314).
                  IconButton(
                    key: const Key('edit-song'),
                    tooltip: song.chordproProblems > 0
                        ? l10n.chordProProblemsShow(song.chordproProblems)
                        : l10n.editSource,
                    icon: Badge(
                      key: song.chordproProblems > 0
                          ? const Key('song-problems')
                          : null,
                      isLabelVisible: song.chordproProblems > 0,
                      backgroundColor: chordProProblemColor(context),
                      textColor: Theme.of(context).colorScheme.surface,
                      label: Text('${song.chordproProblems}'),
                      child: const Icon(Icons.edit_outlined),
                    ),
                    onPressed: () => _editSource(
                      song,
                      showProblem: song.chordproProblems > 0,
                    ),
                  ),
                  // Sets the song's own edit button apart from the panels.
                  const VerticalDivider(
                    key: Key('edit-song-divider'),
                    width: 16,
                    indent: 16,
                    endIndent: 16,
                  ),
                ],
                // Panels: as buttons where the width allows, otherwise at
                // the top of the ⋮ menu (#838).
                AppBarActions<String>(
                  otherWidth:
                      (canEdit ? AppBarActions.actionWidth + 16 : 0) +
                      LivePlayButton.widthOn(MediaQuery.sizeOf(context).width),
                  actions: [
                    if (showBand)
                      AppBarAction(
                        id: 'open-band-arrangement',
                        label: l10n.bandArrangement,
                        icon: Icons.groups_outlined,
                        active: arrangement != null,
                        onPressed: () => _open(_Panel.band),
                      ),
                    // How the band played the song before (ADR-0046).
                    if (historyBand != null && (plays > 0 || otherPlays > 0))
                      AppBarAction(
                        id: 'open-play-history',
                        label: l10n.playHistory,
                        icon: Icons.history,
                        count: plays,
                        onPressed: () => _open(_Panel.played),
                      ),
                    AppBarAction(
                      id: 'open-personal-adjustments',
                      label: l10n.personalAdjustments,
                      icon: Icons.person_outline,
                      // Freehand annotations change how the song looks, too.
                      active:
                          overlay.hasAdjustments ||
                          (!overlay.hideAnnotations &&
                              settings.showAnnotations &&
                              (ref
                                          .watch(
                                            annotationCountProvider(song.id),
                                          )
                                          .value ??
                                      0) >
                                  0),
                      onPressed: () => _open(_Panel.personal),
                    ),
                    if (attachmentsInPanel)
                      AppBarAction(
                        id: 'open-attachments',
                        label: l10n.attachments,
                        icon: Icons.attach_file,
                        count: attachments.length,
                        onPressed: () => _open(_Panel.attachments),
                      ),
                    if (links.isNotEmpty || canEdit)
                      AppBarAction(
                        id: 'open-song-links',
                        label: l10n.songLinks,
                        icon: Icons.headphones_outlined,
                        count: links.length,
                        onPressed: () => _open(_Panel.links),
                      ),
                  ],
                  onSelected: (value) => switch (value) {
                    'title' => _editTitle(song),
                    'language' => _chooseLanguage(song),
                    'linkVersion' => linkLanguageVersion(context, ref, song),
                    'unlinkVersion' => unlinkLanguageVersion(
                      context,
                      ref,
                      song,
                    ),
                    'export' => exportSongs(context, ref, [song.id]),
                    'copyToBand' => copySongsToBand(context, ref, [
                      song.id,
                    ], fromLibraryId: song.libraryId),
                    'delete' => _delete(song),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    if (!hasSourceTitle && canEdit)
                      MenuAction(
                        value: 'title',
                        icon: Icons.title,
                        label: l10n.editTitle,
                      ),
                    if (canEdit)
                      MenuAction(
                        key: const Key('song-language'),
                        value: 'language',
                        icon: Icons.language,
                        label: l10n.songLanguageMenu,
                      ),
                    if (canEdit)
                      MenuAction(
                        key: const Key('song-link-version'),
                        value: 'linkVersion',
                        icon: Icons.link,
                        label: l10n.linkLanguageVersion,
                      ),
                    if (canEdit && hasVersions)
                      MenuAction(
                        key: const Key('song-unlink-version'),
                        value: 'unlinkVersion',
                        icon: Icons.link_off,
                        label: l10n.unlinkLanguageVersion,
                      ),
                    // Also on web: the archive loads the files (ADR-0018).
                    MenuAction(
                      key: const Key('song-export-menu'),
                      value: 'export',
                      icon: Icons.file_download_outlined,
                      label: l10n.exportMenu,
                    ),
                    MenuAction(
                      value: 'copyToBand',
                      icon: Icons.copy_all_outlined,
                      label: l10n.copyToBand,
                    ),
                    if (library.canDeleteSongs)
                      MenuAction(
                        value: 'delete',
                        icon: Icons.delete_outline,
                        label: l10n.delete,
                        destructive: true,
                      ),
                  ],
                ),
                LivePlayButton(
                  onPressed: () => LiveScreen.openSong(context, song.id),
                ),
              ],
            ),
            // The song is fitted to the visible area below the app bar; the
            // header scrolls away above it.
            body: LayoutBuilder(
              builder: (context, constraints) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (ref.watch(songConflictProvider(song.id)).value
                      case final conflict?)
                    ConflictBanner(conflict: conflict),
                  // The app bar shows the title (#268).
                  SongHeader(
                    title: song.title.isEmpty ? l10n.untitled : song.title,
                    showTitle: false,
                    artist: song.artist,
                    song: parsed,
                    formatter: formatter,
                  ),
                  LanguageVersionChips(song: song),
                  AdjustmentOfferBanner(song: song, overlay: overlay),
                  if (!parsed.hasContent) ...[
                    const SizedBox(height: 12),
                    attachmentsCard(inPanel: false),
                  ],
                  const SizedBox(height: 16),
                  if (parsed.hasContent)
                    _FittedSongBody(
                      songId: song.id,
                      source: song.chordproSource,
                      song: songWithVerseChords(parsed, overlay.verseChords),
                      overlay: overlay,
                      formatter: formatter,
                      // The visible area without the list's padding.
                      page: Size(
                        constraints.maxWidth - 32,
                        constraints.maxHeight - 40,
                      ),
                      attachments: attachments,
                      imageLookup: (src) {
                        final image = imageAttachmentFor(attachments, src);
                        return image == null
                            ? null
                            : ref
                                  .read(attachmentStorageProvider)
                                  .file(image.fileName);
                      },
                    )
                  else
                    Card.outlined(
                      child: ListTile(
                        leading: const Icon(Icons.text_snippet_outlined),
                        title: Text(l10n.noContent),
                        trailing: !canEdit
                            ? null
                            : FilledButton.tonal(
                                onPressed: () => _editSource(song),
                                child: Text(l10n.addChordPro),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fits the song to [page] like live mode (ADR-0007): with automatic
/// fitting, font size and columns are chosen so that the whole song fits;
/// the personal font scale applies on top. When it does not fit (or without
/// automatic fitting) the song keeps the base font size and is split into as
/// many columns as needed, up to what the width allows, and scrolls.
class _FittedSongBody extends ConsumerWidget {
  const _FittedSongBody({
    required this.songId,
    required this.source,
    required this.song,
    required this.overlay,
    required this.formatter,
    required this.page,
    required this.attachments,
    required this.imageLookup,
  });

  final String songId;

  /// The ChordPro text, for the layout of freehand annotations.
  final String source;
  final Song song;
  final SongOverlay overlay;
  final ChordFormatter formatter;
  final Size page;
  final List<AttachmentEntry> attachments;
  final ImageLookup imageLookup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);
    final lyricsOnly = settings.displayMode == DisplayMode.lyricsOnly;
    final resolver = DiagramResolver(
      song,
      formatter,
      diagramInstrumentFor(
        settings.instrument,
        bassStrings: settings.bassStrings,
      ),
    );
    final diagrams = diagramsPosition(song.diagrams, settings.diagrams);
    final textScaler = MediaQuery.textScalerOf(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final scale = overlay.fontScale;
    // {columns} in the song wins over the automatic choice.
    final songColumns =
        settings.columns == ColumnMode.auto && song.columns != null
        ? song.columns!.clamp(1, 4)
        : null;
    final maxColumns = songColumns ?? settings.maxColumns;
    // By content: the list is loaded anew on every change.
    final key = (
      song,
      formatter.transpose,
      formatter.capo,
      formatter.notation,
      formatter.view,
      lyricsOnly,
      overlay.notes,
      diagrams,
      settings.instrument,
      textScaler,
      baseStyle,
      [for (final a in attachments) '${a.id}/${a.name}/${a.fileName}']
          .join('\n'),
      Localizations.localeOf(context),
      settings.songDisplay,
    );

    SongRenderOptions options(
      double fontSize,
      int columns,
      bool collapse,
      SongLayout layout,
    ) => SongRenderOptions(
      formatter: formatter,
      lyricsOnly: lyricsOnly,
      fontSize: fontSize,
      columns: columns,
      notes: overlay.notes,
      collapseRecalls: collapse,
      diagramResolver: resolver,
      diagramsPosition: diagrams,
      imageLookup: imageLookup,
      layout: layout,
      display: settings.songDisplay,
    );

    if (settings.autoFit && page.width > 0 && page.height > 0) {
      final fit = _fits.get(
        (
          key,
          settings.fontSize,
          songColumns,
          settings.maxColumns,
          settings.chorusRepeat,
          page,
        ),
        () => fitSong(
          song,
          formatter: formatter,
          lyricsOnly: lyricsOnly,
          labeler: sectionLabeler(l10n),
          notes: overlay.notes,
          baseFontSize: settings.fontSize,
          maxFontSize: settings.fontSize * 2,
          minFontSize: AppSettings.minFontSize,
          size: page,
          textScaler: textScaler,
          baseStyle: baseStyle,
          minColumns: songColumns ?? 1,
          maxColumns: maxColumns,
          chorusRepeat: settings.chorusRepeat,
          diagramResolver: resolver,
          diagramsPosition: diagrams,
          imageLookup: imageLookup,
          display: settings.songDisplay,
        ),
      );
      if (fit.fits && fit.layout != null) {
        final layout = fit.layout!;
        final font = fit.fontSize * scale;
        // A larger personal scale may need fewer columns: chord lines must
        // fit (breaks in the song keep their columns).
        var columns = fit.columns;
        if (forcedColumns(layout.blocks) == null) {
          final widest = layout.metrics.fold<double>(
            0,
            (w, m) => math.max(w, m.minWidth),
          );
          while (columns > 1 &&
              columnWidth(page.width, columns, font) < widest * font) {
            columns--;
          }
        }
        return _annotated(
          font,
          columns,
          lyricsOnly,
          SongBody(
            song: song,
            options: options(font, columns, fit.collapseRecalls, layout),
          ),
        );
      }
    }

    // Does not fit (or no automatic fitting): base font size, columns.
    final collapse = settings.chorusRepeat == ChorusRepeat.label;
    final layout = _layouts.get(
      (key, collapse),
      () => layoutSong(
        song,
        formatter: formatter,
        lyricsOnly: lyricsOnly,
        labeler: sectionLabeler(l10n),
        notes: overlay.notes,
        collapseRecalls: collapse,
        diagramResolver: resolver,
        diagramsPosition: diagrams,
        textScaler: textScaler,
        baseStyle: baseStyle,
        imageLookup: imageLookup,
        display: settings.songDisplay,
      ),
    );
    final font = settings.fontSize * scale;
    final columns = scrollColumns(
      layout,
      fontSize: font,
      size: page,
      maxColumns: maxColumns,
    );
    return _annotated(
      font,
      columns,
      lyricsOnly,
      SongBody(song: song, options: options(font, columns, collapse, layout)),
    );
  }

  /// The person's freehand annotations over [body], shown at their lines:
  /// they are drawn in live mode, whose pages this screen does not have
  /// (ADR-0032).
  Widget _annotated(double font, int columns, bool lyricsOnly, Widget body) =>
      AnnotatedPage(
        songId: songId,
        page: 0,
        layout: LayoutFingerprint(
          mode: 'screen',
          width: page.width,
          height: page.height,
          font: font,
          columns: columns,
          lyricsOnly: lyricsOnly,
          verseChords: overlay.verseChords.name,
          content: textHash(source),
        ),
        font: font,
        hidden: overlay.hideAnnotations,
        child: body,
      );
}

/// Freehand annotations in the personal panel (ADR-0032): how many there
/// are, whether they are shown for this song, and deleting them all.
class _AnnotationsSection extends ConsumerWidget {
  const _AnnotationsSection({
    required this.songId,
    required this.overlay,
    required this.onChanged,
  });

  final String songId;
  final SongOverlay overlay;
  final Future<void> Function(SongOverlay Function(SongOverlay)) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = ref.watch(annotationCountProvider(songId)).value ?? 0;
    return Column(
      key: const Key('annotations-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.draw_outlined, size: 20),
            const SizedBox(width: 8),
            // Wraps in narrow panels (phones).
            Flexible(
              child: Text(
                l10n.annotationsPanelTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.annotationsCount(count),
          key: const Key('annotations-count'),
          style: theme.textTheme.bodySmall,
        ),
        if (count > 0) ...[
          SwitchListTile(
            key: const Key('annotations-show'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.annotationsPanelShow),
            value: !overlay.hideAnnotations,
            onChanged: (show) =>
                onChanged((o) => o.copyWith(hideAnnotations: !show)),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('annotations-delete-all'),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.annotationsDeleteAll),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final repo = ref.read(annotationRepositoryProvider);
                final removed = await repo.deleteAll(songId);
                if (removed.isEmpty) return;
                showUndo(
                  messenger,
                  l10n.annotationsDeleted,
                  undoLabel: l10n.undo,
                  onUndo: () => repo.restoreAll(songId, removed),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Results of [fitSong] for the song screen.
final _fits = LruCache<Object, SongFit>(8);

/// Measured songs for the song screen when they do not fit.
final _layouts = LruCache<Object, SongLayout>(8);

/// Transposition, capo, font size, chord view and notes (layer 3, ADR-0006).
class _AdjustmentsBar extends StatelessWidget {
  const _AdjustmentsBar({
    required this.songKey,
    required this.formatter,
    required this.songCapo,
    required this.notation,
    required this.overlay,
    required this.deviceChordView,
    required this.hasKey,
    required this.song,
    this.beatEnabled = false,
    this.playClick = false,
    this.subdivisionSetting = Subdivision.off,
    required this.onChanged,
  });

  final cp.Key? songKey;

  /// Formatter of the song view; the capo menu previews the header with it.
  final ChordFormatter formatter;

  /// `{capo}` of the song (0 if none).
  final int songCapo;
  final ChordNotation notation;
  final SongOverlay overlay;
  final ChordView deviceChordView;
  final bool hasKey;

  /// The parsed song, for the choices of how verses show their chords.
  final cp.Song song;

  /// Whether the person uses the beat or the click (ADR-0026): the grouping
  /// and subdivisions of the click are offered then (#698).
  final bool beatEnabled;
  final bool playClick;
  final Subdivision subdivisionSetting;
  final Future<void> Function(SongOverlay Function(SongOverlay)) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A capo menu entry followed by the header it leads to, e.g.
    // "No capo – Key: D" (only with a key).
    String withHeader(String label, int? capo) => hasKey
        ? '$label – ${keyAndCapoText(l10n, formatter.withCapo(capo))}'
        : label;

    return Wrap(
      spacing: 8,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        KeyPicker(
          baseKey: songKey,
          transpose: overlay.transpose,
          notation: notation,
          tooltip: l10n.keyPickerPersonal,
          onChanged: (value) => onChanged((o) => o.copyWith(transpose: value)),
        ),
        MenuAnchor(
          builder: (context, controller, _) => ActionChip(
            avatar: const Icon(Icons.straighten, size: 18),
            // The capo as in the header, e.g. "Capo: 2 (G)".
            label: Text(switch ((overlay.capoFret, capoText(l10n, formatter))) {
              (_, null) => l10n.noCapo,
              (null, final capo?) => l10n.capoAsInSongLabel(capo),
              (_, final capo?) => capo,
            }),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
          menuChildren: [
            // null = as written in the song ({capo}), 0 = explicitly none.
            if (songCapo > 0)
              MenuItemButton(
                onPressed: () =>
                    onChanged((o) => o.copyWith(capoFret: const Value(null))),
                child: Text(withHeader(l10n.capoAsInSong(songCapo), null)),
              ),
            for (var fret = 0; fret <= 9; fret++)
              MenuItemButton(
                onPressed: () => onChanged(
                  (o) => o.copyWith(
                    capoFret: Value(fret == 0 && songCapo == 0 ? null : fret),
                  ),
                ),
                child: Text(
                  fret == 0
                      ? withHeader(l10n.noCapo, 0)
                      : hasKey
                      // What the header shows with this capo.
                      ? keyAndCapoText(l10n, formatter.withCapo(fret))
                      : l10n.capoValue(fret),
                ),
              ),
          ],
        ),
        _Stepper(
          icon: Icons.format_size,
          label: '${(overlay.fontScale * 100).round()} %',
          downTooltip: l10n.fontSmaller,
          upTooltip: l10n.fontLarger,
          onDown: () => onChanged(
            (o) => o.copyWith(fontScale: (o.fontScale - 0.1).clamp(0.5, 2.5)),
          ),
          onUp: () => onChanged(
            (o) => o.copyWith(fontScale: (o.fontScale + 0.1).clamp(0.5, 2.5)),
          ),
        ),
        // Chord names, Nashville numbers or Roman numerals (ADR-0055).
        ChordViewPicker(
          view: overlay.chordView ?? deviceChordView,
          hasKey: hasKey,
          onChanged: (view) => onChanged(
            (o) => o.copyWith(
              chordView: Value(view == deviceChordView ? null : view),
            ),
          ),
        ),
        // Chords in the first verse only (#518) or stacked verses (#521).
        VerseChordsPicker(
          song: song,
          mode: overlay.verseChords,
          onChanged: (mode) => onChanged((o) => o.copyWith(verseChords: mode)),
        ),
        // Grouping and subdivisions of the click (#698): for people who use
        // the beat or the click, and always to reset a choice.
        if ((beatEnabled || overlay.clickGrouping != null) &&
            song.meter.groupingChoices().isNotEmpty)
          ClickGroupingPicker(
            songMeter: song.meter,
            grouping: overlay.clickGrouping,
            onChanged: (grouping) =>
                onChanged((o) => o.copyWith(clickGrouping: Value(grouping))),
          ),
        if (playClick || overlay.clickSubdivision != null)
          ClickSubdivisionPicker(
            meter: song.meter.withGrouping(overlay.clickGrouping),
            subdivision: overlay.clickSubdivision,
            setting: subdivisionSetting,
            onChanged: (subdivision) => onChanged(
              (o) => o.copyWith(clickSubdivision: Value(subdivision)),
            ),
          ),
        ActionChip(
          avatar: const Icon(Icons.sticky_note_2_outlined, size: 18),
          label: Text(l10n.notes),
          onPressed: () async {
            final text = await askText(
              context,
              title: l10n.notes,
              initial: overlay.notes ?? '',
              hint: l10n.notesHint,
              multiline: true,
              allowEmpty: true,
            );
            if (text != null) {
              await onChanged(
                (o) => o.copyWith(notes: Value(text.isEmpty ? null : text)),
              );
            }
          },
        ),
        if (overlay.hasAdjustments)
          TextButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.resetAdjustments),
            onPressed: () => onChanged(
              (o) => o.copyWith(
                transpose: 0,
                capoFret: const Value(null),
                fontScale: 1.0,
                chordView: const Value(null),
                verseChords: VerseChords.all,
                clickGrouping: const Value(null),
                clickSubdivision: const Value(null),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icon,
    required this.label,
    required this.downTooltip,
    required this.upTooltip,
    required this.onDown,
    required this.onUp,
  });

  final IconData icon;
  final String label;
  final String downTooltip;
  final String upTooltip;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: downTooltip,
            icon: const Icon(Icons.remove),
            onPressed: onDown,
          ),
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelLarge),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: upTooltip,
            icon: const Icon(Icons.add),
            onPressed: onUp,
          ),
        ],
      ),
    );
  }
}

/// The song's PDFs and images and the choice of the live view: in the
/// attachments panel ([inPanel]) or, for songs without ChordPro content, as
/// a card in the body.
class _AttachmentsCard extends ConsumerWidget {
  const _AttachmentsCard({
    required this.attachments,
    required this.overlay,
    required this.hasChordPro,
    required this.inPanel,
    required this.onAdd,
    required this.onLiveView,
    required this.onOpen,
    this.canRename = true,
    this.canDelete = true,
  });

  final List<AttachmentEntry> attachments;
  final SongOverlay overlay;
  final bool hasChordPro;
  final bool inPanel;

  /// Null hides the "add" button (no permission, ADR-0005).
  final VoidCallback? onAdd;
  final bool canRename;
  final bool canDelete;
  final void Function(String? attachmentId) onLiveView;

  /// Shows an attachment without changing the live view choice (#507).
  final void Function(AttachmentEntry attachment) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(songRepositoryProvider);
    final pdfs = [
      for (final a in attachments)
        if (isPdfFile(a.fileName)) a,
    ];
    final images = [
      for (final a in attachments)
        if (!isPdfFile(a.fileName)) a,
    ];
    final selected = livePdfFor(
      attachments,
      overlay.liveView,
      hasChordPro: hasChordPro,
    )?.id;

    final theme = Theme.of(context);
    final liveViewLabel = pdfs.length > 1 || (hasChordPro && pdfs.isNotEmpty)
        ? Row(
            children: [
              Flexible(child: Text(l10n.liveView)),
              const ScopeInfo(SettingScope.personal),
            ],
          )
        : null;
    final addButton = onAdd == null
        ? null
        : TextButton.icon(
            key: const Key('song-add-attachment'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addAttachment),
          );
    final tiles = [
      if (hasChordPro && pdfs.isNotEmpty)
        RadioListTile<String?>(
          value: null,
          title: Text(l10n.liveViewChordPro),
          secondary: const Icon(Icons.text_snippet_outlined),
        ),
      for (final a in pdfs)
        RadioListTile<String?>(
          value: a.id,
          title: Text(a.name),
          subtitle: Text(
            [
              if (a.pages != null) l10n.pagesCount(a.pages!),
              formatBytes(a.sizeBytes),
            ].join(' · '),
          ),
          secondary: _actions(context, repo, a),
        ),
      for (final a in images)
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(a.name),
          subtitle: Text(formatBytes(a.sizeBytes)),
          trailing: _actions(context, repo, a),
          onTap: () => onOpen(a),
        ),
    ];

    final list = RadioGroup<String?>(
      groupValue: selected,
      onChanged: onLiveView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: inPanel
            ? [
                ?addButton,
                if (attachments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.noAttachments,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (liveViewLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DefaultTextStyle.merge(
                      style: theme.textTheme.titleSmall,
                      child: liveViewLabel,
                    ),
                  ),
                ...tiles,
              ]
            : [
                ListTile(
                  title: Text(
                    l10n.attachments,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: liveViewLabel,
                  trailing: addButton,
                ),
                ...tiles,
              ],
      ),
    );
    return inPanel ? list : Card.outlined(child: list);
  }

  /// The open button and the menu of an attachment.
  Widget _actions(
    BuildContext context,
    SongRepository repo,
    AttachmentEntry a,
  ) {
    final menu = _menu(context, repo, a);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('open-attachment-${a.id}'),
          tooltip: AppLocalizations.of(context).openAttachment,
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () => onOpen(a),
        ),
        ?menu,
      ],
    );
  }

  Widget? _menu(BuildContext context, SongRepository repo, AttachmentEntry a) {
    final l10n = AppLocalizations.of(context);
    if (!canRename && !canDelete) return null;
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'rename') {
          final name = await askText(
            context,
            title: l10n.rename,
            initial: a.name,
            label: l10n.attachmentName,
          );
          if (name != null) await repo.renameAttachment(a.id, name);
        } else if (value == 'delete') {
          // No confirmation: the deletion can be undone (#267).
          final messenger = ScaffoldMessenger.of(context);
          final deleted = await repo.deleteAttachment(a);
          showUndo(
            messenger,
            l10n.attachmentDeleted(a.name),
            undoLabel: l10n.undo,
            onUndo: () => repo.restoreAttachment(deleted),
            onGone: () => repo.purgeFiles([a]),
          );
        }
      },
      itemBuilder: (_) => [
        if (canRename)
          MenuAction(
            value: 'rename',
            icon: Icons.edit_outlined,
            label: l10n.rename,
          ),
        if (canDelete)
          MenuAction(
            value: 'delete',
            icon: Icons.delete_outline,
            label: l10n.delete,
            destructive: true,
          ),
      ],
    );
  }
}

extension on SongOverlay {
  /// Whether the song is shown differently from how it is written (the
  /// notes and the live view are not counted: they add, not change).
  bool get hasAdjustments =>
      transpose != 0 ||
      capoFret != null ||
      fontScale != 1.0 ||
      chordView != null ||
      verseChords != VerseChords.all ||
      clickGrouping != null ||
      clickSubdivision != null;
}
