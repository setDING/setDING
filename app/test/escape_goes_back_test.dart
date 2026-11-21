import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/widgets/escape_goes_back.dart';

/// Esc acts like the back button on every screen (#726).
void main() {
  Future<NavigatorState> pumpApp(WidgetTester tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      EscapeGoesBack(
        child: MaterialApp(
          navigatorKey: key,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
    return key.currentState!;
  }

  Future<void> push(
    NavigatorState nav,
    WidgetTester tester,
    Widget page,
  ) async {
    nav.push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  Future<void> escape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  testWidgets('Esc pops the current page', (tester) async {
    final nav = await pumpApp(tester);
    await push(nav, tester, const Scaffold(body: Text('song')));
    await escape(tester);
    expect(find.text('song'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Esc on the start screen does nothing', (tester) async {
    await pumpApp(tester);
    await escape(tester);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Esc closes only the open dialog, not the page', (tester) async {
    final nav = await pumpApp(tester);
    await push(nav, tester, const Scaffold(body: Text('song')));
    showDialog<void>(
      context: nav.context,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await tester.pumpAndSettle();
    await escape(tester);
    expect(find.text('dialog'), findsNothing);
    expect(find.text('song'), findsOneWidget);
  });

  testWidgets('Esc does not close a dialog that is not dismissible', (
    tester,
  ) async {
    final nav = await pumpApp(tester);
    showDialog<void>(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await tester.pumpAndSettle();
    await escape(tester);
    expect(find.text('dialog'), findsOneWidget);
  });

  testWidgets('Esc respects PopScope', (tester) async {
    final nav = await pumpApp(tester);
    var attempts = 0;
    await push(
      nav,
      tester,
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) => attempts++,
        child: const Scaffold(body: Text('editor')),
      ),
    );
    await escape(tester);
    expect(find.text('editor'), findsOneWidget);
    expect(attempts, 1);
  });

  testWidgets('a widget with its own Esc keeps it', (tester) async {
    final nav = await pumpApp(tester);
    var closed = 0;
    await push(
      nav,
      tester,
      Scaffold(
        body: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event.logicalKey != LogicalKeyboardKey.escape) {
              return KeyEventResult.ignored;
            }
            if (event is KeyDownEvent) closed++;
            return KeyEventResult.handled;
          },
          child: const Text('search'),
        ),
      ),
    );
    await escape(tester);
    expect(closed, 1);
    expect(find.text('search'), findsOneWidget);
  });
}
