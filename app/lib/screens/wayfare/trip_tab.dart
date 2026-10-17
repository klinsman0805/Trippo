import 'package:flutter/material.dart' hide TimeOfDay;

import '../../design/features.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';
import '../../models/flight.dart';
import '../../models/travel.dart';
import '../../models/trip.dart';
import '../../state/wayfare_controller.dart';
import 'formatting.dart';
import 'itinerary/day_editing.dart';
// `spellOut`, shared with the questions screen so "two guesses" and "TWO
// ANSWERS NEEDED" count the same way.
import 'needs_info.dart';

/// Trip tab: one day at a time, paginated.
///
/// The days are pages rather than a cross-fade. A switcher draws both days at
/// once through the middle of the transition, and no amount of curve tuning
/// hides that — two overlapping itineraries is a rendering artefact, not a
/// movement. Pages never overlap: one slides out as the next slides in, they
/// stay opaque throughout, and the gesture that does it is the one people
/// already try, which is swiping sideways.
class TripTab extends StatefulWidget {
  const TripTab({
    super.key,
    required this.controller,
    required this.onAddActivity,
    required this.onEditActivity,
    required this.onRemoveActivity,
    required this.onAnswerQuestions,
    this.onOpenMap,
  });

  final WayfareController controller;

  /// Opens the add sheet for one slot on the selected day.
  final void Function(TimeOfDay slot) onAddActivity;
  final ValueChanged<PlanBlock> onEditActivity;
  final ValueChanged<PlanBlock> onRemoveActivity;

  /// Opens the planner's outstanding questions from the band above the days.
  final VoidCallback onAnswerQuestions;

  /// Opens the selected day on a map. Null hides the way in.
  final VoidCallback? onOpenMap;

  @override
  State<TripTab> createState() => _TripTabState();
}

class _TripTabState extends State<TripTab> {
  late final PageController _pages = PageController(
    initialPage: _indexOfSelected,
  );

  WayfareController get controller => widget.controller;
  void Function(TimeOfDay) get onAddActivity => widget.onAddActivity;
  ValueChanged<PlanBlock> get onEditActivity => widget.onEditActivity;
  ValueChanged<PlanBlock> get onRemoveActivity => widget.onRemoveActivity;
  VoidCallback get onAnswerQuestions => widget.onAnswerQuestions;

  int get _indexOfSelected {
    final days = controller.plan?.itinerary ?? const [];
    final i = days.indexWhere((d) => d.day == controller.selectedDay);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    // The tab follows the controller itself rather than relying on an
    // ancestor to rebuild it. A day chosen elsewhere — the header menu, a
    // refinement jumping to the day it changed — has to move the pager, and
    // that cannot depend on who happens to be listening above.
    controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(_syncToSelected);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _pages.dispose();
    super.dispose();
  }

  /// Follows a day chosen somewhere else — a chip, the header menu, a
  /// refinement jumping to the day it changed.
  void _syncToSelected() {
    if (!_pages.hasClients) return;
    final target = _indexOfSelected;
    if (_pages.page?.round() == target) return;
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan!;
    final day = controller.currentDay;
    if (day == null) return const SizedBox.shrink();

    final currency = plan.trip.currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dayChips(context, plan),
        Expanded(
          child: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: plan.itinerary.length,
                // Which day is on screen is the page's to say; the chips
                // above follow it rather than the other way round.
                onPageChanged: (i) =>
                    controller.selectDay(plan.itinerary[i].day.toInt()),
                itemBuilder: (context, i) =>
                    _dayPage(context, plan.itinerary[i], currency),
              ),
              // Over the list rather than in the header, which already holds
              // two actions: down here it is where the thumb is, and it
              // stays put while the day scrolls under it.
              if (widget.onOpenMap != null && !controller.dayIsEmpty(day))
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Center(child: MapPill(onTap: widget.onOpenMap!)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// One day, scrolling on its own so the pager above it stays a fixed height.
  Widget _dayPage(BuildContext context, PlanDay day, String currency) {
    // Pages either side are built too, so their legs are on their way before
    // the swipe that shows them.
    controller.ensureTravelFor(day);
    final travel = controller.travelOn(day);

    return SingleChildScrollView(
      // Room at the foot for the map pill, so the last card can scroll clear
      // of it instead of ending underneath.
      padding: EdgeInsets.fromLTRB(16, 10, 16, widget.onOpenMap == null ? 18 : 76),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Above the short-day band: a guess the planner is carrying
                // applies to the whole plan, where a shortened day is about
                // this one day.
                if (controller.showQuestionsPrompt)
                  OpenQuestionsBand(
                    questions: controller.questions,
                    onAnswer: onAnswerQuestions,
                    onDismiss: controller.dismissQuestions,
                  ),
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
                  ..._slotGroups(day, currency),
                if (!controller.dayIsEmpty(day))
                  for (final slot in controller.openSlotsOn(day)) ...[
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
                // OSM data is ODbL: the credit goes wherever times derived
                // from it are shown, and only there.
                if (travel != null && controller.travelAttribution != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Travel times ${controller.travelAttribution}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: WayfareColors.mutedLight,
                      ),
                    ),
                  ),
              ],
      ),
    );
  }

  /// The day's activities, grouped by slot.
  ///
  /// Order inside a slot is the start time's to decide, not the finger's:
  /// hand-dragging is out for now, and a card is moved by giving it a time.
  /// Tapping opens it; swiping left reveals edit and delete.
  List<Widget> _slotGroups(PlanDay day, String currency) {
    // The page's own day, not the selected one: a pager builds its
    // neighbours, and they would otherwise all draw the day on screen.
    final blocks = controller.visibleBlocksOn(day);

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
            key: ValueKey('slot-${day.day}-${slot.name}'),
            blocks: blocks.where((b) => b.timeOfDay == slot).toList(),
            members: controller.members,
            currency: currency,
            onEdit: onEditActivity,
            onRemove: onRemoveActivity,
            before: (block) => _travelInto(day, block),
          ),
    ];
  }

  /// The connector above [block], or nothing where no leg can arrive.
  Widget _travelInto(PlanDay day, PlanBlock block) {
    final chain = controller.travelChainOn(day);
    final i = chain.indexWhere((b) => b.id == block.id);
    // First of the day, or `anytime`: nothing travels into it. No connector
    // at all, rather than an empty one that would animate for no reason.
    if (i <= 0) return const SizedBox.shrink();

    final leg = controller.legInto(day, block);
    final previous = chain[i - 1];
    final unplacedName = switch (leg?.unplacedEnd) {
      'from' => previous.activity,
      'to' => block.activity,
      _ => null,
    };
    return TravelConnector(leg: leg, unplacedName: unplacedName);
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

  Widget _dayMeta(PlanDay day, String currency) {
    final cost = day.costPerPerson(includeOptional: controller.showOptional);
    // An empty day has no cost worth stating, so the figure says how much of
    // it is written instead.
    final money = controller.dayIsEmpty(day)
        ? '${controller.slotsFilledOn(day)} of 3 slots filled'
        : '${formatMoney(cost, currency)} pp planned';
    // The day's travel leads, since it is the figure that says whether the
    // day can happen; the `+` admits a leg that could not be placed, so the
    // total is a floor rather than a promise.
    final travel = controller.travelOn(day);
    final right = travel == null || travel.minutes == 0
        ? money
        : '${formatDuration(travel.minutes)}${travel.unknown > 0 ? '+' : ''} '
            'travel · $money';

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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: selected
                        ? WayfareColors.surface
                        : WayfareColors.inkSecondary,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
    this.before,
  });

  final List<PlanBlock> blocks;
  final List<Member> members;
  final String currency;
  final ValueChanged<PlanBlock> onEdit;
  final ValueChanged<PlanBlock> onRemove;

  /// What sits above a card — the travel arriving at it. Supplied rather than
  /// worked out here, because the leg into a slot's first card starts in the
  /// slot before it, which this group knows nothing about.
  final Widget Function(PlanBlock block)? before;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final block in blocks) ...[
          if (before != null)
            KeyedSubtree(
              key: ValueKey('before-${block.id}'),
              child: before!(block),
            ),
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
      ],
    );
  }
}

/// The way into the day's map: a dark pill floating over the list.
class MapPill extends StatelessWidget {
  const MapPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Show this day on a map',
      excludeSemantics: true,
      child: Material(
        color: WayfareColors.ink,
        shape: const StadiumBorder(),
        elevation: 4,
        shadowColor: const Color(0x55000000),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 11, 18, 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Map',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The line between two activities: how long getting from one to the next
/// takes, and on what.
///
/// Sits in the gap the cards already leave, so a day with travel is not a day
/// that got taller. Arrives late — the legs are fetched after the day draws —
/// so it grows in rather than appearing, and pushes the cards below it
/// instead of jumping them.
class TravelConnector extends StatelessWidget {
  const TravelConnector({
    super.key,
    required this.leg,
    this.unplacedName,
  });

  /// Null while the leg is still being worked out.
  final TravelLeg? leg;

  /// The activity that could not be placed, named so the fix is obvious: give
  /// it a real address and the time appears.
  final String? unplacedName;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _content() ?? const SizedBox(width: double.infinity),
    );
  }

  Widget? _content() {
    final leg = this.leg;
    if (leg == null || leg.status == LegStatus.samePlace) return null;

    final unknown = leg.status == LegStatus.unplaced;
    final long = !unknown && leg.isLongHop;
    final color = unknown
        ? WayfareColors.mutedLight
        : long
            ? WayfareColors.amberInkDeep
            : WayfareColors.muted;

    return Semantics(
      label: _semantics(leg),
      excludeSemantics: true,
      child: Padding(
        // Indented to the card's own text, so the line reads as belonging to
        // the gap between two cards rather than as a third, smaller card.
        padding: const EdgeInsets.fromLTRB(16, 0, 12, WayfareSpace.cardGap),
        child: Row(
          children: [
            Icon(_icon(leg), size: 15, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                _label(leg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  color: color,
                  fontWeight: long ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(TravelLeg leg) {
    if (leg.status == LegStatus.unplaced) {
      final name = unplacedName?.trim() ?? '';
      return name.isEmpty
          ? 'Travel time unknown'
          : "Travel time unknown — couldn't place $name";
    }
    return travelPhrase(leg);
  }

  String _semantics(TravelLeg leg) {
    if (leg.status == LegStatus.unplaced) return _label(leg);
    final phrase = travelPhrase(leg).replaceFirst('~', 'About ');
    return leg.isLongHop ? '$phrase. A long hop.' : phrase;
  }

  static IconData _icon(TravelLeg leg) {
    if (leg.status == LegStatus.unplaced) return Icons.more_vert;
    return switch (leg.vehicle) {
      Vehicle.walk => Icons.directions_walk,
      Vehicle.train => Icons.train_outlined,
      Vehicle.bus => Icons.directions_bus_outlined,
      Vehicle.ferry => Icons.directions_boat_outlined,
      Vehicle.car => Icons.directions_car_outlined,
      Vehicle.transit || null => Icons.commute,
    };
  }
}

/// "12 min walk", "22 min by train · Kelana Jaya Line", "~25 min by transit".
///
/// The `~` is the whole of the estimate's wording, and it is never dropped:
/// an estimate presented as a routed time is a timetable the app made up.
String travelPhrase(TravelLeg leg) {
  final minutes = leg.minutes ?? 0;
  final time = minutes >= 60 ? formatDuration(minutes) : '$minutes min';
  final approx = leg.isEstimate ? '~' : '';
  final line = leg.line?.trim() ?? '';

  final how = switch (leg.vehicle) {
    Vehicle.walk => '$approx$time walk',
    Vehicle.train => '$approx$time by train',
    Vehicle.bus => '$approx$time by bus',
    Vehicle.ferry => '$approx$time by ferry',
    Vehicle.car => '$approx$time by car',
    Vehicle.transit || null => '$approx$time by transit',
  };
  return line.isEmpty || leg.vehicle == Vehicle.walk ? how : '$how · $line';
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
        // Optional cards read as lighter than required ones, but the colour
        // is mixed rather than made transparent: an alpha here let whatever
        // sat behind the card show through it.
        color: block.optional ? WayfareColors.optionalCard : WayfareColors.surface,
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
              style: WayfareType.body(14.5, color: WayfareColors.muted),
            ),
          ],
          if (_hasFooter) ...[
            const SizedBox(height: 11),
            _footer(fit),
          ],
          // Last line on the card, under the facts rather than among them:
          // where the activity came from is about the card, not part of it.
          if (block.isFromReference) ...[
            SizedBox(height: _hasFooter ? 7 : 11),
            _provenance(),
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: WayfareColors.ink,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          block.timeOfDay.name.toUpperCase(),
          style: WayfareType.eyebrow(12.5, color: const Color(0xFF6D6255)),
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
          // Widened with the type: at 17.5 a title wrapped to a second line
          // sooner than it needed to, and the pills it makes room for sit
          // beside it in a Wrap rather than fighting it for the row.
          constraints: const BoxConstraints(maxWidth: 285),
          child: Text(
            block.activity,
            style: const TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              height: 1.28,
            ),
          ),
        ),
        if (block.optional) WayfarePill.optional(),
        if (WayfareFeatures.groups && block.isMine) WayfarePill.yours(),
      ],
    );
  }

  /// Where this activity came from, named.
  ///
  /// This was a bare link glyph for a while, to keep the card compact. The
  /// glyph was the wrong economy: that an item resolved against something the
  /// traveller actually saved is the one claim this app makes that a generated
  /// itinerary cannot, and an unlabelled icon makes it only to a screen
  /// reader. So the source is named again — in the footer rather than on a row
  /// of its own, which is what made it expensive before.
  ///
  /// `isFromReference` means the planner's item resolved to a stored place, so
  /// the line is a statement about Trippo's own records, never about what the
  /// model claimed.
  Widget _provenance() {
    final source = block.fromSourceTitle;

    return Semantics(
      label: source == null
          ? 'From a place you saved'
          : 'From your link: $source',
      excludeSemantics: true,
      child: Row(
        children: [
          const Icon(Icons.link, size: 13, color: WayfareColors.accent),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              source == null ? 'From a place you saved' : 'From $source',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.2,
                color: WayfareColors.accent,
              ),
            ),
          ),
        ],
      ),
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
        style: const TextStyle(fontSize: 13.5, color: WayfareColors.mutedLight),
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

/// The band above the days when the planner had to guess at something.
///
/// A `needs_info` run used to replace the itinerary with its list of
/// questions, and the draft that same run produced was discarded. That is
/// backwards: the plan is the thing worth seeing, and an unanswered question
/// is a refinement waiting to happen rather than a gate in front of one. So
/// the questions live up here, collapsed, naming what was guessed — in the
/// info blue, because a guess the planner admits to is not the same kind of
/// fact as a flight that cut the day short.
class OpenQuestionsBand extends StatefulWidget {
  const OpenQuestionsBand({
    super.key,
    required this.questions,
    required this.onAnswer,
    required this.onDismiss,
  });

  final List<ClarifyingQuestion> questions;

  /// Opens the questions themselves. Owned by the shell, which navigates.
  final VoidCallback onAnswer;

  /// "Keep as is" — the guesses stand and the band goes away.
  final VoidCallback onDismiss;

  @override
  State<OpenQuestionsBand> createState() => _OpenQuestionsBandState();
}

class _OpenQuestionsBandState extends State<OpenQuestionsBand> {
  /// Collapsed by default, like the short-day band: the headline is the whole
  /// finding, and the questions themselves are worth reading when you intend
  /// to answer them, not on every scroll past.
  bool _open = false;

  static const _duration = Duration(milliseconds: 240);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final count = widget.questions.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        expanded: _open,
        child: Material(
          color: WayfareColors.infoBg,
          shape: RoundedRectangleBorder(
            borderRadius: theme.cardLg,
            side: const BorderSide(color: WayfareColors.infoBorderAlt, width: 1.5),
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
                              '${spellOut(count)} '
                              '${count == 1 ? 'guess' : 'guesses'}',
                              color: WayfareColors.info,
                              size: 11.5,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              count == 1
                                  ? 'The plan below rests on one guess.'
                                  : 'The plan below rests on $count guesses.',
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
                          color: WayfareColors.info,
                        ),
                      ),
                    ],
                  ),
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
                          padding: const EdgeInsets.only(top: 10, right: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // What was guessed, in the planner's own words,
                              // so the decision to answer is informed before
                              // the screen opens.
                              for (final question in widget.questions) ...[
                                Text(
                                  '— ${question.question}',
                                  style: WayfareType.body(
                                    13.5,
                                    color: WayfareColors.infoBody,
                                  ),
                                ),
                                const SizedBox(height: 5),
                              ],
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  Expanded(
                                    child: WayfareSecondaryButton(
                                      label: count == 1
                                          ? 'Answer it'
                                          : 'Answer them',
                                      onPressed: widget.onAnswer,
                                      background: WayfareColors.infoBgAlt,
                                      foreground: WayfareColors.info,
                                      minHeight: 42,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: WayfareSecondaryButton(
                                      label: 'Keep as is',
                                      onPressed: widget.onDismiss,
                                      foreground: WayfareColors.muted,
                                      minHeight: 42,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
}
