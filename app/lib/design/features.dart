/// Features that are built but switched off.
///
/// A flag rather than deleted code: everything behind one of these works, has
/// tests, and is reachable again by flipping a single constant. The server
/// keeps its routes either way — turning a flag off makes a feature
/// unreachable, never unsupported.
class WayfareFeatures {
  const WayfareFeatures._();

  /// Planning a trip *with other people*: the Group tab and its travellers,
  /// the per-person preferences that produce conflicts, the avatar stacks
  /// saying who an activity suits, and the YOURS badge — which only means
  /// anything when somebody else could have written the activity instead.
  ///
  /// Off while the app is an individual's tool. Costs still read "pp", because
  /// that is what a price per person is, with or without a group.
  static const bool groups = false;

  /// Shopping for flights inside the app: the comparison screen, its fare
  /// cards and the "what does this one cost you in trip time" consequence
  /// sheet.
  ///
  /// Off because it cannot yet do the job — the fare provider is mock, so the
  /// prices are invented, and nobody books a flight from here anyway. Entering
  /// a flight you have already booked is a different feature and stays on: it
  /// reads a real schedule and is how the trip gets its dates.
  static const bool flightSearch = false;
}
