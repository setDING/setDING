import 'package:chordpro/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/projection/projection_controller.dart';
import 'package:setding/projection/projection_state.dart';
import 'package:setding/ui/live/live_screen.dart' show SongPageController;

/// A host that records what it would send to the browsers.
class FakeProjectionHost implements ProjectionHost {
  FakeProjectionHost({this.addresses = const []});

  final List<Uri> addresses;
  final sent = <ProjectionState>[];
  String? page;
  var starts = 0;

  @override
  bool running = false;

  @override
  Future<void> start(String page) async {
    this.page = page;
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async => running = false;

  @override
  void update(ProjectionState state) => sent.add(state);

  @override
  Future<List<Uri>> urls() async => running ? addresses : const [];

  Map<String, Object?> get last => sent.last.toJson();
}

/// The projection of live mode (ADR-0068 §5–8, #1169).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeProjectionHost host;
  late ProjectionController projection;

  setUp(() async {
    host = FakeProjectionHost();
    projection = ProjectionController(host);
    await projection.start('<html>');
  });

  /// The source line of the section of [song] whose first line is [text].
  int lineOf(Song song, String text) => sourceLineOf(
    song.sections.firstWhere(
      (s) => s.lines.whereType<LyricLine>().any((l) => l.plainText == text),
    ),
  )!;

  final song = parseChordPro('''
{title: Amazing}
{copyright: Public domain}
{x_sequence: V1, C, V2, C}
{start_of_verse: Verse 1}
First verse
{end_of_verse}
{start_of_verse: Verse 2}
Second verse
{end_of_verse}
{start_of_chorus: Chorus}
Chorus line
{end_of_chorus}
''');

  ProjectionSong item(Song s) => ProjectionSong(s, sequence: s.sequence);

  test('starts blank and shows the first slide of a song', () {
    expect(host.page, '<html>');
    expect(host.last['blank'], isTrue);
    projection.show(item(song));
    expect(host.last['lines'], ['First verse']);
    expect(host.last['title'], 'Amazing');
    expect(host.last['copyright'], 'Public domain');
    expect(projection.slides, hasLength(4));
    expect(projection.missingCopyright, isFalse);
  });

  test('follows the section at the top of the page, a repeated part after '
      'the current slide', () {
    projection.show(item(song));
    projection.followSection(lineOf(song, 'Chorus line'));
    expect(projection.slide, 1);
    projection.followSection(lineOf(song, 'Second verse'));
    expect(projection.slide, 2);
    projection.followSection(lineOf(song, 'Chorus line'));
    expect(projection.slide, 3, reason: 'the chorus after the second verse');
    expect(host.last['lines'], ['Chorus line']);
    projection.followSection(null);
    expect(projection.slide, 3);
  });

  test('advancing by hand makes the song manual until the next one', () {
    projection.show(item(song));
    projection.next();
    expect(projection.slide, 1);
    expect(projection.manual, isTrue);
    projection.followSection(lineOf(song, 'Second verse'));
    expect(projection.slide, 1, reason: 'manual: live mode is not followed');
    projection.previous();
    projection.previous();
    expect(projection.slide, 0);
    expect(projection.canPrevious, isFalse);

    // Follow again: back to the section live mode shows.
    projection.follow();
    expect(projection.manual, isFalse);
    expect(projection.slide, 2);

    projection.next();
    projection.show(item(song));
    expect(projection.manual, isFalse);
    expect(projection.slide, 0);
  });

  test('next stops at the last slide', () {
    projection.show(item(song));
    for (var i = 0; i < 10; i++) {
      projection.next();
    }
    expect(projection.slide, 3);
    expect(projection.canNext, isFalse);
  });

  test('blank wins until switched off', () {
    projection.show(item(song));
    projection.toggleBlank();
    expect(host.last['blank'], isTrue);
    expect(host.last['lines'], isEmpty);
    projection.next();
    expect(host.last['blank'], isTrue);
    projection.toggleBlank();
    expect(host.last['lines'], ['Chorus line']);
  });

  test('a marker is blank, or its text with the option', () {
    projection.show(const ProjectionMarker('Prayer'));
    expect(host.last['blank'], isTrue);
    expect(projection.slides, isEmpty);
    projection.options = const ProjectionOptions(markersAsText: true);
    expect(host.last['marker'], 'Prayer');
    projection.show(null);
    expect(host.last['blank'], isTrue);
  });

  test('a song without lyrics or copyright', () {
    projection.show(item(parseChordPro('{title: Riff}\n[C] [G]\n')));
    expect(host.last['blank'], isTrue);
    expect(projection.missingCopyright, isFalse);
    projection.show(item(parseChordPro('{title: X}\nWords\n')));
    expect(host.last['lines'], ['Words']);
    expect(host.last.containsKey('copyright'), isFalse);
    expect(projection.missingCopyright, isTrue);
  });

  test('options: lines per slide, preview and a second language', () {
    final long = parseChordPro(
      '{start_of_verse}\n${List.generate(10, (i) => 'Line $i').join('\n')}\n{end_of_verse}\n',
    );
    projection.options = const ProjectionOptions(
      linesPerSlide: 4,
      preview: true,
    );
    projection.show(
      ProjectionSong(
        long,
        second: parseChordPro('{start_of_verse}\nOne\nTwo\n{end_of_verse}\n'),
      ),
    );
    expect(projection.slides, hasLength(3));
    expect(host.last['lines'], ['Line 0', 'Line 1', 'Line 2', 'Line 3']);
    expect(host.last['second'], ['One']);
    expect(host.last['next'], ['Line 4', 'Line 5', 'Line 6']);
  });

  test('nothing is sent while stopped', () async {
    await projection.stop();
    final count = host.sent.length;
    projection.show(item(song));
    projection.next();
    expect(host.sent, hasLength(count));
    expect(projection.running, isFalse);
  });

  test('the song page reports the first section of the shown page', () {
    final pages = SongPageController();
    addTearDown(pages.dispose);
    expect(pages.section, isNull);
    pages.attach(2, sections: [3, 9]);
    expect(pages.section, 3);
    pages.next();
    expect(pages.section, 9);
    pages.attach(1);
    expect(pages.section, isNull);
  });
}
