/// Dart mirror of the planner's output schema.
///
/// Keep this in sync with `server/src/schemas/plan.ts` — that file is the
/// source of truth, since it is what constrains the model's output.
library;

List<String> _strings(dynamic value) =>
    (value as List?)?.map((e) => e.toString()).toList() ?? const [];

enum PlanStatus { complete, needsInfo, infeasible }

PlanStatus planStatusFrom(String? value) => switch (value) {
      'needs_info' => PlanStatus.needsInfo,
      'infeasible' => PlanStatus.infeasible,
      _ => PlanStatus.complete,
    };

enum TimeOfDay { morning, afternoon, evening }

TimeOfDay timeOfDayFrom(String? value) => switch (value) {
      'afternoon' => TimeOfDay.afternoon,
      'evening' => TimeOfDay.evening,
      _ => TimeOfDay.morning,
    };

/// One budget category: what was intended against what the plan costs.
/// The Budget tab draws these as two stacked bars.
class CategoryBudget {
  const CategoryBudget({
    required this.name,
    required this.planned,
    required this.estimated,
  });

  final String name;
  final num planned;
  final num estimated;

  num get delta => estimated - planned;
  bool get isOver => delta > 0;

  /// "on plan" when the gap is small enough not to matter to the reader.
  bool get isOnPlan => delta.abs() < 1;

  factory CategoryBudget.fromJson(String name, Map<String, dynamic> json) =>
      CategoryBudget(
        name: name,
        planned: json['planned'] as num? ?? 0,
        estimated: json['estimated'] as num? ?? 0,
      );
}

class BudgetBreakdown {
  const BudgetBreakdown(this.categories);

  /// Ordered lodging → transport → food → activities → buffer, as designed.
  final List<CategoryBudget> categories;

  /// The largest single value across all categories, which every bar is drawn
  /// as a fraction of.
  num get peak => categories.fold<num>(
        0,
        (max, c) => [max, c.planned, c.estimated].reduce((a, b) => a > b ? a : b),
      );

  static const _order = ['lodging', 'transport', 'food', 'activities', 'buffer'];

  factory BudgetBreakdown.fromJson(Map<String, dynamic> json) => BudgetBreakdown([
        for (final name in _order)
          if (json[name] is Map<String, dynamic>)
            CategoryBudget.fromJson(name, json[name] as Map<String, dynamic>),
      ]);
}

class TripSummary {
  const TripSummary({
    required this.title,
    required this.destinations,
    required this.durationDays,
    required this.currency,
    required this.estimatedTotalCost,
    required this.overBudget,
    required this.budgetBreakdown,
    this.startDate,
    this.endDate,
    this.totalBudget,
    this.assumptions = const [],
  });

  final String title;
  final List<String> destinations;
  final String? startDate;
  final String? endDate;
  final num durationDays;
  final String currency;
  final num? totalBudget;
  final BudgetBreakdown budgetBreakdown;
  final num estimatedTotalCost;

  /// When true, the client must visually flag the budget section per the spec.
  final bool overBudget;
  final List<String> assumptions;

  factory TripSummary.fromJson(Map<String, dynamic> json) => TripSummary(
        title: json['title'] as String? ?? '',
        destinations: _strings(json['destinations']),
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        durationDays: json['duration_days'] as num? ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        totalBudget: json['total_budget'] as num?,
        budgetBreakdown: BudgetBreakdown.fromJson(
          json['budget_breakdown'] as Map<String, dynamic>? ?? const {},
        ),
        estimatedTotalCost: json['estimated_total_cost'] as num? ?? 0,
        overBudget: json['over_budget'] as bool? ?? false,
        assumptions: _strings(json['assumptions']),
      );
}

/// A conflict the planner surfaced rather than silently resolving. The spec is
/// explicit that these should be shown prominently, not buried.
class Conflict {
  const Conflict({
    required this.tag,
    required this.description,
    required this.membersInvolved,
    required this.resolution,
  });

  /// Pace / Mobility / Food / Budget / Interests — rendered as the card's pill.
  final String tag;
  final String description;
  final List<String> membersInvolved;
  final String resolution;

  factory Conflict.fromJson(Map<String, dynamic> json) => Conflict(
        tag: json['tag'] as String? ?? 'Pace',
        description: json['description'] as String? ?? '',
        membersInvolved: _strings(json['members_involved']),
        resolution: json['resolution'] as String? ?? '',
      );
}

class PlanBlock {
  const PlanBlock({
    required this.timeOfDay,
    required this.activity,
    required this.description,
    required this.location,
    required this.estimatedDurationMinutes,
    required this.suitedForMembers,
    required this.optional,
    this.estimatedCostPerPerson,
    this.weatherBackup,
  });

  final TimeOfDay timeOfDay;
  final String activity;
  final String description;
  final String location;
  final num estimatedDurationMinutes;
  final num? estimatedCostPerPerson;

  /// Member ids. Fewer than the full group means this is a split-group block.
  final List<String> suitedForMembers;
  final bool optional;
  final String? weatherBackup;

  factory PlanBlock.fromJson(Map<String, dynamic> json) => PlanBlock(
        timeOfDay: timeOfDayFrom(json['time_of_day'] as String?),
        activity: json['activity'] as String? ?? '',
        description: json['description'] as String? ?? '',
        location: json['location'] as String? ?? '',
        estimatedDurationMinutes: json['estimated_duration_minutes'] as num? ?? 0,
        estimatedCostPerPerson: json['estimated_cost_per_person'] as num?,
        suitedForMembers: _strings(json['suited_for_members']),
        optional: json['optional'] as bool? ?? false,
        weatherBackup: json['weather_backup'] as String?,
      );
}

class PlanDay {
  const PlanDay({
    required this.day,
    required this.location,
    required this.blocks,
    this.date,
    this.lodgingAreaSuggestion,
    this.notes,
  });

  final num day;
  final String? date;
  final String location;
  final String? lodgingAreaSuggestion;
  final List<PlanBlock> blocks;
  final String? notes;

  /// Per-person cost for the day — the sum of its blocks, as the design's
  /// "€75 pp planned" label. Optional blocks count only when shown.
  num costPerPerson({bool includeOptional = true}) => blocks
      .where((b) => includeOptional || !b.optional)
      .fold<num>(0, (sum, b) => sum + (b.estimatedCostPerPerson ?? 0));

  factory PlanDay.fromJson(Map<String, dynamic> json) => PlanDay(
        day: json['day'] as num? ?? 0,
        date: json['date'] as String?,
        location: json['location'] as String? ?? '',
        lodgingAreaSuggestion: json['lodging_area_suggestion'] as String?,
        blocks: (json['blocks'] as List? ?? const [])
            .map((b) => PlanBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
        notes: json['notes'] as String?,
      );
}

class PlanMember {
  const PlanMember({required this.id, required this.name});

  final String id;
  final String name;

  factory PlanMember.fromJson(Map<String, dynamic> json) => PlanMember(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// A question the planner needs answered, rendered as a numbered card on the
/// Trip tab when the plan is [PlanStatus.needsInfo].
class ClarifyingQuestion {
  const ClarifyingQuestion({
    required this.id,
    required this.question,
    required this.why,
    required this.answerType,
    this.options = const [],
    this.placeholder,
  });

  final String id;
  final String question;

  /// What changes depending on the answer — shown under the question.
  final String why;

  /// 'choice' renders single-select chips; 'text' renders an input.
  final String answerType;
  final List<String> options;
  final String? placeholder;

  bool get isChoice => answerType == 'choice';

  factory ClarifyingQuestion.fromJson(Map<String, dynamic> json) =>
      ClarifyingQuestion(
        id: json['id'] as String? ?? '',
        question: json['question'] as String? ?? '',
        why: json['why'] as String? ?? '',
        answerType: json['answer_type'] as String? ?? 'text',
        options: _strings(json['options']),
        placeholder: json['placeholder'] as String?,
      );
}

/// The last planning attempt that produced nothing.
///
/// Deliberately worded against revisions rather than days: a planning run
/// either writes a revision or it doesn't, so "it planned days 1 and 2" is not
/// a state this system can be in. [lastGoodRevision] is what actually survived.
class PlanFailure {
  const PlanFailure({
    required this.reasonCode,
    required this.reason,
    required this.elapsedMs,
    required this.at,
    this.lastGoodRevision,
    this.lastGoodDays,
    this.userRequest,
  });

  final String reasonCode;

  /// One plain sentence, already worded by the server. Shown as-is.
  final String reason;
  final int elapsedMs;
  final DateTime at;

  /// The revision still on the trip, or null when nothing was ever planned.
  final int? lastGoodRevision;
  final int? lastGoodDays;

  /// The refinement being attempted, when the failure came from one.
  final String? userRequest;

  /// Whether there is a plan to fall back to. Drives which actions are offered.
  bool get hasFallback => lastGoodRevision != null;

  /// `STOPPED AT 14:32` — local time, since that's when the user saw it stop.
  String get stoppedAtLabel {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  factory PlanFailure.fromJson(Map<String, dynamic> json) => PlanFailure(
        reasonCode: json['reason_code'] as String? ?? 'unknown',
        reason: json['reason'] as String? ?? 'The planner stopped',
        elapsedMs: (json['elapsed_ms'] as num?)?.toInt() ?? 0,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        lastGoodRevision: (json['last_good_revision'] as num?)?.toInt(),
        lastGoodDays: (json['last_good_days'] as num?)?.toInt(),
        userRequest: json['user_request'] as String?,
      );
}

class Plan {
  const Plan({
    required this.conversationalSummary,
    required this.status,
    required this.trip,
    this.missingInfo = const [],
    this.members = const [],
    this.conflicts = const [],
    this.itinerary = const [],
    this.packingAndPrepNotes = const [],
    this.verifyBeforeBooking = const [],
    this.clarifyingQuestions = const [],
  });

  /// Part A — the prose the user reads.
  final String conversationalSummary;
  final PlanStatus status;
  final List<String> missingInfo;
  final TripSummary trip;
  final List<PlanMember> members;
  final List<Conflict> conflicts;
  final List<PlanDay> itinerary;
  final List<String> packingAndPrepNotes;
  final List<String> verifyBeforeBooking;
  final List<ClarifyingQuestion> clarifyingQuestions;

  /// The spec's rule: on needs_info, show questions instead of an itinerary.
  bool get shouldRenderItinerary =>
      status != PlanStatus.needsInfo && itinerary.isNotEmpty;

  String nameForMember(String id) =>
      members.where((m) => m.id == id).map((m) => m.name).firstOrNull ?? id;

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        conversationalSummary: json['conversational_summary'] as String? ?? '',
        status: planStatusFrom(json['status'] as String?),
        missingInfo: _strings(json['missing_info']),
        trip: TripSummary.fromJson(
          json['trip'] as Map<String, dynamic>? ?? const {},
        ),
        members: (json['members'] as List? ?? const [])
            .map((m) => PlanMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        conflicts: (json['conflicts'] as List? ?? const [])
            .map((c) => Conflict.fromJson(c as Map<String, dynamic>))
            .toList(),
        itinerary: (json['itinerary'] as List? ?? const [])
            .map((d) => PlanDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        packingAndPrepNotes: _strings(json['packing_and_prep_notes']),
        verifyBeforeBooking: _strings(json['verify_before_booking']),
        clarifyingQuestions: (json['clarifying_questions'] as List? ?? const [])
            .map((q) => ClarifyingQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

/// A stored plan revision. Refinements produce a new revision rather than
/// mutating the last one, so the group can compare or roll back.
class PlanRevision {
  const PlanRevision({
    required this.id,
    required this.revision,
    required this.plan,
    required this.createdAt,
    this.userRequest,
  });

  final String id;
  final int revision;
  final Plan plan;
  final DateTime createdAt;
  final String? userRequest;

  factory PlanRevision.fromJson(Map<String, dynamic> json) => PlanRevision(
        id: json['id'] as String,
        revision: (json['revision'] as num?)?.toInt() ?? 1,
        plan: Plan.fromJson(json['plan'] as Map<String, dynamic>),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        userRequest: json['user_request'] as String?,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// One bubble in the Refine tab. Derived server-side from plan revisions.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.revision = 0,
  });

  final String role; // 'user' | 'bot'
  final String text;
  final int revision;

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String? ?? 'bot',
        text: json['text'] as String? ?? '',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
      );
}

/// The outcome of one Refine turn. Exactly one of [plan] or [reply] is set:
/// a link import answers conversationally, an instruction returns a new plan.
class RefineResult {
  const RefineResult({
    this.plan,
    this.reply,
    this.awaitingPaste = false,
    this.pendingSourceId,
    this.importedPlaceCount = 0,
    this.updatedDay,
  });

  final PlanRevision? plan;
  final String? reply;

  /// The source was blocked; the next message should be the pasted text.
  final bool awaitingPaste;
  final String? pendingSourceId;
  final int importedPlaceCount;
  final int? updatedDay;

  factory RefineResult.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'] as Map<String, dynamic>?;
    final importJson = json['import'] as Map<String, dynamic>?;
    return RefineResult(
      plan: planJson == null ? null : PlanRevision.fromJson(planJson),
      reply: json['reply'] as String?,
      awaitingPaste: json['awaiting_paste'] as bool? ?? false,
      pendingSourceId: json['pending_source_id'] as String?,
      importedPlaceCount: (importJson?['places'] as List?)?.length ?? 0,
      updatedDay: (json['updated_day'] as num?)?.toInt(),
    );
  }
}
