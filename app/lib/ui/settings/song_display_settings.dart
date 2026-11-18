import 'package:chordpro/chordpro.dart' hide Key;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../live/live_theme.dart';
import '../render/song_display_colors.dart';
import '../render/song_view.dart';
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

/// The song display settings (ADR-0033): a preview, the presets, and the
/// styles of the selected section type.
class SongDisplaySettings extends ConsumerStatefulWidget {
  const SongDisplaySettings({super.key});

  @override
  ConsumerState<SongDisplaySettings> createState() =>
      _SongDisplaySettingsState();
}

class _SongDisplaySettingsState extends ConsumerState<SongDisplaySettings> {
  SectionRole _role = SectionRole.standard;

  void _set(SongDisplay display) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(songDisplay: display));

  Future<void> _choosePreset(SongDisplay current, SongDisplayPreset p) async {
    final l10n = AppLocalizations.of(context);
    if (current.preset == SongDisplayPreset.custom &&
        !await confirm(
          context,
          title: l10n.songDisplayDiscardTitle,
          message: l10n.songDisplayDiscardMessage(
            songDisplayPresetName(l10n, p),
          ),
          action: l10n.songDisplayDiscard,
        )) {
      return;
    }
    _set(SongDisplay.preset(p));
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.songDisplayPreview),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Preview(display: display, settings: settings),
        ),
        _Heading(l10n.songDisplayPreset),
        Padding(
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
                        : (_) => _choosePreset(display, p),
                  ),
            ],
          ),
        ),
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

/// The preview song in the live appearance of this device.
class _Preview extends StatelessWidget {
  const _Preview({required this.display, required this.settings});

  final SongDisplay display;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = liveTheme(
      Theme.of(context),
      settings.liveAppearance,
      settings.accent,
    );
    final song = parseChordPro(songDisplayPreviewSource);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => Material(
          key: const Key('song-display-preview'),
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: theme.colorScheme.onSurface),
            child: LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: const EdgeInsets.all(16),
                child: SongBody(
                  song: song,
                  options: SongRenderOptions(
                    formatter: ChordFormatter.forSong(
                      song,
                      notation: settings.notation,
                      style: settings.chordStyle,
                      superscript: settings.chordSuperscript,
                    ),
                    fontSize: 16,
                    columns: constraints.maxWidth >= 520 ? 2 : 1,
                    display: display,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
                    width: 32,
                    height: 32,
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
