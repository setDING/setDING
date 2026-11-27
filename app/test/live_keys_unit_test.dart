import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show KeyEventResult;
import 'package:setding/ui/live/live_keys.dart';

// The keys of live mode, extracted from live_screen.dart (#1202).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  var active = true;
  var spaceBeat = false;
  var beat = false;

  LiveKeys make() {
    calls = [];
    active = true;
    spaceBeat = false;
    beat = false;
    return LiveKeys(
      active: () => active,
      spaceStartsBeat: () => spaceBeat,
      onPageTurnKey: () => calls.add('used'),
      current: () => 3,
      canBeat: (index) => beat,
      toggleBeat: (index) => calls.add('beat $index'),
      next: () => calls.add('next'),
      previous: () => calls.add('previous'),
      escape: () => calls.add('escape'),
    );
  }

  KeyEvent down(LogicalKeyboardKey key) => KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
  KeyEvent up(LogicalKeyboardKey key) => KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
  KeyEvent repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
    character: null,
  );

  test('turns once per press, back and forward', () {
    final keys = make();
    addTearDown(keys.dispose);
    expect(
      keys.handle(down(LogicalKeyboardKey.arrowRight)),
      KeyEventResult.handled,
    );
    keys.handle(repeat(LogicalKeyboardKey.arrowRight));
    keys.handle(up(LogicalKeyboardKey.arrowRight));
    keys.handle(down(LogicalKeyboardKey.arrowLeft));
    expect(calls, ['used', 'next', 'used', 'previous']);
    expect(keys.handle(down(LogicalKeyboardKey.keyQ)), KeyEventResult.ignored);
  });

  test('leaves the keys to routes on top of live mode', () {
    final keys = make();
    addTearDown(keys.dispose);
    active = false;
    expect(
      keys.handle(down(LogicalKeyboardKey.arrowRight)),
      KeyEventResult.ignored,
    );
    expect(calls, isEmpty);
  });

  testWidgets('a held forward key starts the beat, a short press turns', (
    tester,
  ) async {
    final keys = make();
    beat = true;
    keys.handle(down(LogicalKeyboardKey.arrowRight));
    await tester.pump(beatLongPress);
    keys.handle(up(LogicalKeyboardKey.arrowRight));
    expect(calls, ['used', 'beat 3']);

    calls.clear();
    keys.handle(down(LogicalKeyboardKey.arrowRight));
    await tester.pump(beatLongPress ~/ 2);
    keys.handle(up(LogicalKeyboardKey.arrowRight));
    expect(calls, ['used', 'next']);

    // Disposed: a pending long press does nothing.
    calls.clear();
    keys
      ..handle(down(LogicalKeyboardKey.arrowRight))
      ..dispose();
    await tester.pump(beatLongPress);
    expect(calls, ['used']);
  });

  test('Enter and Space (when chosen) toggle the beat, Escape escapes', () {
    final keys = make();
    addTearDown(keys.dispose);
    keys.handle(down(LogicalKeyboardKey.enter));
    expect(calls, isEmpty, reason: 'no beat');
    beat = true;
    keys.handle(down(LogicalKeyboardKey.enter));
    spaceBeat = true;
    keys.handle(down(LogicalKeyboardKey.space));
    keys.handle(down(LogicalKeyboardKey.escape));
    expect(calls, ['beat 3', 'beat 3', 'escape']);
  });
}
