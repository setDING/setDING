import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/language_detection.dart';

/// Lyrics written for these tests, a few lines like a verse and a chorus.
const _lyrics = {
  'de': '''
Ich gehe durch die Nacht und du bist immer bei mir,
wenn der Wind über das Land zieht, singe ich mit dir.
Du bist mein Licht, auch wenn die Sterne nicht mehr scheinen,
wir sind nicht allein, denn alle Wege führen heim.''',
  'en': '''
I walk along the river and you are always there with me,
when the wind is in the willows and the night is calling me.
You are my light, and all the stars will shine for you,
we are not alone, so hold on to what is true.''',
  'fr': '''
Je marche dans la nuit et tu es toujours avec moi,
quand le vent chante sur la mer, je pense à toi.
Tu es ma lumière, et les étoiles brillent pour nous,
nous ne sommes pas seuls, ce chemin est à vous.''',
  'it': '''
Io cammino nella notte e tu sei sempre con me,
quando il vento canta sul mare, penso solo a te.
Sei la mia luce, e le stelle brillano per noi,
non siamo soli, questo è il cuore che vuoi.''',
  'es': '''
Yo camino por la noche y tú estás siempre conmigo,
cuando el viento canta en el mar, pienso en ti, amigo.
Eres mi luz, y las estrellas brillan para los dos,
no estamos solos, este es el camino de Dios.''',
  'pt': '''
Eu caminho pela noite e você está sempre comigo,
quando o vento canta no mar, penso em ti, amigo.
Você é a minha luz, e as estrelas brilham por nós,
não estamos sós, o coração não perde a voz.''',
  'nl': '''
Ik loop door de nacht en jij bent altijd bij mij,
als de wind over het water zingt, ben ik vrij.
Jij bent mijn licht, en de sterren schijnen voor ons,
wij zijn niet alleen, dit is de weg naar het licht.''',
};

void main() {
  for (final MapEntry(key: language, value: text) in _lyrics.entries) {
    test('detects $language', () => expect(detectLanguage(text), language));
  }

  test('every detectable language has lyrics in this test', () {
    expect(_lyrics.keys, unorderedEquals(detectableLanguages));
  });

  test('ignores case and punctuation', () {
    expect(detectLanguage(_lyrics['en']!.toUpperCase()), 'en');
  });

  test('detects nothing in empty or short texts', () {
    expect(detectLanguage(null), isNull);
    expect(detectLanguage(''), isNull);
    expect(detectLanguage('Halleluja, Amen'), isNull);
    expect(detectLanguage('Ich und du'), isNull);
  });

  test('detects nothing in a text that mixes two languages evenly', () {
    expect(detectLanguage('${_lyrics['de']}\n${_lyrics['en']}'), isNull);
  });

  test(
    'a song with a short refrain in another language keeps its language',
    () {
      final text =
          '${_lyrics['de']}\n${_lyrics['de']}\nHallelujah, glory to the King';
      expect(detectLanguage(text), 'de');
    },
  );

  test('Swiss German is German or nothing, never another language', () {
    const text = '''
Mir sind hüt alli da und mir singed zäme es Lied,
das chunnt vo ganzem Härze, wo mer nöd vergässed.
Du bisch mis Liecht, au wenn d Stärne nümme schined,
mir sind nöd elei, will alli Wäg hei füehred.''';
    expect(detectLanguage(text), anyOf(isNull, 'de'));
  });

  test('numbers and chords-like tokens do not count as words', () {
    expect(detectLanguage('1 2 3 4 G D Em C 120'), isNull);
  });
}
