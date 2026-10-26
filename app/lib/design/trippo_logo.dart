// Trippo logo widgets: the static mark, the map pin, the full lockup and the
// animated logo. Drawn with CustomPainter, so no extra packages are needed
// (google_fonts is already a dependency and supplies Instrument Serif).
//
// All geometry is in a 120 x 120 unit box, copied 1:1 from the SVGs in
// brand/logo/svg/. If you change a shape, change it in both places.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logo colours. These match WayfareColors (accent, accentDark, ink, bgApp,
/// surface); [blush] is used only by the reversed mark.
abstract final class TrippoBrandColors {
  static const accent = Color(0xFFB8543A);
  static const accentDark = Color(0xFF8F3D28);
  static const ink = Color(0xFF241F1A);
  static const cream = Color(0xFFF4EFE6);
  static const surface = Color(0xFFFFFDF9);
  static const blush = Color(0xFFE3A18A);
  static const muted = Color(0xFF6B6158);
}

/// Colour scheme for the mark.
@immutable
class TrippoMarkColors {
  const TrippoMarkColors({
    required this.body,
    required this.detail,
    required this.water,
    required this.pupil,
    this.eyeWhite,
  });

  /// Terracotta hippo on a light background (the default).
  static const standard = TrippoMarkColors(
    body: TrippoBrandColors.accent,
    detail: TrippoBrandColors.accentDark,
    water: TrippoBrandColors.accent,
    pupil: TrippoBrandColors.ink,
    eyeWhite: TrippoBrandColors.surface,
  );

  /// Cream hippo for terracotta or dark backgrounds (the app icon).
  static const reversed = TrippoMarkColors(
    body: TrippoBrandColors.surface,
    detail: TrippoBrandColors.blush,
    water: TrippoBrandColors.surface,
    pupil: TrippoBrandColors.ink,
  );

  final Color body;
  final Color detail;
  final Color water;
  final Color pupil;

  /// Null draws solid pupils without eye whites (used by [reversed]).
  final Color? eyeWhite;
}

// ---------------------------------------------------------------------------
// Static widgets
// ---------------------------------------------------------------------------

/// The hippo peeking above the waterline. Square; [size] is its side.
class TrippoMark extends StatelessWidget {
  const TrippoMark({
    super.key,
    this.size = 48,
    this.colors = TrippoMarkColors.standard,
    this.semanticLabel = 'Trippo',
  });

  final double size;
  final TrippoMarkColors colors;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(colors: colors, pose: _MarkPose.still),
      ),
    );
  }
}

/// The hippo-shaped map pin. Square; the pin's tip is at [tipAlignment],
/// so use that as the marker's anchor on a map.
class TrippoPin extends StatelessWidget {
  const TrippoPin({super.key, this.size = 48, this.semanticLabel});

  /// Where the tip sits inside the square: (60, 112) in the 120-unit box.
  static const tipAlignment = Alignment(0, 112 / 60 - 1);

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: CustomPaint(size: Size.square(size), painter: const _PinPainter()),
    );
  }
}

/// Mark + "Trippo" wordmark, side by side.
class TrippoLogo extends StatelessWidget {
  const TrippoLogo({
    super.key,
    this.height = 64,
    this.onDark = false,
  });

  /// Height of the mark; the wordmark is sized from it (136 / 176).
  final double height;

  /// Cream wordmark for dark backgrounds.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trippo',
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrippoMark(size: height, semanticLabel: null),
          SizedBox(width: height * 22 / 176),
          Text('Trippo', style: _wordStyle(height, onDark)),
        ],
      ),
    );
  }
}

TextStyle _wordStyle(double markHeight, bool onDark) => GoogleFonts.getFont(
      'Instrument Serif',
      fontSize: markHeight * 136 / 176,
      height: 1,
      letterSpacing: markHeight * 136 / 176 * -0.01,
      color: onDark ? TrippoBrandColors.cream : TrippoBrandColors.ink,
    );

// ---------------------------------------------------------------------------
// Animated logo
// ---------------------------------------------------------------------------

/// The animated logo: the hippo rises out of the water, "Trippo" comes in
/// letter by letter, the hippo blinks and wiggles its ears, then everything
/// sinks and the 6-second loop repeats.
///
/// With [loop] false it plays the intro once, holds on the full logo and calls
/// [onIntroComplete] (use this for a splash screen). When the platform asks
/// for reduced motion it shows the still logo and calls [onIntroComplete]
/// straight away.
class TrippoLogoAnimation extends StatefulWidget {
  const TrippoLogoAnimation({
    super.key,
    this.height = 120,
    this.loop = true,
    this.showTagline = true,
    this.tagline = 'Plan the trip with a hippo guide',
    this.onIntroComplete,
  });

  /// Height of the mark.
  final double height;
  final bool loop;
  final bool showTagline;
  final String tagline;
  final VoidCallback? onIntroComplete;

  /// Length of one full loop.
  static const cycle = Duration(seconds: 6);

  /// Where the logo is fully shown and holds when [loop] is false.
  static const _holdAt = 0.5;

  @override
  State<TrippoLogoAnimation> createState() => _TrippoLogoAnimationState();
}

class _TrippoLogoAnimationState extends State<TrippoLogoAnimation>
    with TickerProviderStateMixin {
  // Built in initState, not as `late final` initialisers. A lazy field is
  // only created when something reads it — and with reduced motion on,
  // nothing does: neither controller is ever started. `dispose` then became
  // the first read, which built a Ticker while the element was already
  // deactivated and threw on the inherited lookup. Dismissing the splash
  // screen crashed, for exactly the people who had asked for less animation.
  late final AnimationController _main;
  late final AnimationController _wave;

  bool _reduceMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _main = AnimationController(vsync: this, duration: TrippoLogoAnimation.cycle);
    // The waves keep moving even while the main timeline holds.
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      // `mounted`, as the animated path below also checks: a splash dismissed
      // before the next frame leaves this callback holding a disposed State,
      // and reading `widget` from one throws while the tree is being torn
      // down. The quickest route off a splash screen is the one that does not
      // wait for an animation, so this is the path most likely to be cut
      // short.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onIntroComplete?.call();
      });
      return;
    }
    _wave.repeat();
    if (widget.loop) {
      _main.repeat();
    } else {
      _main.animateTo(
        TrippoLogoAnimation._holdAt,
        duration: TrippoLogoAnimation.cycle * TrippoLogoAnimation._holdAt,
      ).whenComplete(() {
        if (mounted) widget.onIntroComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _main.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final style = _wordStyle(h, false);
    final tagStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: h * 17 / 200,
              color: TrippoBrandColors.muted,
            ) ??
        TextStyle(fontSize: h * 17 / 200, color: TrippoBrandColors.muted);

    if (_reduceMotion) {
      return Semantics(
        label: 'Trippo',
        container: true,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrippoLogo(height: h),
            if (widget.showTagline) ...[
              SizedBox(height: h * 0.14),
              Text(widget.tagline, style: tagStyle),
            ],
          ],
        ),
      );
    }

    return Semantics(
      label: 'Trippo',
      container: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_main, _wave]),
        builder: (context, _) {
          final t = _main.value;
          final pose = _MarkPose.at(t, _wave.value);
          const letters = 'Trippo';
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: Size.square(h),
                    painter: _MarkPainter(
                      colors: TrippoMarkColors.standard,
                      pose: pose,
                    ),
                  ),
                  SizedBox(width: h * 22 / 176),
                  for (var i = 0; i < letters.length; i++)
                    _Letter(
                      letter: letters[i],
                      // Each letter starts 0.05 s after the one before it.
                      t: _wrap(t - i * 0.05 / 6),
                      style: style,
                      rise: h * 28 / 200,
                    ),
                ],
              ),
              if (widget.showTagline) ...[
                SizedBox(height: h * 0.14),
                _fadeSlide(
                  t: t,
                  inStart: 0.34,
                  inEnd: 0.42,
                  outStart: 0.82,
                  outEnd: 0.90,
                  rise: 8,
                  curve: Curves.easeOut,
                  child: Text(widget.tagline, style: tagStyle),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.letter,
    required this.t,
    required this.style,
    required this.rise,
  });

  final String letter;
  final double t;
  final TextStyle style;
  final double rise;

  @override
  Widget build(BuildContext context) => _fadeSlide(
        t: t,
        inStart: 0.20,
        inEnd: 0.30,
        outStart: 0.84,
        outEnd: 0.91,
        rise: rise,
        curve: const Cubic(0.2, 0.9, 0.3, 1.2),
        child: Text(letter, style: style),
      );
}

/// Fades and slides a child in, holds, then fades it out (no slide on exit).
Widget _fadeSlide({
  required double t,
  required double inStart,
  required double inEnd,
  required double outStart,
  required double outEnd,
  required double rise,
  required Curve curve,
  required Widget child,
}) {
  final p = curve.transform(_progress(t, inStart, inEnd));
  final pOut = curve.transform(_progress(t, outStart, outEnd));
  final opacity = (t < outStart ? p : 1 - pOut).clamp(0.0, 1.0);
  final dy = t < outStart ? (1 - p) * rise : 0.0;
  return Opacity(
    opacity: opacity,
    child: Transform.translate(offset: Offset(0, dy), child: child),
  );
}

// ---------------------------------------------------------------------------
// Timeline (fractions of the 6 s cycle, matching the canvas animation)
// ---------------------------------------------------------------------------

double _progress(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);

double _wrap(double t) => t - t.floorToDouble();

double _lerp(double a, double b, double p) => a + (b - a) * p;

/// One frame of the mark's animation. [still] is the static logo.
@immutable
class _MarkPose {
  const _MarkPose({
    this.sink = 0,
    this.blink = 1,
    this.leftEar = 0,
    this.rightEar = 0,
    this.wave = 0,
    this.rippleScale = 1,
    this.rippleOpacity = 0,
    this.dotsOpacity = 0.55,
    this.scrollingWave = false,
  });

  static const still = _MarkPose();

  /// How far the head is pushed down, in units (0 = up, 72 = under water).
  final double sink;

  /// Vertical scale of the eyes (1 = open).
  final double blink;

  /// Ear rotation in radians, about the base of each ear.
  final double leftEar;
  final double rightEar;

  /// Wave offset as a fraction of one wavelength (32 units).
  final double wave;

  final double rippleScale;
  final double rippleOpacity;
  final double dotsOpacity;

  /// False for the still logo, whose wave has rounded ends.
  final bool scrollingWave;

  static const _bounce = Cubic(0.3, 1.4, 0.5, 1);

  factory _MarkPose.at(double t, double wave) {
    // Rise 6%–18%, hold, sink 84%–94%.
    final double sink;
    if (t < 0.84) {
      sink = 72 * (1 - _bounce.transform(_progress(t, 0.06, 0.18)));
    } else {
      sink = 72 * _bounce.transform(_progress(t, 0.84, 0.94)).clamp(0.0, 1.0);
    }

    // Blink 42%–48%.
    final blinkP = t < 0.45
        ? Curves.easeInOut.transform(_progress(t, 0.42, 0.45))
        : 1 - Curves.easeInOut.transform(_progress(t, 0.45, 0.48));
    final blink = _lerp(1, 0.08, blinkP);

    // Ripple 8%–30%.
    final rp = Curves.easeOut.transform(_progress(t, 0.08, 0.30));
    final rippleOpacity = t < 0.12
        ? _lerp(0, 0.6, _progress(t, 0.08, 0.12))
        : _lerp(0.6, 0, Curves.easeOut.transform(_progress(t, 0.12, 0.30)));

    // Route dots fade in 22%–32%, out 84%–92%.
    final dots = t < 0.84
        ? 0.55 * Curves.easeInOut.transform(_progress(t, 0.22, 0.32))
        : 0.55 * (1 - Curves.easeInOut.transform(_progress(t, 0.84, 0.92)));

    return _MarkPose(
      sink: sink,
      blink: blink,
      leftEar: _ear(t),
      rightEar: _ear(_wrap(t - 0.08 / 6)),
      wave: wave,
      rippleScale: _lerp(0.3, 1.6, rp),
      rippleOpacity: t < 0.08 ? 0 : rippleOpacity,
      dotsOpacity: dots,
      scrollingWave: true,
    );
  }

  /// Ear wiggle 56%–70%: 0 → -16° → 12° → -6° → 0.
  static double _ear(double t) {
    const keys = [0.56, 0.59, 0.63, 0.67, 0.70];
    const degs = [0.0, -16.0, 12.0, -6.0, 0.0];
    for (var i = 0; i < keys.length - 1; i++) {
      if (t >= keys[i] && t < keys[i + 1]) {
        final p = Curves.easeInOut.transform(_progress(t, keys[i], keys[i + 1]));
        return _lerp(degs[i], degs[i + 1], p) * math.pi / 180;
      }
    }
    return 0;
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Scales the canvas so the painter can draw in a 120 x 120 unit box.
void _fitUnits(Canvas canvas, Size size) {
  final s = size.shortestSide / 120;
  canvas.translate(
    (size.width - 120 * s) / 2,
    (size.height - 120 * s) / 2,
  );
  canvas.scale(s);
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.colors, required this.pose});

  final TrippoMarkColors colors;
  final _MarkPose pose;

  /// The snout's flat base doubles as the waterline; nothing above the water
  /// is drawn below this.
  static const _waterTop = 82.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _fitUnits(canvas, size);

    final body = Paint()..color = colors.body;
    final detail = Paint()..color = colors.detail;

    // Ripple, behind everything.
    if (pose.rippleOpacity > 0) {
      canvas.save();
      canvas.translate(60, 88);
      canvas.scale(pose.rippleScale);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 88, height: 14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / pose.rippleScale
          ..color = colors.water.withValues(alpha: pose.rippleOpacity),
      );
      canvas.restore();
    }

    // Head, clipped at the waterline so it can rise out of the water.
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(-20, -20, 160, _waterTop + 20));
    canvas.translate(0, pose.sink);

    _ear(canvas, const Offset(37, 27), const Offset(36, 26), pose.leftEar,
        body, detail);
    _ear(canvas, const Offset(83, 27), const Offset(84, 26), pose.rightEar,
        body, detail);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 50), width: 64, height: 44),
      body,
    );
    canvas.drawCircle(const Offset(45, 38), 12, body);
    canvas.drawCircle(const Offset(75, 38), 12, body);
    canvas.drawPath(
      Path()
        ..moveTo(20, _waterTop)
        ..lineTo(20, 76)
        ..arcToPoint(const Offset(42, 54), radius: const Radius.circular(22))
        ..lineTo(78, 54)
        ..arcToPoint(const Offset(100, 76), radius: const Radius.circular(22))
        ..lineTo(100, _waterTop)
        ..close(),
      body,
    );
    // Inner ears are drawn with the ears (so they wiggle together).

    // Nostrils.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(48, 68), width: 9, height: 7),
      detail,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(72, 68), width: 9, height: 7),
      detail,
    );

    // Eyes (squashed vertically to blink).
    canvas.save();
    canvas.translate(0, 38.5);
    canvas.scale(1, pose.blink);
    canvas.translate(0, -38.5);
    final pupil = Paint()..color = colors.pupil;
    final eyeWhite = colors.eyeWhite;
    if (eyeWhite != null) {
      final white = Paint()..color = eyeWhite;
      canvas.drawCircle(const Offset(45, 38), 6.5, white);
      canvas.drawCircle(const Offset(75, 38), 6.5, white);
      canvas.drawCircle(const Offset(46.5, 39), 3.3, pupil);
      canvas.drawCircle(const Offset(76.5, 39), 3.3, pupil);
    } else {
      canvas.drawCircle(const Offset(46, 39), 4.5, pupil);
      canvas.drawCircle(const Offset(74, 39), 4.5, pupil);
    }
    canvas.restore();

    canvas.restore(); // head clip

    // Waterline: a wave with wavelength 32 running from x 4 to 116. When
    // animated it scrolls left inside that span.
    canvas.save();
    final Path wave;
    if (pose.scrollingWave) {
      canvas.clipRect(const Rect.fromLTRB(1.5, 0, 118.5, 120));
      wave = Path()..moveTo(4 - 32 - 32 * pose.wave, 90);
      for (var i = 0; i < 12; i++) {
        wave.relativeQuadraticBezierTo(8, i.isEven ? -6 : 6, 16, 0);
      }
    } else {
      wave = Path()..moveTo(4, 90);
      for (var i = 0; i < 7; i++) {
        wave.relativeQuadraticBezierTo(8, i.isEven ? -6 : 6, 16, 0);
      }
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = colors.water,
    );
    canvas.restore();

    // Dotted route under the water.
    if (pose.dotsOpacity > 0) {
      final dot = Paint()
        ..color = colors.water.withValues(alpha: pose.dotsOpacity);
      for (var x = 30.0; x <= 78; x += 12) {
        canvas.drawCircle(Offset(x, 106), 2.5, dot);
      }
    }

    canvas.restore();
  }

  void _ear(Canvas canvas, Offset centre, Offset innerCentre, double angle,
      Paint body, Paint detail) {
    canvas.save();
    // Rotate about the bottom of the ear.
    final pivot = Offset(centre.dx, centre.dy + 10);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawOval(Rect.fromCenter(center: centre, width: 18, height: 20), body);
    canvas.drawOval(
        Rect.fromCenter(center: innerCentre, width: 8, height: 10), detail);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.pose != pose || old.colors != colors;
}

class _PinPainter extends CustomPainter {
  const _PinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _fitUnits(canvas, size);

    final body = Paint()..color = TrippoBrandColors.accent;
    canvas.drawCircle(const Offset(35, 29), 5.5, body);
    canvas.drawCircle(const Offset(85, 29), 5.5, body);
    canvas.drawCircle(const Offset(47, 33), 10, body);
    canvas.drawCircle(const Offset(73, 33), 10, body);
    canvas.drawRect(const Rect.fromLTWH(37, 33, 46, 30), body);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 66), width: 70, height: 44),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(36, 80)
        ..quadraticBezierTo(52, 94, 60, 112)
        ..quadraticBezierTo(68, 94, 84, 80)
        ..close(),
      body,
    );

    final white = Paint()..color = TrippoBrandColors.surface;
    final pupil = Paint()..color = TrippoBrandColors.ink;
    canvas.drawCircle(const Offset(47, 34), 5, white);
    canvas.drawCircle(const Offset(73, 34), 5, white);
    canvas.drawCircle(const Offset(47.5, 35), 2.7, pupil);
    canvas.drawCircle(const Offset(73.5, 35), 2.7, pupil);

    canvas.drawPath(
      Path()
        ..moveTo(50, 72)
        ..quadraticBezierTo(60, 78, 70, 72),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = TrippoBrandColors.accentDark,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}
