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
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 46 + viewInsets),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4, bottom: 16),
                    decoration: BoxDecoration(
                      color: WayfareColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                ...children,
              ],
            ),
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

/// Moving an activity to another day.
///
/// A sheet rather than a drag: the Trip tab shows one day at a time, so there
/// is nowhere to drag *to*. The confirm button restates the destination, since
/// by then the day you came from is off screen.
class MoveActivitySheet extends StatefulWidget {
  const MoveActivitySheet({
    super.key,
    required this.block,
    required this.fromDay,
    required this.days,
    required this.onMove,
    required this.onCancel,
  });

  final PlanBlock block;
  final int fromDay;

  /// Every day in the trip, with how full it currently is.
  final List<({int day, String? date, int blockCount})> days;

  final void Function(int day, TimeOfDay slot) onMove;
  final VoidCallback onCancel;

  @override
  State<MoveActivitySheet> createState() => _MoveActivitySheetState();
}

class _MoveActivitySheetState extends State<MoveActivitySheet> {
  int? _day;
  late TimeOfDay _slot;

  @override
  void initState() {
    super.initState();
    _slot = widget.block.timeOfDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final candidates =
        widget.days.where((d) => d.day != widget.fromDay).toList();

    return SheetFrame(
      children: [
        Text('Move this activity', style: WayfareType.display(22)),
        const SizedBox(height: 6),
        Text(
          widget.block.activity,
          style: WayfareType.body(13.5, color: WayfareColors.subhead),
        ),
        const SizedBox(height: 16),
        if (candidates.isEmpty)
          Text(
            'This trip only has the one day, so there is nowhere to move it to.',
            style: WayfareType.body(13.5, color: WayfareColors.mutedLight),
          )
        else ...[
          for (final candidate in candidates) ...[
            _DayRow(
              day: candidate.day,
              date: candidate.date,
              blockCount: candidate.blockCount,
              selected: _day == candidate.day,
              onTap: () => setState(() => _day = candidate.day),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: const WayfareEyebrow('Part of the day', size: 10.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in const [
                TimeOfDay.morning,
                TimeOfDay.afternoon,
                TimeOfDay.evening,
                TimeOfDay.anytime,
              ])
                WayfareSelectChip(
                  label: _slotLabel(slot),
                  selected: _slot == slot,
                  onTap: () => setState(() => _slot = slot),
                ),
            ],
          ),
          const SizedBox(height: 18),
          WayfarePrimaryButton(
            label: _day == null
                ? 'Pick a day'
                : 'Move to day $_day, ${_slotLabel(_slot).toLowerCase()}',
            onPressed: _day == null ? null : () => widget.onMove(_day!, _slot),
            minHeight: WayfareTouch.sheetCta,
          ),
        ],
        const SizedBox(height: 10),
        WayfareSecondaryButton(
          // Names what staying means rather than saying "Cancel", which would
          // leave the user to work out what the default was.
          label: 'Leave it on day ${widget.fromDay}',
          onPressed: widget.onCancel,
          background: Colors.transparent,
          foreground: WayfareColors.muted,
          fontSize: 13.5,
        ),
        SizedBox(height: theme.isAndroid ? 4 : 0),
      ],
    );
  }

  static String _slotLabel(TimeOfDay slot) => switch (slot) {
        TimeOfDay.morning => 'Morning',
        TimeOfDay.afternoon => 'Afternoon',
        TimeOfDay.evening => 'Evening',
        TimeOfDay.anytime => 'Anytime',
      };
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.date,
    required this.blockCount,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final String? date;
  final int blockCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final empty = blockCount == 0;

    return Material(
      color: selected ? WayfareColors.surfaceAlt : Colors.transparent,
      borderRadius: theme.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.card,
        child: Container(
          constraints: const BoxConstraints(minHeight: WayfareTouch.input),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: theme.card,
            border: Border.all(
              color: selected ? WayfareColors.ink : WayfareColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day $day',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if ((date ?? '').isNotEmpty)
                      Text(
                        formatShortDate(date),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: WayfareColors.mutedLight,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                empty
                    ? 'Empty'
                    : '$blockCount ${blockCount == 1 ? 'activity' : 'activities'}',
                style: TextStyle(
                  fontSize: 12.5,
                  color:
                      empty ? WayfareColors.accent : WayfareColors.mutedLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
