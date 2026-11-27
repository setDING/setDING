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

  /// The token of every start, in order.
  final tokens = <String>[];

  @override
  bool running = false;

  @override
  Future<void> start(String page, {required String token}) async {
    this.page = page;
    tokens.add(token);
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
    await projection.start('<html>', token: 'a' * 22);
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

  test('copyright on the first and last slide only', () {
    projection.options = const ProjectionOptions(
      copyright: ProjectionCopyright.firstAndLast,
    );
    projection.show(item(song));
    expect(host.last['copyright'], 'Public domain');
    projection.next();
    expect(host.last.containsKey('copyright'), isFalse);
    projection.next();
    projection.next();
    expect(host.last['copyright'], 'Public domain');
  });

  test('a second language found later keeps the slide and the manual mode', () {
    final english = parseChordPro(
      '{start_of_verse}\nFirst EN\n{end_of_verse}\n'
      '{start_of_chorus}\nChorus EN\n{end_of_chorus}\n',
    );
    projection.show(item(song));
    projection.next();
    projection.pairWith(song, english);
    expect(projection.slide, 1);
    expect(projection.manual, isTrue);
    expect(host.last['second'], ['Chorus EN']);

    // Too late: another song is shown by now.
    final other = parseChordPro('Other');
    projection.show(item(other));
    projection.pairWith(song, english);
    expect(host.last.containsKey('second'), isFalse);
  });

  test('page turns move the slides without making the song manual (#1181)', () {
    projection.show(item(song));
    expect(projection.turn(forward: false), isFalse, reason: 'first slide');
    expect(projection.turn(forward: true), isTrue);
    expect(projection.slide, 1);
    expect(projection.manual, isFalse);
    expect(projection.sectionLine, lineOf(song, 'Chorus line'));
    // Live mode shows the slide's page; that does not pull the slide back.
    projection.followSection(lineOf(song, 'First verse'));
    expect(projection.slide, 1);
    expect(projection.turn(forward: true), isTrue);
    expect(projection.turn(forward: true), isTrue);
    expect(projection.turn(forward: true), isFalse, reason: 'last slide');
    expect(projection.slide, 3);
    expect(projection.turn(forward: false), isTrue);
    expect(projection.slide, 2);

    // Blank or stopped: turns go on to live mode.
    projection.toggleBlank();
    expect(projection.turn(forward: true), isFalse);
    projection.toggleBlank();

    // Back into a song: its last slide; a new song follows live mode again.
    projection.show(item(song));
    projection.toLast();
    expect(projection.slide, 3);
    projection.show(item(song));
    projection.followSection(lineOf(song, 'Second verse'));
    expect(projection.slide, 2);
  });

  test('the page of a section', () {
    final pages = SongPageController();
    addTearDown(pages.dispose);
    pages.attach(3, sections: [3, 12, 20]);
    expect(pages.pageOf(2), isNull);
    expect(pages.pageOf(3), 0);
    expect(pages.pageOf(15), 1);
    expect(pages.pageOf(30), 2);
    pages.show(2);
    expect(pages.page, 2);
    pages.show(7);
    expect(pages.page, 2);
  });

  test('a new address restarts a running projection with it (#1183)', () async {
    projection.show(item(song));
    projection.next();
    await projection.renew('b' * 22);
    expect(host.tokens, ['a' * 22, 'b' * 22]);
    expect(host.page, '<html>');
    expect(host.last['lines'], ['Chorus line'], reason: 'the same slide');
    await projection.stop();
    await projection.renew('c' * 22);
    expect(host.tokens, hasLength(2), reason: 'not running: no restart');
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
