import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/outbox.dart' show songLanguages;
import '../../l10n/generated/app_localizations.dart';
import '../../projection/projection_state.dart';
import '../../projection/projection_token_store.dart';
import '../../settings/settings.dart';
import '../songs/song_language.dart';
import '../widgets/dialogs.dart';
import 'settings_layout.dart';

/// The settings of the lyrics projection (ADR-0068 §11): device settings
/// in the live mode category, only where the app can project.
class ProjectionSettings extends ConsumerWidget {
  const ProjectionSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    void update(AppSettings Function(AppSettings) change) =>
        notifier.update(change);
    return SettingsSection(
      key: const Key('settings-projection'),
      title: l10n.settingsHeadingProjection,
      hint: l10n.settingsProjectionHint,
      children: [
        SettingsChoice(
          tileKey: const Key('settings-projection-theme'),
          icon: Icons.contrast,
          title: l10n.settingsProjectionColours,
          value: s.projectionTheme,
          options: {
            ProjectionTheme.dark: l10n.projectionThemeDark,
            ProjectionTheme.light: l10n.projectionThemeLight,
          },
          onChanged: (v) => update((s) => s.copyWith(projectionTheme: v)),
        ),
        SettingsChoice(
          tileKey: const Key('settings-projection-font'),
          icon: Icons.font_download_outlined,
          title: l10n.settingsProjectionFont,
          value: s.projectionFont,
          options: {
            ProjectionFont.sans: l10n.projectionFontSans,
            ProjectionFont.serif: l10n.projectionFontSerif,
          },
          onChanged: (v) => update((s) => s.copyWith(projectionFont: v)),
        ),
        SettingsChoice(
          tileKey: const Key('settings-projection-align'),
          icon: Icons.format_align_center,
          title: l10n.settingsProjectionAlign,
          value: s.projectionAlign,
          options: {
            ProjectionAlign.center: l10n.projectionAlignCenter,
            ProjectionAlign.left: l10n.projectionAlignLeft,
          },
          onChanged: (v) => update((s) => s.copyWith(projectionAlign: v)),
        ),
        SettingsChoice(
          tileKey: const Key('settings-projection-lines'),
          icon: Icons.format_line_spacing,
          title: l10n.settingsProjectionLines,
          hint: l10n.settingsProjectionLinesHint,
          value: s.projectionLines,
          options: {for (final n in projectionLineChoices) n: '$n'},
          onChanged: (v) => update((s) => s.copyWith(projectionLines: v)),
        ),
        SettingsSwitch(
          tileKey: const Key('settings-projection-label'),
          icon: Icons.label_important_outline,
          title: l10n.settingsProjectionShowLabel,
          hint: l10n.settingsProjectionShowLabelHint,
          value: s.projectionShowLabel,
          onChanged: (v) => update((s) => s.copyWith(projectionShowLabel: v)),
        ),
        SettingsChoice(
          tileKey: const Key('settings-projection-copyright'),
          icon: Icons.copyright,
          title: l10n.settingsProjectionCopyright,
          value: s.projectionCopyright,
          options: {
            ProjectionCopyright.everySlide: l10n.projectionCopyrightEvery,
            ProjectionCopyright.firstAndLast:
                l10n.projectionCopyrightFirstAndLast,
          },
          onChanged: (v) => update((s) => s.copyWith(projectionCopyright: v)),
        ),
        // Nine languages: a drop-down, not a row of segments.
        SettingsDropdown(
          dropdownKey: const Key('settings-projection-second-language'),
          expanded: true,
          icon: Icons.translate,
          title: l10n.settingsProjectionSecondLanguage,
          hint: l10n.settingsProjectionSecondLanguageHint,
          value: s.projectionSecondLanguage,
          options: {
            '': l10n.projectionSecondLanguageOff,
            for (final code in songLanguages)
              if (code != 'other') code: songLanguageName(l10n, code),
          },
          onChanged: (v) =>
              update((s) => s.copyWith(projectionSecondLanguage: v)),
        ),
        SettingsSwitch(
          tileKey: const Key('settings-projection-turns-slides'),
          icon: Icons.swipe_right_alt,
          title: l10n.settingsProjectionTurnsSlides,
          hint: l10n.settingsProjectionTurnsSlidesHint,
          value: s.projectionTurnsSlides,
          onChanged: (v) => update((s) => s.copyWith(projectionTurnsSlides: v)),
        ),
        SettingsSwitch(
          tileKey: const Key('settings-projection-markers'),
          icon: Icons.label_outline,
          title: l10n.settingsProjectionMarkers,
          hint: l10n.settingsProjectionMarkersHint,
          value: s.projectionMarkersAsText,
          onChanged: (v) =>
              update((s) => s.copyWith(projectionMarkersAsText: v)),
        ),
        SettingsSwitch(
          tileKey: const Key('settings-projection-preview'),
          icon: Icons.preview_outlined,
          title: l10n.settingsProjectionPreview,
          hint: l10n.settingsProjectionPreviewHint,
          value: s.projectionPreview,
          onChanged: (v) => update((s) => s.copyWith(projectionPreview: v)),
        ),
        // The address of this device and how to renew it (#1183).
        ListTile(
          key: const Key('settings-projection-renew'),
          leading: const Icon(Icons.autorenew),
          title: Text(l10n.settingsProjectionAddress),
          subtitle: Text(l10n.settingsProjectionAddressHint),
          onTap: () {
            ref.read(projectionTokenProvider).renew();
            showMessage(context, l10n.projectionRenewed);
          },
        ),
      ],
    );
  }
}
