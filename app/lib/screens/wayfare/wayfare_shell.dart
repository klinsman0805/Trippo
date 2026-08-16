import 'package:flutter/material.dart';

import '../../api/trippo_api.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../state/wayfare_controller.dart';
import 'budget_tab.dart';
import 'flights/flights_screen.dart';
import 'formatting.dart';
import 'group_tab.dart';
import 'needs_info.dart';
import 'plan_failed.dart';
import 'refine_tab.dart';
import 'shell_chrome.dart';
import 'traveller_sheet.dart';
import 'trip_tab.dart';

/// The whole app shell: header → scroll area → [composer] → nav, with the
/// sheet and generating overlay stacked above.
class WayfareShell extends StatefulWidget {
  const WayfareShell({
    super.key,
    required this.api,
    required this.tripId,
    this.platformOverride,
  });

  final TrippoApi api;
  final String tripId;

  /// Forces a platform dress. Null follows the host OS.
  final WayfarePlatform? platformOverride;

  @override
  State<WayfareShell> createState() => _WayfareShellState();
}

class _WayfareShellState extends State<WayfareShell> {
  late final WayfareController _controller =
      WayfareController(widget.api, widget.tripId);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    // The short-day band links back to the decision that caused it.
    _controller.onSeeOtherFlights = _openFlights;
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final platform = widget.platformOverride ?? WayfareTheme.hostPlatform();

    return WayfareTheme(
      platform: platform,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: WayfareColors.bgApp,
          // The header and nav handle their own insets so the blurred iOS bar
          // can sit under the home indicator.
          body: Stack(
            children: [
              Positioned.fill(child: _frame(context)),
              if (_controller.sheetOpen) _sheet(context),
              if (_controller.generating) const GeneratingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame(BuildContext context) {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: WayfareColors.accent),
      );
    }

    return Column(
      children: [
        WayfareHeader(
          overline: _overline(),
          title: _title(),
          subtitle: _subtitle(),
          actionIcon: _actionIcon(),
          actionLabel: _controller.tab == WayfareTab.group
              ? 'Add traveller'
              : 'Trip options',
          onAction: _controller.tab == WayfareTab.group
              ? _controller.openSheet
              : _openTripOptions,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: _body(),
          ),
        ),
        if (_controller.tab == WayfareTab.chat)
          RefineComposer(controller: _controller),
        WayfareNavBar(
          current: _controller.tab,
          onSelect: _controller.goTo,
        ),
      ],
    );
  }

  Widget _body() {
    if (_controller.error != null && _controller.plan == null) {
      return _ErrorState(
        message: _controller.error!,
        onRetry: _controller.load,
      );
    }

    // A failed run outranks everything else on these two tabs: the plan behind
    // it may be stale, and the user needs to know why before reading it.
    if (_controller.isFailed) {
      return PlanFailedView(
        failure: _controller.failure!,
        onRetry: _controller.retryPlanning,
        onDismiss: _controller.dismissFailure,
        onFinishByHand: () => _controller.goTo(WayfareTab.chat),
      );
    }

    // The planner asked rather than guessed. The questions replace the
    // itinerary — a needs_info plan has no itinerary to show.
    if (_controller.tab == WayfareTab.itinerary && _controller.needsInfo) {
      return NeedsInfoView(
        questions: _controller.questions,
        answers: _controller.answers,
        onAnswer: _controller.setAnswer,
        onSend: _controller.sendAnswers,
        onSkip: _controller.planWithoutAnswers,
      );
    }

    // Dates come from flights, so before there are any the Trip tab leads with
    // that rather than a generic empty state — the highest-intent moment.
    if (_controller.tab == WayfareTab.itinerary &&
        !_controller.hasPlan &&
        (_controller.trip?.startDate == null)) {
      return _NoDatesYet(
        onOpenFlights: _openFlights,
        onGoToGroup: () => _controller.goTo(WayfareTab.group),
        memberCount: _controller.members.length,
      );
    }

    // Trip and Budget need a plan; Group and Refine work without one.
    if (_controller.isBlank) {
      return _BlankState(
        title: _controller.tab == WayfareTab.budget
            ? 'No numbers yet'
            : 'No itinerary yet',
        note: _controller.members.length < 2
            ? 'Add at least two travellers with their preferences, then hit Generate.'
            : 'You have ${_controller.members.length} travellers ready. '
                'Hit Generate and this fills in.',
        onGoToGroup: () => _controller.goTo(WayfareTab.group),
      );
    }

    return switch (_controller.tab) {
      WayfareTab.itinerary => TripTab(controller: _controller),
      WayfareTab.budget => BudgetTab(controller: _controller),
      WayfareTab.group => GroupTab(controller: _controller),
      WayfareTab.chat => RefineTab(controller: _controller),
    };
  }

  /// Flights is a pushed screen, not a tab. Entered from the day-1 row while
  /// the trip has no dates, and from the header sheet once it does.
  Future<void> _openFlights() async {
    final trip = _controller.trip;
    if (trip == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WayfareTheme(
          platform: widget.platformOverride ?? WayfareTheme.hostPlatform(),
          child: FlightsScreen(
            api: widget.api,
            trip: trip,
            onSelected: (offer, envelope) {
              // Hand back to the Trip tab, where the consequence lands.
              Navigator.of(context).pop();
              _controller.goTo(WayfareTab.itinerary);
              _controller.load();
            },
          ),
        ),
      ),
    );
  }

  /// The header `⋯` sheet on non-Group tabs.
  void _openTripOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WayfareColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WayfareTheme.of(context).sheetRadius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: WayfareColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.flight_takeoff, color: WayfareColors.ink),
              title: const Text('Flights and dates'),
              subtitle: const Text('Picking flights sets the trip dates'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openFlights();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: WayfareColors.ink),
              title: const Text('Ask for a change'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _controller.goTo(WayfareTab.chat);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    return Stack(
      children: [
        // Tap-to-dismiss backdrop.
        Positioned.fill(
          child: GestureDetector(
            onTap: _controller.closeSheet,
            child: const ColoredBox(color: WayfareColors.scrim),
          ),
        ),
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, offset, child) => FractionalTranslation(
              translation: Offset(0, offset),
              child: child,
            ),
            child: _travellerSheet(),
          ),
        ),
      ],
    );
  }

  Widget _travellerSheet() {
    final editing = _controller.editingMember;
    if (editing == null) {
      return TravellerSheet(
        onSave: _controller.addMember,
        onCancel: _controller.closeSheet,
      );
    }

    final index = _controller.memberIndex(editing.id);

    return TravellerSheet(
      key: ValueKey(editing.id),
      existing: editing,
      avatarColor: WayfareColors.memberColor(index),
      optionalForMember: _optionalFor(editing.id),
      onSave: (member) => _controller.saveMember(editing.id, member),
      onRemove: () => _controller.removeMember(editing.id),
      onCancel: _controller.closeSheet,
    );
  }

  /// Blocks the plan currently marks optional for one traveller — what the
  /// edit sheet names as being at stake.
  List<({int day, String activity})> _optionalFor(String memberId) => [
        for (final day in _controller.plan?.itinerary ?? const [])
          for (final block in day.blocks)
            if (block.optional && block.suitedForMembers.contains(memberId))
              (day: day.day.toInt(), activity: block.activity),
      ];

  // --- header copy, per tab ---

  /// A `needs_info` plan often carries a partial draft itinerary, and a failed
  /// run leaves the previous one in place — but neither is on screen, so
  /// counting its days here would label a page the user cannot see.
  String _overline() {
    if (_controller.isFailed || _controller.needsInfo) return 'Wayfare';
    if (_controller.tab == WayfareTab.itinerary && _controller.hasPlan) {
      return 'Day ${_controller.selectedDay} of ${_controller.plan!.itinerary.length}';
    }
    return 'Wayfare';
  }

  String _title() => switch (_controller.tab) {
        WayfareTab.itinerary =>
          _controller.trip?.title ?? _controller.plan?.trip.title ?? 'Trip',
        WayfareTab.budget => 'Budget',
        WayfareTab.group => 'Your group',
        WayfareTab.chat => 'Refine',
      };

  String _subtitle() {
    final trip = _controller.trip;
    final plan = _controller.plan;

    // Both load-bearing states say so in the header, so the reason the tab
    // looks different is visible before scrolling to find it.
    if (_controller.isFailed) {
      final revision = _controller.failure!.lastGoodRevision;
      return revision == null
          ? 'Nothing planned yet · generation stopped'
          : 'Revision $revision kept · generation stopped';
    }
    if (_controller.tab == WayfareTab.itinerary && _controller.needsInfo) {
      final count = _controller.questions.length;
      final dates = trip?.startDate == null ? 'No dates yet' : 'Dates set';
      return '$dates · waiting on '
          '${spellOut(count).toLowerCase()} ${count == 1 ? 'answer' : 'answers'}';
    }

    return switch (_controller.tab) {
      WayfareTab.itinerary => destinationsSubtitle(
          trip?.destinations ?? const [],
          trip?.startDate,
          trip?.endDate,
        ),
      WayfareTab.budget => plan == null
          ? 'Nothing committed yet'
          : '${formatMoney(plan.trip.estimatedTotalCost, plan.trip.currency)} of '
              '${formatMoney(plan.trip.totalBudget ?? 0, plan.trip.currency)} committed',
      WayfareTab.group => () {
          final count = _controller.members.length;
          final conflicts = plan?.conflicts.length ?? 0;
          final people = '$count ${count == 1 ? 'traveller' : 'travellers'}';
          return conflicts > 0
              ? '$people · $conflicts things to balance'
              : people;
        }(),
      WayfareTab.chat => 'Ask for a change in plain words',
    };
  }

  /// `+` on Group opens the sheet; `↻` on Trip and `⋯` elsewhere route to
  /// Refine, per the handoff.
  IconData _actionIcon() => switch (_controller.tab) {
        WayfareTab.group => Icons.add,
        WayfareTab.itinerary => Icons.refresh,
        _ => Icons.more_horiz,
      };
}

/// Full-frame overlay while the planner runs. Real calls take minutes, so the
/// note names what's actually happening rather than showing a bare spinner.
class GeneratingOverlay extends StatelessWidget {
  const GeneratingOverlay({super.key, this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        child: ColoredBox(
          color: WayfareColors.ink,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WayfarePulsingDots(
                    colors: WayfareColors.loadingDots,
                    size: 13,
                    gap: 10,
                    period: Duration(milliseconds: 1100),
                    stagger: [0.0, 0.16, 0.33],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Building your itinerary…',
                    textAlign: TextAlign.center,
                    style: WayfareType.display(
                      28,
                      color: WayfareColors.generatingInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      note ?? 'Balancing everyone\'s preferences. This takes a minute.',
                      textAlign: TextAlign.center,
                      style: WayfareType.body(
                        14,
                        color: WayfareColors.generatingNote,
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

/// Occupies the day-1 position while the trip has no dates. Flights set them,
/// so this is where flights are offered — unmissable, and only while relevant.
class _NoDatesYet extends StatelessWidget {
  const _NoDatesYet({
    required this.onOpenFlights,
    required this.onGoToGroup,
    required this.memberCount,
  });

  final VoidCallback onOpenFlights;
  final VoidCallback onGoToGroup;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: WayfareColors.surface,
              borderRadius: theme.cardLg,
              border: Border.all(color: WayfareColors.borderSoft, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flight_takeoff,
                        size: 20, color: WayfareColors.accent),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Flights — sets your dates',
                        style: WayfareType.ui(16, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The planner works from when you land and when you leave. '
                  'Pick flights and the days fill in around them.',
                  style: WayfareType.body(13.5, color: WayfareColors.subhead),
                ),
                const SizedBox(height: 16),
                WayfarePrimaryButton(
                  label: 'Find flights',
                  onPressed: onOpenFlights,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            memberCount < 2
                ? 'You can add travellers first — the planner needs at least two.'
                : 'Already booked? Set the dates by hand from the menu above.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: WayfareColors.mutedLight),
          ),
          if (memberCount < 2) ...[
            const SizedBox(height: 12),
            WayfareSecondaryButton(
              label: 'Go to the group',
              onPressed: onGoToGroup,
            ),
          ],
        ],
      ),
    );
  }
}

class _BlankState extends StatelessWidget {
  const _BlankState({
    required this.title,
    required this.note,
    required this.onGoToGroup,
  });

  final String title;
  final String note;
  final VoidCallback onGoToGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: WayfareColors.blankTile,
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: WayfareType.display(24)),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              note,
              textAlign: TextAlign.center,
              style: WayfareType.body(13.5, color: WayfareColors.subhead),
            ),
          ),
          const SizedBox(height: 18),
          WayfarePrimaryButton(
            label: 'Go to the group',
            onPressed: onGoToGroup,
            fontSize: 14.5,
            weight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      child: Column(
        children: [
          Text('Something went wrong', style: WayfareType.display(24)),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: WayfareType.body(13.5, color: WayfareColors.subhead),
          ),
          const SizedBox(height: 18),
          WayfarePrimaryButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}
