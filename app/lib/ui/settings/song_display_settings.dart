import 'dart:math' as math;

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../../providers.dart';
import '../live/live_theme.dart';
import '../render/render_cache.dart';
import '../render/song_display_colors.dart';
import '../render/song_view.dart';
import '../sets/song_picker.dart';
import '../widgets/dialogs.dart';

/// Song shown in the preview: every section type once. Original text
/// written for setDING, like the demo song.
const songDisplayPreviewSource = '''{title: Late Train Home}
{c: Intro}
[G] [D] [Em] [C]

{start_of_verse: Verse 1}
[G]Streetlights fading [D/F#]one by one,
[Em]the station clock says [C]we are done.
{end_of_verse}

{c: Pre-Chorus}
[Am]Hold the [C]note a little [D]longer

{start_of_chorus: Chorus}
[C]Take the [D]late train [G]home,
[Em]sing it [C]soft, we're not a[D]lone.
{end_of_chorus}

{c: Solo}
[Em] [C] [G] [D]

{start_of_bridge: Bridge}
[Am]Lights go [Em]down, [C]one more [D]round
{end_of_bridge}

{c: Outro}
[C] [D] [G]
''';

/// Name of [role] in the settings.
String songDisplayTypeName(AppLocalizations l10n, SectionRole role) =>
    switch (role) {
      SectionRole.standard => l10n.songDisplayTypeStandard,
      SectionRole.intro => l10n.songDisplayTypeIntro,
      SectionRole.verse => l10n.songDisplayTypeVerse,
      SectionRole.preChorus => l10n.songDisplayTypePreChorus,
      SectionRole.chorus => l10n.songDisplayTypeChorus,
      SectionRole.bridge => l10n.songDisplayTypeBridge,
      SectionRole.interlude => l10n.songDisplayTypeInterlude,
      SectionRole.outro => l10n.songDisplayTypeOutro,
    };

String songDisplayPresetName(AppLocalizations l10n, SongDisplayPreset preset) =>
    switch (preset) {
      SongDisplayPreset.classic => l10n.songDisplayPresetClassic,
      SongDisplayPreset.colorCoded => l10n.songDisplayPresetColorCoded,
      SongDisplayPreset.chorusFocus => l10n.songDisplayPresetChorusFocus,
      SongDisplayPreset.singer => l10n.songDisplayPresetSinger,
      SongDisplayPreset.guitar => l10n.songDisplayPresetGuitar,
      SongDisplayPreset.minimal => l10n.songDisplayPresetMinimal,
      SongDisplayPreset.custom => l10n.songDisplayPresetCustom,
    };

String _colorName(AppLocalizations l10n, SongColor color) => switch (color) {
  SongColor.auto => l10n.songColorAuto,
  SongColor.blue => l10n.songColorBlue,
  SongColor.amber => l10n.songColorAmber,
  SongColor.red => l10n.songColorRed,
  SongColor.green => l10n.songColorGreen,
  SongColor.teal => l10n.songColorTeal,
  SongColor.purple => l10n.songColorPurple,
  SongColor.pink => l10n.songColorPink,
  SongColor.grey => l10n.songColorGrey,
};

/// The song of the preview on this device (UI state, not synced): a song
/// ID, or null for the demo song.
class PreviewSongNotifier extends Notifier<String?> {
  static const prefsKey = 'songDisplayPreviewSong';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(prefsKey);

  Future<void> set(String? id) async {
    state = id;
    final prefs = ref.read(sharedPreferencesProvider);
    if (id == null) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, id);
    }
  }
}

final songDisplayPreviewSongProvider =
    NotifierProvider<PreviewSongNotifier, String?>(PreviewSongNotifier.new);

void _setDisplay(WidgetRef ref, SongDisplay display) => ref
    .read(settingsProvider.notifier)
    .update((s) => s.copyWith(songDisplay: display));

/// Chooses preset [p]; asks first when it replaces custom styles.
Future<void> _choosePreset(
  BuildContext context,
  WidgetRef ref,
  SongDisplay current,
  SongDisplayPreset p,
) async {
  final l10n = AppLocalizations.of(context);
  if (current.preset == SongDisplayPreset.custom &&
      !await confirm(
        context,
        title: l10n.songDisplayDiscardTitle,
        message: l10n.songDisplayDiscardMessage(songDisplayPresetName(l10n, p)),
        action: l10n.songDisplayDiscard,
      )) {
    return;
  }
  _setDisplay(ref, SongDisplay.preset(p));
}

/// The presets of the song display.
class _PresetChips extends ConsumerWidget {
  const _PresetChips({required this.display});

  final SongDisplay display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in SongDisplayPreset.values)
            if (p != SongDisplayPreset.custom ||
                display.preset == SongDisplayPreset.custom)
              ChoiceChip(
                key: Key('song-display-preset-${p.name}'),
                label: Text(songDisplayPresetName(l10n, p)),
                selected: display.preset == p,
                onSelected: p == SongDisplayPreset.custom
                    ? null
                    : (_) => _choosePreset(context, ref, display, p),
              ),
        ],
      ),
    );
  }
}

/// The song display category of the settings (ADR-0033): the presets, a
/// button to the editor and a preview.
class SongDisplaySettings extends ConsumerWidget {
  const SongDisplaySettings({super.key});

  /// Height of the preview in the settings.
  static const previewHeight = 360.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final display = ref.watch(settingsProvider.select((s) => s.songDisplay));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.songDisplayPreset),
        _PresetChips(display: display),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: const Key('song-display-customise'),
              icon: const Icon(Icons.tune),
              label: Text(l10n.songDisplayCustomise),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SongDisplayEditorScreen(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: previewHeight,
            child: SongDisplayPreview(display: display),
          ),
        ),
      ],
    );
  }
}

/// The editor of the song display over the whole screen: on wide screens
/// the controls on the left and the preview next to them, on narrow ones
/// the preview pinned on top (resizable) and the controls below, so the
/// effect of a change is always in view (#478).
class SongDisplayEditorScreen extends ConsumerStatefulWidget {
  const SongDisplayEditorScreen({super.key});

  /// From this width the preview is shown next to the controls.
  static const sideBySideWidth = 760.0;

  /// Width of the controls next to the preview.
  static const controlsWidth = 380.0;

  @override
  ConsumerState<SongDisplayEditorScreen> createState() =>
      _SongDisplayEditorState();
}

class _SongDisplayEditorState extends ConsumerState<SongDisplayEditorScreen> {
  SectionRole _role = SectionRole.standard;

  /// Height of the pinned preview on narrow screens; null = 40 %.
  double? _previewHeight;

  void _set(SongDisplay display) => _setDisplay(ref, display);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final display = settings.songDisplay;
    final type = display.allTypes[_role]!;
    final inherits = _role != SectionRole.standard && type.from != null;
    final style = display.styleOf(_role);

    void change(SectionStyle Function(SectionStyle) f) =>
        _set(display.withType(_role, TypeStyle(style: f(style))));

    final controls = ListView(
      key: const Key('song-display-controls'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Heading(l10n.songDisplayPreset),
        _PresetChips(display: display),
        _Heading(l10n.songDisplaySection),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in SectionRole.values)
                _TypeChip(
                  role: role,
                  display: display,
                  selected: role == _role,
                  onSelected: () => setState(() => _role = role),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_role == SectionRole.standard)
          _Hint(l10n.songDisplayStandardHint)
        else
          ListTile(
            title: Text(l10n.songDisplayStyle),
            trailing: DropdownButton<SectionRole?>(
              key: const Key('song-display-inherit'),
              value: type.from,
              onChanged: (from) => _set(
                display.withType(
                  _role,
                  // Own style starts from what the type looked like so far.
                  from == null
                      ? TypeStyle(style: style)
                      : TypeStyle(from: from, style: type.style),
                ),
              ),
              items: [
                DropdownMenuItem(child: Text(l10n.songDisplayOwnStyle)),
                for (final role in SectionRole.values)
                  if (role != _role)
                    DropdownMenuItem(
                      value: role,
                      enabled: !display.makesCycle(_role, role),
                      child: Text(
                        l10n.songDisplayLike(songDisplayTypeName(l10n, role)),
                      ),
                    ),
              ],
            ),
          ),
        if (inherits)
          _Hint(l10n.songDisplayInheritsHint(_chain(l10n, display, _role)))
        else ...[
          _Heading(l10n.songDisplayChords),
          _Row(
            children: [
              _Toggles(
                prefix: 'chord',
                bold: style.chordBold,
                italic: style.chordItalic,
                onBold: (v) => change((s) => s.copyWith(chordBold: v)),
                onItalic: (v) => change((s) => s.copyWith(chordItalic: v)),
              ),
              _Segments<ChordSize>(
                key: const Key('song-display-chordSize'),
                value: style.chordSize,
                labels: {
                  ChordSize.small: l10n.songDisplaySizeSmall,
                  ChordSize.medium: l10n.songDisplaySizeMedium,
                  ChordSize.large: l10n.songDisplaySizeLarge,
                },
                onChanged: (v) => change((s) => s.copyWith(chordSize: v)),
              ),
            ],
          ),
          _Colors(
            name: 'chordColor',
            value: style.chordColor,
            onChanged: (v) => change((s) => s.copyWith(chordColor: v)),
          ),
          _Heading(l10n.songDisplayLyrics),
          _Row(
            children: [
              _Toggles(
                prefix: 'text',
                bold: style.textBold,
                italic: style.textItalic,
                onBold: (v) => change((s) => s.copyWith(textBold: v)),
                onItalic: (v) => change((s) => s.copyWith(textItalic: v)),
              ),
            ],
          ),
          _Colors(
            name: 'textColor',
            value: style.textColor,
            onChanged: (v) => change((s) => s.copyWith(textColor: v)),
          ),
          _Heading(l10n.songDisplayHeading),
          SwitchListTile(
            key: const Key('song-display-showLabel'),
            title: Text(l10n.songDisplayShowHeading),
            value: style.showLabel,
            onChanged: (v) => change((s) => s.copyWith(showLabel: v)),
          ),
          if (style.showLabel) ...[
            _Row(
              children: [
                _Toggles(
                  prefix: 'label',
                  bold: style.labelBold,
                  italic: style.labelItalic,
                  onBold: (v) => change((s) => s.copyWith(labelBold: v)),
                  onItalic: (v) => change((s) => s.copyWith(labelItalic: v)),
                ),
                _Segments<LabelSize>(
                  key: const Key('song-display-labelSize'),
                  value: style.labelSize,
                  labels: {
                    LabelSize.small: l10n.songDisplaySizeSmall,
                    LabelSize.medium: l10n.songDisplaySizeMedium,
                    LabelSize.large: l10n.songDisplaySizeLarge,
                    LabelSize.extraLarge: l10n.songDisplaySizeExtraLarge,
                  },
                  onChanged: (v) => change((s) => s.copyWith(labelSize: v)),
                ),
              ],
            ),
            _Colors(
              name: 'labelColor',
              value: style.labelColor,
              onChanged: (v) => change((s) => s.copyWith(labelColor: v)),
            ),
          ],
          _Heading(l10n.songDisplayBar),
          SwitchListTile(
            key: const Key('song-display-bar'),
            title: Text(l10n.songDisplayShowBar),
            value: style.bar,
            onChanged: (v) => change((s) => s.copyWith(bar: v)),
          ),
          if (style.bar) ...[
            _Row(
              children: [
                _Segments<BarWidth>(
                  key: const Key('song-display-barWidth'),
                  value: style.barWidth,
                  labels: {
                    BarWidth.thin: l10n.songDisplayBarThin,
                    BarWidth.medium: l10n.songDisplayBarMedium,
                    BarWidth.wide: l10n.songDisplayBarWide,
                  },
                  onChanged: (v) => change((s) => s.copyWith(barWidth: v)),
                ),
              ],
            ),
            _Colors(
              name: 'barColor',
              value: style.barColor,
              onChanged: (v) => change((s) => s.copyWith(barColor: v)),
            ),
          ],
          ListTile(
            title: Text(l10n.songDisplayIndent),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _Segments<SectionIndent>(
                  key: const Key('song-display-indent'),
                  value: style.indent,
                  labels: {
                    SectionIndent.none: l10n.songDisplayIndentNone,
                    SectionIndent.normal: l10n.songDisplayIndentNormal,
                    SectionIndent.large: l10n.songDisplayIndentLarge,
                  },
                  onChanged: (v) => change((s) => s.copyWith(indent: v)),
                ),
              ),
            ),
          ),
          SwitchListTile(
            key: const Key('song-display-tint'),
            title: Text(l10n.songDisplayTint),
            value: style.tint,
            onChanged: (v) => change((s) => s.copyWith(tint: v)),
          ),
        ],
      ],
    );
    final preview = SongDisplayPreview(display: display, role: _role);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.songDisplayEditorTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= SongDisplayEditorScreen.sideBySideWidth) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: SongDisplayEditorScreen.controlsWidth,
                  child: controls,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: preview,
                  ),
                ),
              ],
            );
          }
          final max = constraints.maxHeight;
          final height = (_previewHeight ?? max * 0.4)
              .clamp(math.min(120.0, max / 2), math.max(120.0, max - 160))
              .toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: preview,
                ),
              ),
              Semantics(
                label: l10n.songDisplayResizePreview,
                child: GestureDetector(
                  key: const Key('song-display-resize'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) =>
                      setState(() => _previewHeight = height + d.delta.dy),
                  child: SizedBox(
                    height: 24,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: controls),
            ],
          );
        },
      ),
    );
  }
}

/// "Interlude → Standard": where [role] takes its style from.
String _chain(AppLocalizations l10n, SongDisplay display, SectionRole role) {
  final names = <String>[];
  final all = display.allTypes;
  SectionRole? current = all[role]!.from;
  while (current != null && names.length < SectionRole.values.length) {
    names.add(songDisplayTypeName(l10n, current));
    current = current == SectionRole.standard ? null : all[current]!.from;
  }
  return names.join(' → ');
}

/// The preview: the demo song or a song from the library (chosen per
/// device), in the live appearance of this device and in [display]. When
/// [role] changes, it scrolls to the first section of that type.
class SongDisplayPreview extends ConsumerStatefulWidget {
  const SongDisplayPreview({super.key, required this.display, this.role});

  final SongDisplay display;
  final SectionRole? role;

  @override
  ConsumerState<SongDisplayPreview> createState() => _SongDisplayPreviewState();
}

class _SongDisplayPreviewState extends ConsumerState<SongDisplayPreview> {
  final _scroll = ScrollController();
  final _body = GlobalKey();
  List<SongBlock> _blocks = const [];

  @override
  void didUpdateWidget(SongDisplayPreview old) {
    super.didUpdateWidget(old);
    final role = widget.role;
    if (role != null && role != old.role) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(role));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls to the first block shown in the style of [role], if any.
  void _scrollTo(SectionRole role) {
    final index = _blocks.indexWhere((b) => b.role == role);
    final root = _body.currentContext;
    if (index < 0 || root == null || !mounted) return;
    final key = ValueKey(('song-block', index));
    Element? found;
    void visit(Element e) {
      if (found != null) return;
      if (e.widget.key == key) {
        found = e;
        return;
      }
      e.visitChildElements(visit);
    }

    (root as Element).visitChildElements(visit);
    final target = found;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _chooseSong(String choice) async {
    final notifier = ref.read(songDisplayPreviewSongProvider.notifier);
    if (choice == 'demo') {
      await notifier.set(null);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final id = await pickSong(context, title: l10n.songDisplayPickSong);
    if (id != null) await notifier.set(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final songId = ref.watch(songDisplayPreviewSongProvider);
    // A deleted or missing song falls back to the demo song.
    final entry = songId == null ? null : ref.watch(songProvider(songId)).value;
    final song = parseChordProCached(
      entry?.chordproSource ?? songDisplayPreviewSource,
      selectors: ref.watch(selectorsProvider),
    );
    final lyricsOnly = settings.displayMode == DisplayMode.lyricsOnly;
    _blocks = buildSongBlocks(
      song,
      lyricsOnly: lyricsOnly,
      labeler: sectionLabeler(l10n),
    );
    final theme = liveTheme(
      Theme.of(context),
      settings.liveAppearance,
      settings.accent,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.songDisplayPreview,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            PopupMenuButton<String>(
              key: const Key('song-display-preview-song'),
              tooltip: l10n.songDisplayPickSong,
              onSelected: _chooseSong,
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const Key('song-display-preview-demo'),
                  value: 'demo',
                  child: Text(l10n.songDisplayDemoSong),
                ),
                PopupMenuItem(
                  key: const Key('song-display-preview-library'),
                  value: 'library',
                  child: Text(l10n.songDisplayLibrarySong),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        entry?.title ?? l10n.songDisplayDemoSong,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Theme(
            data: theme,
            child: Material(
              key: const Key('song-display-preview'),
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: theme.colorScheme.onSurface),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    child: KeyedSubtree(
                      key: _body,
                      child: SongBody(
                        song: song,
                        options: SongRenderOptions(
                          formatter: ChordFormatter.forSong(
                            song,
                            notation: settings.notation,
                            style: settings.chordStyle,
                            superscript: settings.chordSuperscript,
                          ),
                          lyricsOnly: lyricsOnly,
                          fontSize: 16,
                          columns: constraints.maxWidth >= 520 ? 2 : 1,
                          display: widget.display,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

/// Bold and italic of one element.
class _Toggles extends StatelessWidget {
  const _Toggles({
    required this.prefix,
    required this.bold,
    required this.italic,
    required this.onBold,
    required this.onItalic,
  });

  final String prefix;
  final bool bold;
  final bool italic;
  final ValueChanged<bool> onBold;
  final ValueChanged<bool> onItalic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          key: Key('song-display-$prefix-bold'),
          avatar: const Icon(Icons.format_bold),
          label: Text(l10n.songDisplayBold),
          selected: bold,
          showCheckmark: false,
          onSelected: onBold,
        ),
        FilterChip(
          key: Key('song-display-$prefix-italic'),
          avatar: const Icon(Icons.format_italic),
          label: Text(l10n.songDisplayItalic),
          selected: italic,
          showCheckmark: false,
          onSelected: onItalic,
        ),
      ],
    );
  }
}

class _Segments<T> extends StatelessWidget {
  const _Segments({
    super.key,
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: false,
    segments: [
      for (final MapEntry(:key, :value) in labels.entries)
        ButtonSegment(value: key, label: Text(value)),
    ],
    selected: {value},
    onSelectionChanged: (v) => onChanged(v.single),
  );
}

/// The palette: automatic plus the curated colours, in the tones of the
/// app theme.
class _Colors extends StatelessWidget {
  const _Colors({
    required this.name,
    required this.value,
    required this.onChanged,
  });

  final String name;
  final SongColor value;
  final ValueChanged<SongColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final color in SongColor.values)
            Tooltip(
              message: _colorName(l10n, color),
              child: Semantics(
                selected: color == value,
                button: true,
                label: '${l10n.songDisplayColor}: ${_colorName(l10n, color)}',
                child: InkResponse(
                  key: Key('song-display-$name-${color.name}'),
                  onTap: () => onChanged(color),
                  radius: 20,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          songColorValue(color, scheme.brightness) ??
                          scheme.surfaceContainerHighest,
                      border: Border.all(
                        color: color == value
                            ? scheme.onSurface
                            : scheme.outlineVariant,
                        width: color == value ? 3 : 1,
                      ),
                    ),
                    child: color == SongColor.auto
                        ? Text(
                            'A',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A section type: a filled dot for its own style, a ring when it
/// inherits; the parent is named unless it is the standard type.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.role,
    required this.display,
    required this.selected,
    required this.onSelected,
  });

  final SectionRole role;
  final SongDisplay display;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final from = role == SectionRole.standard
        ? null
        : display.allTypes[role]!.from;
    final style = display.styleOf(role);
    final dot =
        songColorValue(
          style.bar ? style.barColor : style.chordColor,
          scheme.brightness,
        ) ??
        scheme.primary;
    final name = songDisplayTypeName(l10n, role);
    return ChoiceChip(
      key: Key('song-display-type-${role.name}'),
      avatar: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: from == null ? dot : null,
          border: from == null ? null : Border.all(color: dot, width: 2),
        ),
      ),
      label: Text(
        from == null || from == SectionRole.standard
            ? name
            : '$name ↳ ${songDisplayTypeName(l10n, from)}',
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
