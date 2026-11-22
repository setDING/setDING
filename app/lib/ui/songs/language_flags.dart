import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The flags shown in front of the song languages in the language dialog
/// (ADR-0053, #845), so a language is found faster. Drawn for this project
/// as simplified SVGs (3:2, no coats of arms); bundled because Windows has
/// no flag emoji. A flag stands for the language here, not for a country:
/// English uses the Union Jack, Swiss German the Swiss flag.
const _flags = <String, String>{
  'de':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">'
      '<path fill="#000" d="M0 0h30v7H0z"/><path fill="#D00" d="M0 7h30v6H0z"/>'
      '<path fill="#FFCE00" d="M0 13h30v7H0z"/></svg>',
  'gsw':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">'
      '<path fill="#DA291C" d="M0 0h30v20H0z"/>'
      '<path fill="#FFF" d="M13 4h4v4h4v4h-4v4h-4v-4H9V8h4z"/></svg>',
  'en':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40">'
      '<clipPath id="c"><path d="M0 0h60v40H0z"/></clipPath>'
      '<g clip-path="url(#c)"><path fill="#012169" d="M0 0h60v40H0z"/>'
      '<path stroke="#FFF" stroke-width="8" d="M0 0l60 40M60 0L0 40"/>'
      '<path stroke="#C8102E" stroke-width="3" d="M0 0l60 40M60 0L0 40"/>'
      '<path stroke="#FFF" stroke-width="12" d="M30 0v40M0 20h60"/>'
      '<path stroke="#C8102E" stroke-width="7" d="M30 0v40M0 20h60"/></g></svg>',
  'fr':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">'
      '<path fill="#002395" d="M0 0h10v20H0z"/><path fill="#FFF" d="M10 0h10v20H10z"/>'
      '<path fill="#ED2939" d="M20 0h10v20H20z"/></svg>',
  'it':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">'
      '<path fill="#009246" d="M0 0h10v20H0z"/><path fill="#FFF" d="M10 0h10v20H10z"/>'
      '<path fill="#CE2B37" d="M20 0h10v20H20z"/></svg>',
  'es':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">'
      '<path fill="#AA151B" d="M0 0h30v20H0z"/>'
      '<path fill="#F1BF00" d="M0 5h30v10H0z"/></svg>',
  'pt':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">'
      '<path fill="#DA291C" d="M0 0h30v20H0z"/><path fill="#046A38" d="M0 0h12v20H0z"/>'
      '<circle cx="12" cy="10" r="4.5" fill="#FFE900"/>'
      '<circle cx="12" cy="10" r="2.6" fill="#DA291C"/></svg>',
  'nl':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">'
      '<path fill="#AE1C28" d="M0 0h30v7H0z"/><path fill="#FFF" d="M0 7h30v6H0z"/>'
      '<path fill="#21468B" d="M0 13h30v7H0z"/></svg>',
};

/// The flag of the song [language] code, 24×16 with a thin outline so white
/// stripes stay visible on a light surface; a neutral language icon for
/// *other* and every code without a flag.
class SongLanguageFlag extends StatelessWidget {
  const SongLanguageFlag({super.key, required this.language});

  final String language;

  static const width = 24.0;

  @override
  Widget build(BuildContext context) {
    final svg = _flags[language];
    final scheme = Theme.of(context).colorScheme;
    if (svg == null) {
      return SizedBox(
        width: width,
        child: Icon(Icons.language, size: 18, color: scheme.onSurfaceVariant),
      );
    }
    return ExcludeSemantics(
      child: Container(
        key: ValueKey('song-language-flag-$language'),
        width: width,
        height: 16,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        clipBehavior: Clip.antiAlias,
        child: SvgPicture.string(svg, fit: BoxFit.cover),
      ),
    );
  }
}
