import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:google_fonts/google_fonts.dart';

import '../../design/fonts.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';

/// Pick the card font by looking at it.
///
/// Every option renders the same activity card, in the real sizes and weights,
/// so the comparison is the one that matters — how a title, a slot label and a
/// venue line sit together at 16, 11.5 and 12.5 point. Tapping applies it
/// across the app immediately; the sheet stays open so the next one is one tap
/// away.
class FontPreviewSheet extends StatefulWidget {
  const FontPreviewSheet({super.key});

  @override
  State<FontPreviewSheet> createState() => _FontPreviewSheetState();
}

class _FontPreviewSheetState extends State<FontPreviewSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return WayfareDismissibleSheet(
      builder: (context, scrollController) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: WayfareColors.bgApp,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(theme.sheetRadius)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WayfareSheetGrabber(),
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 28 + safeBottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Card font', style: WayfareType.display(26)),
                      const SizedBox(height: 6),
                      Text(
                        'The trip title stays Instrument Serif. This is '
                        'everything else — tap one to see it on the real '
                        'screens.',
                        style: WayfareType.body(
                          13.5,
                          color: WayfareColors.subhead,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final option in WayfareFonts.options) ...[
                        _Sample(
                          option: option,
                          selected: WayfareFonts.family.value == option.family,
                          onTap: () {
                            WayfareFonts.family.value = option.family;
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: WayfareSpace.cardGap),
                      ],
                    ],
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

class _Sample extends StatelessWidget {
  const _Sample({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final FontOption option;
  final bool selected;
  final VoidCallback onTap;

  /// The style the real card uses, in this option's face.
  TextStyle _as(TextStyle style) =>
      option.family == null ? style : GoogleFonts.getFont(option.family!, textStyle: style);

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.cardLg,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WayfareColors.surface,
            borderRadius: theme.cardLg,
            border: Border.all(
              color: selected ? WayfareColors.ink : WayfareColors.borderSoft,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: _as(
                        const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        size: 18, color: WayfareColors.accent),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                option.note,
                style: WayfareType.body(12, color: WayfareColors.mutedLight),
              ),
              const SizedBox(height: 12),
              // The real card, at the real sizes.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                decoration: BoxDecoration(
                  color: WayfareColors.surfaceAlt,
                  borderRadius: theme.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: WayfareColors.morning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '10:00 AM',
                          style: _as(
                            const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'MORNING',
                          style: _as(
                            const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.75,
                              color: Color(0xFF6D6255),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jim Thompson House tour',
                      style: _as(
                        const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Opens at 09:00 and the last tour leaves at 17:00.',
                      style: _as(
                        const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: WayfareColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '1h 30m · Pathum Wan',
                      style: _as(
                        const TextStyle(
                          fontSize: 12.5,
                          color: WayfareColors.mutedLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
