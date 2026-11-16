import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('sourceMetadata', () {
    test('reads long, short and meta forms', () {
      const source =
          '{t: Amazing Grace}\n{meta: artist John Newton}\n{key:G}\n'
          '{tempo 72}\n{time: 3/4 }\n[G]A-[C]ma-[G]zing';
      expect(sourceMetadata(source, 'title'), 'Amazing Grace');
      expect(sourceMetadata(source, 'artist'), 'John Newton');
      expect(sourceMetadata(source, 'key'), 'G');
      expect(sourceMetadata(source, 'tempo'), '72');
      expect(sourceMetadata(source, 'time'), '3/4');
      expect(sourceMetadata(source, 'capo'), isNull);
    });

    test('ignores selector variants and later songs', () {
      const source =
          '{key-piano: C}\n{title: One}\n{new_song}\n{title: Two}\n{key: D}';
      expect(sourceMetadata(source, 'key'), isNull);
      expect(sourceMetadata(source, 'title'), 'One');
    });

    test('an empty directive has an empty value', () {
      expect(sourceMetadata('{title: }\n', 'title'), '');
      expect(sourceMetadata('{key}\n', 'key'), '');
    });
  });

  group('setSourceMetadata', () {
    test('replaces the value in place, keeping the form', () {
      expect(
        setSourceMetadata('{t: Old}\n{key: G}\nla', 'title', 'New'),
        '{t: New}\n{key: G}\nla',
      );
      expect(
        setSourceMetadata('{meta: key G}\nla', 'key', 'A'),
        '{meta: key A}\nla',
      );
      expect(setSourceMetadata('{tempo 72}', 'tempo', '80'), '{tempo 80}');
      expect(setSourceMetadata('{title: }\n', 'title', 'X'), '{title: X}\n');
      expect(setSourceMetadata('{key}\n', 'key', 'E'), '{key: E}\n');
    });

    test('a value equal to the directive name is replaced, not the name', () {
      expect(
        setSourceMetadata('{title: title}\n', 'title', 'Song'),
        '{title: Song}\n',
      );
    });

    test('adds a missing directive at the end of the header', () {
      expect(
        setSourceMetadata('{title: T}\n{key: G}\n\n[G]la', 'tempo', '90'),
        '{title: T}\n{key: G}\n{tempo: 90}\n\n[G]la',
      );
      expect(
        setSourceMetadata('{start_of_verse}\nla', 'capo', '2'),
        '{capo: 2}\n{start_of_verse}\nla',
      );
      expect(
        setSourceMetadata('{title: T}', 'key', 'C'),
        '{title: T}\n{key: C}\n',
      );
      expect(setSourceMetadata('', 'title', 'T'), '{title: T}\n');
    });

    test('an empty value removes the directive line', () {
      expect(
        setSourceMetadata('{title: T}\n{capo: 2}\nla', 'capo', ''),
        '{title: T}\nla',
      );
      expect(
        setSourceMetadata('{title: T}\n{capo: 2}', 'capo', null),
        '{title: T}\n',
      );
      expect(
        setSourceMetadata('{title: T}\nla', 'capo', ' '),
        '{title: T}\nla',
      );
    });

    test('only changes the first song', () {
      expect(
        setSourceMetadata('{title: A}\n{new_song}\n{title: B}', 'title', 'C'),
        '{title: C}\n{new_song}\n{title: B}',
      );
    });

    test('the result parses to the new values', () {
      var source = '{title: T}\n\n{start_of_verse}\n[C]la\n{end_of_verse}\n';
      source = setSourceMetadata(source, 'key', 'Bb');
      source = setSourceMetadata(source, 'tempo', '120');
      source = setSourceMetadata(source, 'time', '6/8');
      final song = parseChordPro(source);
      expect(song.title, 'T');
      expect(song.keyName, 'Bb');
      expect(song.tempo, 120);
      expect(song.time, '6/8');
    });
  });

  test('metadataHeaderEnd stops at the first non-directive line', () {
    expect(metadataHeaderEnd('{title: T}\n{key: G}\n\nla'), 20);
    expect(metadataHeaderEnd('{start_of_verse}\nla'), 0);
    expect(metadataHeaderEnd('{title: T}'), 10);
  });
}
