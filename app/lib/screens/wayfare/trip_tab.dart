import 'package:flutter/material.dart' hide TimeOfDay;

import '../../design/features.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';
import '../../models/flight.dart';
import '../../models/trip.dart';
import '../../state/wayfare_controller.dart';
import 'formatting.dart';
import 'itinerary/day_editing.dart';

/// Trip tab: one day at a time behind a horizontal day-chip scroller.
class TripTab extends StatelessWidget {
  const TripTab({
    super.key,
    required this.controller,
    required this.onAddActivity,
    required this.onEditActivity,
    required this.onRemoveActivity,
  });

  final WayfareController controller;

  /// Opens the add sheet for one slot on the selected day.
  final void Function(TimeOfDay slot) onAddActivity;
  final ValueChanged<PlanBlock> onEditActivity;
  final ValueChanged<PlanBlock> onRemoveActivity;

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
        // The day's content enters from the side you came from, so moving
        // through the trip reads as movement rather than as a redraw.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: AnimatedSize(
            // Days differ in height, and without this the page below them
            // jumps the instant the new day is laid out.
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            // The outgoing day leaves in the first third. Fading both across
            // the full duration muddies the middle, where two days are drawn
            // on top of each other at half opacity.
            switchOutCurve: const Interval(0, 0.35, curve: Curves.easeIn),
            // Top-aligned: the default centres the two children on each other,
            // so a short day and a long one slide vertically past each other
            // as well as sideways.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(controller.selectedDay);
              final from = controller.dayDirection == 0
                  ? 0.0
                  : controller.dayDirection * (incoming ? 0.06 : -0.06);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(from, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey(controller.selectedDay),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.updatedDay == day.day) _updatedNotice(theme),
                if (controller.dateEnvelope?.shortDayFor(day.day) case final short?)
                  ShortDayBand(
                    short: short,
                    flightLabel: controller.flightLabelFor(short),
                  ),
                _dayMeta(day, currency),
                const SizedBox(height: 10),
                if (controller.dayIsEmpty(day))
                  EmptyDayCard(
                    day: day.day.toInt(),
                    otherPlannedDays: controller.plan!.itinerary
                        .where((d) => d.day != day.day && d.blocks.isNotEmpty)
                        .length,
                    onAddFirst: () => onAddActivity(TimeOfDay.morning),
                    onAskPlanner: controller.canGenerate
                        ? () => controller.send(
                              'Fill in day ${day.day} — the rest of the trip '
                              'is planned, that day is empty.',
                            )
                        : null,
                  )
                else
                  ..._slotGroups(currency),
                if (!controller.dayIsEmpty(day))
                  for (final slot in controller.openSlots) ...[
                    AddSlotRow(slot: slot, onAdd: () => onAddActivity(slot)),
                    const SizedBox(height: WayfareSpace.cardGap),
                  ],
                const SizedBox(height: 2),
                // Adding lives in the header's `+`. Down here it sat below
                // everything already planned, so it drifted further out of
                // reach the more there was on the day.
                if (day.blocks.any((b) => b.optional)) ...[
                  // Only offered when there is something optional to hide;
                  // otherwise it is a control that does nothing.
                  WayfareSecondaryButton(
                    label: controller.showOptional
                        ? 'Hide optional activities'
                        : 'Show optional activities',
                    onPressed: controller.toggleOptional,
                    fontSize: 13.5,
                    foreground: WayfareColors.inkSecondary,
                    background: WayfareColors.surface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
            ),
          ),
        ),
      ],
    );
  }

  /// The day's activities, grouped by slot.
  ///
  /// Order inside a slot is the start time's to decide, not the finger's:
  /// hand-dragging is out for now, and a card is moved by giving it a time.
  /// Tapping opens it; swiping left reveals edit and delete.
  List<Widget> _slotGroups(String currency) {
    final blocks = controller.visibleBlocks;

    const order = [
      TimeOfDay.morning,
      TimeOfDay.afternoon,
      TimeOfDay.evening,
      TimeOfDay.anytime,
    ];

    return [
      for (final slot in order)
        if (blocks.any((b) => b.timeOfDay == slot))
          _SlotGroup(
            key: ValueKey('slot-${controller.selectedDay}-${slot.name}'),
            blocks: blocks.where((b) => b.timeOfDay == slot).toList(),
            members: controller.members,
            currency: currency,
            onEdit: onEditActivity,
            onRemove: onRemoveActivity,
          ),
    ];
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
              // Deliberately not the amber dot: a shortened day is a
              // constraint, an unfilled one is a to-do.
              isUnfilled: controller.dayIsEmpty(day),
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
    // An empty day has no cost worth stating, so the figure says how much of
    // it is written instead.
    final right = controller.dayIsEmpty(day)
        ? '${controller.slotsFilledOn(day)} of 3 slots filled'
        : '${formatMoney(cost, currency)} pp planned';

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
          right,
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
    this.isUnfilled = false,
  });

  final String label;
  final String sub;
  final bool selected;
  final double radius;
  final bool isShort;
  final bool isUnfilled;
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

    if (!isShort && !isUnfilled) return chip;

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
            decoration: BoxDecoration(
              // Solid amber = shortened by a flight. Hollow terracotta ring =
              // you have not written it yet. Two different meanings, so never
              // the same mark.
              color: isShort ? WayfareColors.morning : Colors.transparent,
              shape: BoxShape.circle,
              border: isShort
                  ? null
                  : Border.all(color: WayfareColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// One slot's activities, reorderable among themselves.
class _SlotGroup extends StatelessWidget {
  const _SlotGroup({
    super.key,
    required this.blocks,
    required this.members,
    required this.currency,
    required this.onEdit,
    required this.onRemove,
  });

  final List<PlanBlock> blocks;
  final List<Member> members;
  final String currency;
  final ValueChanged<PlanBlock> onEdit;
  final ValueChanged<PlanBlock> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final block in blocks)
          Padding(
            key: ValueKey(block.id),
            padding: const EdgeInsets.only(bottom: WayfareSpace.cardGap),
            child: SwipeableActivity(
              onEdit: () => onEdit(block),
              onDelete: () => onRemove(block),
              child: GestureDetector(
                onTap: () => onEdit(block),
                child: ActivityCard(
                  block: block,
                  members: members,
                  currency: currency,
                ),
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

  bool get _hasFooter =>
      members.isNotEmpty ||
      (block.estimatedDurationMinutes ?? 0) > 0 ||
      _venue.isNotEmpty;

  /// The venue, unless it is the title again.
  ///
  /// A cited place with no street address stores its own name as the venue, so
  /// the footer printed the card's heading back at it word for word.
  String get _venue {
    final venue = block.location.trim();
    return venue.toLowerCase() == block.activity.trim().toLowerCase()
        ? ''
        : venue;
  }

  /// The description, unless it says nothing the title has not.
  ///
  /// The extractor writes a generic line for most places — "Recommended
  /// shopping mall." under a card already headed Pavilion Bukit Bintang — and
  /// a sentence that adds nothing costs a line on every card in the day.
  String get _description {
    final text = block.description.trim();
    if (text.isEmpty) return '';
    final stripped = text.toLowerCase().replaceAll(RegExp(r'[.\s]+$'), '');
    return _generic.hasMatch(stripped) ? '' : text;
  }

  static final _generic = RegExp(
    r'^(a )?(recommended|must-visit|popular|suggested)\b[^.]*$',
  );

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    // Who an activity suits is a group fact; on a solo trip the footer falls
    // back to duration and place.
    final fit = WayfareFeatures.groups
        ? block.suitedForMembers
            .map((id) => members.indexWhere((m) => m.id == id))
            .where((i) => i >= 0)
            .toList()
        : const <int>[];

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
          // A hand-written activity often has no description, and an empty
          // Text still claims a line — which left a hollow gap in the middle
          // of every card typed in a hurry.
          if (_description.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              _description,
              style: WayfareType.body(13.5, color: WayfareColors.muted),
            ),
          ],
          if (_hasFooter) ...[
            const SizedBox(height: 11),
            _footer(fit),
          ],
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
        // A stated time prints ahead of the slot label; without one the
        // activity simply sits in its part of the day.
        if (block.startTime != null) ...[
          Text(
            formatClock(block.startTime!),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: WayfareColors.ink,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          block.timeOfDay.name.toUpperCase(),
          style: WayfareType.eyebrow(11.5, color: const Color(0xFF6D6255)),
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
        if (WayfareFeatures.groups && block.isMine) WayfarePill.yours(),
        // Provenance, reduced to a mark. The named source took a whole line
        // on every card; this keeps the fact that an activity came from
        // something the traveller saved without spending a row on it. The
        // source is named in full on the activity itself.
        if (block.isFromReference)
          Semantics(
            label: block.fromSourceTitle == null
                ? 'From a place you saved'
                : 'From your link: ${block.fromSourceTitle}',
            child: const Icon(
              Icons.link,
              size: 14,
              color: WayfareColors.accent,
            ),
          ),
      ],
    );
  }

  /// Footer line.
  ///
  /// With no group to show, the avatar row has nothing to say, so the design
  /// gives the row to `duration · venue` instead. When group planning returns
  /// the avatars take it back.
  Widget _footer(List<int> memberIndexes) {
    if (members.isEmpty) {
      final parts = [
        if (block.estimatedDurationMinutes != null &&
            block.estimatedDurationMinutes! > 0)
          formatDuration(block.estimatedDurationMinutes!),
        if (_venue.isNotEmpty) _venue,
      ];
      // Both blank is a legitimate one-line activity, so the row goes entirely
      // rather than leaving a gap where a fact should be.
      if (parts.isEmpty) return const SizedBox.shrink();
      return Text(
        parts.join(' · '),
        style: const TextStyle(fontSize: 12.5, color: WayfareColors.mutedLight),
      );
    }
    return _fitRow(memberIndexes);
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
class ShortDayBand extends StatefulWidget {
  const ShortDayBand({
    super.key,
    required this.short,
    this.flightLabel,
  });

  final ShortDay short;
  final String? flightLabel;

  @override
  State<ShortDayBand> createState() => _ShortDayBandState();
}

class _ShortDayBandState extends State<ShortDayBand> {
  /// Collapsed by default. The headline is the whole finding — which day is
  /// short and from when — and the explanation underneath is worth reading
  /// once, not on every scroll past it.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final short = widget.short;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        expanded: _open,
        child: Material(
          color: WayfareColors.amberSurface,
          // The border belongs to the Material, not to a child inside it —
          // on the child, the amber fill spilled past the outline.
          shape: RoundedRectangleBorder(
            borderRadius: theme.cardLg,
            side: const BorderSide(
              color: WayfareColors.amberBorder,
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WayfareEyebrow(
                              ['Short day', ?widget.flightLabel].join(' · '),
                              color: WayfareColors.amberInkDeep,
                              size: 11.5,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _headline(),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                color: WayfareColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: _duration,
                        curve: _curve,
                        child: const Icon(
                          Icons.expand_more,
                          size: 20,
                          color: WayfareColors.amberInkDeep,
                        ),
                      ),
                    ],
                  ),
                  // Grows from the top edge and fades in as it goes, so the
                  // cards below are pushed rather than jumped.
                  ClipRect(
                    child: AnimatedAlign(
                      alignment: Alignment.topLeft,
                      heightFactor: _open ? 1 : 0,
                      duration: _duration,
                      curve: _curve,
                      child: AnimatedOpacity(
                        opacity: _open ? 1 : 0,
                        duration: _duration,
                        curve: _curve,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, right: 4),
                          child: Text(
                            '${short.note} The planner left the rest out '
                            'rather than pretending it exists.',
                            style: WayfareType.body(
                              13.5,
                              color: WayfareColors.amberInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _duration = Duration(milliseconds: 240);
  static const _curve = Curves.easeOutCubic;

  String _headline() {
    final short = widget.short;
    if (short.isWriteOff) {
      return 'Day ${short.day} has no usable time.';
    }
    return short.reason == 'late_arrival'
        ? 'Day ${short.day} runs from ${formatClock(short.at)}, not the morning.'
        : 'Day ${short.day} ends at ${formatClock(short.at)}.';
  }
}
