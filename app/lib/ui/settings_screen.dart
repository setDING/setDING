import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../settings/settings.dart';
import '../sync/auth_providers.dart';
import 'account/account_section.dart';
import 'widgets/dialogs.dart';

/// Device settings (layer 4, ADR-0006).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final usage = ref.watch(storageUsageProvider).value;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );

    Widget choice<T>(
      String title,
      T value,
      Map<T, String> options,
      void Function(T) onChanged, {
      String? hint,
    }) => ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hint != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint)),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              header(l10n.settingsSectionAccount),
              const AccountSection(),
              if (ref.watch(authProvider) != null)
                choice(
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

              header(l10n.settingsSectionGeneral),
              choice(l10n.settingsLanguage, s.language, {
                LanguageMode.system: l10n.languageSystem,
                LanguageMode.de: l10n.languageDe,
                LanguageMode.en: l10n.languageEn,
              }, (v) => notifier.update((s) => s.copyWith(language: v))),
              choice(l10n.settingsTheme, s.themeMode, {
                ThemeMode.system: l10n.themeSystem,
                ThemeMode.light: l10n.themeLight,
                ThemeMode.dark: l10n.themeDark,
              }, (v) => notifier.update((s) => s.copyWith(themeMode: v))),

              header(l10n.settingsSectionMusician),
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

              choice(
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

              header(l10n.settingsSectionDisplay),
              choice(l10n.settingsNotation, s.notation, {
                ChordNotation.international: l10n.notationInternational,
                ChordNotation.german: l10n.notationGerman,
              }, (v) => notifier.update((s) => s.copyWith(notation: v))),
              SwitchListTile(
                title: Text(l10n.settingsNashville),
                subtitle: Text(l10n.settingsNashvilleHint),
                value: s.nashville,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(nashville: v)),
              ),
              choice(l10n.settingsDisplayMode, s.displayMode, {
                DisplayMode.lyricsAndChords: l10n.displayLyricsAndChords,
                DisplayMode.lyricsOnly: l10n.displayLyricsOnly,
              }, (v) => notifier.update((s) => s.copyWith(displayMode: v))),
              ListTile(
                title: Text(l10n.settingsFontSize),
                subtitle: Slider(
                  value: s.fontSize,
                  min: AppSettings.minFontSize,
                  max: AppSettings.maxFontSize,
                  divisions: (AppSettings.maxFontSize - AppSettings.minFontSize)
                      .round(),
                  label: s.fontSize.round().toString(),
                  onChanged: (v) =>
                      notifier.update((s) => s.copyWith(fontSize: v)),
                ),
                trailing: Text('${s.fontSize.round()}'),
              ),

              header(l10n.settingsSectionLive),
              SwitchListTile(
                title: Text(l10n.settingsAutoFit),
                subtitle: Text(l10n.settingsAutoFitHint),
                value: s.autoFit,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(autoFit: v)),
              ),
              choice(
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
              choice(
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
              choice(l10n.settingsPageTurn, s.pageTurn, {
                PageTurnMode.full: l10n.pageTurnFull,
                PageTurnMode.half: l10n.pageTurnHalf,
              }, (v) => notifier.update((s) => s.copyWith(pageTurn: v))),
              ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                subtitle: Text(l10n.settingsPedalHint),
              ),

              header(l10n.settingsSectionStorage),
              ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text(l10n.settingsStorageUsed(formatBytes(usage ?? 0))),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                subtitle: Text(l10n.settingsAbout),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
