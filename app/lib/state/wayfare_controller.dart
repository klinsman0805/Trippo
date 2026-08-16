import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/trippo_api.dart';
import '../models/flight.dart';
import '../models/plan.dart';
import '../models/trip.dart';

/// The four bottom tabs.
enum WayfareTab { itinerary, budget, group, chat }

/// Single controller behind the whole shell, mirroring the prototype's one
/// logic class rather than splitting state per tab.
///
/// The prototype fakes its data with `setTimeout`; this replaces those with API
/// calls while keeping the same optimistic and loading states, which is exactly
/// what the handoff asks for.
class WayfareController extends ChangeNotifier {
  WayfareController(this._api, this.tripId);

  final TrippoApi _api;
  final String tripId;

  // --- view state ---
  WayfareTab tab = WayfareTab.itinerary;
  int selectedDay = 1;
  bool sheetOpen = false;
  bool showOptional = true;

  /// Day changed by the last refinement — drives the "Updated from your last
  /// chat request." notice.
  int? updatedDay;

  // --- data ---
  Trip? trip;
  Plan? plan;

  /// Derived from the selected flights. Drives the short-day treatment on the
  /// Trip tab — which days lost slots, and why.
  DateEnvelope? dateEnvelope;

  /// Flight numbers behind the short days, by direction.
  ///
  /// A day cut short at the start is the arriving flight's doing; one cut
  /// short at the end is the departing flight's. Labelling both with the
  /// outbound number — as this did — told the user the wrong aircraft was
  /// ending their last day.
  String? outboundFlightLabel;
  String? returnFlightLabel;

  /// Which flight shortened this particular day.
  String? flightLabelFor(ShortDay short) =>
      short.reason == 'early_departure' ? returnFlightLabel : outboundFlightLabel;

  /// Opens the Flights screen from a short-day band. Wired by the shell,
  /// which owns navigation.
  VoidCallback? onSeeOtherFlights;
  List<ChatMessage> messages = const [];
  Set<String> acceptedConflicts = {};

  /// The last planning attempt that produced nothing. Takes over the Trip and
  /// Budget tabs until it is retried or dismissed.
  PlanFailure? failure;

  /// Answers typed or chosen so far, keyed by question id. Local until sent —
  /// the CTA counts these, so a half-filled form is a legitimate state.
  Map<String, String> answers = {};

  /// The traveller whose edit sheet is open, if any.
  String? editingMemberId;

  /// Set while an edit is in flight, so a double-tap cannot fire twice.
  bool savingActivity = false;

  /// Set after an edit that changes what the planner reconciled. The conflicts
  /// on screen were computed against the old preferences, so they are shown as
  /// out of date rather than quietly left looking current.
  bool conflictsMayBeStale = false;

  // --- transient ---
  bool loading = true;
  bool generating = false;
  bool thinking = false;
  String? error;

  /// Set when a link import was blocked and we're waiting for pasted text.
  /// The next composer message is routed to that source instead of the planner.
  String? pendingSourceId;

  bool get hasPlan => plan != null && plan!.itinerary.isNotEmpty;
  bool get isReady => hasPlan;
  List<Member> get members => trip?.members ?? const [];

  /// Travellers are optional.
  ///
  /// They make the plan more tailored — pace, access needs and the conflicts
  /// between them are what this planner is for — but a solo traveller, or
  /// someone who hasn't got round to adding the group yet, still gets a real
  /// itinerary. What the planner actually needs is somewhere to go.
  bool get canGenerate => trip != null && trip!.destinations.isNotEmpty;

  /// Whether the plan is missing the group context that makes it worth using.
  /// Not a blocker — a prompt.
  bool get wouldBenefitFromTravellers => members.length < 2;

  /// The planner asked questions instead of planning. The spec's rule is that
  /// the questions replace the itinerary rather than sitting beside it.
  bool get needsInfo =>
      plan != null &&
      plan!.status == PlanStatus.needsInfo &&
      plan!.clarifyingQuestions.isNotEmpty;

  List<ClarifyingQuestion> get questions =>
      plan?.clarifyingQuestions ?? const [];

  /// `Send 2 of 3 answers` — counts what is actually filled in.
  int get answeredCount =>
      questions.where((q) => (answers[q.id] ?? '').trim().isNotEmpty).length;

  /// A failure with nothing to show behind it takes the whole tab; one with a
  /// surviving plan does too, but the plan is still there when it's dismissed.
  bool get isFailed =>
      failure != null &&
      !generating &&
      (tab == WayfareTab.itinerary || tab == WayfareTab.budget);

  /// Trip/Budget before a plan exists show the blank state instead.
  bool get isBlank =>
      !generating &&
      !isReady &&
      !needsInfo &&
      (tab == WayfareTab.itinerary || tab == WayfareTab.budget);

  PlanDay? get currentDay {
    if (plan == null || plan!.itinerary.isEmpty) return null;
    return plan!.itinerary.firstWhere(
      (d) => d.day == selectedDay,
      orElse: () => plan!.itinerary.first,
    );
  }

  /// The current day's blocks, with optional ones filtered out when hidden.
  List<PlanBlock> get visibleBlocks {
    final day = currentDay;
    if (day == null) return const [];
    return showOptional ? day.blocks : day.blocks.where((b) => !b.optional).toList();
  }

  int memberIndex(String id) => members.indexWhere((m) => m.id == id);

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      trip = await _api.getTrip(tripId);
      final latest = await _api.latestPlan(tripId);
      plan = latest.plan?.plan;
      updatedDay = latest.updatedDay;
      acceptedConflicts = latest.accepted.toSet();
      messages = await _api.chatThread(tripId);
      failure = await _api.planFailure(tripId);
      answers = {};

      final flights = await _api.tripFlights(tripId);
      dateEnvelope = flights.envelope;
      outboundFlightLabel = _flightLabelFrom(flights.selections, 'outbound');
      returnFlightLabel = _flightLabelFrom(flights.selections, 'return');

      _clampSelectedDay();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  void goTo(WayfareTab next) {
    tab = next;
    sheetOpen = false; // Tab switch closes any open sheet.
    editingMemberId = null;
    notifyListeners();
  }

  void selectDay(int day) {
    selectedDay = day;
    notifyListeners();
  }

  void toggleOptional() {
    showOptional = !showOptional;
    notifyListeners();
  }

  /// Opens the add-traveller sheet. Clears any member being edited, so `+`
  /// after an edit adds someone rather than reopening the last person.
  void openSheet() {
    editingMemberId = null;
    sheetOpen = true;
    notifyListeners();
  }

  void closeSheet() {
    sheetOpen = false;
    editingMemberId = null;
    notifyListeners();
  }

  /// The header action: `+` opens the sheet on Group, everything else goes to
  /// Refine, per the handoff.
  void headerAction() {
    if (tab == WayfareTab.group) {
      openSheet();
    } else {
      goTo(WayfareTab.chat);
    }
  }

  // --- members ---

  Future<void> addMember(Member member) async {
    try {
      await _api.addMember(tripId, member);
      trip = await _api.getTrip(tripId);
      sheetOpen = false;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  Future<void> removeMember(String memberId) async {
    try {
      await _api.removeMember(tripId, memberId);
      trip = await _api.getTrip(tripId);
      // Losing a traveller changes what there was to reconcile, so the
      // compromises on screen no longer describe this group.
      if (plan?.conflicts.isNotEmpty ?? false) conflictsMayBeStale = true;
      editingMemberId = null;
      sheetOpen = false;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  Member? get editingMember =>
      members.where((m) => m.id == editingMemberId).firstOrNull;

  /// Open the edit sheet for one traveller. Same sheet as adding, prefilled.
  void editMember(String memberId) {
    editingMemberId = memberId;
    sheetOpen = true;
    notifyListeners();
  }

  Future<void> saveMember(String memberId, Member member) async {
    try {
      final result = await _api.updateMember(tripId, memberId, member);
      trip = await _api.getTrip(tripId);
      // Only claim staleness when there are conflicts to be stale — saying it
      // with no conflicts on screen is a warning about nothing.
      conflictsMayBeStale =
          result.conflictsMayBeStale && (plan?.conflicts.isNotEmpty ?? false);
      editingMemberId = null;
      sheetOpen = false;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  /// Dates without a flight behind them — the "not flying" path.
  ///
  /// Deliberately does not derive a date envelope: there is no arrival time to
  /// reason about, so no day is short. Inventing one would put a warning on a
  /// day that is perfectly fine.
  Future<void> setDatesByHand(DateTime start, DateTime end) async {
    try {
      trip = await _api.updateTrip(tripId, {
        'start_date': _isoDate(start),
        'end_date': _isoDate(end),
        'date_flexible': false,
      });
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // --- editing the itinerary by hand ---

  /// "Build it by hand" — days with nothing in them, ready to fill.
  Future<void> startBlankItinerary() async {
    try {
      plan = await _api.startBlankItinerary(tripId);
      selectedDay = plan!.itinerary.isEmpty ? 1 : plan!.itinerary.first.day.toInt();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  /// What regenerating would keep. Null when the plan cannot be read.
  Future<PinnedSummary?> loadPinnedSummary() async {
    try {
      return await _api.pinnedSummary(tripId);
    } on ApiException {
      return null;
    }
  }

  /// The one-way path: unpin everything, then replan.
  ///
  /// Unpinning first is what makes it real — the planner honours pins, so
  /// leaving them in place would quietly keep the work this button says it
  /// replaces.
  Future<void> replanEverything() async {
    final summary = await loadPinnedSummary();
    for (final pinned in summary?.pinned ?? const <PinnedActivity>[]) {
      try {
        plan = await _api.setPinned(tripId, pinned.id, false);
      } on ApiException catch (e) {
        error = e.message;
        notifyListeners();
        return;
      }
    }
    await generate();
  }

  /// Remove a day. The trip gets a day shorter, and the days after renumber.
  Future<void> deleteDay(int day) async {
    await _editPlan(() => _api.deleteDay(tripId, day));
    // The trip's own dates moved, so the header and chips need the new ones.
    try {
      trip = await _api.getTrip(tripId);
    } on ApiException catch (e) {
      error = e.message;
    }
    _clampSelectedDay();
    notifyListeners();
  }

  Future<void> addActivity(int day, Map<String, dynamic> activity) =>
      _editPlan(() => _api.addActivity(tripId, day, activity));

  Future<void> updateActivity(String blockId, Map<String, dynamic> activity) =>
      _editPlan(() => _api.updateActivity(tripId, blockId, activity));

  Future<void> removeActivity(String blockId) =>
      _editPlan(() => _api.removeActivity(tripId, blockId));

  Future<void> moveActivity(
    String blockId, {
    required int day,
    required TimeOfDay slot,
  }) async {
    await _editPlan(() => _api.moveActivity(
          tripId,
          blockId,
          day: day,
          timeOfDay: timeOfDayTo(slot),
        ));
    // Follow the activity, so the move is visible rather than taken on trust.
    selectedDay = day;
    notifyListeners();
  }

  /// Reorder within a slot. Across slots is [moveActivity]'s job — the slot
  /// decides that, not the user's finger.
  Future<void> reorderActivity(String blockId, int toIndex) =>
      _editPlan(() => _api.reorderActivity(tripId, blockId, toIndex));

  Future<void> setPinned(String blockId, bool pinned) =>
      _editPlan(() => _api.setPinned(tripId, blockId, pinned));

  /// One hand-edit. Every one returns the whole plan, so state is replaced
  /// wholesale rather than patched locally — there is no second copy to drift.
  Future<void> _editPlan(Future<Plan> Function() edit) async {
    if (savingActivity) return;
    savingActivity = true;
    notifyListeners();

    try {
      plan = await edit();
      _clampSelectedDay();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }

    savingActivity = false;
    notifyListeners();
  }

  /// Blocks on the current day, in the slot given.
  List<PlanBlock> blocksIn(TimeOfDay slot) =>
      (currentDay?.blocks ?? const []).where((b) => b.timeOfDay == slot).toList();

  /// Named slots with nothing in them. `anytime` is deliberately excluded —
  /// it is not a part of the day, so it cannot be "open".
  List<TimeOfDay> get openSlots => [
        for (final slot in const [
          TimeOfDay.morning,
          TimeOfDay.afternoon,
          TimeOfDay.evening,
        ])
          if (blocksIn(slot).isEmpty) slot,
      ];

  /// `2 of 3 slots filled` — counts only the three the flight envelope acts on.
  int slotsFilledOn(PlanDay day) => const [
        TimeOfDay.morning,
        TimeOfDay.afternoon,
        TimeOfDay.evening,
      ].where((s) => day.blocks.any((b) => b.timeOfDay == s)).length;

  bool dayIsEmpty(PlanDay day) => day.blocks.isEmpty;

  // --- planning ---

  /// Generate or regenerate. Shows the full-screen overlay for the duration,
  /// then lands on Trip / Day 1 as the prototype does.
  Future<void> generate() async {
    if (!canGenerate) return;
    await _runPlanning(() => _api.generatePlan(tripId));
  }

  /// Send the answers the group filled in, then re-plan.
  Future<void> sendAnswers() async {
    if (answeredCount == 0) return;
    final sent = Map<String, String>.from(answers);
    await _runPlanning(
      () => _api.answerQuestions(tripId, answers: sent),
      // Keep them until the round trip succeeds — a failure that also wiped
      // what they typed would be two losses instead of one.
      clearAnswersOnSuccess: true,
    );
  }

  /// "Plan without these" — proceed on assumptions rather than answers.
  Future<void> planWithoutAnswers() => _runPlanning(
        () => _api.answerQuestions(tripId, planAnyway: true),
        clearAnswersOnSuccess: true,
      );

  void setAnswer(String questionId, String answer) {
    if (answer.trim().isEmpty) {
      answers = {...answers}..remove(questionId);
    } else {
      answers = {...answers, questionId: answer};
    }
    notifyListeners();
  }

  /// Retry after a failure. Same path as a first attempt, deliberately — a
  /// retry that behaves differently is a retry the user cannot reason about.
  Future<void> retryPlanning() async {
    failure = null;
    notifyListeners();
    await generate();
  }

  /// Keep what's already there and stop showing the failure.
  Future<void> dismissFailure() async {
    failure = null;
    notifyListeners();
    try {
      await _api.dismissPlanFailure(tripId);
    } on ApiException {
      // The state the user asked for is already gone from the screen; a failed
      // dismissal would only reappear on the next load, which is recoverable.
    }
  }

  /// One planning run, whichever door it came in by.
  ///
  /// The overlay, the landing tab and — crucially — the failure handling are
  /// the same for a first plan, an answered question and a retry.
  Future<void> _runPlanning(
    Future<PlanRevision> Function() run, {
    bool clearAnswersOnSuccess = false,
  }) async {
    generating = true;
    tab = WayfareTab.itinerary;
    sheetOpen = false;
    failure = null;
    notifyListeners();

    try {
      final revision = await run();
      plan = revision.plan;
      selectedDay = 1;
      updatedDay = null; // A fresh plan has no "changed by chat" day.
      if (clearAnswersOnSuccess) answers = {};
      conflictsMayBeStale = false;
      messages = await _api.chatThread(tripId);
      error = null;
    } on ApiException catch (e) {
      // The server recorded why it stopped and what survived; read that back
      // rather than inventing a second account of the same event here.
      try {
        failure = await _api.planFailure(tripId);
      } on ApiException {
        failure = null;
      }
      if (failure == null) error = e.message;
    }

    generating = false;
    notifyListeners();
  }

  /// Send one Refine turn.
  ///
  /// Appends the user's bubble immediately and shows the thinking indicator, so
  /// the conversation feels responsive across a call that can run for minutes.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || thinking) return;

    messages = [...messages, ChatMessage(role: 'user', text: message)];
    thinking = true;
    tab = WayfareTab.chat;
    sheetOpen = false;
    notifyListeners();

    try {
      final result = await _api.refine(
        tripId,
        message,
        pendingSourceId: pendingSourceId,
      );
      pendingSourceId = result.awaitingPaste ? result.pendingSourceId : null;

      if (result.plan != null) {
        plan = result.plan!.plan;
        updatedDay = result.updatedDay;
        // Jump to the day that changed so the update is visible, not buried.
        if (result.updatedDay != null) selectedDay = result.updatedDay!;
        _clampSelectedDay();
      }

      // Re-derive the thread so the bubbles match what the server stored,
      // rather than trusting the optimistic copy.
      messages = await _api.chatThread(tripId);
      if (result.reply != null) {
        messages = [...messages, ChatMessage(role: 'bot', text: result.reply!)];
      }
      error = null;
    } on ApiException catch (e) {
      messages = [
        ...messages,
        ChatMessage(role: 'bot', text: 'That didn\'t work: ${e.message}'),
      ];
    }

    thinking = false;
    notifyListeners();
  }

  // --- conflicts ---

  bool isAccepted(String tag) => acceptedConflicts.contains(tag);

  Future<void> toggleAccepted(String tag) async {
    final next = !isAccepted(tag);
    // Optimistic: the round trip is short and the toggle should feel instant.
    if (next) {
      acceptedConflicts = {...acceptedConflicts, tag};
    } else {
      acceptedConflicts = {...acceptedConflicts}..remove(tag);
    }
    notifyListeners();

    try {
      final server = await _api.acceptConflict(tripId, tag, accepted: next);
      acceptedConflicts = server.toSet();
    } on ApiException catch (e) {
      error = e.message;
      await load(); // Fall back to server truth if the write failed.
    }
    notifyListeners();
  }

  /// "Discuss" on a conflict card: opens the conversation with a concrete ask.
  Future<void> discussConflict(Conflict conflict) =>
      send('About the ${conflict.tag.toLowerCase()} issue — '
          '${conflict.description} Can you adjust the plan for that?');

  /// "Flight AK893" from the stored selection going the given way.
  static String? _flightLabelFrom(
    List<Map<String, dynamic>> selections,
    String direction,
  ) {
    for (final selection in selections) {
      final offer = selection['offer'] as Map<String, dynamic>?;
      final itineraries = offer?['itineraries'] as List?;
      final match = itineraries?.firstWhere(
        (i) => (i as Map)['direction'] == direction,
        orElse: () => null,
      );
      final segments = (match as Map?)?['segments'] as List?;
      final number = (segments?.firstOrNull as Map?)?['flight_number'] as String?;
      if (number != null && number.isNotEmpty) return 'Flight $number';
    }
    return null;
  }

  void _clampSelectedDay() {
    final days = plan?.itinerary ?? const [];
    if (days.isEmpty) {
      selectedDay = 1;
      return;
    }
    if (!days.any((d) => d.day == selectedDay)) {
      selectedDay = days.first.day.toInt();
    }
  }
}


extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
