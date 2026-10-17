/// Travel between two consecutive activities.
///
/// Mirrors `TravelLeg` in `server/src/modules/travel/legs.ts`, which is the
/// source of truth for every rule here — this side only reads.
library;

enum Vehicle { walk, train, bus, ferry, car, transit }

Vehicle? _vehicleFrom(String? value) => switch (value) {
      'walk' => Vehicle.walk,
      'train' => Vehicle.train,
      'bus' => Vehicle.bus,
      'ferry' => Vehicle.ferry,
      'car' => Vehicle.car,
      'transit' => Vehicle.transit,
      _ => null,
    };

enum LegStatus {
  /// Has a duration.
  ok,

  /// Both activities are at the same spot — nothing worth printing.
  samePlace,

  /// One end could not be put on a map with any confidence. Said as such,
  /// never filled in with a figure.
  unplaced,
}

class TravelLeg {
  const TravelLeg({
    required this.fromBlockId,
    required this.toBlockId,
    required this.status,
    this.unplacedEnd,
    this.minutes,
    this.distanceMeters,
    this.vehicle,
    this.line,
    this.isEstimate = false,
    this.directionsUrl,
  });

  final String fromBlockId;
  final String toBlockId;
  final LegStatus status;

  /// 'from', 'to' or 'both' — which activity could not be placed.
  final String? unplacedEnd;
  final int? minutes;
  final int? distanceMeters;
  final Vehicle? vehicle;

  /// The line the longest ride is on, e.g. "Kelana Jaya Line".
  final String? line;

  /// Straight-line arithmetic rather than a routed answer. Worded with a `~`
  /// so it never reads as a timetable.
  final bool isEstimate;
  final String? directionsUrl;

  /// Long enough that a day built around it deserves a second look.
  static const longHopMinutes = 60;
  bool get isLongHop => (minutes ?? 0) >= longHopMinutes;

  factory TravelLeg.fromJson(Map<String, dynamic> json) => TravelLeg(
        fromBlockId: json['from_block_id'] as String? ?? '',
        toBlockId: json['to_block_id'] as String? ?? '',
        status: switch (json['status']) {
          'same_place' => LegStatus.samePlace,
          'unplaced' => LegStatus.unplaced,
          _ => LegStatus.ok,
        },
        unplacedEnd: json['unplaced'] as String?,
        minutes: (json['minutes'] as num?)?.round(),
        distanceMeters: (json['distance_meters'] as num?)?.round(),
        vehicle: _vehicleFrom(json['vehicle'] as String?),
        line: json['line'] as String?,
        isEstimate: json['is_estimate'] as bool? ?? false,
        directionsUrl: json['directions_url'] as String?,
      );
}

/// A day's travel, summed from the legs that are known so far.
class DayTravel {
  const DayTravel({required this.minutes, required this.unknown});

  /// Minutes across every leg with a duration.
  final int minutes;

  /// Legs that could not be placed. The total is a floor while any remain,
  /// and is worded that way.
  final int unknown;
}

/// Where one activity is, as the server placed it.
///
/// Mirrors `BlockPoint` in `server/src/modules/travel/legs.ts`. An unplaced
/// activity has no coordinates at all — the map lists it without a pin rather
/// than inventing one.
class BlockPoint {
  const BlockPoint({required this.blockId, this.lat, this.lng});

  final String blockId;
  final double? lat;
  final double? lng;

  bool get isPlaced => lat != null && lng != null;

  factory BlockPoint.fromJson(Map<String, dynamic> json) {
    final placed = json['status'] == 'placed';
    return BlockPoint(
      blockId: json['block_id'] as String? ?? '',
      lat: placed ? (json['lat'] as num?)?.toDouble() : null,
      lng: placed ? (json['lng'] as num?)?.toDouble() : null,
    );
  }
}

/// One day on the map: each activity's point, and where to look if none of
/// them could be placed.
class DayPoints {
  const DayPoints({
    required this.points,
    this.anchorLat,
    this.anchorLng,
    this.attribution,
  });

  /// By block id.
  final Map<String, BlockPoint> points;

  /// The trip's destination — the view when nothing on the day has a pin.
  final double? anchorLat;
  final double? anchorLng;
  final String? attribution;

  bool get anyPlaced => points.values.any((p) => p.isPlaced);

  factory DayPoints.fromJson(Map<String, dynamic> json) {
    final anchor = json['anchor'] as Map<String, dynamic>?;
    return DayPoints(
      points: {
        for (final p in (json['points'] as List? ?? const []))
          if (p is Map<String, dynamic>)
            (p['block_id'] as String? ?? ''): BlockPoint.fromJson(p),
      },
      anchorLat: (anchor?['lat'] as num?)?.toDouble(),
      anchorLng: (anchor?['lng'] as num?)?.toDouble(),
      attribution:
          (json['attribution'] as Map<String, dynamic>?)?['text'] as String?,
    );
  }
}
