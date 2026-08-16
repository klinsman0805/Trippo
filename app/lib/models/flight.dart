/// Flight offers and the date envelope they imply.
library;

class FlightSegment {
  const FlightSegment({
    required this.origin,
    required this.destination,
    required this.departsAt,
    required this.arrivesAt,
    required this.flightNumber,
    required this.durationMinutes,
  });

  final String origin;
  final String destination;
  final String departsAt;
  final String arrivesAt;
  final String flightNumber;
  final num durationMinutes;

  factory FlightSegment.fromJson(Map<String, dynamic> json) => FlightSegment(
        origin: json['origin'] as String? ?? '',
        destination: json['destination'] as String? ?? '',
        departsAt: json['departs_at'] as String? ?? '',
        arrivesAt: json['arrives_at'] as String? ?? '',
        flightNumber: json['flight_number'] as String? ?? '',
        durationMinutes: json['duration_minutes'] as num? ?? 0,
      );
}

class FlightItinerary {
  const FlightItinerary({
    required this.direction,
    required this.durationMinutes,
    required this.stops,
    required this.segments,
  });

  final String direction; // outbound | return
  final num durationMinutes;
  final int stops;
  final List<FlightSegment> segments;

  factory FlightItinerary.fromJson(Map<String, dynamic> json) => FlightItinerary(
        direction: json['direction'] as String? ?? 'outbound',
        durationMinutes: json['duration_minutes'] as num? ?? 0,
        stops: (json['stops'] as num?)?.toInt() ?? 0,
        segments: (json['segments'] as List? ?? const [])
            .map((s) => FlightSegment.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class FlightOffer {
  const FlightOffer({
    required this.id,
    required this.provider,
    required this.isEstimate,
    required this.priceTotal,
    required this.pricePerTraveler,
    required this.currency,
    required this.cabin,
    required this.itineraries,
    required this.raw,
    this.seatsAvailable,
  });

  final String id;
  final String provider;

  /// When true the price is synthetic or from a sandbox environment. The UI
  /// MUST label these — presenting one as a bookable fare would be a lie.
  final bool isEstimate;
  final num priceTotal;
  final num pricePerTraveler;
  final String currency;
  final String cabin;
  final int? seatsAvailable;
  final List<FlightItinerary> itineraries;

  /// The untouched payload, echoed back verbatim when selecting this offer.
  final Map<String, dynamic> raw;

  /// Carrier name for the card header. The API returns codes, so an unknown
  /// code is shown as-is rather than guessed at.
  String get carrierName {
    final code = itineraries
        .expand((i) => i.segments)
        .map((s) => s.flightNumber)
        .where((f) => f.length > 2)
        .map((f) => f.substring(0, 2))
        .firstOrNull;
    if (code == null) return provider;
    return _carriers[code] ?? code;
  }

  /// `ABC123 · ABC188 return`
  String get flightNumbersLabel {
    final out = itineraries
        .where((i) => i.direction == 'outbound')
        .expand((i) => i.segments)
        .map((s) => s.flightNumber);
    final back = itineraries
        .where((i) => i.direction == 'return')
        .expand((i) => i.segments)
        .map((s) => s.flightNumber);
    return [
      out.join(' + '),
      if (back.isNotEmpty) '${back.join(' + ')} return',
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  factory FlightOffer.fromJson(Map<String, dynamic> json) => FlightOffer(
        id: json['id'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        isEstimate: json['is_estimate'] as bool? ?? true,
        priceTotal: json['price_total'] as num? ?? 0,
        pricePerTraveler: json['price_per_traveler'] as num? ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        cabin: json['cabin'] as String? ?? 'ECONOMY',
        seatsAvailable: (json['seats_available'] as num?)?.toInt(),
        itineraries: (json['itineraries'] as List? ?? const [])
            .map((i) => FlightItinerary.fromJson(i as Map<String, dynamic>))
            .toList(),
        raw: json,
      );
}

/// Carrier codes seen often enough to be worth naming. Anything else falls
/// back to the raw code — a wrong airline name is worse than a code.
const _carriers = <String, String>{
  'MH': 'Malaysia Airlines',
  'SQ': 'Singapore Airlines',
  'TR': 'Scoot',
  'AK': 'AirAsia',
  'D7': 'AirAsia X',
  'JL': 'Japan Airlines',
  'NH': 'ANA',
  'CX': 'Cathay Pacific',
  'BA': 'British Airways',
  'TP': 'TAP Air Portugal',
  'XX': 'Sample Airline',
};

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class FlightSearchResult {
  const FlightSearchResult({
    required this.provider,
    required this.estimatesOnly,
    required this.offers,
  });

  final String provider;
  final bool estimatesOnly;
  final List<FlightOffer> offers;

  factory FlightSearchResult.fromJson(Map<String, dynamic> json) =>
      FlightSearchResult(
        provider: json['provider'] as String? ?? '',
        estimatesOnly: json['estimates_only'] as bool? ?? true,
        offers: (json['offers'] as List? ?? const [])
            .map((o) => FlightOffer.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

class Airport {
  const Airport({
    required this.iata,
    required this.name,
    this.city,
    this.country,
  });

  final String iata;
  final String name;
  final String? city;
  final String? country;

  factory Airport.fromJson(Map<String, dynamic> json) => Airport(
        iata: json['iata'] as String? ?? '',
        name: json['name'] as String? ?? '',
        city: json['city'] as String?,
        country: json['country'] as String?,
      );
}

/// Which slots survive on a shortened day, and why.
class ShortDay {
  const ShortDay({
    required this.day,
    required this.date,
    required this.usableSlots,
    required this.lostSlots,
    required this.reason,
    required this.at,
    required this.note,
  });

  final int day;
  final String date;
  final List<String> usableSlots;
  final List<String> lostSlots;

  /// 'late_arrival' | 'early_departure'
  final String reason;

  /// The local time that caused it, e.g. "13:15".
  final String at;

  /// Plain-language explanation for the amber band.
  final String note;

  /// "2 of 3 slots"
  String get slotLabel => '${usableSlots.length} of 3 slots';
  bool get isWriteOff => usableSlots.isEmpty;

  factory ShortDay.fromJson(Map<String, dynamic> json) => ShortDay(
        day: (json['day'] as num?)?.toInt() ?? 0,
        date: json['date'] as String? ?? '',
        usableSlots:
            (json['usable_slots'] as List? ?? const []).map((e) => '$e').toList(),
        lostSlots:
            (json['lost_slots'] as List? ?? const []).map((e) => '$e').toList(),
        reason: json['reason'] as String? ?? 'late_arrival',
        at: json['at'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}

/// The trip's usable window, derived from selected flights. This is what turns
/// "we land at 13:15" into "day 1 has no morning".
class DateEnvelope {
  const DateEnvelope({
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.planningDays,
    this.arrivalLocalTime,
    this.departureLocalTime,
    this.shortDays = const [],
  });

  final String startDate;
  final String endDate;
  final String? arrivalLocalTime;
  final String? departureLocalTime;

  /// Calendar days between arrival and departure, inclusive.
  final int totalDays;

  /// Days worth planning — [totalDays] minus any day with no usable slot.
  final int planningDays;
  final List<ShortDay> shortDays;

  ShortDay? shortDayFor(num day) =>
      shortDays.where((d) => d.day == day).firstOrNull;

  /// "4 days · 1 short at each end"
  String get planningDaysLabel {
    final days = '$planningDays ${planningDays == 1 ? 'day' : 'days'}';
    if (shortDays.isEmpty) return days;
    if (shortDays.length == 2) return '$days · 1 short at each end';
    return '$days · ${shortDays.length} short';
  }

  factory DateEnvelope.fromJson(Map<String, dynamic> json) => DateEnvelope(
        startDate: json['start_date'] as String? ?? '',
        endDate: json['end_date'] as String? ?? '',
        arrivalLocalTime: json['arrival_local_time'] as String?,
        departureLocalTime: json['departure_local_time'] as String?,
        totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
        planningDays: (json['planning_days'] as num?)?.toInt() ?? 0,
        shortDays: (json['short_days'] as List? ?? const [])
            .map((d) => ShortDay.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}
