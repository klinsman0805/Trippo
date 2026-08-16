import 'package:flutter/material.dart';

/// Wayfare design tokens, transcribed from the handoff.
///
/// Values are literal from the spec — do not "round them off" to Material
/// defaults. Anything platform-dependent lives on [WayfareTheme] rather than
/// here, so this file stays a flat palette + scale.
abstract final class WayfareColors {
  // Surfaces
  static const bgApp = Color(0xFFF4EFE6);
  static const surface = Color(0xFFFFFDF9);
  static const surfaceAlt = Color(0xFFFAF5EB);

  // Ink
  static const ink = Color(0xFF241F1A);
  static const inkSecondary = Color(0xFF5C5347);
  static const muted = Color(0xFF6D6255);
  static const mutedLight = Color(0xFF8A7D6D);
  static const faint = Color(0xFF9A8D7D);
  static const subhead = Color(0xFF7A6F61);

  // Lines
  static const hairline = Color(0xFFECE3D4);
  static const border = Color(0xFFDDD3C4);
  static const borderSoft = Color(0xFFE6DDCE);
  static const borderChip = Color(0xFFE2D8C8);
  static const divider = Color(0xFFF0E8DA);

  // Accent
  static const accent = Color(0xFFB8543A);
  static const accentDark = Color(0xFF8F3D28);
  static const accentWarm = Color(0xFFE8A13C);

  // Info
  static const info = Color(0xFF2F6F8F);
  static const infoBg = Color(0xFFF1F6F8);
  static const infoBgAlt = Color(0xFFE6F0F5);
  static const infoBorder = Color(0xFFDBE7ED);
  static const infoBorderAlt = Color(0xFFD1E2EA);
  static const infoText = Color(0xFF2B5A70);
  static const infoBody = Color(0xFF38424A);

  // Success
  static const success = Color(0xFF5F7F5A);
  static const successText = Color(0xFF31532F);
  static const successBg = Color(0xFFE6F0E8);
  static const successBgAlt = Color(0xFFEEF5EC);
  static const successBorder = Color(0xFFCFE0CB);

  // Warning (the OPTIONAL and conflict-tag pills)
  static const warningText = Color(0xFF8A6A1E);
  static const warningBg = Color(0xFFF7EDD6);
  static const warningBorder = Color(0xFFE8D7AD);

  // Over budget
  static const overBudget = Color(0xFF9C3F27);
  static const overBg = Color(0xFFFDF0EA);
  static const overBorder = Color(0xFFECCFC1);

  // Amber — the estimate treatment, short-day bands and the failed state.
  // Distinct from `warning*`, which is the OPTIONAL/conflict-tag pill family.
  static const amberSurface = Color(0xFFFBF1D9);
  static const amberBorder = Color(0xFFE0C47F);
  static const amberInk = Color(0xFF6A5210);
  static const amberInkDeep = Color(0xFF7A5C12);
  static const amberPillBg = Color(0xFFF2E0AE);
  static const amberSoftBg = Color(0xFFFBF6E9);
  static const amberButtonBorder = Color(0xFFDCC08A);
  static const amberButtonInk = Color(0xFF5C4610);

  /// Muted price ink for estimates — signal 2 of the four.
  static const estimatePrice = Color(0xFF7A6F61);

  // Destructive, for "Remove <name> from the trip". Named, never a red fill.
  static const destructiveInk = Color(0xFF9C3F27);
  static const destructiveBorder = Color(0xFFE2C4BC);

  // "You wrote this" — hue-matched to the evening dot so it cannot be confused
  // with the amber optional/short-day family or the info blue used for chat.
  static const writtenBg = Color(0xFFEAEEF6);
  static const writtenBorder = Color(0xFFD4DCEA);
  static const writtenInk = Color(0xFF3D4F78);
  static const writtenInkDeep = Color(0xFF39445C);
  static const writtenPinBorder = Color(0xFFC9D3E4);

  /// An unfilled day is a to-do, not a constraint — deliberately neutral, so
  /// it never reads as the amber "the flight left no time" treatment.
  static const todoDashed = Color(0xFFD6CAB6);
  static const todoBg = Color(0xFFFBF7EF);
  static const gripLine = Color(0xFFA99C8B);

  // Loading skeletons
  static const skeletonDark = Color(0xFFEFE6D6);
  static const skeletonMid = Color(0xFFE9DFCD);
  static const skeletonLight = Color(0xFFF2EBDE);

  /// Live-fare confirmation, the counterpart to the estimate band.
  static const liveFareDot = Color(0xFF5F7F5A);
  static const liveFareInk = Color(0xFF4B6B46);

  // Android chrome
  static const androidNavBg = Color(0xFFF7F0E5);
  static const androidNavBorder = Color(0xFFEBE1D2);
  static const androidPill = Color(0xFFEEDDC9);
  static const androidActiveInk = Color(0xFF3F2D22);

  // Misc surfaces called out by name in the spec
  static const emptyStateBg = Color(0xFFFBF7EF);
  static const emptyStateBorder = Color(0xFFD6CAB6);
  static const placeholderTile = Color(0xFFEFE6D6);
  static const blankTile = Color(0xFFE9E0D0);
  static const paceChipBg = Color(0xFFF1E9DC);
  static const barTrack = Color(0xFFF2EBDE);
  static const barPlanned = Color(0xFFDFD4C1);
  static const removeIcon = Color(0xFFA2947F);
  static const optionalDash = Color(0xFFDCC9A4);
  static const generatingInk = Color(0xFFFDF8EF);
  static const generatingNote = Color(0xFFC3B8A8);
  static const scrim = Color(0x6B1E1812); // rgba(30,24,18,.42)

  /// Assigned to members by index, wrapping.
  static const memberColors = <Color>[
    Color(0xFFB8543A),
    Color(0xFF2F6F8F),
    Color(0xFFA8802A),
    Color(0xFF6B7F4A),
    Color(0xFF8A5A7A),
    Color(0xFF4A6B8A),
  ];

  static Color memberColor(int index) =>
      memberColors[(index < 0 ? 0 : index) % memberColors.length];

  // Time-of-day dots on activity cards
  static const morning = Color(0xFFD99A3E);
  static const afternoon = Color(0xFFB8543A);
  static const evening = Color(0xFF4A5F8F);

  // The three generating-overlay dots
  static const loadingDots = <Color>[
    Color(0xFFE8A13C),
    Color(0xFFD97A5A),
    Color(0xFF7FB0C4),
  ];
}

/// Spacing scale. The gutter is 16; card padding 14–20; card gap 12–14.
abstract final class WayfareSpace {
  static const gutter = 16.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const cardGap = 12.0;
  static const sectionGap = 14.0;
}

/// Minimum tap targets, from the accessibility notes.
abstract final class WayfareTouch {
  static const ios = 44.0;
  static const android = 48.0;
  static const input = 48.0;
  static const sheetCta = 52.0;
}
