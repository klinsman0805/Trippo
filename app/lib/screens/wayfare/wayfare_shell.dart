import 'dart:math' as math;

import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/scheduler.dart';

import '../../api/trippo_api.dart';
import '../../design/features.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';
import '../../models/trip.dart';
import '../../state/wayfare_controller.dart';
import 'budget_tab.dart';
import 'currency_picker.dart';
import 'flights/booked_flight_screen.dart';
import 'flights/flights_screen.dart';
import 'formatting.dart';
import 'group_tab.dart';
import 'itinerary/activity_sheet.dart';
import 'itinerary/activity_sheets.dart';
import 'itinerary/regenerate_sheet.dart';
import 'needs_info.dart';
import 'plan_failed.dart';
import 'refine_tab.dart';
import 'sources/import_sheet.dart';
import 'sources/sources_screen.dart';
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
              if (_controller.generating)
                GeneratingOverlay(
                  placeCount: _controller.importedPlaces.length,
                  dayCount: _plannedDayCount(),
                ),
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
          actionLabel: _onGroupTab ? 'Add traveller' : 'Trip options',
          onAction: _onGroupTab ? _controller.openSheet : _openTripOptions,
          // Adding is its own affordance rather than a row at the end of the
          // day, which is the point at which it is furthest from the thumb.
          secondaryActionIcon:
              _controller.tab == WayfareTab.itinerary && _controller.hasPlan
                  ? Icons.add
                  : null,
          secondaryActionLabel: 'Add',
          onSecondaryAction: _openAddMenu,
          // Only when there is a list behind us. Booting straight into a trip
          // with TRIPPO_TRIP_ID has nothing to go back to.
          onBack: Navigator.of(context).canPop()
              ? () => Navigator.of(context).pop()
              : null,
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
        onEnterBookedFlight: _openBookedFlight,
        onOpenFlights: _openFlights,
        onSetDatesByHand: _pickDatesByHand,
        onImportLink: _openImport,
        onSeeReferences: _openSources,
        importedPlaces: _controller.importedPlaces,
        sourceCount: _controller.sourceCount,
        onGoToGroup: () => _controller.goTo(WayfareTab.group),
        memberCount: _controller.members.length,
      );
    }

    // Dates exist, nothing planned: two equal ways forward rather than one
    // path plus an apology.
    if (_controller.tab == WayfareTab.itinerary &&
        !_controller.hasPlan &&
        _controller.trip?.startDate != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: ItineraryStartOptions(
          importedPlaces: _controller.importedPlaces,
          onSeeReferences: _openSources,
          dayCount: _plannedDayCount(),
          canGenerate: _controller.canGenerate,
          onGenerate: _controller.generate,
          onWriteFirst: _startFromScratch,
          onImportLink: _openImport,
          sourceCount: _controller.sourceCount,
        ),
      );
    }

    // Trip and Budget need a plan; Group and Refine work without one.
    if (_controller.isBlank) {
      return _BlankState(
        title: _controller.tab == WayfareTab.budget
              ? 'No numbers yet'
              : 'No itinerary yet',
        note: !WayfareFeatures.groups
              ? 'Generate one whenever you like, or write the first activity '
                  'yourself.'
              : _controller.members.isEmpty
                  ? 'Generate one whenever you like. Adding travellers first '
                      'makes the plan fit the group, but it is not required.'
                  : 'You have ${_controller.members.length} '
                      '${_controller.members.length == 1 ? 'traveller' : 'travellers'} '
                      'ready. Generate and this fills in.',
        canGenerate: _controller.canGenerate,
        onGenerate: _controller.generate,
        memberCount: _controller.members.length,
        onGoToGroup: () => _controller.goTo(WayfareTab.group),
        onSetDestination: _setDestination,
      );
    }

    return switch (_controller.tab) {
      WayfareTab.itinerary => TripTab(
          controller: _controller,
          onAddActivity: _openAddActivity,
          onEditActivity: _openEditActivity,
          onRemoveActivity: _openRemoveActivity,
        ),
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

  /// "I have my flight booked" — the shortest path to a dated trip.
  Future<void> _openBookedFlight() async {
    final trip = _controller.trip;
    if (trip == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookedFlightScreen(
          api: widget.api,
          trip: trip,
          onConfirmed: (_) {
              Navigator.of(context).pop();
              _controller.goTo(WayfareTab.itinerary);
              _controller.load();
          },
        ),
      ),
    );
  }

  /// "Not flying" — dates without a flight behind them.
  ///
  /// No envelope is derived, so no day is marked short. That is correct rather
  /// than missing: a train at 09:00 does not cost you a morning the way a
  /// 13:15 landing does, and guessing would be worse than saying nothing.
  Future<void> _pickDatesByHand() async {
    final trip = _controller.trip;
    if (trip == null) return;

    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _existingRange(trip),
      helpText: 'When are you travelling?',
      saveText: 'Set dates',
    );
    if (range == null) return;

    await _controller.setDatesByHand(range.start, range.end);
  }

  DateTimeRange? _existingRange(Trip trip) {
    final start = DateTime.tryParse(trip.startDate ?? '');
    final end = DateTime.tryParse(trip.endDate ?? '');
    if (start == null || end == null || end.isBefore(start)) return null;
    return DateTimeRange(start: start, end: end);
  }

  /// Days between the trip's dates — what "fill the 4 days" counts.
  int _plannedDayCount() {
    final envelope = _controller.dateEnvelope;
    if (envelope != null) return envelope.planningDays;
    final start = DateTime.tryParse(_controller.trip?.startDate ?? '');
    final end = DateTime.tryParse(_controller.trip?.endDate ?? '');
    if (start == null || end == null) return 0;
    return end.difference(start).inDays + 1;
  }

  Future<void> _sheet2(Widget child) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => WayfareTheme(
          platform: widget.platformOverride ?? WayfareTheme.hostPlatform(),
          child: child,
        ),
      );

  /// "Build it by hand" from the empty state — there is no plan yet, so one is
  /// created around the trip's dates before the first activity can land.
  Future<void> _startFromScratch() async {
    await _controller.startBlankItinerary();
    if (!mounted) return;
    await _openAddActivity(TimeOfDay.morning);
  }

  Future<void> _openAddActivity(TimeOfDay slot) async {
    final day = _controller.selectedDay;
    await _sheet2(
      ActivitySheet(
        day: day,
        initialSlot: slot,
        onCancel: () => Navigator.of(context).pop(),
        onSave: (activity) {
          Navigator.of(context).pop();
          _controller.addActivity(day, activity);
        },
      ),
    );
  }

  Future<void> _openEditActivity(PlanBlock block) async {
    final day = _controller.selectedDay;
    await _sheet2(
      ActivitySheet(
        day: day,
        existing: block,
        onCancel: () => Navigator.of(context).pop(),
        onSave: (activity) {
          Navigator.of(context).pop();
          _controller.updateActivity(block.id, activity);
        },
        onRemove: () {
          Navigator.of(context).pop();
          _openRemoveActivity(block);
        },
      ),
    );
  }

  Future<void> _openRemoveActivity(PlanBlock block) async {
    final day = _controller.currentDay;
    if (day == null) return;

    await _sheet2(
      RemoveActivitySheet(
        block: block,
        day: day.day.toInt(),
        // Whether the slot goes dark matters more than the count, so it is
        // computed rather than described vaguely.
        slotBecomesEmpty:
              day.blocks.where((b) => b.timeOfDay == block.timeOfDay).length == 1,
        dayCostBefore: day.costPerPerson(),
        currency: _controller.plan?.trip.currency ??
              _controller.trip?.currency ??
              'USD',
        onKeep: () => Navigator.of(context).pop(),
        onRemove: () {
          Navigator.of(context).pop();
          _controller.removeActivity(block.id);
        },
      ),
    );
  }

  /// The header `+`: the two things there are to add.
  Future<void> _openAddMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: WayfareColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WayfareTheme.of(context).sheetRadius),
        ),
      ),
      // Scrollable and capped: a menu grows an item at a time, and a fixed
      // Column in a sheet has no way to say it ran out of room — it just
      // overflows off the bottom edge.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
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
              // First, because it is the one that does the work for you: the
              // places are already written down somewhere.
              ListTile(
                leading: const Icon(Icons.link, color: WayfareColors.accent),
                title: const Text('Add from a link'),
                subtitle: const Text('A 小红书 post, a list, a blog'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openImport();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.add_task_outlined, color: WayfareColors.ink),
                title: const Text('Add an activity'),
                subtitle: Text('Onto day ${_controller.selectedDay}'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openAddActivity(TimeOfDay.anytime);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.today_outlined, color: WayfareColors.ink),
                title: const Text('Add a day'),
                subtitle: const Text('Extends the trip by one day'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _controller.addDay();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Paste a link, get places. Reloads the trip after, because an import
  /// changes what a regeneration would produce.
  Future<void> _openImport() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WayfareTheme(
        platform: widget.platformOverride ?? WayfareTheme.hostPlatform(),
        child: ImportLinkSheet(controller: _controller),
      ),
    );
    if (mounted) await _controller.load();
  }

  Future<void> _openSources() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WayfareTheme(
          platform: widget.platformOverride ?? WayfareTheme.hostPlatform(),
          child: SourcesScreen(controller: _controller),
        ),
      ),
    );
    if (mounted) await _controller.load();
  }

  /// Where the trip is going, for a trip created before the app asked.
  Future<void> _setDestination() async {
    final current = _controller.trip?.destinations.firstOrNull ?? '';
    final input = TextEditingController(text: current);

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WayfareColors.surface,
        title: Text('Where are you going?', style: WayfareType.display(24)),
        content: WayfareTextField(
          controller: input,
          hint: 'e.g. Bangkok',
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: WayfareColors.mutedLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, input.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(color: WayfareColors.accent),
            ),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty) return;
    await _controller.setDestination(value);
  }

  /// What the trip's money is counted in.
  Future<void> _setCurrency() async {
    var picked = _controller.trip?.currency ?? 'USD';

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          backgroundColor: WayfareColors.surface,
          title: Text('Currency', style: WayfareType.display(24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Every figure on the trip is shown in this. Changing it '
                  'relabels what is already planned — it does not convert the '
                  'amounts.',
                  style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
                ),
                const SizedBox(height: 14),
                CurrencyPicker(
                  value: picked,
                  onChanged: (v) => setSheetState(() => picked = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: WayfareColors.mutedLight),
              ),
            ),
            TextButton(
              onPressed:
                  picked.length == 3 ? () => Navigator.pop(ctx, picked) : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: picked.length == 3
                      ? WayfareColors.accent
                      : WayfareColors.mutedLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (value == null || value.length != 3) return;
    await _controller.setCurrency(value);
  }

  /// Removing the day currently on screen.
  ///
  /// Irreversible and it takes whatever is on the day, so it names the loss
  /// rather than the action.
  Future<void> _confirmDeleteDay(int day) async {
    final count = _controller.currentDay?.blocks.length ?? 0;
    final remaining = (_controller.plan?.itinerary.length ?? 1) - 1;
    // Which end moves follows from which day goes.
    final shift = _controller.deletingMovesStart(day)
        ? 'your trip starts a day later'
        : 'your return moves a day earlier';
    final loses = count == 0
        ? 'Nothing is planned on this day.'
        : 'The $count ${count == 1 ? 'activity' : 'activities'} on this day '
            'go with it.';

    final confirmed = await confirmDestructive(
      context,
      title: 'Delete day $day?',
      body: 'The trip becomes $remaining days and $shift. $loses The airline '
          'knows nothing about this — your booking does not change.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep it',
    );
    if (confirmed) await _controller.deleteDay(day);
  }

  /// `↻` once hand-written work exists.
  ///
  /// Regenerating never fires straight from a tap when there is something to
  /// lose — the sheet states what survives first.
  Future<void> _openRegenerate() async {
    final summary = await _controller.loadPinnedSummary();
    if (!mounted || summary == null) {
      await _controller.generate();
      return;
    }
    if (!summary.hasPinned) {
      await _controller.generate();
      return;
    }

    await _sheet2(
      RegenerateSheet(
        summary: summary,
        currency: _controller.plan?.trip.currency ??
            _controller.trip?.currency ??
            'USD',
        onCancel: () => Navigator.of(context).pop(),
        onUnpin: (blockId) {
          Navigator.of(context).pop();
          _controller.setPinned(blockId, false);
        },
        onKeepMine: () {
          Navigator.of(context).pop();
          _controller.generate();
        },
        onReplaceEverything: () {
          Navigator.of(context).pop();
          _controller.replanEverything();
        },
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
      // Scrollable and capped: a menu grows an item at a time, and a fixed
      // Column in a sheet has no way to say it ran out of room — it just
      // overflows off the bottom edge.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
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
              leading: const Icon(Icons.place_outlined, color: WayfareColors.ink),
              title: const Text('Set the destination'),
              subtitle: Text(
                _controller.trip?.destinations.isNotEmpty == true
                    ? _controller.trip!.destinations.join(', ')
                    : 'Not set — the planner cannot run without one',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setDestination();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.payments_outlined, color: WayfareColors.ink),
              title: const Text('Currency'),
              subtitle: Text(_controller.trip?.currency ?? 'USD'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setCurrency();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: WayfareColors.ink),
              title: const Text('Your references'),
              subtitle: const Text('Links you have imported, and what came out'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openSources();
              },
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined,
                  color: WayfareColors.ink),
              title: const Text('I have my flight booked'),
              subtitle: const Text('Set the dates from a flight number'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openBookedFlight();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flight_takeoff, color: WayfareColors.ink),
              title: const Text('Search flights'),
              subtitle: const Text('Picking flights sets the trip dates'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openFlights();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined, color: WayfareColors.ink),
              title: const Text('Set dates myself'),
              subtitle: const Text('For trips that do not involve a flight'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickDatesByHand();
              },
            ),
            // Editing lives here too, so a day can be changed from anywhere
            // rather than only from the button at the end of it.
            if (_controller.hasPlan)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: WayfareColors.ink),
                title: Text('Edit day ${_controller.selectedDay}'),
                subtitle: const Text('Add, change or reorder activities'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _controller.goTo(WayfareTab.itinerary);
                              },
              ),
            // Acts on the day currently on screen, which is why it names it.
            // Only offered on the ends: removing a middle day would move every
            // later day onto a different date than the one being looked at.
            if (_controller.hasPlan &&
                _controller.canDeleteDay(_controller.selectedDay))
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: WayfareColors.destructiveInk),
                title: Text(
                  'Delete day ${_controller.selectedDay}',
                  style: const TextStyle(color: WayfareColors.destructiveInk),
                ),
                subtitle: const Text('Shortens the trip by one day'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDeleteDay(_controller.selectedDay);
                },
              ),
            // This is where regenerating lives now that the header icon no
            // longer implies it. Labelled, so it cannot be hit by accident.
            if (_controller.canGenerate)
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: WayfareColors.ink),
                title: Text(
                  _controller.isReady
                      ? 'Regenerate the itinerary'
                      : 'Generate the itinerary',
                ),
                subtitle: _controller.isReady
                    ? const Text('Replaces the current plan')
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openRegenerate();
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

  /// `+` on Group opens the add sheet; everywhere else the action opens the
  /// options menu.
  ///
  /// The Trip tab used a refresh icon, which promised a reload and delivered a
  /// menu. The icon has to describe what the button does, not what the tab is
  /// about — regenerating lives inside the menu, where it is labelled.
  IconData _actionIcon() => _onGroupTab ? Icons.add : Icons.more_horiz;

  /// Group is behind [WayfareFeatures.groups]. Reading the flag through the
  /// tab check keeps every group branch in one shape, so none of them can be
  /// missed when it comes back.
  bool get _onGroupTab =>
      WayfareFeatures.groups && _controller.tab == WayfareTab.group;
}

/// Full-frame overlay while the planner runs. Real calls take minutes, so the
/// note names what's actually happening rather than showing a bare spinner.
class GeneratingOverlay extends StatefulWidget {
  const GeneratingOverlay({
    super.key,
    this.note,
    this.placeCount = 0,
    this.dayCount = 0,
  });

  final String? note;

  /// What the run is working from. Both are known before the call starts, and
  /// naming them is the one honest thing this screen can say about progress.
  final int placeCount;
  final int dayCount;

  @override
  State<GeneratingOverlay> createState() => _GeneratingOverlayState();
}

class _GeneratingOverlayState extends State<GeneratingOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    setState(() => _elapsed = elapsed);
  });

  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Started here, not in the field's initialiser: a `late final` is lazy, so
    // a ticker nobody reads is a ticker that never runs.
    _ticker.start();
  }

  /// The run is one request: there is no progress to report, only time spent.
  ///
  /// So the bar is drawn from elapsed time against a typical run, easing as it
  /// goes and stopping short of the end — it never claims to be nearly done,
  /// because it does not know. A bar that marched to 100% and then sat there
  /// would be a lie told slowly.
  static const _typical = Duration(seconds: 45);
  static const _ceiling = 0.92;

  /// Past this the estimate has plainly been beaten, so the copy says so
  /// rather than letting the bar keep creeping in silence.
  static const _slow = Duration(seconds: 100);

  double get _fraction {
    final t = _elapsed.inMilliseconds / _typical.inMilliseconds;
    // 1 − e^−t: quick at first, slower the longer it runs, never arriving.
    return _ceiling * (1 - math.exp(-1.6 * t));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

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
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: WayfareBar(
                      fraction: _fraction,
                      fill: WayfareColors.accent,
                      track: WayfareColors.generatingTrack,
                      height: 5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      widget.note ?? _line(),
                      textAlign: TextAlign.center,
                      style: WayfareType.body(
                        14,
                        color: WayfareColors.generatingNote,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _clock(),
                    style: WayfareType.body(
                      12.5,
                      color: WayfareColors.generatingTrack,
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

  /// What it is working from, which is knowable, rather than what step it is
  /// on, which is not.
  String _line() {
    if (_elapsed > _slow) {
      return 'Still going. More days and more saved places take longer.';
    }

    final parts = [
      if (widget.placeCount > 0)
        '${widget.placeCount} saved '
            '${widget.placeCount == 1 ? 'place' : 'places'}',
      if (widget.dayCount > 0)
        '${widget.dayCount} ${widget.dayCount == 1 ? 'day' : 'days'}',
    ];
    if (parts.isEmpty) {
      return WayfareFeatures.groups
          ? 'Balancing everyone\'s preferences. This takes a minute.'
          : 'Working through your days. This takes a minute.';
    }
    return 'Working from ${parts.join(' across ')}.';
  }

  String _clock() {
    final seconds = _elapsed.inSeconds;
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m ${(seconds % 60).toString().padLeft(2, '0')}s';
  }
}

/// Occupies the day-1 position while the trip has no dates.
///
/// Three ways in, ordered by how much work each asks of the user rather than
/// by how much the app would like them to do. Someone holding a booking has
/// the answer already and should not be sent shopping; someone taking a train
/// should not have to pretend to look at flights to get past this screen.
class _NoDatesYet extends StatelessWidget {
  const _NoDatesYet({
    required this.onEnterBookedFlight,
    required this.onOpenFlights,
    required this.onSetDatesByHand,
    required this.onGoToGroup,
    required this.memberCount,
    required this.onImportLink,
    required this.onSeeReferences,
    required this.importedPlaces,
    required this.sourceCount,
  });

  final VoidCallback onEnterBookedFlight;
  final VoidCallback onOpenFlights;
  final VoidCallback onSetDatesByHand;
  final VoidCallback onImportLink;
  final VoidCallback onSeeReferences;
  final List<Place> importedPlaces;
  final int sourceCount;
  final VoidCallback onGoToGroup;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ImportedPlacesCard(
            places: importedPlaces,
            sourceCount: sourceCount,
            onSeeAll: onSeeReferences,
            onImportMore: onImportLink,
            awaitingDates: true,
          ),
          Text(
            'The planner builds around your dates. Where do yours come from?',
            style: WayfareType.body(14, color: WayfareColors.subhead),
          ),
          const SizedBox(height: WayfareSpace.sectionGap),
          _StartOption(
            icon: Icons.confirmation_number_outlined,
            title: 'I have my flight booked',
            body: 'Enter your flight number and we will fill in the dates from '
                'the schedule — including how much of the first and last day '
                'you actually get.',
            cta: 'Enter flight number',
            emphasis: true,
            onTap: onEnterBookedFlight,
          ),
          const SizedBox(height: WayfareSpace.cardGap),
          _StartOption(
            icon: Icons.flight_takeoff,
            title: "Haven't booked yet?",
            body: 'Compare flights here and see what each one costs you in '
                'trip time before you commit to it.',
            cta: 'Search flights',
            onTap: onOpenFlights,
          ),
          const SizedBox(height: WayfareSpace.cardGap),
          const SizedBox(height: WayfareSpace.cardGap),
          _StartOption(
            icon: Icons.directions_railway_outlined,
            title: 'Not flying?',
            body: 'Driving, training, already there — pick your dates and start '
                'planning. Flights are one way to set them, not the only one.',
            cta: 'Set dates myself',
            onTap: onSetDatesByHand,
          ),
          // Dates and references are independent: the planner can hold a pile
          // of places long before it knows which days to spread them across,
          // and collecting them is what people are doing anyway. Once
          // something is saved, the card above says so and this would be
          // asking twice.
          if (importedPlaces.isEmpty) ...[
            const SizedBox(height: WayfareSpace.sectionGap),
            _StartOption(
              icon: Icons.link,
              title: 'Already saving places?',
              body: 'Paste a 小红书 post, a list or a blog now. We read it and '
                  'keep the places, ready for whenever the dates land.',
              cta: 'Import a link',
              onTap: onImportLink,
            ),
          ],
          if (WayfareFeatures.groups && memberCount == 0) ...[
            const SizedBox(height: WayfareSpace.sectionGap),
            Text(
              'You can add travellers whenever you like — the plan gets more '
              'tailored with them, and works without.',
              textAlign: TextAlign.center,
              style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
            ),
            const SizedBox(height: 12),
            WayfareSecondaryButton(
              label: 'Add who is coming',
              onPressed: onGoToGroup,
            ),
          ],
        ],
      ),
    );
  }
}

/// What the imports actually produced, named back.
///
/// Importing eight places and landing on a screen that looks exactly as it did
/// before reads as an import that did nothing — which is what happened, and
/// the reason this exists. It names them, and it says what they are waiting
/// for, because places alone cannot become an itinerary without dates.
class ImportedPlacesCard extends StatelessWidget {
  const ImportedPlacesCard({
    super.key,
    required this.places,
    required this.sourceCount,
    required this.onSeeAll,
    required this.onImportMore,
    this.awaitingDates = false,
  });

  final List<Place> places;
  final int sourceCount;
  final VoidCallback onSeeAll;
  final VoidCallback onImportMore;

  /// True on the no-dates screen, where the places cannot be planned yet.
  final bool awaitingDates;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    if (places.isEmpty) return const SizedBox.shrink();

    final names = places.take(3).map((p) => p.name).join(', ');
    final rest = places.length - 3;

    return Container(
      margin: const EdgeInsets.only(bottom: WayfareSpace.sectionGap),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
      decoration: BoxDecoration(
        color: WayfareColors.infoBgAlt,
        borderRadius: theme.cardLg,
        border: Border.all(color: WayfareColors.infoBorderAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WayfareEyebrow(
            'Saved from your links',
            color: WayfareColors.accent,
            size: 11.5,
          ),
          const SizedBox(height: 6),
          Text(
            '${places.length} ${places.length == 1 ? 'place' : 'places'} from '
            '$sourceCount ${sourceCount == 1 ? 'link' : 'links'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            rest > 0 ? '$names and $rest more.' : '$names.',
            style: WayfareType.body(13, color: WayfareColors.infoText),
          ),
          const SizedBox(height: 8),
          Text(
            awaitingDates
                ? 'They are saved. Set your dates and the planner builds the '
                    'itinerary around them.'
                : 'The planner works from these when it builds the itinerary.',
            style: WayfareType.body(12.5, color: WayfareColors.subhead),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: WayfareSecondaryButton(
                  label: 'See all ${places.length}',
                  onPressed: onSeeAll,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: WayfareSecondaryButton(
                  label: 'Add another link',
                  onPressed: onImportMore,
                  fontSize: 13.5,
                  background: Colors.transparent,
                  foreground: WayfareColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One route into a dated trip. [emphasis] marks the recommended one with a
/// filled CTA — a preference, not a restriction.
class _StartOption extends StatelessWidget {
  const _StartOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String cta;
  final bool emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Material(
      color: WayfareColors.surface,
      borderRadius: theme.cardLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.cardLg,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: theme.cardLg,
            border: Border.all(
              color: emphasis
                  ? WayfareColors.borderChip
                  : WayfareColors.borderSoft,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: WayfareColors.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: WayfareType.ui(16, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: WayfareType.body(13.5, color: WayfareColors.subhead),
              ),
              const SizedBox(height: 16),
              if (emphasis)
                WayfarePrimaryButton(label: cta, onPressed: onTap)
              else
                WayfareSecondaryButton(label: cta, onPressed: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dates are set but nothing is planned yet.
///
/// Leads with generating, because that is what the user came here to do.
/// Travellers are an improvement offered underneath, not a gate — sending
/// someone to the Group tab to unlock a button that was never locked is how
/// this screen used to read.
class _BlankState extends StatelessWidget {
  const _BlankState({
    required this.title,
    required this.note,
    required this.canGenerate,
    required this.onGenerate,
    required this.memberCount,
    required this.onGoToGroup,
    required this.onSetDestination,
  });

  final String title;
  final String note;
  final bool canGenerate;
  final VoidCallback onGenerate;
  final int memberCount;
  final VoidCallback onGoToGroup;
  final VoidCallback onSetDestination;

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
          if (canGenerate)
            WayfarePrimaryButton(
              label: 'Generate the itinerary',
              onPressed: onGenerate,
              fontSize: 14.5,
              weight: FontWeight.w500,
            )
          else ...[
            Text(
              'The planner needs somewhere to go before it can plan anything.',
              textAlign: TextAlign.center,
              style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
            ),
            const SizedBox(height: 10),
            // This said what was missing and left you to find where to fix it.
            WayfarePrimaryButton(
              label: 'Set the destination',
              onPressed: onSetDestination,
              fontSize: 14.5,
              weight: FontWeight.w500,
            ),
          ],
          if (WayfareFeatures.groups && memberCount < 2) ...[
            const SizedBox(height: 10),
            WayfareSecondaryButton(
              label: memberCount == 0
                  ? 'Add who is coming'
                  : 'Add another traveller',
              onPressed: onGoToGroup,
              fontSize: 13.5,
              foreground: WayfareColors.muted,
            ),
          ],
        ],
      ),
    );
  }
}

/// Dates exist, nothing is planned: two equal ways forward.
///
/// Same geometry, same size, same place in the reading order. The only
/// hierarchy is fill versus outline — writing it yourself is not a fallback
/// for people the planner failed, it is a way of working.
class ItineraryStartOptions extends StatelessWidget {
  const ItineraryStartOptions({
    super.key,
    required this.dayCount,
    required this.canGenerate,
    required this.onGenerate,
    required this.onWriteFirst,
    required this.onImportLink,
    required this.sourceCount,
    required this.importedPlaces,
    required this.onSeeReferences,
  });

  final int dayCount;
  final bool canGenerate;
  final VoidCallback onGenerate;
  final VoidCallback onWriteFirst;
  final VoidCallback onImportLink;

  /// How many links have already been read. Changes the first card from an
  /// invitation into a statement of what the planner is working from.
  final int sourceCount;

  final List<Place> importedPlaces;
  final VoidCallback onSeeReferences;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImportedPlacesCard(
          places: importedPlaces,
          sourceCount: sourceCount,
          onSeeAll: onSeeReferences,
          onImportMore: onImportLink,
        ),
        // First, and framed as the thing that saves you the typing. Generating
        // from nothing gives you a competent stranger's itinerary; generating
        // from your own saved posts is the reason to use this at all.
        // Only until something has been read: after that the card above
        // carries the count and the way to add more.
        if (importedPlaces.isEmpty) ...[
          _card(
            context,
            eyebrow: 'Start from what you saved',
            eyebrowColor: WayfareColors.accent,
            title: 'Paste a link you already saved',
            cta: 'Import a link',
            filled: true,
            onTap: onImportLink,
          ),
          const SizedBox(height: WayfareSpace.cardGap),
        ],
        _card(
          context,
          eyebrow: 'Have it planned',
          eyebrowColor: WayfareColors.accent,
          title: dayCount > 0
              ? 'Let the planner fill the $dayCount days'
              : 'Let the planner fill your days',
          cta: 'Generate the itinerary',
          filled: sourceCount > 0,
          onTap: canGenerate ? onGenerate : null,
        ),
        const SizedBox(height: WayfareSpace.cardGap),
        _card(
          context,
          eyebrow: 'Write it yourself',
          eyebrowColor: WayfareColors.writtenInk,
          title: 'Build it by hand',
          cta: 'Add the first activity',
          filled: false,
          onTap: onWriteFirst,
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required String eyebrow,
    required Color eyebrowColor,
    required String title,
    required String cta,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WayfareColors.surface,
        borderRadius: theme.cardLg,
        border: Border.all(color: WayfareColors.borderSoft, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: WayfareEyebrow(eyebrow, color: eyebrowColor, size: 10.5),
          ),
          const SizedBox(height: 8),
          Text(title, style: WayfareType.ui(16, weight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (filled)
            WayfarePrimaryButton(label: cta, onPressed: onTap)
          else
            WayfareSecondaryButton(
              label: cta,
              onPressed: onTap,
              // Outline in full ink rather than the muted border, so the two
              // cards read as siblings rather than primary and afterthought.
              foreground: WayfareColors.ink,
              weight: FontWeight.w600,
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
