import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The typeface everything that is not a display heading is set in.
///
/// Source Sans — humanist, and a little narrower than the alternatives. It was
/// the platform sans, which on iOS is San Francisco: correct for a system app
/// and slightly anonymous next to a serif as characterful as Instrument Serif.
/// This is warmer and quieter than a grotesque, and the narrower set fits more
/// of a venue line before it truncates.
///
/// Deliberately the same on both platforms. The rest of the app wears two
/// dresses; the voice does not change between them.
class WayfareFonts {
  const WayfareFonts._();

  static const family = 'Source Sans 3';

  /// The family applied to a style, for the places that build one directly.
  ///
  /// Most text in the app inherits it from the theme instead — a `Text` merges
  /// its style onto the ambient `DefaultTextStyle`, so a plain `TextStyle` with
  /// no family picks this up without asking.
  static TextStyle apply(TextStyle style) =>
      GoogleFonts.getFont(family, textStyle: style);
}
