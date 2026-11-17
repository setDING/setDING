import 'package:material_ui/material_ui.dart';

/// Brand colors of the setDING logo (sources in `app/branding/`).
abstract final class BrandColors {
  /// Top and bottom of the tile gradient (night blue).
  static const tileTop = Color(0xFF3D7BFF);
  static const tileBottom = Color(0xFF1A2F8F);

  /// Top and bottom of the bell gradient (brass).
  static const bellTop = Color(0xFFFFD34D);
  static const bellBottom = Color(0xFFF59E0B);

  /// Text of the wordmark ("set") on light and dark backgrounds.
  static const ink = Color(0xFF1B1D22);
  static const inkDark = Color(0xFFFFFFFF);

  /// Splash background, the same as the native and web splash
  /// (`flutter_native_splash.yaml`, `web/index.html`).
  static const splashLight = Color(0xFFFFFFFF);
  static const splashDark = Color(0xFF121417);

  /// The tile; also "DING" of the wordmark on light backgrounds.
  static const gradient = LinearGradient(
    // Matches x2=0.35 in mark.svg: slightly diagonal, top to bottom.
    begin: Alignment(-1, -1),
    end: Alignment(-0.3, 1),
    colors: [tileTop, tileBottom],
  );

  /// The bell; also "DING" of the wordmark on dark backgrounds.
  static const bellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bellTop, bellBottom],
  );
}

/// The logo mark: a desk bell in front of a set list on a blue tile. Drawn
/// in code (the same geometry as `app/branding/mark.svg`), so it shows on
/// the very first frame without loading an asset.
class SetdingMark extends StatelessWidget {
  const SetdingMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // mark.svg uses a 512 × 512 view box.
    canvas.scale(size.width / 512, size.height / 512);

    final tile = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 40, 432, 432),
      const Radius.circular(120),
    );
    canvas.drawRRect(
      tile,
      Paint()..shader = BrandColors.gradient.createShader(tile.outerRect),
    );

    // The set list.
    final list = Paint()..color = Colors.white.withValues(alpha: 0.28);
    for (final (y, width) in const [
      (95.0, 250.0),
      (143.0, 320.0),
      (191.0, 200.0),
      (239.0, 300.0),
      (287.0, 240.0),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(96, y, width, 18),
          const Radius.circular(9),
        ),
        list,
      );
    }

    // The bell: knob, stem, dome and base, each with the brass gradient
    // over its own bounds (like the SVG's objectBoundingBox gradient).
    void bell(Path part) => canvas.drawPath(
      part,
      Paint()..shader = BrandColors.bellGradient.createShader(part.getBounds()),
    );
    Path rounded(double x, double y, double w, double h, double r) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      );
    bell(rounded(242, 210, 28, 15, 6));
    bell(rounded(251, 222, 10, 26, 3));
    bell(
      Path()
        ..moveTo(154, 358)
        ..cubicTo(154, 294, 199, 245, 256, 245)
        ..cubicTo(313, 245, 358, 294, 358, 358)
        ..close(),
    );
    bell(rounded(127, 369, 258, 31, 15.5));
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

/// The wordmark "setDING": "set" in [ink], "DING" in the tile gradient on
/// light and in the bell gradient on dark backgrounds.
class SetdingWordmark extends StatelessWidget {
  const SetdingWordmark({super.key, this.height = 32, this.ink, this.dark});

  /// Font size of the wordmark.
  final double height;

  /// Color of "set"; defaults to a color readable on the background.
  final Color? ink;

  /// Whether the background is dark; defaults to the current theme.
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final dark = this.dark ?? Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
      fontFamily: 'NotoSans',
      fontWeight: FontWeight.w700,
      fontSize: height,
      height: 1.1,
      letterSpacing: -0.025 * height,
      color: ink ?? (dark ? BrandColors.inkDark : BrandColors.ink),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('set', style: style),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback:
                (dark ? BrandColors.bellGradient : BrandColors.gradient)
                    .createShader,
            child: Text('DING', style: style),
          ),
        ],
      ),
    );
  }
}

/// Mark and wordmark side by side.
class SetdingLogo extends StatelessWidget {
  const SetdingLogo({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'setDING',
    image: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SetdingMark(size: height * 1.25),
        SizedBox(width: height * 0.3),
        SetdingWordmark(height: height),
      ],
    ),
  );
}

/// Shown while the app starts: the same layout as the native splash
/// (Android, iOS) and the web splash, so the change is seamless. Follows
/// the system brightness, since the settings are not loaded yet.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.busy = false});

  /// Shows a progress indicator below the mark (e.g. the first sync).
  final bool busy;

  static const markSize = 128.0;
  static const wordmarkWidth = 200.0;

  /// Shortest time the splash stays on screen (counted from the start of
  /// `main()`), so it is noticeable even where the app starts in a fraction
  /// of a second (Windows, Linux). Starting runs during this time; only the
  /// rest is waited for.
  static const minimumDuration = Duration(seconds: 1);

  /// Waits until [shown] has run for at least [minimumDuration].
  static Future<void> waitForMinimum(Stopwatch shown) async {
    final rest = remaining(shown.elapsed);
    if (rest > Duration.zero) await Future<void>.delayed(rest);
  }

  /// How much longer the splash stays after it has been shown for [elapsed].
  static Duration remaining(
    Duration elapsed, {
    Duration minimum = minimumDuration,
  }) => elapsed >= minimum ? Duration.zero : minimum - elapsed;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: dark ? BrandColors.splashDark : BrandColors.splashLight,
        child: Semantics(
          label: 'setDING',
          child: Stack(
            children: [
              const Center(child: SetdingMark(size: markSize)),
              if (busy)
                Align(
                  alignment: const Alignment(0, 0.45),
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: BrandColors.tileTop,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Center(
                  child: SizedBox(
                    width: wordmarkWidth,
                    child: FittedBox(
                      child: SetdingWordmark(
                        height: 40,
                        ink: dark ? BrandColors.inkDark : BrandColors.ink,
                        dark: dark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
