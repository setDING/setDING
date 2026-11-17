import 'package:chordpro/chordpro.dart' hide Key;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../settings/settings.dart';
import '../sync/auth_providers.dart';
import '../util/app_version.dart';
import '../util/log.dart';
import 'account/account_section.dart';
import 'settings/latency_calibration.dart';
import 'theme.dart';
import 'widgets/breakpoint_builder.dart';
import 'widgets/dialogs.dart';

/// The categories of the settings screen, in order.
enum SettingsCategory { account, general, musician, display, live, about }

/// Settings (layer 4, ADR-0006), grouped into categories: the account on
/// top, then the personal settings (synced with the account) and the
/// settings of this device (ADR-0027), so it is clear which are synced.
///
/// On wide screens the categories are listed on the left and the selected one
/// is shown next to them; on narrow screens the overview lists the categories
/// and each one opens as its own page.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// Minimum width for showing the categories and their content side by side.
  static const wideLayoutWidth = 640.0;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsCategory _selected = SettingsCategory.account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: BreakpointBuilder(
        select: (constraints) =>
            constraints.maxWidth >= SettingsScreen.wideLayoutWidth,
        builder: (context, wide) {
          if (!wide) {
            return _CategoryList(
              onSelected: (c) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _CategoryPage(category: c),
                ),
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 300,
                child: _CategoryList(
                  selected: _selected,
                  onSelected: (c) => setState(() => _selected = c),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _CategoryContent(
                      key: ValueKey(_selected),
                      category: _selected,
                      showTitle: true,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension on SettingsCategory {
  /// Personal or device settings; null for the account itself.
  SettingSyncScope? get scope => switch (this) {
    SettingsCategory.account => null,
    SettingsCategory.general ||
    SettingsCategory.musician ||
    SettingsCategory.display => SettingSyncScope.personal,
    SettingsCategory.live || SettingsCategory.about => SettingSyncScope.device,
  };

  IconData get icon => switch (this) {
    SettingsCategory.account => Icons.account_circle_outlined,
    SettingsCategory.general => Icons.tune,
    SettingsCategory.musician => Icons.music_note_outlined,
    SettingsCategory.display => Icons.text_fields,
    SettingsCategory.live => Icons.play_circle_outline,
    SettingsCategory.about => Icons.info_outline,
  };

  String title(AppLocalizations l10n) => switch (this) {
    SettingsCategory.account => l10n.settingsSectionAccount,
    SettingsCategory.general => l10n.settingsSectionGeneral,
    SettingsCategory.musician => l10n.settingsSectionMusician,
    SettingsCategory.display => l10n.settingsSectionDisplay,
    SettingsCategory.live => l10n.settingsSectionLive,
    SettingsCategory.about => l10n.settingsSectionStorage,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    SettingsCategory.account => l10n.settingsCategoryAccountHint,
    SettingsCategory.general => l10n.settingsCategoryGeneralHint,
    SettingsCategory.musician => l10n.settingsCategoryMusicianHint,
    SettingsCategory.display => l10n.settingsCategoryDisplayHint,
    SettingsCategory.live => l10n.settingsCategoryLiveHint,
    SettingsCategory.about => l10n.settingsCategoryAboutHint,
  };
}

/// The list of categories; [selected] is highlighted in the wide layout.
class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.onSelected, this.selected});

  final SettingsCategory? selected;
  final ValueChanged<SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrow = selected == null;
    final items = <Widget>[];
    SettingSyncScope? group;
    for (final c in SettingsCategory.values) {
      if (c.scope case final scope? when scope != group) {
        group = scope;
        items.add(_GroupHeader(scope));
      }
      items.add(
        ListTile(
          key: Key('settings-category-${c.name}'),
          leading: Icon(c.icon),
          title: Text(c.title(l10n)),
          subtitle: Text(c.hint(l10n)),
          trailing: narrow ? const Icon(Icons.chevron_right) : null,
          selected: c == selected,
          onTap: () => onSelected(c),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: items,
    );
  }
}

/// A category opened as its own page (narrow layout).
class _CategoryPage extends StatelessWidget {
  const _CategoryPage({required this.category});

  final SettingsCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(category.title(l10n))),
      body: _CategoryContent(category: category),
    );
  }
}

/// The settings of one category.
class _CategoryContent extends ConsumerWidget {
  const _CategoryContent({
    super.key,
    required this.category,
    this.showTitle = false,
  });

  final SettingsCategory category;
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final children = switch (category) {
      SettingsCategory.account => [
        const AccountSection(),
        if (ref.watch(authProvider) != null)
          _Choice(
            l10n.settingsSyncMode,
            s.syncMode,
            {
              SyncMode.automatic: l10n.syncModeAutomatic,
              SyncMode.onStart: l10n.syncModeOnStart,
              SyncMode.manual: l10n.syncModeManual,
            },
            (v) => notifier.update((s) => s.copyWith(syncMode: v)),
            hint: switch (s.syncMode) {
              SyncMode.automatic => l10n.syncModeAutomaticHint,
              SyncMode.onStart => l10n.syncModeOnStartHint,
              SyncMode.manual => l10n.syncModeManualHint,
            },
          ),
      ],
      SettingsCategory.general => [
        _Choice(l10n.settingsLanguage, s.language, {
          LanguageMode.system: l10n.languageSystem,
          LanguageMode.de: l10n.languageDe,
          LanguageMode.en: l10n.languageEn,
        }, (v) => notifier.update((s) => s.copyWith(language: v))),
        _Choice(l10n.settingsTheme, s.themeMode, {
          ThemeMode.system: l10n.themeSystem,
          ThemeMode.light: l10n.themeLight,
          ThemeMode.dark: l10n.themeDark,
        }, (v) => notifier.update((s) => s.copyWith(themeMode: v))),
        _AccentTile(
          value: s.accent,
          onChanged: (v) => notifier.update((s) => s.copyWith(accent: v)),
        ),
      ],
      SettingsCategory.musician => [
        _InstrumentTile(settings: s, notifier: notifier),
        ListTile(
          title: Text(l10n.settingsUserName),
          subtitle: Text(
            s.userName.isEmpty
                ? '${l10n.notSet} – ${l10n.settingsUserNameHint}'
                : s.userName,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final name = await askText(
              context,
              title: l10n.settingsUserName,
              initial: s.userName,
              hint: l10n.settingsUserNameHint,
              allowEmpty: true,
            );
            if (name != null) {
              await notifier.update((s) => s.copyWith(userName: name));
            }
          },
        ),
        _Choice(
          l10n.settingsDiagrams,
          s.diagrams,
          {
            DiagramsPosition.off: l10n.diagramsOff,
            DiagramsPosition.top: l10n.diagramsTop,
            DiagramsPosition.bottom: l10n.diagramsBottom,
          },
          (v) => notifier.update((s) => s.copyWith(diagrams: v)),
          hint: l10n.settingsDiagramsHint,
        ),
        ..._beatTiles(l10n, s, notifier),
      ],
      SettingsCategory.display => [
        _Choice(l10n.settingsNotation, s.notation, {
          ChordNotation.international: l10n.notationInternational,
          ChordNotation.german: l10n.notationGerman,
        }, (v) => notifier.update((s) => s.copyWith(notation: v))),
        SwitchListTile(
          title: Text(l10n.settingsNashville),
          subtitle: Text(l10n.settingsNashvilleHint),
          value: s.nashville,
          onChanged: (v) => notifier.update((s) => s.copyWith(nashville: v)),
        ),
        _Choice(
          l10n.settingsChordStyle,
          s.chordStyle,
          {
            ChordStyle.asWritten: l10n.chordStyleAsWritten,
            ChordStyle.standard: l10n.chordStyleStandard,
            ChordStyle.jazz: l10n.chordStyleJazz,
          },
          (v) => notifier.update((s) => s.copyWith(chordStyle: v)),
          hint: l10n.settingsChordStyleHint,
        ),
        SwitchListTile(
          title: Text(l10n.settingsChordSuperscript),
          subtitle: Text(l10n.settingsChordSuperscriptHint),
          value: s.chordSuperscript,
          onChanged: s.chordStyle == ChordStyle.asWritten
              ? null
              : (v) => notifier.update((s) => s.copyWith(chordSuperscript: v)),
        ),
        _Choice(l10n.settingsDisplayMode, s.displayMode, {
          DisplayMode.lyricsAndChords: l10n.displayLyricsAndChords,
          DisplayMode.lyricsOnly: l10n.displayLyricsOnly,
        }, (v) => notifier.update((s) => s.copyWith(displayMode: v))),
        _Choice(
          l10n.settingsChorusRepeat,
          s.chorusRepeat,
          {
            ChorusRepeat.auto: l10n.chorusRepeatAuto,
            ChorusRepeat.full: l10n.chorusRepeatFull,
            ChorusRepeat.label: l10n.chorusRepeatLabel,
          },
          (v) => notifier.update((s) => s.copyWith(chorusRepeat: v)),
          hint: l10n.settingsChorusRepeatHint,
        ),
        SwitchListTile(
          title: Text(l10n.settingsSetProgress),
          subtitle: Text(l10n.settingsSetProgressHint),
          value: s.setProgress,
          onChanged: (v) => notifier.update((s) => s.copyWith(setProgress: v)),
        ),
      ],
      SettingsCategory.live => [
        ListTile(
          title: Text(l10n.settingsFontSize),
          subtitle: Slider(
            value: s.fontSize,
            min: AppSettings.minFontSize,
            max: AppSettings.maxFontSize,
            divisions: (AppSettings.maxFontSize - AppSettings.minFontSize)
                .round(),
            label: s.fontSize.round().toString(),
            onChanged: (v) => notifier.update((s) => s.copyWith(fontSize: v)),
          ),
          trailing: Text('${s.fontSize.round()}'),
        ),
        SwitchListTile(
          title: Text(l10n.settingsAutoFit),
          subtitle: Text(l10n.settingsAutoFitHint),
          value: s.autoFit,
          onChanged: (v) => notifier.update((s) => s.copyWith(autoFit: v)),
        ),
        _Choice(
          l10n.settingsColumns,
          s.columns,
          {
            ColumnMode.auto: l10n.columnsAuto,
            ColumnMode.one: l10n.columnsOne,
            ColumnMode.two: l10n.columnsTwo,
            ColumnMode.three: l10n.columnsThree,
          },
          (v) => notifier.update((s) => s.copyWith(columns: v)),
          hint: l10n.settingsColumnsHint,
        ),
        _Choice(l10n.settingsPageTurn, s.pageTurn, {
          PageTurnMode.full: l10n.pageTurnFull,
          PageTurnMode.half: l10n.pageTurnHalf,
        }, (v) => notifier.update((s) => s.copyWith(pageTurn: v))),
        ListTile(
          leading: const Icon(Icons.touch_app_outlined),
          subtitle: Text(l10n.settingsPageTurnHint),
        ),
        _Choice(
          l10n.settingsLiveAppearance,
          s.liveAppearance,
          {
            LiveAppearance.app: l10n.liveAppearanceApp,
            LiveAppearance.dark: l10n.liveAppearanceDark,
            LiveAppearance.black: l10n.liveAppearanceBlack,
          },
          (v) => notifier.update((s) => s.copyWith(liveAppearance: v)),
          hint: l10n.settingsLiveAppearanceHint,
        ),
        ..._clickDeviceTiles(l10n, s, notifier),
      ],
      SettingsCategory.about => [const _AboutTiles()],
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              category.title(l10n),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        if (category.scope case final scope?) _ScopeNote(scope),
        ...children,
      ],
    );
  }
}

/// Icon of personal (synced) and device settings (ADR-0027).
IconData scopeIcon(SettingSyncScope scope) => switch (scope) {
  SettingSyncScope.personal => Icons.cloud_outlined,
  SettingSyncScope.device => Icons.devices_outlined,
};

/// Heading of a group of categories in the category list.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.scope);

  final SettingSyncScope scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      key: Key('settings-group-${scope.name}'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(scopeIcon(scope), size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(switch (scope) {
              SettingSyncScope.personal => l10n.settingsGroupPersonal,
              SettingSyncScope.device => l10n.settingsGroupDevice,
            }, style: theme.textTheme.titleSmall?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Explains at the top of a category whether its settings are synced.
class _ScopeNote extends ConsumerWidget {
  const _ScopeNote(this.scope);

  final SettingSyncScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authProvider.select((u) => u != null));
    return ListTile(
      key: Key('settings-scope-${scope.name}'),
      leading: Icon(scopeIcon(scope)),
      subtitle: Text(switch (scope) {
        SettingSyncScope.personal when signedIn =>
          l10n.settingsScopePersonalHint,
        SettingSyncScope.personal => l10n.settingsScopePersonalSignedOutHint,
        SettingSyncScope.device => l10n.settingsScopeDeviceHint,
      }),
    );
  }
}

/// Beat and click in live mode (ADR-0026), personal (ADR-0027): a group of
/// the musician settings. Edge flash and song map are offered for drums
/// only; the click's details only while it is on.
List<Widget> _beatTiles(
  AppLocalizations l10n,
  AppSettings s,
  SettingsNotifier notifier,
) => [
  const Divider(),
  ListTile(
    key: const Key('settings-beat-section'),
    leading: const Icon(Icons.timer_outlined),
    title: Text(l10n.settingsBeatSection),
    subtitle: Text(l10n.settingsBeatSectionHint),
  ),
  SwitchListTile(
    key: const Key('settings-beat-display'),
    title: Text(l10n.settingsBeatDisplay),
    subtitle: Text(l10n.settingsBeatDisplayHint),
    value: s.showBeat,
    onChanged: (v) => notifier.update((s) => s.copyWith(beatDisplay: v)),
  ),
  if (s.isDrums)
    SwitchListTile(
      key: const Key('settings-edge-flash'),
      title: Text(l10n.settingsEdgeFlash),
      subtitle: Text(l10n.settingsEdgeFlashHint),
      value: s.showEdgeFlash,
      onChanged: (v) => notifier.update((s) => s.copyWith(edgeFlash: v)),
    ),
  SwitchListTile(
    key: const Key('settings-click'),
    title: Text(l10n.settingsClick),
    subtitle: Text(l10n.settingsClickHint),
    value: s.playClick,
    onChanged: (v) => notifier.update((s) => s.copyWith(click: v)),
  ),
  if (s.beatEnabled) ...[
    _Choice(
      l10n.settingsClickStart,
      s.beatStart,
      {
        ClickStart.automatic: l10n.clickStartAutomatic,
        ClickStart.manual: l10n.clickStartManual,
      },
      (v) => notifier.update((s) => s.copyWith(clickStart: v)),
      hint: l10n.settingsClickStartHint,
    ),
    _Choice(l10n.settingsCountIn, s.countInBars, {
      0: l10n.countInOff,
      1: l10n.countInOneBar,
      2: l10n.countInTwoBars,
    }, (v) => notifier.update((s) => s.copyWith(countInBars: v))),
    _Choice(l10n.settingsClickDuration, s.clickDuration, {
      ClickDuration.wholeSong: l10n.clickDurationSong,
      ClickDuration.countIn: l10n.clickDurationCountIn,
    }, (v) => notifier.update((s) => s.copyWith(clickDuration: v))),
  ],
  if (s.playClick) ...[
    _Choice(l10n.settingsClickSound, s.clickSound, {
      ClickSound.click: l10n.clickSoundClick,
      ClickSound.woodblock: l10n.clickSoundWoodblock,
      ClickSound.beep: l10n.clickSoundBeep,
    }, (v) => notifier.update((s) => s.copyWith(clickSound: v))),
    SwitchListTile(
      title: Text(l10n.settingsClickAccent),
      value: s.clickAccent,
      onChanged: (v) => notifier.update((s) => s.copyWith(clickAccent: v)),
    ),
    SwitchListTile(
      title: Text(l10n.settingsClickSubdivision),
      subtitle: Text(l10n.settingsClickSubdivisionHint),
      value: s.clickSubdivision,
      onChanged: (v) => notifier.update((s) => s.copyWith(clickSubdivision: v)),
    ),
  ],
  if (s.isDrums)
    SwitchListTile(
      key: const Key('settings-song-map'),
      title: Text(l10n.settingsSongMap),
      subtitle: Text(l10n.settingsSongMapHint),
      value: s.showSongMap,
      onChanged: (v) => notifier.update((s) => s.copyWith(songMap: v)),
    ),
];

/// The click on this device (ADR-0026, ADR-0027): volume and the delay of
/// the audio output, which depend on the device and its headphones.
List<Widget> _clickDeviceTiles(
  AppLocalizations l10n,
  AppSettings s,
  SettingsNotifier notifier,
) => [
  if (s.playClick) ...[
    const Divider(),
    ListTile(
      key: const Key('settings-click-volume'),
      leading: const Icon(Icons.volume_up_outlined),
      title: Text(l10n.settingsClickVolume),
      subtitle: Slider(
        value: s.clickVolume,
        divisions: 20,
        onChanged: (v) => notifier.update((s) => s.copyWith(clickVolume: v)),
      ),
      trailing: Text('${(s.clickVolume * 100).round()} %'),
    ),
    ListTile(
      key: const Key('settings-audio-latency'),
      title: Text(l10n.settingsAudioLatency),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.settingsAudioLatencyHint),
          ),
          Slider(
            value: s.audioLatencyMs.toDouble(),
            max: AppSettings.maxAudioLatencyMs.toDouble(),
            divisions: AppSettings.maxAudioLatencyMs ~/ 10,
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(audioLatencyMs: v.round())),
          ),
        ],
      ),
      trailing: Text(l10n.audioLatencyValue(s.audioLatencyMs)),
    ),
    Builder(
      builder: (context) => ListTile(
        key: const Key('settings-audio-latency-measure'),
        leading: const Icon(Icons.headphones_outlined),
        title: Text(l10n.audioLatencyCalibrate),
        onTap: () async {
          final ms = await showLatencyCalibration(context);
          if (ms != null) {
            await notifier.update((s) => s.copyWith(audioLatencyMs: ms));
          }
        },
      ),
    ),
  ],
];

/// Storage, diagnostic log and version.
class _AboutTiles extends ConsumerWidget {
  const _AboutTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usage = ref.watch(storageUsageProvider).value;
    final version = ref.watch(appVersionProvider).value;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.sd_storage_outlined),
          title: Text(l10n.settingsStorageUsed(formatBytes(usage ?? 0))),
        ),
        ListTile(
          key: const Key('copy-log'),
          leading: const Icon(Icons.bug_report_outlined),
          title: Text(l10n.settingsLogCopy),
          subtitle: Text(l10n.settingsLogCopyHint),
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(
                text: [
                  if (version != null) 'setDING $version',
                  Log.export(),
                ].join('\n'),
              ),
            );
            if (context.mounted) {
              showMessage(context, l10n.settingsLogCopied);
            }
          },
        ),
        ListTile(
          key: const Key('app-version'),
          leading: const Icon(Icons.info_outline),
          title: version == null ? null : Text(l10n.settingsVersion(version)),
          subtitle: Text(l10n.settingsAbout),
        ),
      ],
    );
  }
}

/// A setting with a few options, shown as a segmented button.
class _Choice<T> extends StatelessWidget {
  const _Choice(
    this.title,
    this.value,
    this.options,
    this.onChanged, {
    this.hint,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final void Function(T) onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hint != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!)),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final e in options.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {value},
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        ),
      ],
    ),
  );
}

/// The accent colour (issue #300): one swatch per colour in the current
/// brightness, the selected one with a check mark.
class _AccentTile extends StatelessWidget {
  const _AccentTile({required this.value, required this.onChanged});

  final AccentColor value;
  final void Function(AccentColor) onChanged;

  static String label(AppLocalizations l10n, AccentColor accent) =>
      switch (accent) {
        AccentColor.brand => l10n.accentBrand,
        AccentColor.red => l10n.accentRed,
        AccentColor.amber => l10n.accentAmber,
        AccentColor.green => l10n.accentGreen,
        AccentColor.teal => l10n.accentTeal,
        AccentColor.purple => l10n.accentPurple,
        AccentColor.pink => l10n.accentPink,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(l10n.settingsAccent),
          subtitle: Text(label(l10n, value)),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final accent in AccentColor.values)
                _AccentSwatch(
                  key: ValueKey('accent-${accent.name}'),
                  scheme: appTheme(brightness, accent).colorScheme,
                  label: label(l10n, accent),
                  selected: accent == value,
                  onTap: () => onChanged(accent),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    super.key,
    required this.scheme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme scheme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? Icon(Icons.check, color: scheme.onPrimary, size: 24)
              : null,
        ),
      ),
    ),
  );
}

class _InstrumentTile extends StatelessWidget {
  const _InstrumentTile({required this.settings, required this.notifier});

  final AppSettings settings;
  final SettingsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = {
      'guitar': l10n.instrumentGuitar,
      'ukulele': l10n.instrumentUkulele,
      'bass': l10n.instrumentBass,
      'keyboard': l10n.instrumentKeyboard,
      'vocals': l10n.instrumentVocals,
      'drums': l10n.instrumentDrums,
    };
    final current = settings.instrument.trim().toLowerCase();
    final isPreset = names.containsKey(current);
    return ListTile(
      title: Text(l10n.settingsInstrument),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.settingsInstrumentHint),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in names.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: current == e.key,
                  onSelected: (_) =>
                      notifier.update((s) => s.copyWith(instrument: e.key)),
                ),
              ChoiceChip(
                label: Text(
                  isPreset || current.isEmpty
                      ? l10n.instrumentOther
                      : settings.instrument,
                ),
                selected: !isPreset && current.isNotEmpty,
                onSelected: (_) async {
                  final value = await askText(
                    context,
                    title: l10n.settingsInstrument,
                    initial: isPreset ? '' : settings.instrument,
                  );
                  if (value != null && value.isNotEmpty) {
                    await notifier.update(
                      (s) => s.copyWith(instrument: value.toLowerCase()),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
