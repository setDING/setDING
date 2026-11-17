import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/ui/live/live_preparation.dart';

/// The steps in which live mode prepares the pages around the current one
/// (issue #296).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LivePreparation preparation;
  setUp(
    () => preparation = LivePreparation(length: 5, current: 0, linesPerStep: 4),
  );
  tearDown(() => preparation.dispose());

  /// Pages take part while they are built (they listen).
  void mount(int index) => preparation[index].addListener(() {});

  test('the page on stage is complete, the next one is prepared in steps', () {
    mount(0);
    mount(1);
    expect(preparation[0].complete, isTrue);
    expect(preparation[1].started, isFalse);

    // First the header and the first lines.
    expect(preparation.step(), isTrue);
    expect(preparation[1].started, isTrue);
    expect(preparation[1].body.value, 4);
    // The page found that its song is not fitted yet: the fit runs as a
    // step of its own (outside of frames).
    var fitted = false;
    preparation[1].pending = () => fitted = true;
    expect(preparation.step(), isTrue);
    expect(fitted, isTrue);
    expect(preparation[1].pending, isNull);
    expect(preparation[1].body.value, 4);
    // Then four more lines per step, until the body (10 lines) is built.
    preparation[1].body.total = 10;
    expect(preparation.step(), isTrue);
    expect(preparation[1].body.value, 8);
    expect(preparation.step(), isTrue);
    expect(preparation[1].body.value, 12);
    expect(preparation[1].complete, isFalse);
    expect(preparation.step(), isFalse);
    expect(preparation[1].complete, isTrue);
    expect(preparation.busy, isFalse);
  });

  test('pages without a song body are complete after their start', () {
    mount(1);
    expect(preparation.step(), isTrue);
    expect(preparation[1].started, isTrue);
    // Nothing reported a body (e.g. a PDF): nothing to build in steps.
    expect(preparation.step(), isFalse);
    expect(preparation[1].complete, isTrue);
  });

  test('pages that are not built are not prepared', () {
    expect(preparation.busy, isFalse);
    expect(preparation.step(), isFalse);
    expect(preparation[1].started, isFalse);
  });

  test('the next page comes before the previous one', () {
    preparation.focus(2);
    for (final i in [1, 2, 3]) {
      mount(i);
    }
    expect(preparation.step(), isTrue);
    expect(preparation[3].started, isTrue);
    expect(preparation[1].started, isFalse);
  });

  test('pages that are no neighbours any more are taken down in steps', () {
    for (final i in [0, 1, 2]) {
      mount(i);
    }
    preparation.complete(1);
    preparation[1].body.total = 10;
    preparation.focus(3);
    expect(preparation.wanted(1), isFalse);
    expect(preparation.wanted(2), isTrue);

    // The neighbour first.
    expect(preparation.step(), isTrue);
    expect(preparation[2].started, isTrue);
    expect(preparation[1].body.value, greaterThan(10));

    // Then the pages behind are taken down, the song from its end.
    final lines = <int>[];
    while (preparation.step()) {
      if (preparation[1].started) lines.add(preparation[1].body.value);
    }
    // (The first step completes page 2 and releases page 0, which had no
    // body.)
    expect(lines.where((v) => v <= 10), [6, 2]);
    expect(preparation[2].complete, isTrue);
    for (final i in [0, 1]) {
      expect(preparation[i].started, isFalse);
      expect(preparation[i].complete, isFalse);
      expect(preparation[i].body.total, isNull);
    }
    expect(preparation.busy, isFalse);
  });

  test('complete builds a page at once, e.g. the target of a turn', () {
    mount(1);
    expect(preparation.step(), isTrue);
    preparation[1].pending = () => fail('fitted when it is built');
    preparation.complete(1);
    expect(preparation[1].complete, isTrue);
    expect(preparation[1].pending, isNull);
    expect(preparation[1].body.value, greaterThan(1000));
    expect(preparation.step(), isFalse);
  });
}
