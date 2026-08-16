/// Data model mirroring the backend's trip + member records.
///
/// Hand-written rather than code-generated: the shapes are stable and small
/// enough that a build_runner step would cost more than it saves.
library;

enum Pace { packed, moderate, relaxed }

Pace paceFrom(String? value) => switch (value) {
      'packed' => Pace.packed,
      'relaxed' => Pace.relaxed,
      _ => Pace.moderate,
    };

String paceTo(Pace pace) => pace.name;

List<String> _strings(dynamic value) =>
    (value as List?)?.map((e) => e.toString()).toList() ?? const [];

class Member {
  const Member({
    required this.id,
    required this.name,
    this.departureCity,
    this.interests = const [],
    this.pace = Pace.moderate,
    this.budgetSensitivity,
    this.dietaryRestrictions = const [],
    this.accessibilityNeeds = const [],
    this.dealBreakers = const [],
    this.wants = const [],
    this.avoids = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String? departureCity;
  final List<String> interests;
  final Pace pace;
  final String? budgetSensitivity;
  final List<String> dietaryRestrictions;
  final List<String> accessibilityNeeds;
  final List<String> dealBreakers;
  final List<String> wants;
  final List<String> avoids;

  /// When they were added to the trip — the edit sheet's provenance line.
  /// Null for a member being created, which has no history yet.
  final DateTime? createdAt;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        name: json['name'] as String,
        departureCity: json['departure_city'] as String?,
        interests: _strings(json['interests']),
        pace: paceFrom(json['pace'] as String?),
        budgetSensitivity: json['budget_sensitivity'] as String?,
        dietaryRestrictions: _strings(json['dietary_restrictions']),
        accessibilityNeeds: _strings(json['accessibility_needs']),
        dealBreakers: _strings(json['deal_breakers']),
        wants: _strings(json['wants']),
        avoids: _strings(json['avoids']),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );

  /// Shape the POST /trips and POST /trips/:id/members endpoints accept.
  Map<String, dynamic> toJson() => {
        'name': name,
        if (departureCity != null) 'departure_city': departureCity,
        'interests': interests,
        'pace': paceTo(pace),
        if (budgetSensitivity != null) 'budget_sensitivity': budgetSensitivity,
        'dietary_restrictions': dietaryRestrictions,
        'accessibility_needs': accessibilityNeeds,
        'deal_breakers': dealBreakers,
        'wants': wants,
        'avoids': avoids,
      };
}

class Trip {
  const Trip({
    required this.id,
    required this.title,
    this.destinations = const [],
    this.startDate,
    this.endDate,
    this.dateFlexible = true,
    this.currency = 'USD',
    this.totalBudget,
    this.budgetBasis = 'total',
    this.purpose,
    this.hardConstraints = const [],
    this.notes,
    this.members = const [],
    this.countedMembers,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<String> destinations;
  final String? startDate;
  final String? endDate;
  final bool dateFlexible;
  final String currency;
  final num? totalBudget;
  final String budgetBasis;
  final String? purpose;
  final List<String> hardConstraints;
  final String? notes;
  /// Fully hydrated by `GET /trips/:id`; empty in the list response.
  final List<Member> members;
  final DateTime updatedAt;

  /// Sent by the list endpoint, which counts members rather than loading them.
  /// Null from `GET /trips/:id`, where [members] is populated instead.
  final int? countedMembers;

  /// How many travellers this trip has, whether or not they were hydrated.
  int get memberCount => countedMembers ?? members.length;

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        title: json['title'] as String,
        destinations: _strings(json['destinations']),
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        dateFlexible: json['date_flexible'] as bool? ?? true,
        currency: json['currency'] as String? ?? 'USD',
        totalBudget: json['total_budget'] as num?,
        budgetBasis: json['budget_basis'] as String? ?? 'total',
        purpose: json['purpose'] as String?,
        hardConstraints: _strings(json['hard_constraints']),
        notes: json['notes'] as String?,
        members: (json['members'] as List? ?? const [])
            .map((m) => Member.fromJson(m as Map<String, dynamic>))
            .toList(),
        countedMembers: (json['member_count'] as num?)?.toInt(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class Place {
  const Place({
    required this.id,
    required this.name,
    this.category,
    this.city,
    this.address,
    this.lat,
    this.lng,
    this.why,
    this.tags = const [],
    this.resolved = false,
    this.sourceId,
  });

  final String id;
  final String name;
  final String? category;
  final String? city;
  final String? address;
  final double? lat;
  final double? lng;
  final String? why;
  final List<String> tags;

  /// True once geocoded — only resolved places can go into the travel matrix.
  final bool resolved;
  final String? sourceId;

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        city: json['city'] as String?,
        address: json['address'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        why: json['why'] as String?,
        tags: _strings(json['tags']),
        resolved: json['resolved'] as bool? ?? false,
        sourceId: json['source_id'] as String?,
      );
}

/// An imported link. `status == needsManual` is a normal branch, not an error:
/// 小红书 and other walled sources routinely land here and the UI must offer a
/// paste box rather than treating the import as failed.
enum SourceStatus { pending, fetched, extracted, failed, needsManual }

SourceStatus sourceStatusFrom(String? value) => switch (value) {
      'fetched' => SourceStatus.fetched,
      'extracted' => SourceStatus.extracted,
      'failed' => SourceStatus.failed,
      'needs_manual' => SourceStatus.needsManual,
      _ => SourceStatus.pending,
    };

class TripSource {
  const TripSource({
    required this.id,
    required this.kind,
    required this.status,
    this.url,
    this.title,
    this.author,
    this.error,
  });

  final String id;
  final String kind;
  final SourceStatus status;
  final String? url;
  final String? title;
  final String? author;
  final String? error;

  bool get needsManualInput => status == SourceStatus.needsManual;

  factory TripSource.fromJson(Map<String, dynamic> json) => TripSource(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? 'web',
        status: sourceStatusFrom(json['status'] as String?),
        url: json['url'] as String?,
        title: json['title'] as String?,
        author: json['author'] as String?,
        error: json['error'] as String?,
      );
}

class ImportResult {
  const ImportResult({
    required this.source,
    required this.places,
    required this.manualInputRequired,
    this.summary,
    this.planningNotes = const [],
    this.message,
  });

  final TripSource source;
  final List<Place> places;
  final bool manualInputRequired;
  final String? summary;
  final List<String> planningNotes;
  final String? message;

  factory ImportResult.fromJson(Map<String, dynamic> json) => ImportResult(
        source: TripSource.fromJson(json['source'] as Map<String, dynamic>),
        places: (json['places'] as List? ?? const [])
            .map((p) => Place.fromJson(p as Map<String, dynamic>))
            .toList(),
        manualInputRequired: json['manual_input_required'] as bool? ?? false,
        summary: json['summary'] as String?,
        planningNotes: _strings(json['planning_notes']),
        message: json['message'] as String?,
      );
}
