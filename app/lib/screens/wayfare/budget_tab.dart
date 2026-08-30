import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';
import '../../state/wayfare_controller.dart';
import 'formatting.dart';

/// Budget tab: status hero, then planned-vs-estimated bars per category.
class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key, required this.controller});

  final WayfareController controller;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan!;
    final trip = plan.trip;
    final memberCount = controller.members.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusHero(trip: trip, memberCount: memberCount),
          const SizedBox(height: WayfareSpace.sectionGap),
          _ByCategory(trip: trip),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.trip, required this.memberCount});

  final TripSummary trip;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final over = trip.overBudget;
    final budget = trip.totalBudget ?? 0;
    final estimated = trip.estimatedTotalCost;
    final diff = (estimated - budget).abs();
    final currency = trip.currency;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: over ? WayfareColors.overBg : WayfareColors.successBgAlt,
        borderRadius: theme.cardLg,
        border: Border.all(
          color: over ? WayfareColors.overBorder : WayfareColors.successBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WayfareEyebrow(over ? 'Over budget' : 'Under budget'),
          const SizedBox(height: 8),
          Text(
            over
                ? '${formatMoney(diff, currency)} over'
                : '${formatMoney(diff, currency)} to spare',
            style: WayfareType.display(40, height: 1.05),
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? 'Accommodation and activities pushed it. Dropping a couple of optional stops covers the gap.'
                : 'Comfortably inside the budget, with the buffer intact.',
            style: WayfareType.body(13.5, color: WayfareColors.inkSecondary),
          ),
          const SizedBox(height: 16),
          WayfareBar(
            // Capped at 100% — the bar shows how much of the budget is spoken
            // for, and the overspend is stated in the headline instead.
            fraction: budget > 0 ? estimated / budget : 0,
            fill: over ? WayfareColors.accent : WayfareColors.success,
            track: Colors.white.withValues(alpha: 0.65),
            height: 12,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${formatMoney(estimated, currency)} estimated',
                style: const TextStyle(fontSize: 12.5, color: WayfareColors.muted),
              ),
              const Spacer(),
              Text(
                '${formatMoney(budget, currency)} budget',
                style: const TextStyle(fontSize: 12.5, color: WayfareColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x14000000)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Per person',
                style: TextStyle(fontSize: 14, color: WayfareColors.muted),
              ),
              const Spacer(),
              Text(
                memberCount > 0
                    ? '${formatMoney(estimated / memberCount, currency)} each'
                    : '—',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ByCategory extends StatelessWidget {
  const _ByCategory({required this.trip});

  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    final categories = trip.budgetBreakdown.categories;
    // Every bar is a fraction of the largest single figure across all
    // categories, so the rows stay visually comparable.
    final peak = trip.budgetBreakdown.peak;

    return WayfareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WayfareEyebrow('By category'),
          const SizedBox(height: 16),
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: 15),
            _CategoryRow(
              category: categories[i],
              peak: peak,
              currency: trip.currency,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.peak,
    required this.currency,
  });

  final CategoryBudget category;
  final num peak;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final over = category.isOver;
    final barColor = over ? WayfareColors.accent : WayfareColors.success;

    final deltaLabel = category.isOnPlan
        ? 'on plan'
        : '${over ? '+' : '−'}${formatMoney(category.delta.abs(), currency)}';
    final deltaColor = category.isOnPlan
        ? WayfareColors.mutedLight
        : over
            ? WayfareColors.overBudget
            : const Color(0xFF4B6B46);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _capitalize(categoryLabel(category.name)),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              deltaLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: deltaColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        WayfareBar(
          fraction: peak > 0 ? category.planned / peak : 0,
          fill: WayfareColors.barPlanned,
          track: WayfareColors.barTrack,
        ),
        const SizedBox(height: 4),
        WayfareBar(
          fraction: peak > 0 ? category.estimated / peak : 0,
          fill: barColor,
          track: WayfareColors.barTrack,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'planned ${formatMoney(category.planned, currency)}',
              style: const TextStyle(
                fontSize: 11.5,
                color: WayfareColors.mutedLight,
              ),
            ),
            const Spacer(),
            Text(
              'est. ${formatMoney(category.estimated, currency)}',
              style: const TextStyle(
                fontSize: 11.5,
                color: WayfareColors.mutedLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
