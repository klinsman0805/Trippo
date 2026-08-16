import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';
import '../../models/flight.dart';
import '../../models/trip.dart';
import '../../state/wayfare_controller.dart';
import 'formatting.dart';

/// Trip tab: one day at a time behind a horizontal day-chip scroller.
class TripTab extends StatelessWidget {
  const TripTab({super.key, required this.controller});

  final WayfareController controller;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final plan = controller.plan!;
    final day = controller.currentDay;
    if (day == null) return const SizedBox.shrink();

    final currency = plan.trip.currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dayChips(context, plan),
        // wp-slide: content re-enters when the day changes.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.035, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(controller.selectedDay),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.updatedDay == day.day) _updatedNotice(theme),
                if (controller.dateEnvelope?.shortDayFor(day.day) case final short?)
                  ShortDayBand(
                    short: short,
                    flightLabel: controller.flightLabel,
                    onSeeOtherFlights: controller.onSeeOtherFlights,
                  ),
                _dayMeta(day, currency),
                const SizedBox(height: 10),
                for (final block in controller.visibleBlocks) ...[
                  ActivityCard(
                    block: block,
                    members: controller.members,
                    currency: currency,
                  ),
                  const SizedBox(height: WayfareSpace.cardGap),
                ],
                // A short day says why it is short rather than being padded.
                if (controller.dateEnvelope?.shortDayFor(day.day) case final short?)
                  _EmptySlotRow(short: short),
                const SizedBox(height: 2),
                WayfareSecondaryButton(
                  label: controller.showOptional
                      ? 'Hide optional activities'
                      : 'Show optional activities',
                  onPressed: controller.toggleOptional,
                  fontSize: 13.5,
                  foreground: WayfareColors.inkSecondary,
                  background: WayfareColors.surface.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayChips(BuildContext context, Plan plan) {
    final theme = WayfareTheme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final day in plan.itinerary) ...[
            _DayChip(
              label: 'Day ${day.day}',
              sub: formatShortDate(day.date),
              selected: day.day == controller.selectedDay,
              radius: theme.chipRadius,
              // Marks a day the flights cut short, so it reads as deliberate
              // rather than as a day the planner forgot to fill.
              isShort: controller.dateEnvelope?.shortDayFor(day.day) != null,
              onTap: () => controller.selectDay(day.day.toInt()),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _updatedNotice(WayfareTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: WayfareColors.infoBgAlt,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.infoBorderAlt),
      ),
      child: const Text(
        'Updated from your last chat request.',
        style: TextStyle(
          fontSize: 13,
          color: WayfareColors.infoText,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _dayMeta(PlanDay day, String currency) {
    final cost = day.costPerPerson(includeOptional: controller.showOptional);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            day.location,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${formatMoney(cost, currency)} pp planned',
          style: const TextStyle(fontSize: 12.5, color: WayfareColors.mutedLight),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.radius,
    required this.onTap,
    this.isShort = false,
  });

  final String label;
  final String sub;
  final bool selected;
  final double radius;
  final bool isShort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final chip = Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? WayfareColors.ink
            : WayfareColors.surface.withValues(alpha: 0.75),
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: selected ? WayfareColors.ink : WayfareColors.borderChip,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: selected
                        ? WayfareColors.surface
                        : WayfareColors.inkSecondary,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: (selected
                            ? WayfareColors.surface
                            : WayfareColors.inkSecondary)
                        .withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isShort) return chip;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        chip,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: WayfareColors.morning, // #d99a3e
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

/// One activity. Required cards are solid; optional ones are dashed with a
/// badge, so the split between "we're doing this" and "if we feel like it"
/// reads at a glance.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.block,
    required this.members,
    required this.currency,
  });

  final PlanBlock block;
  final List<Member> members;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final fit = block.suitedForMembers
        .map((id) => members.indexWhere((m) => m.id == id))
        .where((i) => i >= 0)
        .toList();

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: block.optional
            ? WayfareColors.surface.withValues(alpha: 0.6)
            : WayfareColors.surface,
        borderRadius: theme.card,
        border: block.optional
            ? null // drawn by the dashed painter below
            : Border.all(color: const Color(0xFFEAE0D0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topRow(),
          const SizedBox(height: 8),
          _titleRow(),
          const SizedBox(height: 7),
          Text(
            block.description,
            style: WayfareType.body(13.5, color: WayfareColors.muted),
          ),
          const SizedBox(height: 11),
          _fitRow(fit),
        ],
      ),
    );

    if (!block.optional) return card;

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: WayfareColors.optionalDash,
        radius: theme.radius,
        strokeWidth: 1.5,
      ),
      child: card,
    );
  }

  Widget _topRow() {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: timeOfDayColor(block.timeOfDay),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          block.timeOfDay.name.toUpperCase(),
          style: WayfareType.eyebrow(11.5, color: const Color(0xFF6D6255)),
        ),
        const Spacer(),
        Text(
          formatBlockCost(block.estimatedCostPerPerson, currency),
          style: const TextStyle(fontSize: 12.5, color: WayfareColors.mutedLight),
        ),
      ],
    );
  }

  Widget _titleRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            block.activity,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.28,
            ),
          ),
        ),
        if (block.optional) WayfarePill.optional(),
      ],
    );
  }

  Widget _fitRow(List<int> memberIndexes) {
    final everyone =
        memberIndexes.length >= members.length && members.isNotEmpty;
    final label = everyone
        ? 'Everyone'
        : memberIndexes
            .map((i) => members[i].name.split(' ').first)
            .join(', ');

    return Row(
      children: [
        WayfareAvatarStack(
          avatars: [
            for (final i in memberIndexes)
              (
                initials: initialsOf(members[i].name),
                color: WayfareColors.memberColor(i),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: WayfareColors.mutedLight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Flutter has no dashed border, so the optional card's outline is painted.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  /// Dash and gap lengths, tuned to read as a dashed outline at card scale.
  static const dash = 5.0;
  static const gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}


/// The amber band above a day the flights cut short.
///
/// The planner left those slots out deliberately; this says so, in the day's
/// own context, with a way back to the decision that caused it.
class ShortDayBand extends StatelessWidget {
  const ShortDayBand({
    super.key,
    required this.short,
    this.flightLabel,
    this.onSeeOtherFlights,
  });

  final ShortDay short;
  final String? flightLabel;
  final VoidCallback? onSeeOtherFlights;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WayfareColors.amberSurface,
        borderRadius: theme.cardLg,
        border: Border.all(color: WayfareColors.amberBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WayfareEyebrow(
            ['Short day', ?flightLabel].join(' · '),
            color: WayfareColors.amberInkDeep,
            size: 11.5,
          ),
          const SizedBox(height: 8),
          Text(
            _headline(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: WayfareColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${short.note} The planner left the rest out rather than '
            'pretending it exists.',
            style: WayfareType.body(13.5, color: WayfareColors.amberInk),
          ),
          if (onSeeOtherFlights != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: WayfareSecondaryButton(
                label: 'See other flights',
                onPressed: onSeeOtherFlights,
                minHeight: WayfareTouch.ios,
                fontSize: 13.5,
                foreground: WayfareColors.amberButtonInk,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headline() {
    if (short.isWriteOff) {
      return 'Day ${short.day} has no usable time.';
    }
    return short.reason == 'late_arrival'
        ? 'Day ${short.day} runs from ${short.at}, not the morning.'
        : 'Day ${short.day} ends at ${short.at}.';
  }
}

/// Explicit "nothing else planned" row. The design is emphatic that a short day
/// must never be padded with filler, so the gap is stated instead of hidden.
class _EmptySlotRow extends StatelessWidget {
  const _EmptySlotRow({required this.short});

  final ShortDay short;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0xFFDCD0BC),
        radius: theme.radius,
        strokeWidth: 1.5,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        alignment: Alignment.center,
        child: Text(
          _copy(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: WayfareColors.mutedLight,
          ),
        ),
      ),
    );
  }

  String _copy() {
    if (short.reason == 'late_arrival') {
      return short.usableSlots.length <= 1
          ? 'Nothing else planned. The flight lands too late for anything more than dinner.'
          : 'Nothing else planned. The flight lands too late for a morning.';
    }
    return 'Nothing else planned. The flight leaves too early for anything before it.';
  }
}
