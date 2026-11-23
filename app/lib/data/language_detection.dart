/// Detection of the language of song lyrics (ADR-0053, #805): frequent
/// function words of each language are counted, without a library and the
/// same on every platform. The result is only a suggestion; a language set
/// by hand always wins.
library;

/// Frequent words that mostly belong to one language. Words that are just
/// as common in another of the languages (`de`, `en`, `la`, `que`, `in`, …)
/// are left out, so that they do not blur the counts.
const _words = <String, Set<String>>{
  'de': {
    'der', 'das', 'und', 'ist', 'ich', 'du', 'wir', 'ihr', 'nicht', //
    'ein', 'eine', 'einen', 'dem', 'den', 'des', 'mit', 'auf', 'für', 'von',
    'zu', 'im', 'mein', 'dein', 'sein', 'auch', 'wie', 'wenn', 'noch', 'nur',
    'aus', 'bei', 'nach', 'über', 'immer', 'alle', 'mir', 'dich', 'mich',
    'dir', 'uns', 'euch', 'hat', 'haben', 'bin', 'bist', 'sind', 'wird',
    'werden', 'kann', 'doch', 'denn', 'wo', 'wer', 'ja', 'sie', 'er',
  },
  'en': {
    'the', 'and', 'you', 'i', 'to', 'of', 'my', 'that', 'it', 'your', 'we', //
    'for', 'with', 'all', 'are', 'this', 'love', 'not', 'what', 'when',
    'there', 'have', 'but', 'can', 'his', 'he', 'she', 'they', 'our', 'oh',
    'just', 'like', 'will', 'be', 'am', 'was', 'so', 'from', 'me', 'him',
  },
  'fr': {
    'les', 'et', 'je', 'elle', 'nous', 'vous', 'ils', 'une', 'des', 'est', //
    'pas', 'qui', 'dans', 'pour', 'sur', 'avec', 'mon', 'ton', 'ta', 'sa',
    'mes', 'tes', 'ce', 'cette', 'au', 'aux', 'ne', 'plus', 'tout', 'toi',
    'moi', 'leur', 'nos', 'vos', 'sont', 'être', 'mais', 'où', 'comme',
    'jamais', 'notre', 'votre', 'été', 'ça', 'c',
  },
  'it': {
    'il', 'gli', 'della', 'di', 'che', 'è', 'per', 'non', 'ti', 'ci', //
    'sono', 'io', 'noi', 'voi', 'lei', 'nel', 'nella', 'questo', 'quella',
    'più', 'anche', 'tutto', 'sei', 'ho', 'hai', 'alla', 'dal',
    'sempre', 'cuore', 'mio', 'tuo', 'suo', 'perché', 'cosa', 'ancora',
  },
  'es': {
    'el', 'los', 'las', 'y', 'por', 'para', 'con', 'está', 'estoy', 'yo', //
    'pero', 'más', 'muy', 'del', 'al', 'cuando', 'donde', 'nos', 'señor',
    'tú', 'también', 'eres', 'soy', 'hay', 'mi', 'lo', 'una', 'es', 'su',
    'tu', 'corazón', 'siempre', 'esta', 'este', 'todos',
  },
  'pt': {
    'o', 'os', 'e', 'um', 'do', 'dos', 'das', 'em', 'na', 'não', 'com', //
    'eu', 'ele', 'ela', 'nós', 'você', 'meu', 'minha', 'seu', 'sua', 'é',
    'são', 'mais', 'muito', 'também', 'quando', 'mas', 'coração', 'sempre',
    'vou', 'teu', 'tua', 'nosso', 'ao', 'pra',
  },
  'nl': {
    'het', 'een', 'van', 'ik', 'je', 'jij', 'niet', 'dat', 'op', 'te', //
    'met', 'voor', 'zijn', 'hij', 'zij', 'wij', 'mijn', 'maar', 'ook',
    'naar', 'uit', 'bij', 'wat', 'hoe', 'nog', 'geen', 'heeft', 'ben',
    'jou', 'jouw', 'onze', 'zo', 'heer', 'wordt', 'kan',
  },
};

/// Words of Swiss German (`gsw`) that Standard German does not have. Swiss
/// German lyrics also use many Standard German words (`und`, `du`, `wenn`,
/// …), so these words only decide between the two once the lyrics are
/// German at all. Words that are Standard German too (`weiss`, `seit`,
/// `hei` of `hei-lig`, …) are left out.
const _swissWords = {
  'isch', 'bisch', 'esch', 'hesch', 'häsch', 'gisch', 'chasch', 'weisch', //
  'machsch', 'liebsch', 'wotsch', 'seisch', 'muesch', 'wirsch', 'chunsch',
  'bruchsch', 'gsehsch', 'regiersch', 'nöd', 'nid', 'nüt', 'nüme', 'nümme',
  'öppis', 'öpper', 'niemer', 'meh', 'mee', 'scho', 'eifach', 'elei', 'zäme',
  'hüt', 'gä', 'gäh', 'chunnt', 'chunt', 'chumm', 'chum', 'cha', 'chan',
  'chind', 'chraft', 'chli', 'vo', 'uf', 'zue', 'guet', 'muet', 'bluet',
  'gnueg', 'güeti', 'dini', 'mini', 'sini', 'dinre', 'minre', 'mim', 'dim',
  'sim', 'eusi', 'üsi', 'üse', 'üses', 'üsem', 'euse', 'eui', 'eues', 'öis',
  'öise', 'öisi', 'oisi', 'üs', 'eus', 'läbe', 'liebi', 'härz', 'wält',
  'ändi', 'liecht', 'sunne', 'ohni', 'wäg', 'alli', 'alls', 'ganzi', 'jedi',
  'ewigi', 'kei', 'keis', 'hend', 'händ', 'hän', 'han', 'git', 'gits', 'gaht',
  'goht', 'stoh', 'stah', 'staht', 'wott', 'wüsse', 'mues', 'söll', 'wänn',
  'dänn', 'jetz', 'itz', 'nomal', 'nomol', 'emal', 'ume', 'fescht', 'geischt',
  'treit', 'bi', 'wil', 'au', 'gäge', 'lut', 'geit', 'wärk',
  'troue', 'tröie', 'starch', 'starche', 'wei', 'gliich', 'lönd',
};

/// Spellings of Swiss German that Standard German does not have: `üe`, a
/// doubled `i`, `u` or `ö` (`guet`, `ziit`, `Huus`, `ghööre`), and a `g`
/// before another consonant at the start (`gsi`, `gmacht`, `gfunde`).
final _swissSpelling = RegExp(r'üe|ii|uu|öö|^g[smfwz]');

/// Languages [detectLanguage] can recognise; *other* is only set by hand.
final detectableLanguages = [..._words.keys, 'gsw'];

/// Hits the most frequent language needs at least.
const _minHits = 5;

/// Share of all words the most frequent language must reach.
const _minShare = 0.12;

/// How far the most frequent language must be ahead of the second.
const _minLead = 1.5;

/// Swiss German words German lyrics need at least to be Swiss German.
const _minSwissHits = 3;

/// Share of the German hits (Standard and Swiss German words together) the
/// Swiss German words must reach.
const _minSwissShare = 0.2;

final _word = RegExp(r"[\p{L}]+", unicode: true);

/// The language of [text] (lyrics without chords), a code of
/// [detectableLanguages], or null when it is unclear: too few words, or
/// no language clearly ahead of the others. Better none than a wrong one.
///
/// Swiss German counts as German against the other languages; German
/// lyrics are Swiss German when enough of their German words are Swiss
/// German ones.
String? detectLanguage(String? text) {
  if (text == null || text.isEmpty) return null;
  final counts = {for (final l in _words.keys) l: 0};
  var total = 0, swiss = 0;
  for (final m in _word.allMatches(text.toLowerCase())) {
    total++;
    final w = m.group(0)!;
    if (_swissWords.contains(w) || _swissSpelling.hasMatch(w)) {
      swiss++;
      counts['de'] = counts['de']! + 1;
    }
    for (final MapEntry(key: language, value: words) in _words.entries) {
      if (words.contains(w)) counts[language] = counts[language]! + 1;
    }
  }
  final ranked = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final best = ranked[0], second = ranked[1];
  if (best.value < _minHits) return null;
  if (best.value < total * _minShare) return null;
  if (best.value < second.value * _minLead) return null;
  if (best.key == 'de' &&
      swiss >= _minSwissHits &&
      swiss >= best.value * _minSwissShare) {
    return 'gsw';
  }
  return best.key;
}
