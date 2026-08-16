import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Which platform dress to render. One component, two dresses — the handoff's
/// entire platform story is this enum plus the values below.
enum WayfarePlatform { ios, android }

/// Platform-dependent design values.
///
/// Read this from context via [WayfareTheme.of]. Everything that differs
/// between iOS and Material 3 in the handoff table lives here, so screens can
/// stay platform-agnostic.
class WayfareTheme extends InheritedWidget {
  const WayfareTheme({
    super.key,
    required this.platform,
    required super.child,
  });

  final WayfarePlatform platform;

  static WayfareTheme of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<WayfareTheme>();
    assert(theme != null, 'No WayfareTheme found in context');
    return theme!;
  }

  /// The dress matching the host OS.
  ///
  /// Uses `defaultTargetPlatform` rather than `dart:io` so this also resolves
  /// on web, and so Flutter's own platform override is respected.
  static WayfarePlatform hostPlatform() =>
      defaultTargetPlatform == TargetPlatform.android
          ? WayfarePlatform.android
          : WayfarePlatform.ios;

  bool get isAndroid => platform == WayfarePlatform.android;
  bool get isIOS => platform == WayfarePlatform.ios;

  // --- radii ---

  double get radius => isAndroid ? 16 : 14;
  double get radiusLg => isAndroid ? 24 : 20;
  double get pillRadius => isAndroid ? 999 : 14;
  double get chipRadius => isAndroid ? 999 : 12;
  double get sheetRadius => isAndroid ? 28 : 20;

  BorderRadius get card => BorderRadius.circular(radius);
  BorderRadius get cardLg => BorderRadius.circular(radiusLg);
  BorderRadius get pill => BorderRadius.circular(pillRadius);
  BorderRadius get chip => BorderRadius.circular(chipRadius);

  /// The chat send button: near-black on iOS, terracotta on Android.
  Color get sendButtonColor =>
      isAndroid ? WayfareColors.accent : WayfareColors.ink;

  /// Active bottom-nav item colour.
  Color get navActive =>
      isAndroid ? WayfareColors.androidActiveInk : WayfareColors.accent;

  double get minTouch => isAndroid ? WayfareTouch.android : WayfareTouch.ios;

  @override
  bool updateShouldNotify(WayfareTheme oldWidget) =>
      oldWidget.platform != platform;
}

/// Type scale.
///
/// Display is Instrument Serif; UI is the platform sans. Sizes are the literal
/// set from the handoff — 10.5 through 40.
abstract final class WayfareType {
  /// Instrument Serif, used for the trip title, budget headline, sheet title
  /// and the generating overlay.
  static TextStyle display(double size, {Color? color, double height = 1.15}) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? WayfareColors.ink,
        height: height,
      );

  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? WayfareColors.ink,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Eyebrow / overline: 10.5–11.5px, 700, uppercase, wide tracking.
  static TextStyle eyebrow(double size, {required Color color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: size * 0.065,
      );

  /// Body copy: line-height 1.45–1.55.
  static TextStyle body(double size, {Color? color, double height = 1.5}) =>
      TextStyle(
        fontSize: size,
        color: color ?? WayfareColors.muted,
        height: height,
      );
}

/// The MaterialApp theme. Mostly a carrier for the background and font family —
/// the design is specific enough that most surfaces are built explicitly rather
/// than inherited from Material defaults.
ThemeData buildAppTheme(WayfarePlatform platform) {
  final base = ThemeData(useMaterial3: true);
  // Roboto on Android, San Francisco (via the system default) on iOS.
  final textTheme = platform == WayfarePlatform.android
      ? GoogleFonts.robotoTextTheme(base.textTheme)
      : base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: WayfareColors.bgApp,
    textTheme: textTheme.apply(
      bodyColor: WayfareColors.ink,
      displayColor: WayfareColors.ink,
    ),
    colorScheme: base.colorScheme.copyWith(
      primary: WayfareColors.accent,
      surface: WayfareColors.surface,
    ),
    splashFactory:
        platform == WayfarePlatform.android ? InkRipple.splashFactory : NoSplash.splashFactory,
  );
}
