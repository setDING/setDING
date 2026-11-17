import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('Meter.tryParse', () {
    test('simple meters count the note value', () {
      final m = Meter.tryParse('4/4')!;
      expect(m.kind, MeterKind.simple);
      expect(m.beatsPerBar, 4);
      expect(m.beatUnit, BeatUnit.quarter);
      expect(m.subdivisions, 2);
      expect(m.accents, [
        BeatAccent.bar,
        BeatAccent.none,
        BeatAccent.none,
        BeatAccent.none,
      ]);
      expect(Meter.tryParse('3/4')!.beatsPerBar, 3);
      expect(Meter.tryParse('2/2')!.beatUnit, BeatUnit.half);
      expect(Meter.tryParse('2/2')!.subdivisions, 4);
      expect(Meter.tryParse(' 3 / 8 ')!.kind, MeterKind.simple);
    });

    test('compound meters count the dotted quarter', () {
      final m = Meter.tryParse('6/8')!;
      expect(m.kind, MeterKind.compound);
      expect(m.beatsPerBar, 2);
      expect(m.beatUnit, BeatUnit.dottedQuarter);
      expect(m.subdivisions, 3);
      expect(m.accents, [BeatAccent.bar, BeatAccent.none]);
      expect(Meter.tryParse('12/8')!.beatsPerBar, 4);
      expect(Meter.tryParse('9/8')!.beatsPerBar, 3);
      expect(Meter.tryParse('6/16')!.beatUnit, BeatUnit.dottedEighth);
    });

    test('odd meters count eighths, accents from the grouping', () {
      final plain = Meter.tryParse('7/8')!;
      expect(plain.kind, MeterKind.odd);
      expect(plain.beatsPerBar, 7);
      expect(plain.beatUnit, BeatUnit.eighth);
      expect(plain.groups, [7]);
      expect(plain.groupingLabel, isNull);
      expect(plain.accents.where((a) => a != BeatAccent.none), hasLength(1));

      final grouped = Meter.tryParse('7/8', grouping: '2+2+3')!;
      expect(grouped.groups, [2, 2, 3]);
      expect(grouped.groupingLabel, '2+2+3');
      expect(grouped.accents, [
        BeatAccent.bar,
        BeatAccent.none,
        BeatAccent.group,
        BeatAccent.none,
        BeatAccent.group,
        BeatAccent.none,
        BeatAccent.none,
      ]);
      expect(Meter.tryParse('5/8', grouping: '3 + 2')!.groups, [3, 2]);
    });

    test('a grouping that does not add up is ignored', () {
      expect(Meter.tryParse('7/8', grouping: '2+2+2')!.groups, [7]);
      expect(Meter.tryParse('7/8', grouping: 'x')!.groups, [7]);
      expect(Meter.tryParse('7/8', grouping: '7')!.groups, [7]);
      expect(Meter.tryParse('4/4', grouping: '2+2')!.groups, [4]);
    });

    test('unreadable values', () {
      expect(Meter.tryParse(null), isNull);
      expect(Meter.tryParse(''), isNull);
      expect(Meter.tryParse('4'), isNull);
      expect(Meter.tryParse('4/3'), isNull);
      expect(Meter.tryParse('0/4'), isNull);
      expect(Meter.tryParse('waltz'), isNull);
    });

    test('durations', () {
      expect(Meter.common.beatDuration(120), const Duration(milliseconds: 500));
      expect(Meter.common.barDuration(120), const Duration(seconds: 2));
      expect(
        Meter.tryParse('6/8')!.barDuration(60),
        const Duration(seconds: 2),
      );
    });
  });

  group('Song.meter', () {
    test('from {time} and {x_time_grouping}', () {
      final song = parseChordPro(
        '{title: T}\n{time: 7/8}\n{x_time_grouping: 3+2+2}\n',
      );
      expect(song.timeGrouping, '3+2+2');
      expect(song.meter.groups, [3, 2, 2]);
      expect(song.meta['x_time_grouping'], ['3+2+2']);
    });

    test('4/4 without or with an unreadable {time}', () {
      expect(parseChordPro('{title: T}').meter, Meter.common);
      expect(parseChordPro('{title: T}\n{time: fast}').meter, Meter.common);
    });

    test('the first {time} applies', () {
      final song = parseChordPro('{time: 3/4}\n[C]a\n{time: 4/4}\n[G]b');
      expect(song.meter.beatsPerBar, 3);
    });
  });
}
