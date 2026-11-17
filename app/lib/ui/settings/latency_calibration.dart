import 'package:chordpro/chordpro.dart' hide Key;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../audio/metronome.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart';

/// Measures the audio delay (ADR-0026): the click plays at 100 BPM and the
/// drummer taps along; the median offset of the taps from the beats is the
/// delay of the headphones. Returns the delay in milliseconds, or null.
Future<int?> showLatencyCalibration(BuildContext context) => showDialog<int>(
  context: context,
  builder: (_) => const _LatencyCalibrationDialog(),
);

class _LatencyCalibrationDialog extends ConsumerStatefulWidget {
  const _LatencyCalibrationDialog();

  @override
  ConsumerState<_LatencyCalibrationDialog> createState() =>
      _LatencyCalibrationDialogState();
}

class _LatencyCalibrationDialogState
    extends ConsumerState<_LatencyCalibrationDialog> {
  static const _bpm = 100;

  /// Taps needed before a result is shown; the first ones are skipped
  /// (finding the beat).
  static const _skip = 2;
  static const _needed = 8;

  late final Metronome _metronome;
  final _offsets = <Duration>[];
  var _taps = 0;

  @override
  void initState() {
    super.initState();
    _metronome = ref.read(metronomeProvider);
    final s = ref.read(settingsProvider);
    final config = ClickConfig.of(s);
    _metronome.start(
      meter: Meter.common,
      bpm: _bpm,
      config: ClickConfig(
        enabled: true,
        volume: config.volume,
        sound: config.sound,
        accent: config.accent,
      ),
    );
  }

  @override
  void dispose() {
    _metronome.stop();
    super.dispose();
  }

  void _tap() {
    final offset = _metronome.tapOffset();
    setState(() {
      _taps++;
      if (offset != null && _taps > _skip) _offsets.add(offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _offsets.length >= _needed
        ? latencyFromTaps(_offsets)
        : null;
    return ValueListenableBuilder<bool>(
      valueListenable: _metronome.clickUnavailable,
      builder: (context, unavailable, _) => AlertDialog(
        title: Text(l10n.audioLatencyCalibrateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              unavailable ? l10n.clickNoAudio : l10n.audioLatencyCalibrateHint,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: FilledButton(
                key: const Key('latency-tap'),
                onPressed: unavailable ? null : _tap,
                child: Text(l10n.audioLatencyTap),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result == null
                  ? l10n.audioLatencyTaps(_taps)
                  : l10n.audioLatencyResult(result),
              key: const Key('latency-result'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('latency-apply'),
            onPressed: result == null
                ? null
                : () => Navigator.pop(context, result),
            child: Text(l10n.audioLatencyApply),
          ),
        ],
      ),
    );
  }
}
