import 'package:flutter_test/flutter_test.dart';
import 'package:setding/audio/engine_clock.dart';

Duration ms(int v) => Duration(milliseconds: v);

/// The time of the click engine between audio buffers (ADR-0026, #545).
void main() {
  late Duration engine;
  late Duration wall;
  late EngineClock clock;

  setUp(() {
    engine = Duration.zero;
    wall = Duration.zero;
    clock = EngineClock(engine: () => engine, wall: () => wall);
  });

  test('fills the gap between engine steps with the wall clock', () {
    engine = ms(1000);
    wall = ms(5000);
    expect(clock.now(), ms(1000));
    wall = ms(5030);
    expect(clock.now(), ms(1030));
    engine = ms(1046);
    wall = ms(5046);
    expect(clock.now(), ms(1046));
  });

  test('does not run ahead of an engine that stands', () {
    // The engine is not started yet while the app runs for minutes (#545).
    wall = ms(76368);
    expect(clock.now(), Duration.zero);
    wall = ms(80000);
    expect(clock.now(), clock.maxExtrapolation);
    engine = ms(10);
    wall = ms(80010);
    expect(clock.now(), clock.maxExtrapolation);
  });

  test('stands while the engine device idles, then follows it again', () {
    engine = ms(2000);
    wall = ms(2000);
    clock.now();
    // The device stops; the playhead stands for a minute.
    wall = ms(62000);
    expect(clock.now(), ms(2000) + clock.maxExtrapolation);
    engine = ms(2200);
    wall = ms(62300);
    expect(clock.now(), ms(2200));
  });

  test('never runs backwards', () {
    engine = ms(1000);
    clock.now();
    wall = ms(80);
    final before = clock.now();
    // The next engine step lands before the extrapolated time.
    engine = ms(1046);
    wall = ms(90);
    expect(clock.now(), greaterThanOrEqualTo(before));
    engine = ms(1060);
    expect(clock.now(), before);
  });

  test('reset takes the engine time as it is now', () {
    // A wrong (too late) time from before is dropped by the reset.
    wall = ms(76368);
    clock.now();
    engine = ms(3390);
    clock.reset();
    expect(clock.now(), ms(3390));
    wall = ms(76398);
    expect(clock.now(), ms(3420));
  });
}
