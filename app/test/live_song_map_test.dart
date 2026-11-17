import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'test_app.dart';

/// Song map for drummers in live mode (ADR-0026, #336).
void main() {
  const first = '''
{title: One}
{tempo: 96}
{time: 6/8}
{x_sequence: I, V, C x2, V, C}
{start_of_verse: Intro}
{comment-drums: Toms, four bars}
{end_of_verse}
{start_of_verse}
[G]Amazing grace
{end_of_verse}
{start_of_chorus}
{comment-drums: Crash on 1}
[C]Through many dangers
{end_of_chorus}
{start_of_verse}
[G]Twas grace that taught
{end_of_verse}
''';
  const second = '{title: Two}\n{tempo: 100}\n{time: 4/4}\n[D]Two';

  Future<TestApp> open(WidgetTester tester, Map<String, Object> prefs) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    final items = (await tester.runAsync(() async {
      final items = <LiveItem>[];
      for (final source in [first, second]) {
        final id = await app.songs.createSong(source: source);
        items.add(LiveItem.song((await app.songs.getSong(id))!));
      }
      return items;
    }))!;
    await tester.pumpWidget(app.build(home: LiveScreen(items: items)));
    await tester.pump();
    await tester.pump();
    return app;
  }

  testWidgets('drums: the parts with cues and drum notes, no chords', (
    tester,
  ) async {
    final app = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
    });
    expect(find.byKey(const Key('song-map')), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Toms, four bars'), findsOneWidget);
    expect(find.text('Chorus ×2'), findsOneWidget);
    expect(find.text('„Amazing grace“'), findsOneWidget);
    expect(find.text('„Twas grace that taught“'), findsOneWidget);
    expect(find.text('Crash on 1'), findsNWidgets(2));
    // No chord sheet.
    expect(find.text('G'), findsNothing);
    // The next song with tempo and time signature.
    expect(find.textContaining('Two · 100 BPM · 4/4'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('not for other instruments, and switchable for drums', (
    tester,
  ) async {
    final guitar = await open(tester, {'instrument': 'guitar'});
    expect(find.byKey(const Key('song-map')), findsNothing);
    expect(find.textContaining('100 BPM'), findsNothing);
    await guitar.dispose(tester);

    final drums = await open(tester, {
      'instrument': 'drums',
      'clickStart': 'manual',
      'songMap': false,
    });
    expect(find.byKey(const Key('song-map')), findsNothing);
    await drums.dispose(tester);
  });
}
