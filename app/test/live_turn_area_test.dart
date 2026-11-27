import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/live/live_turn_area.dart';

// The swipes and taps of live mode, extracted from live_screen.dart (#1202).
void main() {
  testWidgets('swipes turn, short drags do not, taps are told', (tester) async {
    final calls = <String>[];
    double? width;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LiveTurnArea(
          onTap: (p) => calls.add('tap ${p.dx.round()}'),
          onNext: () => calls.add('next'),
          onPrevious: () => calls.add('previous'),
          onWidth: (w) => width = w,
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(width, 800);

    // A fifth of the width, slowly: turns.
    await tester.timedDrag(
      find.byType(LiveTurnArea),
      const Offset(-200, 0),
      const Duration(seconds: 2),
    );
    await tester.timedDrag(
      find.byType(LiveTurnArea),
      const Offset(200, 0),
      const Duration(seconds: 2),
    );
    // Short and slow: nothing.
    await tester.timedDrag(
      find.byType(LiveTurnArea),
      const Offset(-100, 0),
      const Duration(seconds: 2),
    );
    // Short but fast: turns.
    await tester.fling(find.byType(LiveTurnArea), const Offset(-60, 0), 1000);
    await tester.tapAt(const Offset(100, 300));
    expect(calls, ['next', 'previous', 'next', 'tap 100']);
  });
}
