import 'package:chordpro/chordpro.dart' hide Key;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../settings/settings.dart';
import '../sync/auth_providers.dart';
import '../sync/update_check.dart';
import '../util/app_version.dart';
import '../util/log.dart';
import 'account/account_section.dart';
import 'backup/full_backup.dart';
import 'bands/bands_settings.dart';
import 'settings/latency_calibration.dart';
import 'settings/midi_settings.dart';
import 'settings/midi_test_screen.dart';
import 'settings/song_display_settings.dart';
import 'theme.dart';
import 'widgets/app_info.dart';
import 'widgets/breakpoint_builder.dart';
import 'widgets/click_pickers.dart' show subdivisionLabel;
import 'widgets/dialogs.dart';

/// The categories of the settings screen, in order.
/// The most used ones come first; the account and the organizations and
/// bands, set up once and rarely opened afterwards, come last.
enum SettingsCategory {
  general,
  display,
  songDisplay,
  musician,
  live,
  midi,
  about,
  account,
  bands,
  development,
}

/// The groups of the category list, in order: the personal settings (synced
/// with the account), the settings of this device (ADR-0027) and the account
/// with the organizations and bands, and in developer mode the test
/// features (#559).
enum _CategoryGroup { personal, device, account, development }

/// Settings (layer 4, ADR-0006), grouped into categories: the personal
/// settings (synced with the account) and the settings of this device
/// (ADR-0027), so it is clear which are synced, and at the bottom the account
/// and, when signed in, the organizations and bands.
///
/// On wide screens the categories are listed on the left and the selected one
/// is shown next to them; on narrow screens the overview lists the categories
/// and each one opens as its own page.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  /// Minimum width for showing the categories and their content side by side.
  static const wideLayoutWidth = 640.0;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsCategory _selected = SettingsCategory.values.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // After signing out the organizations and bands are no longer listed.
    final signedIn = ref.watch(authProvider.select((u) => u != null));
    final (developer, keyboard) = ref.watch(
      settingsProvider.select((s) => (s.developerMode, s.isKeyboard)),
    );
    final selected =
        _selected.visible(
          signedIn: signedIn,
          developer: developer,
          keyboard: keyboard,
        )
        ? _selected
        : SettingsCategory.values.first;
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
                  selected: selected,
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
                      key: ValueKey(selected),
                      category: selected,
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
  /// Personal or device settings; null for the account and the
  /// organizations and bands, which belong to the account.
  SettingSyncScope? get scope => switch (this) {
    SettingsCategory.account ||
    SettingsCategory.bands ||
    SettingsCategory.development => null,
    SettingsCategory.general ||
    SettingsCategory.musician ||
    SettingsCategory.display ||
    SettingsCategory.songDisplay => SettingSyncScope.personal,
    SettingsCategory.live ||
    SettingsCategory.midi ||
    SettingsCategory.about => SettingSyncScope.device,
  };

  _CategoryGroup get group => switch (scope) {
    _ when this == SettingsCategory.development => _CategoryGroup.development,
    SettingSyncScope.personal => _CategoryGroup.personal,
    SettingSyncScope.device => _CategoryGroup.device,
    null => _CategoryGroup.account,
  };

  IconData get icon => switch (this) {
    SettingsCategory.account => Icons.account_circle_outlined,
    SettingsCategory.bands => Icons.groups_outlined,
    SettingsCategory.general => Icons.tune,
    SettingsCategory.musician => Icons.music_note_outlined,
    SettingsCategory.display => Icons.text_fields,
    SettingsCategory.songDisplay => Icons.palette_outlined,
    SettingsCategory.live => Icons.play_circle_outline,
    SettingsCategory.midi => Icons.piano_outlined,
    SettingsCategory.about => Icons.info_outline,
    SettingsCategory.development => Icons.science_outlined,
  };

  String title(AppLocalizations l10n) => switch (this) {
    SettingsCategory.account => l10n.settingsSectionAccount,
    SettingsCategory.bands => l10n.settingsSectionBands,
    SettingsCategory.general => l10n.settingsSectionGeneral,
    SettingsCategory.musician => l10n.settingsSectionMusician,
    SettingsCategory.display => l10n.settingsSectionDisplay,
    SettingsCategory.songDisplay => l10n.settingsSectionSongDisplay,
    SettingsCategory.live => l10n.settingsSectionLive,
    SettingsCategory.midi => l10n.settingsSectionMidi,
    SettingsCategory.about => l10n.settingsSectionStorage,
    SettingsCategory.development => l10n.settingsSectionDevelopment,
  };

  /// Whether the category is listed: the organizations and bands only for
  /// signed-in users (what they may do there depends on their roles), the
  /// test features only in developer mode (#559).
  bool visible({
    required bool signedIn,
    required bool developer,
    required bool keyboard,
  }) => switch (this) {
    SettingsCategory.bands => signedIn,
    SettingsCategory.development => developer,
    // The keyboard MIDI settings only for keyboard players (ADR-0039).
    SettingsCategory.midi => keyboard,
    _ => true,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    SettingsCategory.account => l10n.settingsCategoryAccountHint,
    SettingsCategory.bands => l10n.settingsCategoryBandsHint,
    SettingsCategory.general => l10n.settingsCategoryGeneralHint,
    SettingsCategory.musician => l10n.settingsCategoryMusicianHint,
    SettingsCategory.display => l10n.settingsCategoryDisplayHint,
    SettingsCategory.songDisplay => l10n.settingsCategorySongDisplayHint,
    SettingsCategory.live => l10n.settingsCategoryLiveHint,
    SettingsCategory.midi => l10n.settingsCategoryMidiHint,
    SettingsCategory.about => l10n.settingsCategoryAboutHint,
    SettingsCategory.development => l10n.settingsCategoryDevelopmentHint,
  };
}

/// The list of categories; [selected] is highlighted in the wide layout.
class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.onSelected, this.selected});

  final SettingsCategory? selected;
  final ValueChanged<SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final narrow = selected == null;
    final signedIn = ref.watch(authProvider.select((u) => u != null));
    final (developer, keyboard) = ref.watch(
      settingsProvider.select((s) => (s.developerMode, s.isKeyboard)),
    );
    final update = ref.watch(updateCheckProvider) != null;
    final items = <Widget>[];
    _CategoryGroup? group;
    for (final c in SettingsCategory.values) {
      if (!c.visible(
        signedIn: signedIn,
        developer: developer,
        keyboard: keyboard,
      )) {
        continue;
      }
      if (c.group != group) {
        group = c.group;
        items.add(_GroupHeader(c.group));
      }
      items.add(
        ListTile(
          key: Key('settings-category-${c.name}'),
          leading: Badge(
            isLabelVisible: update && c == SettingsCategory.about,
            child: Icon(c.icon),
          ),
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
      SettingsCategory.bands => [const BandsSettings()],
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
        SwitchListTile(
          key: const Key('settings-developer-mode'),
          title: Text(l10n.settingsDeveloperMode),
          subtitle: Text(l10n.settingsDeveloperModeHint),
          value: s.developerMode,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(developerMode: v)),
        ),
      ],
      SettingsCategory.songDisplay => [const SongDisplaySettings()],
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
          key: const Key('settings-show-outside-sequence'),
          title: Text(l10n.settingsShowOutsideSequence),
          subtitle: Text(l10n.settingsShowOutsideSequenceHint),
          value: s.showOutsideSequence,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(showOutsideSequence: v)),
        ),
        SwitchListTile(
          title: Text(l10n.settingsSetProgress),
          subtitle: Text(l10n.settingsSetProgressHint),
          value: s.setProgress,
          onChanged: (v) => notifier.update((s) => s.copyWith(setProgress: v)),
        ),
        // Freehand annotations (ADR-0032).
        SwitchListTile(
          key: const Key('settings-show-annotations'),
          title: Text(l10n.settingsShowAnnotations),
          subtitle: Text(l10n.settingsShowAnnotationsHint),
          value: s.showAnnotations,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(showAnnotations: v)),
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
        // Freehand annotations (ADR-0032).
        SwitchListTile(
          key: const Key('settings-annotation-finger'),
          title: Text(l10n.settingsAnnotationFinger),
          subtitle: Text(l10n.settingsAnnotationFingerHint),
          value: s.annotationFinger,
          onChanged: (v) =>
              notifier.update((s) => s.copyWith(annotationFinger: v)),
        ),
      ],
      // MIDI program changes to a keyboard (ADR-0039).
      SettingsCategory.midi => [const MidiSettings()],
      SettingsCategory.about => [const _AboutTiles()],
      SettingsCategory.development => [
        const _ExperimentalNote(),
        // Prototype of MIDI program changes (ADR-0039, #512).
        ListTile(
          key: const Key('settings-midi-test'),
          leading: const Icon(Icons.piano_outlined),
          title: Text(l10n.midiTestTitle),
          subtitle: Text(l10n.midiTestTileHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MidiTestScreen()),
          ),
        ),
      ],
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
/// States at the top of the *Development* category that its features are
/// experimental (#559).
class _ExperimentalNote extends StatelessWidget {
  const _ExperimentalNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('settings-experimental-note'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.science_outlined,
          color: scheme.onTertiaryContainer,
        ),
        title: Text(
          l10n.settingsDevelopmentNoteTitle,
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        subtitle: Text(
          l10n.settingsDevelopmentNote,
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.group);

  final _CategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      key: Key('settings-group-${group.name}'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(
            switch (group) {
              _CategoryGroup.personal => scopeIcon(SettingSyncScope.personal),
              _CategoryGroup.device => scopeIcon(SettingSyncScope.device),
              _CategoryGroup.account => Icons.account_circle_outlined,
              _CategoryGroup.development => Icons.science_outlined,
            },
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(switch (group) {
              _CategoryGroup.personal => l10n.settingsGroupPersonal,
              _CategoryGroup.device => l10n.settingsGroupDevice,
              _CategoryGroup.account => l10n.settingsGroupAccount,
              _CategoryGroup.development => l10n.settingsGroupDevelopment,
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
    _Choice(
      l10n.settingsClickInBackground,
      s.clickInBackground,
      {
        ClickInBackground.stop: l10n.clickInBackgroundStop,
        ClickInBackground.keepPlaying: l10n.clickInBackgroundKeepPlaying,
      },
      (v) => notifier.update((s) => s.copyWith(clickInBackground: v)),
      hint: l10n.settingsClickInBackgroundHint,
    ),
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
    _Choice(
      l10n.settingsClickSubdivision,
      s.clickSubdivision,
      {for (final v in Subdivision.values) v: subdivisionLabel(l10n, v)},
      (v) => notifier.update((s) => s.copyWith(clickSubdivision: v)),
      hint: l10n.settingsClickSubdivisionHint,
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
    final whatsNew = ref.watch(recentNotesProvider);
    return Column(
      children: [
        // A newer release (ADR-0036).
        if (ref.watch(updateCheckProvider) != null)
          const UpdateAvailableTile(key: Key('update-available')),
        ListTile(
          leading: const Icon(Icons.sd_storage_outlined),
          title: Text(l10n.settingsStorageUsed(formatBytes(usage ?? 0))),
        ),
        // Full backup and restore (#639, ADR-0043).
        const BackupTiles(),
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
          // The notes of the recent versions, again (ADR-0041).
          trailing: whatsNew != null && whatsNew.isNotEmpty
              ? const WhatsNewButton(key: Key('whats-new'))
              : null,
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
