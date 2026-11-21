import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/theme.dart';
import 'package:setding/ui/widgets/dialogs.dart';
import 'package:setding/ui/widgets/section_header.dart';

/// The shared widgets of the UI design rules (docs/development/ui-design.md).
void main() {
  Widget app(Widget child, {Brightness brightness = Brightness.light}) =>
      ProviderScope(
        child: MaterialApp(
          theme: appTheme(brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: child),
        ),
      );

  Color? buttonBackground(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-action')),
    );
    return button.style?.backgroundColor?.resolve({});
  }

  Future<void> openConfirm(
    WidgetTester tester, {
    required bool destructive,
  }) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => confirm(
              context,
              title: 'Title',
              message: 'Message',
              destructive: destructive,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a destructive confirmation has an error-coloured button', (
    tester,
  ) async {
    await openConfirm(tester, destructive: true);
    final context = tester.element(find.byType(AlertDialog));
    expect(buttonBackground(tester), Theme.of(context).colorScheme.error);
  });

  testWidgets('another confirmation keeps the ordinary button', (tester) async {
    await openConfirm(tester, destructive: false);
    expect(buttonBackground(tester), isNull);
  });

  testWidgets('a section header is a heading in the primary colour', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(const SectionHeader('Members', icon: Icons.people)),
    );
    final text = tester.widget<Text>(find.text('Members'));
    final context = tester.element(find.text('Members'));
    expect(text.style?.color, Theme.of(context).colorScheme.primary);
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(
      tester.getSemantics(find.text('Members')),
      matchesSemantics(label: 'Members', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('a message replaces the one shown, unless queued', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    showMessage(context, 'first');
    await tester.pumpAndSettle();
    showMessage(context, 'second');
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    showMessageOn(ScaffoldMessenger.of(context), 'queued', queue: true);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('queued'), findsNothing);
  });

  testWidgets('a message with an action still goes away by itself', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    showMessageWithAction(
      context,
      'exported',
      actionLabel: 'Open',
      onAction: () {},
    );
    await tester.pumpAndSettle();
    expect(find.text('exported'), findsOneWidget);
    await tester.pump(messageActionDuration);
    await tester.pumpAndSettle();
    expect(find.text('exported'), findsNothing);
  });

  test('status colours exist in light and dark', () {
    expect(
      appTheme(Brightness.light).extension<StatusColors>(),
      StatusColors.light,
    );
    expect(
      appTheme(Brightness.dark).extension<StatusColors>(),
      StatusColors.dark,
    );
  });
}
