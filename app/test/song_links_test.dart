import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/songs/song_links_panel.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

/// Song sources from `{x_link}` in their own panel of the song view.
void main() {
  late List<Uri> opened;
  late bool openResult;
  setUp(() {
    opened = [];
    openResult = true;
    openSongLink = (uri) async {
      opened.add(uri);
      return openResult;
    };
  });

  const source = '''
{title: X}
{x_link: https://www.youtube.com/watch?v=abc | Live 2009}
{x_link: https://example.com/my demo.mp3}
{x_link: open.spotify.com/track/1}

[G]One''';

  Future<(TestApp, String)> open(WidgetTester tester, String source) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final id = await tester.runAsync(
      () => app.songs.createSong(source: source),
    );
    await tester.pumpWidget(app.build(home: SongScreen(songId: id!)));
    await tester.pumpAndSettle();
    return (app, id);
  }

  testWidgets('the sources panel lists the links and opens them', (
    tester,
  ) async {
    final (app, _) = await open(tester, source);
    final icon = find.byKey(const Key('open-song-links'));
    expect(find.descendant(of: icon, matching: find.text('3')), findsOneWidget);
    // The directive is not shown in the song.
    expect(find.textContaining('x_link'), findsNothing);

    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-links')), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    // The label, else the service, else the domain.
    expect(find.text('Live 2009'), findsOneWidget);
    expect(find.text('youtube.com'), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('example.com'), findsNWidgets(2));

    await tester.tap(find.text('Live 2009'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://www.youtube.com/watch?v=abc')]);

    openResult = false;
    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    expect(opened.last, Uri.parse('https://open.spotify.com/track/1'));
    expect(find.text('The link could not be opened.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a link is added to the ChordPro text', (tester) async {
    final (app, id) = await open(tester, '{title: X}\n{key: G}\n\n[G]One');
    await tester.tap(find.byKey(const Key('open-song-links')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No sources yet.'), findsOneWidget);

    await tester.tap(find.text('Add link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('song-link-url')),
      'not a link',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a web link'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('song-link-url')),
      'https://example.com/my song',
    );
    await tester.enterText(find.byKey(const Key('song-link-label')), 'Demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final song = await tester.runAsync(() => app.songs.getSong(id));
    expect(
      song!.chordproSource,
      '{title: X}\n{key: G}\n{x_link: https://example.com/my song | Demo}\n'
      '\n[G]One',
    );
    expect(find.text('Demo'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('open-song-links')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });
}
