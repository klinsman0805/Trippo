import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/trippo_api.dart';
import '../models/trip.dart';

/// Async state wrapper so screens can render loading/error/data without each
/// one reinventing three booleans.
sealed class Loadable<T> {
  const Loadable();
}

class Idle<T> extends Loadable<T> {
  const Idle();
}

class Loading<T> extends Loadable<T> {
  const Loading();
}

class Loaded<T> extends Loadable<T> {
  const Loaded(this.value);
  final T value;
}

class Failed<T> extends Loadable<T> {
  const Failed(this.error);
  final ApiException error;
}

/// Trip-list state for the picker screen. Per-trip state lives in
/// `WayfareController`, which drives the four-tab shell.
class TripListRepository extends ChangeNotifier {
  TripListRepository(this._api);

  final TrippoApi _api;
  Loadable<List<Trip>> trips = const Idle();

  /// Which server features are configured, from /health. Screens should gate
  /// on this rather than discovering a missing key via a 503.
  Map<String, dynamic> features = const {};

  Future<void> load() async {
    trips = const Loading();
    notifyListeners();
    try {
      features = await _api.features();
      trips = Loaded(await _api.listTrips());
    } on ApiException catch (e) {
      trips = Failed(e);
    }
    notifyListeners();
  }

  bool get plannerAvailable => features['planner'] == true;
  bool get mapsAvailable => features['maps'] == true;
  bool get flightsAreEstimatesOnly => features['flight_provider'] == 'mock';

  Future<Trip> create(
    String title, {
    List<String> destinations = const [],
    String currency = 'USD',
  }) async {
    final trip = await _api.createTrip(
      title: title,
      destinations: destinations,
      currency: currency,
    );
    await load();
    return trip;
  }

  Future<void> delete(String id) async {
    await _api.deleteTrip(id);
    await load();
  }
}
