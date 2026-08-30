import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The typeface the app's non-display text is set in.
///
/// Display stays Instrument Serif; this is everything else — activity titles,
/// body copy, eyebrows, buttons. It was the platform default, which on iOS is
/// San Francisco: correct for a system app and slightly anonymous next to a
/// serif this characterful.
///
/// Kept switchable so the choice can be made by looking rather than by
/// argument. [FontPreviewSheet] shows the same card in each.
class WayfareFonts {
  const WayfareFonts._();

  /// The candidates, in the order the preview lists them.
  static const options = <FontOption>[
    FontOption(
      null,
      'System',
      'San Francisco on iOS, Roboto on Android. Invisible, and reads as '
          'somebody else\'s app.',
    ),
    FontOption(
      'Inter',
      'Inter',
      'Drawn for screens at small sizes. Wide apertures, tall x-height — the '
          'safest possible choice, and the most common.',
    ),
    FontOption(
      'Source Sans 3',
      'Source Sans',
      'Humanist and slightly narrow. Warmer than Inter, and it gets more '
          'words onto a card line without crowding.',
    ),
    FontOption(
      'Libre Franklin',
      'Libre Franklin',
      'A newspaper grotesque. Sturdy captions and headings, and it has the '
          'editorial register Instrument Serif is already reaching for.',
    ),
    FontOption(
      'Work Sans',
      'Work Sans',
      'Geometric with the corners softened. More personality per letter, '
          'which shows most in the short all-caps eyebrows.',
    ),
    FontOption(
      'Literata',
      'Literata',
      'A serif for the cards too. The most opinionated option: it makes the '
          'itinerary read like a printed programme rather than a list.',
    ),
  ];

  /// The live choice. The app rebuilds when it changes.
  static final ValueNotifier<String?> family = ValueNotifier<String?>(null);

  /// Applies the current family to a style. Null leaves the platform default.
  static TextStyle apply(TextStyle style, {String? familyOverride}) {
    final name = familyOverride ?? family.value;
    if (name == null) return style;
    return GoogleFonts.getFont(name, textStyle: style);
  }
}

class FontOption {
  const FontOption(this.family, this.label, this.note);

  /// Null is the platform's own font.
  final String? family;
  final String label;
  final String note;
}
