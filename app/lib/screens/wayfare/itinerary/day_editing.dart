import 'package:flutter/material.dart' hide TimeOfDay;

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/plan.dart';
import '../formatting.dart';

/// The bar that says a day is live.
///
/// Edit mode is per-day and announced, because the alternative — cards that
/// are always tappable — makes reading a plan feel risky. Nothing about the
/// card changes; only what surrounds it.
class DayEditingBar extends StatelessWidget {
  const DayEditingBar({super.key, required this.day, required this.onDone});

  final int day;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: WayfareColors.ink,
        borderRadius: theme.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Editing day $day — tap an activity to change it',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: WayfareColors.generatingInk,
              ),
            ),
          ),
          TextButton(
            onPressed: onDone,
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WayfareColors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one-line composer: the fastest way to get a list of things down.
///
/// Six activities is six taps and no sheet. Anything else about them can be
/// filled in later by tapping the card, which is why a title-only activity has
/// to render as a complete card rather than a stub.
class QuickAddComposer extends StatelessWidget {
  const QuickAddComposer({
    super.key,
    required this.controller,
    required this.slot,
    required this.value,
    required this.onChanged,
    required this.onSubmit,
    required this.onOpenFullSheet,
  });

  final TextEditingController controller;

  /// Where a quick-added activity lands — the slot currently being looked at.
  final TimeOfDay slot;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onOpenFullSheet;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final ready = value.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WayfareColors.surface,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: WayfareTextField(
                  controller: controller,
                  hint: 'Type an activity…',
                  onChanged: onChanged,
                  onSubmitted: (_) => ready ? onSubmit() : null,
                ),
              ),
              const SizedBox(width: 10),
              Opacity(
                opacity: ready ? 1 : 0.45,
                child: WayfarePrimaryButton(
                  label: 'Add',
                  onPressed: ready ? onSubmit : null,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Lands in the ${_slotLabel(slot)} you are looking at. Tap it '
            'afterwards to add a time, venue or cost.',
            style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
          ),
          const SizedBox(height: 12),
          WayfareSecondaryButton(
            label: 'Add with time, venue and cost',
            onPressed: onOpenFullSheet,
            minHeight: WayfareTouch.ios,
            fontSize: 13.5,
            foreground: WayfareColors.inkSecondary,
          ),
        ],
      ),
    );
  }

  static String _slotLabel(TimeOfDay slot) => switch (slot) {
        TimeOfDay.morning => 'morning',
        TimeOfDay.afternoon => 'afternoon',
        TimeOfDay.evening => 'evening',
        TimeOfDay.anytime => 'part of the day',
      };
}

/// A dashed row standing in for a slot with nothing in it, in edit mode.
class AddSlotRow extends StatelessWidget {
  const AddSlotRow({super.key, required this.slot, required this.onAdd});

  final TimeOfDay slot;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return CustomPaint(
      painter: DashedBorderPainter(
        color: WayfareColors.todoDashed,
        radius: theme.radius,
        strokeWidth: 1.5,
      ),
      child: Material(
        color: WayfareColors.surface.withValues(alpha: 0.5),
        borderRadius: theme.card,
        child: InkWell(
          onTap: onAdd,
          borderRadius: theme.card,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                // Hollow, because the slot is empty — the solid dot means
                // something is actually there.
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: timeOfDayColor(slot), width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _label(slot),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: WayfareColors.mutedLight,
                    ),
                  ),
                ),
                const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WayfareColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(TimeOfDay slot) => switch (slot) {
        TimeOfDay.morning => 'Morning',
        TimeOfDay.afternoon => 'Afternoon',
        TimeOfDay.evening => 'Evening',
        TimeOfDay.anytime => 'Anytime',
      };
}

/// A day with nothing on it, in a trip where other days are planned.
///
/// Neutral rather than amber: this is a to-do, not the flight leaving no time.
/// The two must never look alike.
class EmptyDayCard extends StatelessWidget {
  const EmptyDayCard({
    super.key,
    required this.day,
    required this.otherPlannedDays,
    required this.onAddFirst,
    required this.onAskPlanner,
  });

  final int day;
  final int otherPlannedDays;
  final VoidCallback onAddFirst;
  final VoidCallback? onAskPlanner;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return CustomPaint(
      painter: DashedBorderPainter(
        color: WayfareColors.todoDashed,
        radius: theme.radiusLg,
        strokeWidth: 1.5,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        decoration: BoxDecoration(
          color: WayfareColors.todoBg,
          borderRadius: theme.cardLg,
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: WayfareColors.placeholderTile,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Day $day is empty',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                otherPlannedDays > 0
                    ? 'You have not filled this one in yet. The other '
                        '$otherPlannedDays ${otherPlannedDays == 1 ? 'day is' : 'days are'} planned.'
                    : 'You have not filled this one in yet.',
                textAlign: TextAlign.center,
                style: WayfareType.body(13.5, color: WayfareColors.subhead),
              ),
            ),
            const SizedBox(height: 18),
            WayfarePrimaryButton(
              label: 'Add the first activity',
              onPressed: onAddFirst,
              fontSize: 15,
              weight: FontWeight.w500,
            ),
            if (onAskPlanner != null) ...[
              const SizedBox(height: 10),
              WayfareSecondaryButton(
                label: 'Ask the planner to fill day $day',
                onPressed: onAskPlanner,
                background: Colors.transparent,
                foreground: WayfareColors.muted,
                fontSize: 13.5,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reading mode's quiet note that a slot is free.
///
/// A line, not a box: three empty boxes on a half-full day reads as failure
/// rather than as room.
class OpenSlotLine extends StatelessWidget {
  const OpenSlotLine({super.key, required this.slots, required this.onTap});

  final List<TimeOfDay> slots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: WayfareTouch.ios),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '${_list(slots)} open — add something',
            style: const TextStyle(
              fontSize: 13,
              color: WayfareColors.mutedLight,
            ),
          ),
        ),
      ),
    );
  }

  static String _list(List<TimeOfDay> slots) {
    final names = slots.map((s) => 'The ${s.name}').toList();
    if (names.length == 1) return '${names.first} is';
    final joined =
        '${names.sublist(0, names.length - 1).join(', ')} and ${names.last.toLowerCase()}';
    return '$joined are';
  }
}

/// An activity card you can swipe left to act on.
///
/// Reading stays risk-free — nothing happens on a tap or a scroll — but the
/// two things people do most often are one gesture away instead of behind a
/// mode. Edit mode still exists for reordering and moving between days, which
/// a swipe cannot express.
class SwipeableActivity extends StatelessWidget {
  const SwipeableActivity({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return ClipRRect(
      borderRadius: theme.card,
      child: Slidable(
        endActions: [
          _SlidableAction(
            label: 'Edit',
            icon: Icons.edit_outlined,
            background: WayfareColors.writtenBg,
            foreground: WayfareColors.writtenInk,
            onTap: onEdit,
          ),
          _SlidableAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            background: WayfareColors.overBg,
            foreground: WayfareColors.destructiveInk,
            onTap: onDelete,
          ),
        ],
        child: child,
      ),
    );
  }
}

/// One revealed action. Sized to the tap-target minimum in both dresses.
class _SlidableAction extends StatelessWidget {
  const _SlidableAction({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal swipe-to-reveal, rather than a package for one gesture.
///
/// Deliberately not [Dismissible]: a swipe here reveals a choice, it does not
/// itself delete. Removing an activity goes through the confirmation that
/// names what the day loses, same as everywhere else.
class Slidable extends StatefulWidget {
  const Slidable({super.key, required this.child, required this.endActions});

  final Widget child;
  final List<Widget> endActions;

  @override
  State<Slidable> createState() => _SlidableState();
}

class _SlidableState extends State<Slidable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  double get _actionsWidth => widget.endActions.length * 80.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        _controller.value -= d.primaryDelta! / _actionsWidth;
      },
      onHorizontalDragEnd: (d) {
        // Fling or past halfway opens; anything less springs back, so a
        // stray horizontal scroll never leaves actions hanging out.
        final flung = d.velocity.pixelsPerSecond.dx < -300;
        if (flung || _controller.value > 0.5) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = _controller.value * _actionsWidth;
          return Stack(
            children: [
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final action in widget.endActions)
                      GestureDetector(
                        onTap: _close,
                        behavior: HitTestBehavior.translucent,
                        child: action,
                      ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(-offset, 0),
                child: child,
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// The reorder grip, for moving a card within its own slot.
///
/// Ordering across slots is not the user's to set — the slot decides that — so
/// the grip only ever moves a card among its siblings. Moving to another day
/// is the `⇅` button's job.
///
/// **Two ways to use it, on purpose.** Dragging is the fast one, but a drag is
/// unreachable by keyboard and awkward with a screen reader, so tapping the
/// same grip opens an explicit up/down menu. The handoff's accessibility note
/// requires the second; the first is what most people will actually do.
class ReorderGrip extends StatelessWidget {
  const ReorderGrip({
    super.key,
    required this.index,
    required this.positionLabel,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  /// Index within the slot — what `ReorderableDragStartListener` needs.
  final int index;

  /// e.g. "2 of 3 in the morning", read aloud before the menu opens.
  final String positionLabel;

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final lines = SizedBox(
      width: 28,
      height: WayfareTouch.ios,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            Container(width: 14, height: 1.5, color: WayfareColors.gripLine),
          ],
        ],
      ),
    );

    // A single item has nothing to reorder against, so the grip is shown for
    // alignment but does nothing — an affordance that cannot act is worse than
    // a quiet one.
    if (!canMoveUp && !canMoveDown) {
      return Opacity(opacity: 0.35, child: lines);
    }

    return Semantics(
      button: true,
      label: 'Reorder — $positionLabel',
      child: ReorderableDragStartListener(
        index: index,
        child: PopupMenuButton<int>(
          tooltip: 'Reorder within this part of the day',
          position: PopupMenuPosition.under,
          color: WayfareColors.surface,
          padding: EdgeInsets.zero,
          itemBuilder: (_) => [
            PopupMenuItem(
              value: -1,
              enabled: canMoveUp,
              child: const Text('Move up'),
            ),
            PopupMenuItem(
              value: 1,
              enabled: canMoveDown,
              child: const Text('Move down'),
            ),
          ],
          onSelected: (delta) => delta < 0 ? onMoveUp() : onMoveDown(),
          child: lines,
        ),
      ),
    );
  }
}

/// Flutter has no dashed border, so it is painted. Shared by the empty-day
/// card, the add rows and the optional-activity card.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

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
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
