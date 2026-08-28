import 'package:flutter/material.dart' hide TimeOfDay;

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/plan.dart';
import '../formatting.dart';

/// A row of facts in the same idiom as the planner-failure card: label left,
/// consequence right, colour carrying whether it is a loss or a survival.
class FactRows extends StatelessWidget {
  const FactRows({super.key, required this.rows});

  final List<({String label, String value, Color color})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WayfareColors.surfaceAlt,
        borderRadius: theme.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(
                        top: BorderSide(color: WayfareColors.skeletonLight),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: WayfareColors.mutedLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: rows[i].color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The shell every one of these sheets sits in.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    // No Align: showModalBottomSheet already docks this to the bottom, and
    // filling the screen meant every tap above the card landed on a
    // transparent area instead of the barrier — leaving no way out but the
    // buttons.
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: WayfareColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(theme.sheetRadius)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                offset: Offset(0, -12),
                blurRadius: 40,
              ),
            ],
          ),
          // The grabber sits outside the scroll view: inside it, a downward
          // drag scrolls the content instead of dismissing the sheet, which
          // is the gesture everyone reaches for to close one.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WayfareSheetGrabber(),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 46 + viewInsets),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...children,
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

/// Removing one activity, with the loss stated rather than implied.
///
/// The confirmation names what the day becomes and what it costs afterwards —
/// the same reasoning as the flights consequence sheet: when an action takes
/// something away, say what.
class RemoveActivitySheet extends StatelessWidget {
  const RemoveActivitySheet({
    super.key,
    required this.block,
    required this.day,
    required this.slotBecomesEmpty,
    required this.dayCostBefore,
    required this.currency,
    required this.onRemove,
    required this.onKeep,
  });

  final PlanBlock block;
  final int day;
  final bool slotBecomesEmpty;
  final num dayCostBefore;
  final String currency;
  final VoidCallback onRemove;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final after = dayCostBefore - (block.estimatedCostPerPerson ?? 0);
    final slot = block.timeOfDay.name;

    return SheetFrame(
      children: [
        Text('Remove this activity?', style: WayfareType.display(22)),
        const SizedBox(height: 14),
        FactRows(
          rows: [
            (
              label: 'Activity',
              value: block.activity,
              color: WayfareColors.ink,
            ),
            (
              label: 'Day $day $slot',
              value: slotBecomesEmpty ? 'Becomes empty' : 'Still has others',
              color: slotBecomesEmpty
                  ? WayfareColors.destructiveInk
                  : WayfareColors.mutedLight,
            ),
            (
              label: 'Day $day planned cost',
              value: '${formatMoney(dayCostBefore, currency)} → '
                  '${formatMoney(after, currency)} pp',
              color: WayfareColors.ink,
            ),
          ],
        ),
        const SizedBox(height: 16),
        WayfareSecondaryButton(
          label: 'Remove ${_shortTitle(block.activity)}',
          onPressed: onRemove,
          minHeight: WayfareTouch.sheetCta,
          fontSize: 15,
          foreground: WayfareColors.destructiveInk,
        ),
        const SizedBox(height: 10),
        WayfareSecondaryButton(
          label: 'Keep it',
          onPressed: onKeep,
          background: Colors.transparent,
          foreground: WayfareColors.muted,
          fontSize: 13.5,
        ),
      ],
    );
  }

  /// The button names the thing it removes, but a long title would wrap the
  /// button into three lines — so it is shortened rather than the label
  /// becoming a generic "Remove".
  static String _shortTitle(String title) {
    final clean = title.trim();
    if (clean.length <= 28) return clean.toLowerCase();
    return '${clean.substring(0, 25).trimRight().toLowerCase()}…';
  }
}
