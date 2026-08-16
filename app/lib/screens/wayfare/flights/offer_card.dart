import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/flight.dart';
import '../formatting.dart';

/// One flight offer.
///
/// The `is_estimate` treatment is the point of this card. Sandbox inventory is
/// not bookable and its price is directional, so it carries **four redundant
/// signals**, all adjacent to the price and none hidden in a tooltip:
///
///   1. `~` prefixed to the amount
///   2. the price ink muted rather than full ink
///   3. an amber card border instead of the usual hairline
///   4. an ESTIMATE band directly under the price, saying so in words
///
/// The CTA changes with it. Rendering a price without resolving this flag is
/// the one thing this card must never do.
class FlightOfferCard extends StatelessWidget {
  const FlightOfferCard({
    super.key,
    required this.offer,
    required this.currency,
    required this.onSelect,
    this.consequenceWarning,
  });

  final FlightOffer offer;
  final String currency;
  final VoidCallback onSelect;

  /// Shown when these times cost the traveller a part of a day.
  final String? consequenceWarning;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final estimate = offer.isEstimate;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WayfareColors.surface,
        borderRadius: theme.cardLg,
        border: Border.all(
          // Signal 3.
          color: estimate ? WayfareColors.amberBorder : WayfareColors.borderSoft,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(estimate),
                if (estimate) ...[
                  const SizedBox(height: 10),
                  const _EstimateBand(),
                ] else ...[
                  const SizedBox(height: 10),
                  const _LiveFareLine(),
                ],
              ],
            ),
          ),
          for (final itinerary in offer.itineraries) _LegRow(itinerary: itinerary),
          Container(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: WayfareColors.skeletonLight)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (consequenceWarning != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: WayfareColors.amberSoftBg,
                      borderRadius: theme.card,
                    ),
                    child: Text(
                      consequenceWarning!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: WayfareColors.amberInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // An estimate cannot be booked, so the CTA promises only what
                // it can deliver: the times, not the fare.
                estimate
                    ? WayfareSecondaryButton(
                        label: 'Use these times anyway',
                        onPressed: onSelect,
                        fontSize: 14.5,
                        weight: FontWeight.w600,
                      )
                    : WayfarePrimaryButton(
                        label: 'Use these flights',
                        onPressed: onSelect,
                        fontSize: 14.5,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(bool estimate) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.carrierName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WayfareColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                offer.flightNumbersLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: WayfareColors.mutedLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              // Signals 1 and 2.
              '${estimate ? '~' : ''}${formatMoney(offer.priceTotal, currency)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: estimate
                    ? WayfareColors.estimatePrice
                    : WayfareColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${formatMoney(offer.pricePerTraveler, currency)} per person',
              style: const TextStyle(
                fontSize: 12,
                color: WayfareColors.mutedLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Signal 4 — the band that says it in words.
class _EstimateBand extends StatelessWidget {
  const _EstimateBand();

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: WayfareColors.amberSurface,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.amberBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: WayfareColors.amberPillBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'ESTIMATE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: WayfareColors.amberInkDeep,
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Sandbox inventory. This price is directional and this flight '
              'cannot be booked.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: WayfareColors.amberInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The counterpart: a quiet confirmation that a fare is real.
class _LiveFareLine extends StatelessWidget {
  const _LiveFareLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: WayfareColors.liveFareDot,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        const Text(
          'Live fare from the carrier',
          style: TextStyle(fontSize: 12.5, color: WayfareColors.liveFareInk),
        ),
      ],
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.itinerary});

  final FlightItinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final first = itinerary.segments.firstOrNull;
    final last = itinerary.segments.lastOrNull;
    if (first == null || last == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF7F1E6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              itinerary.direction == 'outbound' ? 'OUT' : 'BACK',
              style: WayfareType.eyebrow(11, color: WayfareColors.mutedLight),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${timeOf(first.departsAt)} → ${timeOf(last.arrivesAt)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${first.origin} → ${last.destination}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WayfareColors.mutedLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _meta(),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WayfareColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _meta() {
    final first = itinerary.segments.first;
    final stops = itinerary.stops == 0
        ? 'non-stop'
        : '${itinerary.stops} stop${itinerary.stops == 1 ? '' : 's'}';
    return [
      weekdayAndDate(first.departsAt),
      formatDuration(itinerary.durationMinutes),
      stops,
    ].where((s) => s.isNotEmpty).join(' · ');
  }
}

extension _FirstLast<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
