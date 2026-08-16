import 'package:flutter/material.dart';

import '../../../api/trippo_api.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/flight.dart';
import '../../../models/trip.dart';
import '../../../state/flights_controller.dart';
import '../pushed_screen.dart';
import 'consequence_sheet.dart';
import 'offer_card.dart';
import 'search_form.dart';

/// The Flights pushed screen.
///
/// Entered from the Trip tab and handed back to it — the whole point of
/// choosing flights is that it sets the trip's dates, and the consequence
/// lands where the itinerary lives.
class FlightsScreen extends StatefulWidget {
  const FlightsScreen({
    super.key,
    required this.api,
    required this.trip,
    required this.onSelected,
  });

  final TrippoApi api;
  final Trip trip;

  /// Called with the derived envelope once an offer is chosen, so the caller
  /// can show what it costs before committing.
  final void Function(FlightOffer offer, DateEnvelope? envelope) onSelected;

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen> {
  late final FlightsController _controller =
      FlightsController(widget.api, widget.trip);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Preview → confirm. Nothing is written until the group has seen what these
  /// times cost them and said yes.
  Future<void> _select(FlightOffer offer) async {
    final envelope = await _controller.preview(offer);
    if (!mounted) return;

    if (envelope == null) {
      // No derivable envelope (one-way with no arrival, say) — commit directly
      // rather than showing an empty sheet.
      final committed = await _controller.confirm(offer);
      if (mounted) widget.onSelected(offer, committed);
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: WayfareColors.scrim,
      // Opened by a tap, so it animates in. The handoff calls out the inverse
      // case — an initially-presented sheet must render at rest, or a held
      // start frame leaves it offscreen.
      builder: (sheetContext) => ConsequenceSheet(
        offer: offer,
        envelope: envelope,
        currency: _controller.trip.currency,
        travellers: _controller.seats,
        cheaperAlternative: _controller.cheaperThan(offer),
        onConfirm: () => Navigator.of(sheetContext).pop(true),
        onPickDifferent: () => Navigator.of(sheetContext).pop(false),
      ),
    );

    if (confirmed != true || !mounted) return;

    final committed = await _controller.confirm(offer);
    if (mounted) widget.onSelected(offer, committed);
  }

  @override
  Widget build(BuildContext context) {
    final route = _controller.from != null && _controller.to != null
        ? '${_controller.from!.iata} → ${_controller.to!.iata}'
        : 'Flights';

    // The title becomes the route once there is one — it is the most useful
    // thing to confirm while scanning results.
    final showRoute = _controller.view == FlightsView.results ||
        _controller.view == FlightsView.loading ||
        _controller.view == FlightsView.noResults;

    return WayfarePushedScreen(
      title: showRoute ? route : 'Flights',
      backLabel: 'Trip',
      subtitle: showRoute ? '${_controller.seats} travelling' : null,
      onBack: _controller.view == FlightsView.results ||
              _controller.view == FlightsView.noResults
          // Results push over the form rather than replacing it, so back goes
          // to the query first and out of the screen second.
          ? _controller.backToSearch
          : null,
      child: switch (_controller.view) {
        FlightsView.search => FlightSearchForm(controller: _controller),
        FlightsView.loading => _LoadingView(controller: _controller),
        FlightsView.results => _ResultsView(
            controller: _controller,
            onSelect: _select,
          ),
        FlightsView.noResults => _NoResultsView(controller: _controller),
        FlightsView.unavailable => const FlightsUnavailableView(),
      },
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.controller, required this.onSelect});

  final FlightsController controller;
  final ValueChanged<FlightOffer> onSelect;

  static const _sorts = <(SortMode, String)>[
    (SortMode.cheapest, 'Cheapest'),
    (SortMode.fastest, 'Fastest'),
    (SortMode.bookable, 'Bookable only'),
  ];

  @override
  Widget build(BuildContext context) {
    final offers = controller.offers;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final (mode, label) in _sorts) ...[
                WayfareSelectChip(
                  label: label,
                  selected: controller.sort == mode,
                  onTap: () => controller.setSort(mode),
                  minHeight: 40,
                  fontSize: 12.5,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            controller.resultsCountLabel,
            style: const TextStyle(fontSize: 12.5, color: WayfareColors.mutedLight),
          ),
        ),
        if (offers.isEmpty)
          // Only reachable via "Bookable only" with nothing bookable — a
          // filter result, not an empty search.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: WayfareCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No bookable fares',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Every option here is sandbox inventory. You can still use '
                    'one to set your dates — just don\'t treat the price as real.',
                    style: WayfareType.body(13.5, color: WayfareColors.subhead),
                  ),
                  const SizedBox(height: 16),
                  WayfareSecondaryButton(
                    label: 'Show estimates too',
                    onPressed: () => controller.setSort(SortMode.cheapest),
                  ),
                ],
              ),
            ),
          )
        else
          for (final offer in offers)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: FlightOfferCard(
                offer: offer,
                currency: controller.trip.currency,
                consequenceWarning: _warningFor(offer),
                onSelect: () => onSelect(offer),
              ),
            ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Warn before selection when these times will cost a day part, so the
  /// consequence isn't a surprise on the next screen.
  String? _warningFor(FlightOffer offer) {
    final outbound = offer.itineraries
        .where((i) => i.direction == 'outbound')
        .firstOrNull;
    final inbound =
        offer.itineraries.where((i) => i.direction == 'return').firstOrNull;

    final arrival = outbound?.segments.lastOrNull?.arrivesAt;
    final departure = inbound?.segments.firstOrNull?.departsAt;

    // Thresholds mirror the server's envelope rules so this hint never
    // contradicts the consequence sheet, which is authoritative.
    const redEyeBefore = 5 * 60;
    const killsMorningAfter = 9 * 60 + 30;
    const killsAfternoonAfter = 15 * 60 + 30;
    const killsEveningAfter = 20 * 60;
    const departureKillsMorningBefore = 12 * 60;

    int? minutesOf(String? iso) {
      if (iso == null || iso.length < 16) return null;
      final h = int.tryParse(iso.substring(11, 13));
      final m = int.tryParse(iso.substring(14, 16));
      return (h == null || m == null) ? null : h * 60 + m;
    }

    final notes = <String>[];
    final arriveAt = minutesOf(arrival);
    if (arriveAt != null) {
      final time = arrival!.substring(11, 16);
      if (arriveAt > killsEveningAfter) {
        notes.add('Landing at $time leaves no usable time on day 1.');
      } else if (arriveAt > killsAfternoonAfter) {
        notes.add('Landing at $time leaves only the evening on day 1.');
      } else if (arriveAt < redEyeBefore) {
        notes.add('Landing at $time costs you the first morning to sleep.');
      } else if (arriveAt > killsMorningAfter) {
        notes.add('Landing at $time costs you the first morning.');
      }
    }

    final leaveAt = minutesOf(departure);
    if (leaveAt != null && leaveAt < departureKillsMorningBefore) {
      notes.add(
        'The ${departure!.substring(11, 16)} return means the last morning is gone.',
      );
    }
    return notes.isEmpty ? null : notes.join(' ');
  }
}

/// Skeleton cards while the search runs, so the wait has a shape.
class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.controller});

  final FlightsController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const WayfarePulsingDots(colors: WayfareColors.loadingDots, size: 8),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Checking ${controller.from?.iata} → ${controller.to?.iata} '
                'for ${controller.seats} seat${controller.seats == 1 ? '' : 's'}…',
                style: const TextStyle(fontSize: 15, color: WayfareColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++) ...[
          const _SkeletonCard(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  // wf2-shimmer: 1.4s, opacity .45 → .9 → .45
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: 0.45 + 0.45 * _controller.value,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WayfareColors.surface,
            borderRadius: theme.cardLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _bar(150, WayfareColors.skeletonDark),
                  const Spacer(),
                  _bar(72, WayfareColors.skeletonMid),
                ],
              ),
              const SizedBox(height: 14),
              _bar(220, WayfareColors.skeletonLight),
              const SizedBox(height: 8),
              _bar(160, WayfareColors.skeletonLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double width, Color color) => Container(
        width: width,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      );
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView({required this.controller});

  final FlightsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: WayfareCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nothing on those dates',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              'No ${controller.nonStop ? 'non-stop ' : ''}fares came back for '
              '${controller.from?.iata} → ${controller.to?.iata} on '
              '${controller.departureDate}. Try nearby dates, or allow stops.',
              style: WayfareType.body(13.5, color: WayfareColors.subhead),
            ),
            const SizedBox(height: 18),
            if (controller.nonStop)
              WayfarePrimaryButton(
                label: 'Search again with stops',
                onPressed: () {
                  controller.setNonStop(false);
                  controller.search();
                },
              )
            else
              WayfarePrimaryButton(
                label: 'Change the search',
                onPressed: controller.backToSearch,
              ),
            const SizedBox(height: 10),
            WayfareSecondaryButton(
              label: 'Change the search',
              onPressed: controller.backToSearch,
            ),
          ],
        ),
      ),
    );
  }
}

/// Flight search switched off — a status, not an error. No red, no alert
/// iconography, and the rest of the trip is explicitly said to still work.
class FlightsUnavailableView extends StatelessWidget {
  const FlightsUnavailableView({super.key, this.checkedAt});

  final String? checkedAt;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: WayfareCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: WayfareColors.placeholderTile,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Flight search is switched off',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'No flights provider is connected to this trip, so Wayfare can\'t '
              'look up fares or read your dates from a booking.',
              style: WayfareType.body(13.5, color: WayfareColors.subhead),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: WayfareColors.surfaceAlt,
                borderRadius: theme.card,
                border: Border.all(color: const Color(0xFFEEE2CD)),
              ),
              child: Text(
                [
                  if (checkedAt != null) 'Checked at $checkedAt',
                  'everything else on this trip works as normal',
                ].join(' · '),
                style: WayfareType.body(12.5, color: WayfareColors.muted),
              ),
            ),
            const SizedBox(height: 16),
            WayfarePrimaryButton(
              label: 'Set the dates by hand',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 10),
            WayfareSecondaryButton(
              label: 'Paste a booking confirmation',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstLast<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _ListLast<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
