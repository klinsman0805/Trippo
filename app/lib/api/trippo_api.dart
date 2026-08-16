import '../models/flight.dart';
import '../models/plan.dart';
import '../models/trip.dart';
import 'api_client.dart';

/// Typed wrapper over every backend route. One method per endpoint, no state —
/// state lives in the repository layer above this.
class TrippoApi {
  TrippoApi(this._client);

  final ApiClient _client;

  // --- health ---

  /// Which optional integrations the server actually has keys for. Call this at
  /// startup so the UI can disable features instead of failing at tap time.
  Future<Map<String, dynamic>> features() async {
    final json = await _client.getUnversioned('/health');
    return json['features'] as Map<String, dynamic>? ?? const {};
  }

  // --- trips ---

  Future<List<Trip>> listTrips() async {
    final json = await _client.get('/trips');
    return (json['trips'] as List)
        .map((t) => Trip.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Trip> getTrip(String id) async {
    final json = await _client.get('/trips/$id');
    return Trip.fromJson(json['trip'] as Map<String, dynamic>);
  }

  Future<Trip> createTrip({
    required String title,
    List<String> destinations = const [],
    String currency = 'USD',
    num? totalBudget,
    String budgetBasis = 'total',
    String? startDate,
    String? endDate,
    bool dateFlexible = true,
    String? purpose,
    List<String> hardConstraints = const [],
    String? notes,
    List<Member> members = const [],
  }) async {
    final json = await _client.post('/trips', body: {
      'title': title,
      'destinations': destinations,
      'currency': currency,
      'total_budget': ?totalBudget,
      'budget_basis': budgetBasis,
      'start_date': ?startDate,
      'end_date': ?endDate,
      'date_flexible': dateFlexible,
      'purpose': ?purpose,
      'hard_constraints': hardConstraints,
      'notes': ?notes,
      'members': members.map((m) => m.toJson()).toList(),
    });
    return Trip.fromJson(json['trip'] as Map<String, dynamic>);
  }

  Future<Trip> updateTrip(String id, Map<String, dynamic> patch) async {
    final json = await _client.patch('/trips/$id', body: patch);
    return Trip.fromJson(json['trip'] as Map<String, dynamic>);
  }

  Future<void> deleteTrip(String id) => _client.delete('/trips/$id');

  Future<Member> addMember(String tripId, Member member) async {
    final json = await _client.post('/trips/$tripId/members', body: member.toJson());
    return Member.fromJson(json['member'] as Map<String, dynamic>);
  }

  /// Edit a traveller in place.
  ///
  /// Returns whether the conflicts the planner reconciled are now stale —
  /// changing someone's pace or access needs invalidates the compromises it
  /// made, and the UI is expected to say so rather than show them as current.
  Future<({Member member, bool conflictsMayBeStale})> updateMember(
    String tripId,
    String memberId,
    Member member,
  ) async {
    final json = await _client.patch(
      '/trips/$tripId/members/$memberId',
      body: member.toJson(),
    );
    return (
      member: Member.fromJson(json['member'] as Map<String, dynamic>),
      conflictsMayBeStale: json['conflicts_may_be_stale'] as bool? ?? false,
    );
  }

  Future<void> removeMember(String tripId, String memberId) =>
      _client.delete('/trips/$tripId/members/$memberId');

  // --- link ingestion ---

  Future<List<TripSource>> listSources(String tripId) async {
    final json = await _client.get('/trips/$tripId/sources');
    return (json['sources'] as List)
        .map((s) => TripSource.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Import a link. Accepts raw share text — the server pulls the URL out, so
  /// a 小红书 clipboard paste can be handed over untouched.
  ///
  /// Check [ImportResult.manualInputRequired]: when true the fetch was blocked
  /// and the user must paste the text via [importText] with the same source id.
  Future<ImportResult> importUrl(String tripId, String urlOrShareText) async {
    final json = await _client.postLongRunning(
      '/trips/$tripId/sources/url',
      body: {'url': urlOrShareText},
    );
    return ImportResult.fromJson(json);
  }

  /// Import from pasted text. Pass [sourceId] to complete a previously blocked
  /// import instead of creating a second source row for the same link.
  Future<ImportResult> importText(
    String tripId,
    String text, {
    String? title,
    String? kind,
    String? sourceId,
  }) async {
    final json = await _client.postLongRunning(
      '/trips/$tripId/sources/text',
      body: {
        'text': text,
        'title': ?title,
        'kind': ?kind,
        'source_id': ?sourceId,
      },
    );
    return ImportResult.fromJson(json);
  }

  Future<void> deleteSource(String tripId, String sourceId) =>
      _client.delete('/trips/$tripId/sources/$sourceId');

  // --- saved places ---

  Future<List<Place>> listPlaces(String tripId) async {
    final json = await _client.get('/trips/$tripId/places');
    return (json['places'] as List)
        .map((p) => Place.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Place> addPlace(String tripId, Map<String, dynamic> place) async {
    final json = await _client.post('/trips/$tripId/places', body: place);
    return Place.fromJson(json['place'] as Map<String, dynamic>);
  }

  Future<void> deletePlace(String tripId, String placeId) =>
      _client.delete('/trips/$tripId/places/$placeId');

  /// Geocode saved places so the planner can cluster them geographically.
  /// Returns the counts of resolved vs failed lookups.
  Future<Map<String, dynamic>> resolvePlaces(
    String tripId, {
    List<String>? placeIds,
  }) =>
      _client.postLongRunning(
        '/trips/$tripId/places/resolve',
        body: {'place_ids': ?placeIds},
      );

  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final json = await _client.get('/places/search', query: {
      'q': query,
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
    });
    return (json['places'] as List).cast<Map<String, dynamic>>();
  }

  // --- flights ---

  Future<List<Airport>> searchAirports(String query) async {
    final json = await _client.get('/flights/airports', query: {'q': query});
    return (json['airports'] as List)
        .map((a) => Airport.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<FlightSearchResult> searchFlights({
    required String origin,
    required String destination,
    required String departureDate,
    String? returnDate,
    int adults = 1,
    String cabin = 'ECONOMY',
    bool nonStop = false,
    String currency = 'USD',
  }) async {
    final json = await _client.postLongRunning('/flights/search', body: {
      'origin': origin,
      'destination': destination,
      'departure_date': departureDate,
      'return_date': ?returnDate,
      'adults': adults,
      'cabin': cabin,
      'non_stop': nonStop,
      'currency': currency,
    });
    return FlightSearchResult.fromJson(json);
  }

  /// Look up a flight the group has already booked.
  ///
  /// Returns null when the provider has no record of that number on that date
  /// — a mistyped digit, usually. That is a normal answer the form shows
  /// against the field, not an error, so it is not an exception.
  Future<FlightOffer?> lookupFlight({
    required String flightNumber,
    required String scheduledDate,
    String direction = 'outbound',
  }) async {
    final json = await _client.post('/flights/by-number', body: {
      'flight_number': flightNumber,
      'scheduled_date': scheduledDate,
      'direction': direction,
    });
    final offer = json['offer'] as Map<String, dynamic>?;
    return offer == null ? null : FlightOffer.fromJson(offer);
  }

  /// What an offer would do to the trip, without committing to it. Feeds the
  /// consequence sheet, which confirms before the dates move.
  Future<DateEnvelope?> previewEnvelope(FlightOffer offer) async {
    final json = await _client.post(
      '/flights/envelope-preview',
      body: {'offer': offer.raw},
    );
    final envelope = json['date_envelope'] as Map<String, dynamic>?;
    return envelope == null ? null : DateEnvelope.fromJson(envelope);
  }

  /// Select an offer. By default this pins the trip's start and end dates from
  /// the flight times, which is the point of the flight step.
  Future<DateEnvelope?> selectFlight(
    String tripId, {
    required String direction,
    required FlightOffer offer,
    String? memberId,
    bool applyDatesToTrip = true,
  }) async {
    final json = await _client.post('/trips/$tripId/flights', body: {
      'direction': direction,
      'offer': offer.raw,
      'member_id': ?memberId,
      'apply_dates_to_trip': applyDatesToTrip,
    });
    final envelope = json['date_envelope'] as Map<String, dynamic>?;
    return envelope == null ? null : DateEnvelope.fromJson(envelope);
  }

  Future<({List<Map<String, dynamic>> selections, DateEnvelope? envelope})>
      tripFlights(String tripId) async {
    final json = await _client.get('/trips/$tripId/flights');
    final envelope = json['date_envelope'] as Map<String, dynamic>?;
    return (
      selections: (json['selections'] as List).cast<Map<String, dynamic>>(),
      envelope: envelope == null ? null : DateEnvelope.fromJson(envelope),
    );
  }

  // --- transit ---

  Future<Map<String, dynamic>> routeBetween({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String mode = 'TRANSIT',
    String? departureTime,
  }) =>
      _client.post('/transit/route', body: {
        'origin': {'lat': fromLat, 'lng': fromLng},
        'destination': {'lat': toLat, 'lng': toLng},
        'mode': mode,
        'departure_time': ?departureTime,
      });

  Future<Map<String, dynamic>> routeByName({
    required String from,
    required String to,
    String mode = 'TRANSIT',
  }) =>
      _client.post('/transit/route-by-name', body: {
        'from': from,
        'to': to,
        'mode': mode,
      });

  /// Pairwise travel times between the trip's resolved places.
  Future<Map<String, dynamic>> travelMatrix(
    String tripId, {
    String mode = 'TRANSIT',
  }) =>
      _client.get('/trips/$tripId/places/travel-matrix', query: {'mode': mode});

  // --- planner ---

  /// Generate or refine the plan. [request] carries a refinement instruction
  /// like "make day 3 more relaxed"; omit it for the initial plan.
  ///
  /// Always returns the complete plan, never a diff — replace local state
  /// wholesale with the result.
  Future<PlanRevision> generatePlan(String tripId, {String? request}) async {
    final json = await _client.postLongRunning(
      '/trips/$tripId/plan',
      body: {'request': ?request},
    );
    return PlanRevision.fromJson(json['plan'] as Map<String, dynamic>);
  }

  /// The latest plan plus the view state that goes with it: which day the last
  /// refinement changed, and which conflicts the group has accepted.
  ///
  /// Returns a null plan when the trip has never been planned.
  Future<({PlanRevision? plan, int? updatedDay, List<String> accepted})>
      latestPlan(String tripId) async {
    try {
      final json = await _client.get('/trips/$tripId/plan');
      return (
        plan: PlanRevision.fromJson(json['plan'] as Map<String, dynamic>),
        updatedDay: (json['updated_day'] as num?)?.toInt(),
        accepted: (json['accepted_conflicts'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
    } on ApiException catch (e) {
      if (e.code == 'no_plan_yet') {
        return (plan: null, updatedDay: null, accepted: <String>[]);
      }
      rethrow;
    }
  }

  /// The last planning attempt that produced nothing, if there is one.
  ///
  /// Its own route rather than part of [latestPlan], because the case that
  /// matters most — a trip whose very first plan failed — has no plan to
  /// attach it to.
  Future<PlanFailure?> planFailure(String tripId) async {
    final json = await _client.get('/trips/$tripId/plan/failure');
    final failure = json['failure'] as Map<String, dynamic>?;
    return failure == null ? null : PlanFailure.fromJson(failure);
  }

  /// Dismiss the failed state without retrying — "keep what's already there".
  Future<void> dismissPlanFailure(String tripId) =>
      _client.delete('/trips/$tripId/plan/failure');

  /// Answer the planner's clarifying questions and re-plan.
  ///
  /// Send only ids and answers; the server pairs them with the question text
  /// from the stored plan. Pass [planAnyway] for "Plan without these", which
  /// tells the planner to assume rather than ask again.
  Future<PlanRevision> answerQuestions(
    String tripId, {
    Map<String, String> answers = const {},
    bool planAnyway = false,
  }) async {
    final json = await _client.postLongRunning('/trips/$tripId/plan/answers', body: {
      'answers': [
        for (final entry in answers.entries)
          {'id': entry.key, 'answer': entry.value},
      ],
      'plan_anyway': planAnyway,
    });
    return PlanRevision.fromJson(json['plan'] as Map<String, dynamic>);
  }

  /// The Refine tab's conversation so far.
  Future<List<ChatMessage>> chatThread(String tripId) async {
    final json = await _client.get('/trips/$tripId/chat');
    return (json['messages'] as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Send one Refine turn. The message may be a pasted link, pasted article
  /// text, or a planning instruction — the server works out which.
  ///
  /// Pass [pendingSourceId] when replying to an `awaitingPaste` result.
  Future<RefineResult> refine(
    String tripId,
    String message, {
    String? pendingSourceId,
  }) async {
    final json = await _client.postLongRunning('/trips/$tripId/refine', body: {
      'message': message,
      'pending_source_id': ?pendingSourceId,
    });
    return RefineResult.fromJson(json);
  }

  /// Toggle "Looks good" on a conflict. Keyed by tag, not index, so a
  /// regenerated plan keeps the acknowledgement on the right card.
  Future<List<String>> acceptConflict(
    String tripId,
    String tag, {
    bool accepted = true,
  }) async {
    final json = await _client.post('/trips/$tripId/conflicts/accept', body: {
      'tag': tag,
      'accepted': accepted,
    });
    return (json['accepted_conflicts'] as List).map((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> planRevisions(String tripId) async {
    final json = await _client.get('/trips/$tripId/plan/revisions');
    return (json['revisions'] as List).cast<Map<String, dynamic>>();
  }
}
