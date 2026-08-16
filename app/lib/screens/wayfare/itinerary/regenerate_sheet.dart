import 'package:flutter/material.dart' hide TimeOfDay;

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/flight.dart';
import '../../../models/plan.dart';
import '../formatting.dart';
import 'activity_sheets.dart';

/// What regenerating will actually do, before it does it.
///
/// Once hand-written work exists, `↻` stops meaning "replan" and starts
/// meaning "tell me what replanning costs". The two paths are genuinely
/// different outcomes, so both are named: one keeps what you wrote, the other
/// says in its own label that it replaces it.
class RegenerateSheet extends StatelessWidget {
  const RegenerateSheet({
    super.key,
    required this.summary,
    required this.currency,
    required this.onKeepMine,
    required this.onReplaceEverything,
    required this.onUnpin,
    required this.onCancel,
  });

  final PinnedSummary summary;
  final String currency;

  /// Replan, honouring the pins.
  final VoidCallback onKeepMine;

  /// Replan everything, losing them. One-way, and labelled as such.
  final VoidCallback onReplaceEverything;

  /// Hand one activity back to the planner without deleting it.
  final ValueChanged<String> onUnpin;

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final count = summary.pinned.length;
    final kept = summary.keptDays;

    return SheetFrame(
      children: [
        Text('Plan these days again?', style: WayfareType.display(22)),
        const SizedBox(height: 8),
        Text(
          count == 0
              ? 'Nothing here is yours, so the planner will rebuild every day.'
              : 'You have written $count '
                  '${count == 1 ? 'activity' : 'activities'}. The planner works '
                  'around ${count == 1 ? 'it' : 'them'} unless you say otherwise.',
          style: WayfareType.body(13.5, color: WayfareColors.subhead),
        ),
        const SizedBox(height: 16),
        FactRows(
          rows: [
            (
              label: 'Kept',
              value: count == 0
                  ? 'Nothing'
                  : '$count ${count == 1 ? 'activity' : 'activities'}'
                      '${kept.isEmpty ? '' : ' on ${_dayList(kept)}'}',
              color: count == 0
                  ? WayfareColors.mutedLight
                  : WayfareColors.liveFareInk,
            ),
            (
              label: 'Replanned',
              value: summary.replanDays.isEmpty
                  ? 'The rest of every day'
                  : _dayList(summary.replanDays),
              color: WayfareColors.ink,
            ),
            (
              label: 'Already committed',
              value: summary.committedCost == 0
                  ? 'Nothing yet'
                  : '${formatMoney(summary.committedCost, currency)} pp',
              color: WayfareColors.ink,
            ),
          ],
        ),
        if (summary.hasPinned) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: const WayfareEyebrow(
              'Yours, kept',
              color: WayfareColors.writtenInkDeep,
              size: 10.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final pinned in summary.pinned) ...[
            _PinnedRow(pinned: pinned, onUnpin: () => onUnpin(pinned.id)),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 12),
        // Only offered because the backend genuinely honours pins. If it ever
        // stops, this button must not appear — a promise the planner cannot
        // keep is worse than no option at all.
        if (summary.honoursPinned)
          WayfarePrimaryButton(
            label: summary.hasPinned
                ? 'Replan around what I wrote'
                : 'Plan it again',
            onPressed: onKeepMine,
            minHeight: WayfareTouch.sheetCta,
          ),
        if (summary.hasPinned) ...[
          const SizedBox(height: 10),
          WayfareSecondaryButton(
            // The cost is in the label, not behind it.
            label: 'Replan everything — replaces your '
                '${_spell(count)} ${count == 1 ? 'activity' : 'activities'}',
            onPressed: onReplaceEverything,
            minHeight: WayfareTouch.input,
            fontSize: 13.5,
            foreground: WayfareColors.destructiveInk,
          ),
        ],
        const SizedBox(height: 10),
        WayfareSecondaryButton(
          label: 'Leave the plan as it is',
          onPressed: onCancel,
          background: Colors.transparent,
          foreground: WayfareColors.muted,
          fontSize: 13.5,
        ),
      ],
    );
  }

  static String _dayList(List<int> days) {
    if (days.isEmpty) return 'nothing';
    if (days.length == 1) return 'day ${days.first}';
    final all = days.map((d) => '$d').toList();
    return 'days ${all.sublist(0, all.length - 1).join(', ')} and ${all.last}';
  }

  static String _spell(int n) => switch (n) {
        1 => 'one',
        2 => 'two',
        3 => 'three',
        4 => 'four',
        5 => 'five',
        _ => '$n',
      };
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.pinned, required this.onUnpin});

  final PinnedActivity pinned;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: WayfareColors.writtenBg,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.writtenBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pinned.activity,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Day ${pinned.day} · ${pinned.timeOfDay.name}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WayfareColors.mutedLight,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUnpin,
            child: const Text(
              'Unpin',
              style: TextStyle(fontSize: 13, color: WayfareColors.writtenInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why a day cannot simply be added.
///
/// The flight envelope is the single source of truth for how long a trip is.
/// Letting a day exist outside it would give two answers to "how long is this
/// trip", and the short-day logic depends on there being one.
class DayCountSheet extends StatelessWidget {
  const DayCountSheet({
    super.key,
    required this.envelope,
    required this.dayCount,
    required this.onChangeFlights,
    required this.onKeep,
  });

  final DateEnvelope? envelope;
  final int dayCount;
  final VoidCallback onChangeFlights;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return SheetFrame(
      children: [
        Text('Adding or removing a day', style: WayfareType.display(22)),
        const SizedBox(height: 8),
        Text(
          'Your days come from your flights, so this trip is as long as the '
          'time between them. Changing the number of days means changing those '
          'dates.',
          style: WayfareType.body(13.5, color: WayfareColors.subhead),
        ),
        const SizedBox(height: 16),
        if (envelope != null)
          FactRows(
            rows: [
              (
                label: 'Trip starts',
                value: [
                  formatShortDate(envelope!.startDate),
                  if (envelope!.arrivalLocalTime != null)
                    envelope!.arrivalLocalTime!,
                ].join(' · '),
                color: WayfareColors.ink,
              ),
              (
                label: 'Trip ends',
                value: [
                  formatShortDate(envelope!.endDate),
                  if (envelope!.departureLocalTime != null)
                    envelope!.departureLocalTime!,
                ].join(' · '),
                color: WayfareColors.ink,
              ),
              (
                label: 'Planning days',
                value: envelope!.planningDaysLabel,
                color: WayfareColors.ink,
              ),
            ],
          )
        else
          FactRows(
            rows: [
              (
                label: 'Planning days',
                value: '$dayCount',
                color: WayfareColors.ink,
              ),
            ],
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: WayfareColors.amberSurface,
            borderRadius: theme.card,
            border: Border.all(color: WayfareColors.amberBorder, width: 1.5),
          ),
          child: Text(
            'A later return means a new fare to choose. Anything already '
            'planned on days 1–$dayCount stays; a new day '
            '${dayCount + 1} arrives empty.',
            style: WayfareType.body(13, color: WayfareColors.amberInk),
          ),
        ),
        const SizedBox(height: 16),
        WayfarePrimaryButton(
          label: 'Change the flight dates',
          onPressed: onChangeFlights,
          minHeight: WayfareTouch.sheetCta,
        ),
        const SizedBox(height: 10),
        WayfareSecondaryButton(
          label: 'Keep the $dayCount days',
          onPressed: onKeep,
          background: Colors.transparent,
          foreground: WayfareColors.muted,
          fontSize: 13.5,
        ),
      ],
    );
  }
}
