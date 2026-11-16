import 'package:chordpro/chordpro.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/app.dart';
import 'package:realchord/ui/songs/chordpro_editing_controller.dart';
import 'package:realchord/ui/songs/song_editor_screen.dart';

import 'test_app.dart';

void main() {
  /// The text spans the editor renders, as (text, style).
  List<(String, TextStyle?)> renderedSpans(WidgetTester tester) {
    final span = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable
        .text!;
    final result = <(String, TextStyle?)>[];
    span.visitChildren((child) {
      if (child is TextSpan && child.text != null) {
        result.add((child.text!, child.style));
      }
      return true;
    });
    return result;
  }

  Future<(TestApp, ChordProEditingController)> pumpEditor(
    WidgetTester tester,
    String source, {
    Brightness brightness = Brightness.light,
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: Theme(
          data: RealChordApp.theme(brightness),
          child: SongEditorScreen(initialSource: source),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller =
        tester.widget<TextField>(find.byType(TextField)).controller!
            as ChordProEditingController;
    return (app, controller);
  }

  testWidgets('the editor styles chords, directives and comments', (
    tester,
  ) async {
    const source = '{title: Song}\n# note\n[Am]la [Xyz]li [G';
    final (app, _) = await pumpEditor(tester, source);
    final spans = {
      for (final (text, style) in renderedSpans(tester)) text: style,
    };
    final scheme = RealChordApp.theme(Brightness.light).colorScheme;

    expect(spans['[Am]']!.fontWeight, FontWeight.bold);
    expect(spans['[Am]']!.color, scheme.primary);
    expect(spans['{title: ']!.color, scheme.secondary);
    expect(spans['Song'], isNull);
    expect(spans['# note']!.fontStyle, FontStyle.italic);
    expect(spans['[Xyz]']!.decorationStyle, TextDecorationStyle.wavy);
    expect(spans['[G']!.color, scheme.error);
    // The spans together are exactly the text.
    expect(renderedSpans(tester).map((s) => s.$1).join(), source);
    await app.dispose(tester);
  });

  testWidgets('every token kind has a style in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      final scheme = RealChordApp.theme(brightness).colorScheme;
      final styled = SourceTokenKind.values.where(
        (k) => k != SourceTokenKind.text && k != SourceTokenKind.directiveValue,
      );
      for (final kind in styled) {
        expect(chordProTokenStyle(kind, scheme), isNotNull, reason: '$kind');
      }
    }
  });

  testWidgets('typing keeps text, cursor and selection', (tester) async {
    final (app, controller) = await pumpEditor(
      tester,
      '[C]la',
      brightness: Brightness.dark,
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '[C]la [G]li');
    await tester.pump();
    expect(controller.text, '[C]la [G]li');
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 9);
    await tester.pump();
    expect(controller.selection.textInside(controller.text), '[G]');
    final spans = renderedSpans(tester);
    expect(spans.map((s) => s.$1).join(), '[C]la [G]li');
    expect(
      spans.firstWhere((s) => s.$1 == '[G]').$2!.color,
      RealChordApp.theme(Brightness.dark).colorScheme.primary,
    );
    await app.dispose(tester);
  });

  testWidgets('the bracket pair next to the cursor is highlighted', (
    tester,
  ) async {
    final (app, controller) = await pumpEditor(tester, 'la [Am] li [G');
    final scheme = RealChordApp.theme(Brightness.light).colorScheme;
    List<(String, Color?)> highlighted() => [
      for (final (text, style) in renderedSpans(tester))
        if (style?.backgroundColor != null) (text, style!.backgroundColor),
    ];

    controller.selection = const TextSelection.collapsed(offset: 4);
    await tester.pump();
    expect(highlighted(), [
      ('[', scheme.tertiaryContainer),
      (']', scheme.tertiaryContainer),
    ]);
    // The rest of the chord keeps its chord style.
    final am = renderedSpans(tester).firstWhere((s) => s.$1 == 'Am');
    expect(am.$2!.fontWeight, FontWeight.bold);

    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    expect(highlighted(), isEmpty);

    // An unmatched bracket is shown as an error.
    controller.selection = const TextSelection.collapsed(offset: 11);
    await tester.pump();
    expect(highlighted(), [('[', scheme.errorContainer)]);

    // A selection does not highlight brackets.
    controller.selection = const TextSelection(baseOffset: 3, extentOffset: 7);
    await tester.pump();
    expect(highlighted(), isEmpty);
    expect(renderedSpans(tester).map((s) => s.$1).join(), 'la [Am] li [G');
    await app.dispose(tester);
  });

  testWidgets('the IME composing range stays underlined', (tester) async {
    final controller = ChordProEditingController(text: '[C]hello');
    controller.value = controller.value.copyWith(
      composing: const TextRange(start: 3, end: 6),
    );
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              withComposing: true,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    final children = span.children!.cast<TextSpan>();
    expect(children.map((s) => s.text), ['[C]', 'hel', 'lo']);
    expect(children[1].style!.decoration, TextDecoration.underline);
    expect(children[2].style, isNull);
    controller.dispose();
  });
}
