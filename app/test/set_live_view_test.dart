import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_lookup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/ui/sets/set_screen.dart';
import 'package:setding/ui/widgets/key_picker.dart';

import 'test_app.dart';

/// Bytes that stand in for a PDF; the set view does not render it.
final _pdf = Uint8List.fromList('%PDF-1.4\n%%EOF'.codeUnits);

const _chordPro = '{title: Song}\n[C]Line';
const _pdfOnly = '{title: Scanned}';

/// Creates a song with [pdfs] and a set containing it; returns the IDs.
Future<({String songId, String setId, List<String> pdfIds})> _setup(
  TestApp app, {
  String source = _chordPro,
  List<String> pdfs = const ['Lead sheet', 'Drums'],
  String? liveView,
  bool image = false,
  bool pause = false,
}) async {
  final songId = await app.songs.createSong(source: source);
  final pdfIds = [
    for (final name in pdfs)
      await app.songs.addAttachment(songId, name: name, bytes: _pdf, pages: 1),
  ];
  if (image) {
    await app.songs.addAttachment(
      songId,
      name: 'photo.png',
      bytes: Uint8List(8),
      extension: 'png',
    );
  }
  if (liveView != null) {
    await app.songs.saveOverlay(
      SongRepository.defaultOverlay(songId).copyWith(liveView: Value(liveView)),
    );
  }
  final setId = await app.sets.createSet(name: 'Gig');
  await app.sets.addSongs(setId, [songId]);
  if (pause) await app.sets.addMarker(setId, SetItemType.pause, 'Break');
  return (songId: songId, setId: setId, pdfIds: pdfIds);
}

Finder _button(String songId) => find.byKey(ValueKey('live-view-$songId'));

/// Any live view button.
final _anyButton = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('live-view-') &&
      !(w.key! as ValueKey<String>).value.startsWith('live-view-option-'),
);

/// The name of the current choice, from the button's tooltip.
String _shown(WidgetTester tester, String songId) => tester
    .widget<IconButton>(_button(songId))
    .tooltip!
    .split('\n')
    .first
    .replaceFirst('Show in live mode: ', '');

void main() {
  testWidgets('set view shows and changes the live view of a song', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = (await tester.runAsync(() => _setup(app, pause: true)))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: ids.setId)));
    await tester.pumpAndSettle();

    // ChordPro by default; the pause gets no button.
    expect(_anyButton, findsOneWidget);
    expect(_shown(tester, ids.songId), 'ChordPro text');
    expect(find.byIcon(Icons.text_snippet_outlined), findsOneWidget);
    expect(
      find.byTooltip(
        'Show in live mode: ChordPro text\n'
        'Just for you – the song stays unchanged for everyone else.',
      ),
      findsOneWidget,
    );
    // The key of a set item applies to the whole band, not just to me.
    expect(
      find.byTooltip('Key in this set – for the whole band'),
      findsOneWidget,
    );

    await tester.tap(_button(ids.songId));
    await tester.pumpAndSettle();
    // The menu names what the choice is for.
    expect(find.text('Show in live mode'), findsOneWidget);
    expect(find.text('ChordPro text'), findsOneWidget);
    await tester.tap(find.text('Drums'));
    await tester.pumpAndSettle();

    final overlay = await tester.runAsync(
      () => app.songs.getOverlay(ids.songId),
    );
    expect(overlay!.liveView, ids.pdfIds[1]);
    expect(_shown(tester, ids.songId), 'Drums');
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);

    // And back to ChordPro.
    await tester.tap(_button(ids.songId));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChordPro text'));
    await tester.pumpAndSettle();
    final reset = await tester.runAsync(() => app.songs.getOverlay(ids.songId));
    expect(reset!.liveView, isNull);
    expect(_shown(tester, ids.songId), 'ChordPro text');
    await app.dispose(tester);
  });

  testWidgets('song without ChordPro text shows its first PDF', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = (await tester.runAsync(() => _setup(app, source: _pdfOnly)))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: ids.setId)));
    await tester.pumpAndSettle();

    // First by name, as the song screen lists them.
    expect(_shown(tester, ids.songId), 'Drums');
    // ChordPro is no option without ChordPro text.
    await tester.tap(_button(ids.songId));
    await tester.pumpAndSettle();
    expect(find.text('ChordPro text'), findsNothing);
    expect(find.text('Lead sheet'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a missing attachment falls back to ChordPro', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = (await tester.runAsync(() => _setup(app, liveView: 'gone')))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: ids.setId)));
    await tester.pumpAndSettle();

    expect(_shown(tester, ids.songId), 'ChordPro text');
    await app.dispose(tester);
  });

  testWidgets('no button without a choice', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setIds = await tester.runAsync(
      () async => [
        // No attachment, only an image, a single PDF without ChordPro text.
        (await _setup(app, pdfs: const [])).setId,
        (await _setup(app, pdfs: const [], image: true)).setId,
        (await _setup(app, source: _pdfOnly, pdfs: const ['Only'])).setId,
      ],
    );
    for (final setId in setIds!) {
      await tester.pumpWidget(app.build(home: SetScreen(setId: setId)));
      await tester.pumpAndSettle();
      expect(_anyButton, findsNothing);
    }
    await app.dispose(tester);
  });

  testWidgets('rarely used actions are in the menu of each row', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = (await tester.runAsync(() => _setup(app, pause: true)))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: ids.setId)));
    await tester.pumpAndSettle();
    // The key stays in the row; no remove buttons in the rows.
    expect(find.byType(KeyPicker), findsOneWidget);
    expect(find.byTooltip('Remove from set'), findsNothing);
    final menus = find.byWidgetPredicate(
      (w) => '${w.key}'.contains('set-item-menu-'),
    );
    expect(menus, findsNWidgets(2)); // song and pause

    await tester.tap(menus.first);
    await tester.pumpAndSettle();
    expect(find.text('Song sequence for this set'), findsOneWidget);
    expect(find.text('Remove from set'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // The pause: edit and remove.
    await tester.tap(menus.last);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Remove from set'));
    await tester.pumpAndSettle();
    final items = await tester.runAsync(() => app.sets.getItems(ids.setId));
    expect(items!.single.song?.id, ids.songId);
    await app.dispose(tester);
  });

  testWidgets('a song without ChordPro text has no key in the set', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    final ids = (await tester.runAsync(() => _setup(app, source: _pdfOnly)))!;
    await tester.pumpWidget(app.build(home: SetScreen(setId: ids.setId)));
    await tester.pumpAndSettle();
    expect(find.byType(KeyPicker), findsNothing);
    // Its menu has no sequence either: there are no parts to arrange.
    await tester.tap(
      find.byWidgetPredicate((w) => '${w.key}'.contains('set-item-menu-')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Song sequence for this set'), findsNothing);
    expect(find.text('Remove from set'), findsOneWidget);
    await app.dispose(tester);
  });

  group('livePdfFor', () {
    AttachmentEntry entry(String id, String fileName) => AttachmentEntry(
      id: id,
      songId: 's',
      name: id,
      fileName: fileName,
      sizeBytes: 1,
      revision: 0,
      updatedAt: DateTime(2026),
      deleted: false,
    );
    final attachments = [
      entry('img', 'img.png'),
      entry('a', 'a.pdf'),
      entry('b', 'b.pdf'),
    ];

    test('follows the choice if it is a PDF of the song', () {
      expect(livePdfFor(attachments, 'b', hasChordPro: true)?.id, 'b');
      expect(livePdfFor(attachments, null, hasChordPro: true), isNull);
    });

    test('falls back to ChordPro, or the first PDF without ChordPro', () {
      expect(livePdfFor(attachments, 'gone', hasChordPro: true), isNull);
      expect(livePdfFor(attachments, 'img', hasChordPro: true), isNull);
      expect(livePdfFor(attachments, 'gone', hasChordPro: false)?.id, 'a');
      expect(livePdfFor(attachments, null, hasChordPro: false)?.id, 'a');
      expect(livePdfFor(const [], null, hasChordPro: false), isNull);
    });
  });
}
