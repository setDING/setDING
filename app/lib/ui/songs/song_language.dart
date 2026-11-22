import 'package:material_ui/material_ui.dart';

import '../../data/outbox.dart' show songLanguages;
import '../../l10n/generated/app_localizations.dart';
import 'language_flags.dart';

/// The name of a song language code (ADR-0053), e.g. "German".
String songLanguageName(AppLocalizations l10n, String code) =>
    l10n.songLanguageName(code);

/// The language filter's value for songs without a language (ADR-0053):
/// neither set by hand nor detected. No language code is empty.
const noSongLanguage = '';

/// The languages of [codes] in the order of [songLanguages], *other* last.
List<String> orderedSongLanguages(Iterable<String> codes) => [
  for (final l in songLanguages)
    if (codes.contains(l)) l,
];

/// The language of a song in a list (ADR-0053): a small outlined code such
/// as `EN`, with its name and whether it was detected or set by hand as
/// tooltip. Nothing for *other*.
class SongLanguageTag extends StatelessWidget {
  const SongLanguageTag({
    super.key,
    required this.language,
    this.byHand = false,
  });

  final String language;
  final bool byHand;

  @override
  Widget build(BuildContext context) {
    if (language == 'other') return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = songLanguageName(l10n, language);
    final tooltip = byHand
        ? l10n.songLanguageByHandTooltip(name)
        : l10n.songLanguageDetectedTooltip(name);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        excludeSemantics: true,
        child: Container(
          key: const ValueKey('song-language-tag'),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            l10n.songLanguageShort(language),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The choice of [chooseSongLanguage]: a language set by hand, or null to
/// use the detected one.
typedef SongLanguageChoice = ({String? language});

/// Asks for the language of a song (ADR-0053): *automatic* (the language
/// [detected] from the lyrics, if any) or one of [songLanguages]. [current]
/// is the language set by hand, null for automatic. Returns null when
/// cancelled.
Future<SongLanguageChoice?> chooseSongLanguage(
  BuildContext context, {
  required String? current,
  required String? detected,
}) {
  final l10n = AppLocalizations.of(context);
  Widget option(
    String? language,
    String label, {
    required String flag,
    String? hint,
  }) => SimpleDialogOption(
    key: ValueKey('song-language-${language ?? 'auto'}'),
    onPressed: () => Navigator.pop(context, (language: language)),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 24,
          child: language == current ? const Icon(Icons.check, size: 20) : null,
        ),
        const SizedBox(width: 8),
        SongLanguageFlag(language: flag),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (hint != null)
                Text(
                  hint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  return showDialog<SongLanguageChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.songLanguage),
      children: [
        option(
          null,
          detected == null
              ? l10n.songLanguageNotDetected
              : l10n.songLanguageAutomatic(songLanguageName(l10n, detected)),
          flag: detected ?? 'other',
          hint: l10n.songLanguageAutomaticHint,
        ),
        const Divider(),
        for (final l in songLanguages)
          option(l, songLanguageName(l10n, l), flag: l),
      ],
    ),
  );
}
