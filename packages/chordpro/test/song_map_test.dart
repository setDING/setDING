import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Song map of the drummer mode (ADR-0026, #336).
void main() {
  const source = '''
{title: Map}
{start_of_verse: Intro}
{comment-drums: Toms, four bars}
{end_of_verse}
{start_of_verse}
[G]Amazing <b>grace</b>, how [D]sweet
the sound
{end_of_verse}
{start_of_chorus}
{comment: Crash on 1}
[C]Through many dangers
{end_of_chorus}
{start_of_verse}
[G]Twas grace that taught
{end_of_verse}
{chorus}
''';

  List<String> codes(List<SongMapEntry> map) => [
    for (final e in map) e.part.code,
  ];

  test('without a sequence: the parts in document order', () {
    final song = parseChordPro(
      source,
      selectors: const SelectorContext(instrument: 'drums'),
    );
    final map = songMap(song, const []);
    expect(codes(map), ['I', 'V1', 'C', 'V2', 'C']);
    expect(map[0].notes, ['Toms, four bars']);
    expect(map[1].cue, 'Amazing grace, how sweet');
    expect(map[2].notes, ['Crash on 1']);
    expect(map[2].cue, 'Through many dangers');
    // The chorus recall repeats the chorus with its cue and notes.
    expect(map[4].cue, 'Through many dangers');
    expect(map[4].notes, ['Crash on 1']);
  });

  test('drum comments only for the drums', () {
    final song = parseChordPro(
      source,
      selectors: const SelectorContext(instrument: 'guitar'),
    );
    expect(songMap(song, const []).first.notes, isEmpty);
  });

  test('with a sequence: its order, repetitions and the next verse', () {
    final song = parseChordPro(source);
    final map = songMap(song, parseSequence('I, V, C x2, V, C, O'));
    expect(codes(map), ['I', 'V', 'C x2', 'V', 'C', 'O']);
    expect(map[1].cue, 'Amazing grace, how sweet');
    expect(map[2].part.repeat, 2);
    expect(map[3].cue, 'Twas grace that taught');
    // A part the song does not have: no cue.
    expect(map[5].cue, isNull);
    expect(map[5].part.part, SequencePart.outro);
  });

  test('numbered parts and a sequence that matches nothing', () {
    final song = parseChordPro(source);
    expect(songMap(song, parseSequence('V2, V1')).map((e) => e.cue), [
      'Twas grace that taught',
      'Amazing grace, how sweet',
    ]);
    expect(codes(songMap(song, parseSequence('X, Y'))), [
      'I',
      'V1',
      'C',
      'V2',
      'C',
    ]);
  });
}
