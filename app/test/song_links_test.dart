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

  testWidgets('a link is edited and removed in the ChordPro text', (
    tester,
  ) async {
    final (app, id) = await open(tester, source);
    await tester.tap(find.byKey(const Key('open-song-links')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-song-link-1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit link'), findsOneWidget);
    expect(find.text('https://example.com/my%20demo.mp3'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('song-link-url')),
      'https://example.com/demo.mp3',
    );
    await tester.enterText(find.byKey(const Key('song-link-label')), 'Demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    var song = await tester.runAsync(() => app.songs.getSong(id));
    expect(
      song!.chordproSource,
      source.replaceFirst(
        'https://example.com/my demo.mp3',
        'https://example.com/demo.mp3 | Demo',
      ),
    );
    expect(find.text('Demo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-song-link-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-song-link')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this source from the song?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    song = await tester.runAsync(() => app.songs.getSong(id));
    expect(song!.chordproSource, isNot(contains('youtube')));
    expect(find.text('Live 2009'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('open-song-links')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('the attachments button comes before the sources button', (
    tester,
  ) async {
    final (app, _) = await open(tester, source);
    expect(
      tester.getCenter(find.byKey(const Key('open-attachments'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('open-song-links'))).dx),
    );
    await app.dispose(tester);
  });

  testWidgets('the CCLI number links to SongSelect in the sources panel', (
    tester,
  ) async {
    final (app, _) = await open(
      tester,
      '{title: X}\n{x_ccli: 7114209}\n'
      '{x_link: https://www.youtube.com/watch?v=abc}\n\n[G]One',
    );
    final icon = find.byKey(const Key('open-song-links'));
    // The SongSelect page counts as a source.
    expect(find.descendant(of: icon, matching: find.text('2')), findsOneWidget);

    await tester.tap(icon);
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('song-select-link'));
    expect(
      find.descendant(of: entry, matching: find.text('CCLI SongSelect')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: entry, matching: find.text('CCLI number 7114209')),
      findsOneWidget,
    );
    // It comes first and is not edited in the panel.
    expect(
      tester.getCenter(entry).dy,
      lessThan(tester.getCenter(find.text('YouTube')).dy),
    );
    expect(
      find.descendant(of: entry, matching: find.byIcon(Icons.edit_outlined)),
      findsNothing,
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://songselect.ccli.com/songs/7114209')]);
    await app.dispose(tester);
  });

  testWidgets('a song with only a CCLI number shows its SongSelect page', (
    tester,
  ) async {
    final (app, _) = await open(
      tester,
      '{title: X}\n{x_ccli: 7114209}\n\n[G]One',
    );
    final icon = find.byKey(const Key('open-song-links'));
    expect(find.descendant(of: icon, matching: find.text('1')), findsOneWidget);
    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(find.textContaining('No sources yet.'), findsNothing);
    expect(find.byKey(const Key('song-select-link')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a CCLI value that is not a number shows no SongSelect link', (
    tester,
  ) async {
    final (app, _) = await open(tester, '{title: X}\n{x_ccli: n/a}\n\n[G]One');
    await tester.tap(find.byKey(const Key('open-song-links')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-select-link')), findsNothing);
    expect(find.textContaining('No sources yet.'), findsOneWidget);
    await app.dispose(tester);
  });
}
