import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:realchord/ui/widgets/breakpoint_builder.dart';

/// Layouts that depend only on the width are not built again while only
/// the height changes, e.g. while the keyboard opens (#297).
void main() {
  final built = <bool>[];
  BreakpointBuilder<bool> builder(String label) => BreakpointBuilder(
    select: (constraints) => constraints.maxWidth >= 500,
    builder: (context, wide) {
      built.add(wide);
      return Text('$label ${wide ? 'wide' : 'narrow'}');
    },
  );
  Widget sized(Widget child, double width, double height) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(width: width, height: height, child: child),
    ),
  );

  setUp(built.clear);

  testWidgets('builds again only when the value changes', (tester) async {
    final widget = builder('a');
    await tester.pumpWidget(sized(widget, 400, 600));
    expect(built, [false]);
    await tester.pumpWidget(sized(widget, 400, 300));
    await tester.pumpWidget(sized(widget, 450, 200));
    expect(built, [false]);
    expect(find.text('a narrow'), findsOneWidget);
    await tester.pumpWidget(sized(widget, 600, 200));
    expect(built, [false, true]);
    expect(find.text('a wide'), findsOneWidget);
    await tester.pumpWidget(sized(widget, 300, 200));
    expect(built, [false, true, false]);
    expect(find.text('a narrow'), findsOneWidget);
  });

  testWidgets('a new widget builds again', (tester) async {
    await tester.pumpWidget(sized(builder('a'), 400, 600));
    await tester.pumpWidget(sized(builder('b'), 400, 600));
    expect(built, [false, false]);
    expect(find.text('b narrow'), findsOneWidget);
  });
}
