import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The typeface everything that is not a display heading is set in.
///
/// Work Sans — geometric with the corners softened. It was the platform sans,
/// which on iOS is San Francisco: correct for a system app and slightly
/// anonymous next to a serif as characterful as Instrument Serif. This sits
/// between a newspaper grotesque and a humanist: more personality per letter
/// than either, which shows most in the short all-caps eyebrows.
///
/// Deliberately the same on both platforms. The rest of the app wears two
/// dresses; the voice does not change between them.
class WayfareFonts {
  const WayfareFonts._();

  static const family = 'Work Sans';

  /// The family applied to a style, for the places that build one directly.
  ///
  /// Most text in the app inherits it from the theme instead — a `Text` merges
  /// its style onto the ambient `DefaultTextStyle`, so a plain `TextStyle` with
  /// no family picks this up without asking.
  static TextStyle apply(TextStyle style) =>
      GoogleFonts.getFont(family, textStyle: style);
}
