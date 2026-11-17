import 'package:chordpro/chordpro.dart' hide Key;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../audio/metronome.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';
import '../render/render_cache.dart';
import '../render/song_header.dart' show StageChip;
import '../render/song_style.dart' show StageColors;
import 'live_screen.dart' show LiveItem;

/// The beat of live mode (ADR-0026): which item's beat runs, the tempo on
/// stage (only until live mode is left) and the start and stop rules.
/// Every member of the set navigates on their own (ADR-0007); this is only
/// the beat of this device.
class LiveBeat extends ChangeNotifier {
  LiveBeat({
    required this.metronome,
    required List<LiveItem> items,
    required AppSettings Function() settings,
    Duration Function()? clock,
  }) : _items = items, // ignore: prefer_initializing_formals
       _settings = settings, // ignore: prefer_initializing_formals
       _clock = clock ?? _stopwatch() {
    metronome.running.addListener(_onRunning);
  }

  static Duration Function() _stopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  final Metronome metronome;
  final List<LiveItem> _items;
  final AppSettings Function() _settings;
  final Duration Function() _clock;

  /// Tempo changed on stage per item; forgotten when live mode is left.
  final _stageTempo = <int, int>{};
  final _tapTempo = TapTempo();
  int? _active;
  bool _largeBeat = false;

  /// Whether the beat is shown large beside the song map (wide screens,
  /// ADR-0026); the dots of the header are hidden then.
  bool get largeBeat => _largeBeat;
  set largeBeat(bool value) {
    if (value == _largeBeat) return;
    _largeBeat = value;
    notifyListeners();
  }

  /// The item whose beat runs, or null.
  int? get activeIndex => _active;

  AppSettings get settings => _settings();

  void _onRunning() {
    // The count-in only stops by itself.
    if (!metronome.running.value && _active != null) {
      _active = null;
      notifyListeners();
    }
  }

  Song? _song(int index) {
    final entry = _items[index].song;
    return entry == null ? null : parseChordProCached(entry.chordproSource);
  }

  /// The tempo of the song or of the band's arrangement (ADR-0025).
  int? baseTempo(int index) {
    final arrangement = _items[index].arrangement?.tempo;
    if (arrangement != null && arrangement > 0) return arrangement;
    return _song(index)?.tempo;
  }

  /// The tempo as played tonight.
  int? tempoOf(int index) => _stageTempo[index] ?? baseTempo(index);

  bool tempoChanged(int index) => _stageTempo.containsKey(index);

  Meter meterOf(int index) => _song(index)?.meter ?? Meter.common;

  /// Whether the item can have a beat: a song with a tempo, and a beat
  /// display or click switched on.
  bool canBeat(int index) =>
      index >= 0 &&
      index < _items.length &&
      (tempoOf(index) ?? 0) > 0 &&
      settings.beatEnabled;

  bool isRunning(int index) => _active == index;

  /// Starts the beat of [index] with the count-in of the settings.
  Future<void> start(int index) async {
    if (!canBeat(index)) return;
    final s = settings;
    _active = index;
    notifyListeners();
    await metronome.start(
      meter: meterOf(index),
      bpm: tempoOf(index)!,
      countInBars: s.countInBars,
      countInOnly: s.clickDuration == ClickDuration.countIn,
      config: ClickConfig.of(s),
    );
  }

  Future<void> stop() async {
    if (_active == null && !metronome.running.value) return;
    _active = null;
    notifyListeners();
    await metronome.stop();
  }

  /// Start or stop: a tap on the tempo, a long press of the forward pedal
  /// or Enter.
  Future<void> toggle(int index) => isRunning(index) ? stop() : start(index);

  /// Another item of the set is shown: its beat stops; with the automatic
  /// start the new one counts in.
  Future<void> onItemShown(int index) async {
    if (_active != null && _active != index) await stop();
    if (settings.beatStart == ClickStart.automatic &&
        _active != index &&
        canBeat(index)) {
      await start(index);
    }
  }

  /// Sets the tempo for tonight; a running beat changes at the next bar.
  Future<void> setTempo(int index, int bpm) async {
    final clamped = bpm.clamp(Metronome.minBpm, Metronome.maxBpm);
    if (clamped == baseTempo(index)) {
      _stageTempo.remove(index);
    } else {
      _stageTempo[index] = clamped;
    }
    notifyListeners();
    if (isRunning(index)) await metronome.setTempo(clamped);
  }

  Future<void> nudge(int index, int delta) async {
    final tempo = tempoOf(index);
    if (tempo != null) await setTempo(index, tempo + delta);
  }

  /// Tap tempo: the mean of the last intervals; a pause of two seconds
  /// starts again.
  Future<void> tap(int index) async {
    final bpm = _tapTempo.add(_clock());
    if (bpm != null) await setTempo(index, bpm);
  }

  Future<void> resetTempo(int index) async {
    final base = baseTempo(index);
    if (base != null) await setTempo(index, base);
  }

  @override
  void dispose() {
    metronome.running.removeListener(_onRunning);
    metronome.stop();
    super.dispose();
  }
}

/// Tempo from taps: the mean interval of the last five taps; a pause of
/// two seconds starts again.
class TapTempo {
  final _taps = <Duration>[];

  /// Adds a tap at [now]; the tempo once there are two taps.
  int? add(Duration now) {
    if (_taps.isNotEmpty && now - _taps.last > const Duration(seconds: 2)) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length > 5) _taps.removeAt(0);
    if (_taps.length < 2) return null;
    final interval =
        (_taps.last - _taps.first).inMicroseconds / (_taps.length - 1);
    return (60000000 / interval).round();
  }
}

/// Makes the [LiveBeat] of live mode available to its widgets.
class LiveBeatScope extends InheritedNotifier<LiveBeat> {
  const LiveBeatScope({super.key, required LiveBeat beat, required super.child})
    : super(notifier: beat);

  static LiveBeat? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveBeatScope>()?.notifier;
}

/// The beat as seen now: the bar, the beat and whether it is lit.
typedef _Shown = ({int bar, int beat, bool lit});

/// Redraws while the beat of [index] (any item if null) runs, only when
/// what is shown changes; the beat comes from the metronome's clock, so a
/// slow frame never shifts it.
abstract class _BeatState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  LiveBeat? _beat;
  BeatPosition? position;
  _Shown? _shown;

  /// The item to follow; null for any.
  int? get index;

  /// How long a beat stays lit, as a part of the beat.
  double get litFor => 0.25;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _beat = LiveBeatScope.of(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final beat = _beat;
    final follow =
        beat != null &&
        beat.activeIndex != null &&
        (index == null || beat.activeIndex == index);
    if (follow && !_ticker.isActive) {
      _ticker.start();
    } else if (!follow && _ticker.isActive) {
      _ticker.stop();
      position = null;
      _shown = null;
    }
  }

  void _onTick(Duration _) {
    final p = _beat?.metronome.position();
    final shown = p == null
        ? null
        : (bar: p.bar, beat: p.beat, lit: p.phase < litFor);
    if (shown != _shown) {
      setState(() {
        position = p;
        _shown = shown;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// The tempo chip of the live header: the tempo as played tonight (marked
/// when changed on stage); a tap starts or stops the beat.
class StageTempoChip extends StatelessWidget {
  const StageTempoChip({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final beat = LiveBeatScope.of(context);
    final tempo = beat?.tempoOf(index);
    if (beat == null || tempo == null) return const SizedBox.shrink();
    final changed = beat.tempoChanged(index);
    final running = beat.isRunning(index);
    final chip = StageChip(
      changed ? '${l10n.bpm(tempo)} *' : l10n.bpm(tempo),
      icon: !beat.canBeat(index)
          ? null
          : running
          ? Icons.stop
          : Icons.play_arrow,
    );
    if (!beat.canBeat(index)) return chip;
    return Semantics(
      button: true,
      label: running ? l10n.beatStop : l10n.beatStart,
      child: GestureDetector(
        key: const Key('stage-tempo-button'),
        behavior: HitTestBehavior.opaque,
        onTap: () => beat.toggle(index),
        child: chip,
      ),
    );
  }
}

/// One dot per beat beside the tempo, grouped like the meter; the current
/// beat lights up, the 1 in the chord colour of the stage.
class BeatDots extends StatefulWidget {
  const BeatDots({
    super.key,
    required this.index,
    this.size = 14,
    this.panel = false,
  });

  final int index;

  /// Diameter of a dot; accented dots are larger.
  final double size;

  /// Shown in the beat panel of the wide song map; otherwise in the header,
  /// where the dots are hidden while the panel shows them.
  final bool panel;

  @override
  State<BeatDots> createState() => _BeatDotsState();
}

class _BeatDotsState extends _BeatState<BeatDots> {
  @override
  int get index => widget.index;

  @override
  Widget build(BuildContext context) {
    final beat = LiveBeatScope.of(context);
    if (beat == null ||
        !beat.settings.showBeat ||
        !beat.canBeat(widget.index) ||
        (beat.largeBeat && !widget.panel)) {
      return const SizedBox.shrink();
    }
    final size = widget.size;
    final meter = beat.meterOf(widget.index);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final one = theme.extension<StageColors>()?.chord ?? scheme.tertiary;
    final p = position;
    final lit = p != null && p.phase < litFor ? p.beat : -1;
    final accents = meter.accents;
    final dots = <Widget>[];
    var i = 0;
    for (final group in meter.groups) {
      if (dots.isNotEmpty) dots.add(SizedBox(width: size * 0.6));
      for (var g = 0; g < group; g++, i++) {
        final on = i == lit;
        final accent = accents[i] != BeatAccent.none;
        dots.add(
          Container(
            key: on ? const Key('beat-dot-lit') : null,
            width: accent ? size * 1.3 : size,
            height: accent ? size * 1.3 : size,
            margin: EdgeInsets.symmetric(horizontal: size * 0.2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on
                  ? (i == 0 ? one : scheme.primary)
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                color: i == 0 ? one : scheme.outlineVariant,
                width: size / 7,
              ),
            ),
          ),
        );
      }
    }
    return Semantics(
      label: AppLocalizations.of(context).beatDisplayLabel,
      child: Row(
        key: const Key('beat-dots'),
        mainAxisSize: MainAxisSize.min,
        children: dots,
      ),
    );
  }
}

/// The count-in over the page (ADR-0026): large numbers and the bar; takes
/// no taps and fades out after the count-in.
class CountInOverlay extends StatefulWidget {
  const CountInOverlay({super.key});

  @override
  State<CountInOverlay> createState() => _CountInOverlayState();
}

class _CountInOverlayState extends _BeatState<CountInOverlay> {
  @override
  int? get index => null;

  @override
  double get litFor => 0.5;

  @override
  Widget build(BuildContext context) {
    final beat = LiveBeatScope.of(context);
    final p = position;
    final show =
        beat != null && beat.settings.showBeat && p != null && p.inCountIn;
    final theme = Theme.of(context);
    final one =
        theme.extension<StageColors>()?.chord ?? theme.colorScheme.tertiary;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: !show
            ? const SizedBox.expand()
            : ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        child: Text(
                          '${p.beat + 1}',
                          key: const Key('count-in-number'),
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 200,
                            fontWeight: FontWeight.w800,
                            color: p.beat == 0
                                ? one
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)
                            .countInBar(p.bar + 1, p.countInBars),
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// The edge of the screen flashes on each beat, the 1 in the chord colour
/// of the stage (drums, ADR-0026); for the corner of the eye.
class EdgeFlash extends StatefulWidget {
  const EdgeFlash({super.key});

  @override
  State<EdgeFlash> createState() => _EdgeFlashState();
}

class _EdgeFlashState extends _BeatState<EdgeFlash> {
  @override
  int? get index => null;

  @override
  double get litFor => 0.2;

  @override
  Widget build(BuildContext context) {
    final beat = LiveBeatScope.of(context);
    final p = position;
    final on =
        beat != null &&
        beat.settings.showEdgeFlash &&
        p != null &&
        p.phase < litFor;
    final theme = Theme.of(context);
    final one =
        theme.extension<StageColors>()?.chord ?? theme.colorScheme.tertiary;
    return IgnorePointer(
      child: DecoratedBox(
        key: on ? const Key('edge-flash-on') : null,
        decoration: BoxDecoration(
          border: on
              ? Border.all(
                  color: p.beat == 0 ? one : theme.colorScheme.primary,
                  width: 10,
                )
              : null,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Tempo on stage in the control bar: slower, faster, tap tempo, back to
/// the song's tempo, start and stop.
class StageTempoControls extends StatelessWidget {
  const StageTempoControls({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final beat = LiveBeatScope.of(context);
    if (beat == null || !beat.canBeat(index)) return const SizedBox.shrink();
    final tempo = beat.tempoOf(index)!;
    final running = beat.isRunning(index);
    return Row(
      key: const Key('stage-tempo-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('tempo-slower'),
          tooltip: l10n.tempoSlower,
          icon: const Icon(Icons.remove),
          onPressed: () => beat.nudge(index, -1),
        ),
        SizedBox(
          width: 88,
          child: Text(
            l10n.bpm(tempo),
            key: const Key('stage-tempo-value'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('tempo-faster'),
          tooltip: l10n.tempoFaster,
          icon: const Icon(Icons.add),
          onPressed: () => beat.nudge(index, 1),
        ),
        TextButton(
          key: const Key('tempo-tap'),
          onPressed: () => beat.tap(index),
          child: Text(l10n.tapTempo),
        ),
        if (beat.tempoChanged(index))
          IconButton(
            key: const Key('tempo-reset'),
            tooltip: l10n.tempoReset,
            icon: const Icon(Icons.undo),
            onPressed: () => beat.resetTempo(index),
          ),
        IconButton(
          key: const Key('beat-toggle'),
          tooltip: running ? l10n.beatStop : l10n.beatStart,
          icon: Icon(
            running ? Icons.stop_circle_outlined : Icons.timer_outlined,
          ),
          onPressed: () => beat.toggle(index),
        ),
      ],
    );
  }
}

/// Left of the song map on wide screens (ADR-0026): above, the beat of the
/// current song large; below, the set with tempo and time signature of each
/// song. A tap on an item of the set turns to it.
class DrumPanel extends StatelessWidget {
  const DrumPanel({
    super.key,
    required this.items,
    required this.current,
    required this.onSelect,
  });

  final List<LiveItem> items;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('drum-panel'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _LargeBeat(index: current)),
      const Divider(height: 1),
      Expanded(
        child: _SetList(items: items, current: current, onSelect: onSelect),
      ),
    ],
  );
}

class _LargeBeat extends StatelessWidget {
  const _LargeBeat({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final beat = LiveBeatScope.of(context);
    final tempo = beat?.tempoOf(index);
    if (beat == null || tempo == null) {
      return Center(
        child: Text(l10n.songMapNoTempo, style: theme.textTheme.titleMedium),
      );
    }
    final meter = beat.meterOf(index);
    final running = beat.isRunning(index);
    return LayoutBuilder(
      builder: (context, constraints) {
        // As large as the width allows for the beats of the bar.
        final count = meter.beatsPerBar + meter.groups.length;
        final size = (constraints.maxWidth / (count * 1.8)).clamp(16.0, 72.0);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: const Key('large-beat'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                beat.tempoChanged(index)
                    ? '${l10n.bpm(tempo)} *'
                    : l10n.bpm(tempo),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                [meter.toString(), ?meter.groupingLabel].join('  ·  '),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              FittedBox(
                child: BeatDots(index: index, size: size, panel: true),
              ),
              const SizedBox(height: 16),
              if (beat.canBeat(index))
                FilledButton.tonalIcon(
                  key: const Key('large-beat-toggle'),
                  onPressed: () => beat.toggle(index),
                  icon: Icon(running ? Icons.stop : Icons.play_arrow),
                  label: Text(running ? l10n.beatStop : l10n.beatStart),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SetList extends StatelessWidget {
  const _SetList({
    required this.items,
    required this.current,
    required this.onSelect,
  });

  final List<LiveItem> items;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final beat = LiveBeatScope.of(context);
    return ListView.builder(
      key: const Key('drum-set-list'),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final tempo = item.song == null ? null : beat?.tempoOf(i);
        final details = [
          if (tempo != null) l10n.bpm(tempo),
          if (item.song != null && beat != null) '${beat.meterOf(i)}',
        ].join(' · ');
        return ListTile(
          key: Key('drum-set-$i'),
          selected: i == current,
          selectedTileColor: theme.colorScheme.secondaryContainer,
          leading: Text('${i + 1}', style: theme.textTheme.titleMedium),
          title: Text(
            item.title(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: item.song == null
                ? theme.textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  )
                : theme.textTheme.titleMedium,
          ),
          trailing: details.isEmpty
              ? null
              : Text(details, style: theme.textTheme.titleMedium),
          onTap: () => onSelect(i),
        );
      },
    );
  }
}
