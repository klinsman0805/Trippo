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

  /// The display face: trip titles, the budget headline, sheet headings.
  ///
  /// Was Instrument Serif, which ships one weight — 400 — and no bold, which
  /// is why it read thin: there was nothing heavier to reach for. Fraunces is
  /// variable across 100–900, so the weight is a decision rather than whatever
  /// the file happens to contain, and its softened, slightly wonky letterforms
  /// have the warmth this palette is built around.
  static const displayFamily = 'Fraunces';

  /// Semibold. Heavy enough to hold a trip title against the cream background
  /// without the headings turning into a slab — one line to change if it wants
  /// more (700) or less (500).
  static const displayWeight = FontWeight.w600;

  /// The family applied to a style, for the places that build one directly.
  ///
  /// Most text in the app inherits it from the theme instead — a `Text` merges
  /// its style onto the ambient `DefaultTextStyle`, so a plain `TextStyle` with
  /// no family picks this up without asking.
  static TextStyle apply(TextStyle style) =>
      GoogleFonts.getFont(family, textStyle: style);
}
