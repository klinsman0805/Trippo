import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/trippo_api.dart';
import '../models/flight.dart';
import '../models/trip.dart';

enum FlightsView { search, loading, results, noResults, unavailable }

enum SortMode { cheapest, fastest, bookable }

/// Drives the Flights pushed screen: the query, the search, and the results.
class FlightsController extends ChangeNotifier {
  FlightsController(this._api, this.trip);

  final TrippoApi _api;
  final Trip trip;

  FlightsView view = FlightsView.search;
  SortMode sort = SortMode.cheapest;
  String? error;

  // --- query ---
  Airport? from;
  Airport? to;
  String? departureDate;
  String? returnDate;
  bool oneWay = false;
  late int seats = trip.members.isEmpty ? 1 : trip.members.length;
  String cabin = 'ECONOMY';
  bool nonStop = true;

  List<FlightOffer> _offers = const [];

  /// Type-ahead state, keyed by which field is being edited.
  List<Airport> suggestions = const [];
  bool suggestionsLoading = false;
  Timer? _debounce;

  bool get canSearch =>
      from != null &&
      to != null &&
      departureDate != null &&
      (oneWay || returnDate != null);

  /// Results in the current sort, with estimates filtered out under `bookable`.
  List<FlightOffer> get offers {
    final list = [..._offers];
    switch (sort) {
      case SortMode.cheapest:
        list.sort((a, b) => a.priceTotal.compareTo(b.priceTotal));
      case SortMode.fastest:
        list.sort((a, b) => _totalMinutes(a).compareTo(_totalMinutes(b)));
      case SortMode.bookable:
        list
          ..removeWhere((o) => o.isEstimate)
          ..sort((a, b) => a.priceTotal.compareTo(b.priceTotal));
    }
    return list;
  }

  int get estimateCount => _offers.where((o) => o.isEstimate).length;
  int get bookableCount => _offers.length - estimateCount;

  /// "3 options · 2 are estimates" → "1 bookable fare · 2 estimates hidden"
  String get resultsCountLabel {
    if (sort == SortMode.bookable) {
      final fares = bookableCount == 1 ? 'bookable fare' : 'bookable fares';
      if (estimateCount == 0) return '$bookableCount $fares';
      return '$bookableCount $fares · $estimateCount ${estimateCount == 1 ? 'estimate' : 'estimates'} hidden';
    }
    final options = _offers.length == 1 ? 'option' : 'options';
    if (estimateCount == 0) return '${_offers.length} $options';
    return '${_offers.length} $options · $estimateCount ${estimateCount == 1 ? 'is an estimate' : 'are estimates'}';
  }

  static num _totalMinutes(FlightOffer o) =>
      o.itineraries.fold<num>(0, (sum, i) => sum + i.durationMinutes);

  // --- type-ahead ---

  /// Debounced so a fast typist doesn't fire a request per keystroke.
  void searchAirports(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      suggestions = const [];
      suggestionsLoading = false;
      notifyListeners();
      return;
    }

    suggestionsLoading = true;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        suggestions = await _api.searchAirports(q);
      } on ApiException {
        suggestions = const [];
      }
      suggestionsLoading = false;
      notifyListeners();
    });
  }

  void clearSuggestions() {
    _debounce?.cancel();
    suggestions = const [];
    suggestionsLoading = false;
    notifyListeners();
  }

  // --- query edits ---

  void setFrom(Airport airport) {
    from = airport;
    clearSuggestions();
  }

  void setTo(Airport airport) {
    to = airport;
    clearSuggestions();
  }

  void setDepartureDate(String? date) {
    departureDate = date;
    // A return before departure is never what was meant.
    if (returnDate != null && date != null && returnDate!.compareTo(date) < 0) {
      returnDate = null;
    }
    notifyListeners();
  }

  void setReturnDate(String? date) {
    returnDate = date;
    notifyListeners();
  }

  void setOneWay(bool value) {
    oneWay = value;
    if (value) returnDate = null;
    notifyListeners();
  }

  void setSeats(int value) {
    seats = value.clamp(1, 8);
    notifyListeners();
  }

  void setCabin(String value) {
    cabin = value;
    notifyListeners();
  }

  void setNonStop(bool value) {
    nonStop = value;
    notifyListeners();
  }

  void setSort(SortMode mode) {
    sort = mode;
    notifyListeners();
  }

  void backToSearch() {
    view = FlightsView.search;
    error = null;
    notifyListeners();
  }

  Future<void> search() async {
    if (!canSearch) return;

    view = FlightsView.loading;
    error = null;
    notifyListeners();

    try {
      final result = await _api.searchFlights(
        origin: from!.iata,
        destination: to!.iata,
        departureDate: departureDate!,
        returnDate: oneWay ? null : returnDate,
        adults: seats,
        cabin: cabin,
        nonStop: nonStop,
        currency: trip.currency,
      );
      _offers = result.offers;
      view = _offers.isEmpty ? FlightsView.noResults : FlightsView.results;
    } on ApiException catch (e) {
      // A missing provider is a status, not a failure — it gets its own screen.
      if (e.isFeatureUnavailable) {
        view = FlightsView.unavailable;
      } else {
        error = e.message;
        view = FlightsView.search;
      }
    }
    notifyListeners();
  }

  /// What this offer would do to the trip — derived, not committed. The
  /// consequence sheet shows this before anything is written.
  Future<DateEnvelope?> preview(FlightOffer offer) => _api.previewEnvelope(offer);

  /// Commit: pin the trip's dates to this offer.
  Future<DateEnvelope?> confirm(FlightOffer offer) => _api.selectFlight(
        trip.id,
        direction: 'outbound',
        offer: offer,
      );

  /// The next-cheapest alternative, for the sheet's trade-off panel. Null when
  /// this is already the cheapest — there is no trade-off to name.
  FlightOffer? cheaperThan(FlightOffer offer) {
    final cheaper = _offers.where((o) => o.priceTotal < offer.priceTotal).toList()
      ..sort((a, b) => b.priceTotal.compareTo(a.priceTotal));
    return cheaper.isEmpty ? null : cheaper.first;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
