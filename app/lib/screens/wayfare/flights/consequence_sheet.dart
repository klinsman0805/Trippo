import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../models/flight.dart';
import '../formatting.dart';

/// What choosing these flights does to the trip, shown before it is committed.
///
/// This is the moment the app is most useful and most at risk of being
/// dishonest: the group is about to lock dates, and the cost is measured in
/// day-parts they will never get back. So it states the times plainly, names
/// exactly which slots die, and — when a cheaper option exists — says what that
/// option would actually cost them rather than only what it saves.
class ConsequenceSheet extends StatelessWidget {
  const ConsequenceSheet({
    super.key,
    required this.offer,
    required this.envelope,
    required this.currency,
    required this.travellers,
    required this.onConfirm,
    required this.onPickDifferent,
    this.cheaperAlternative,
  });

  final FlightOffer offer;
  final DateEnvelope envelope;
  final String currency;
  final int travellers;
  final VoidCallback onConfirm;
  final VoidCallback onPickDifferent;

  /// The next-cheapest offer, if there is one. Drives the trade-off panel.
  final FlightOffer? cheaperAlternative;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: WayfareColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(theme.sheetRadius),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            offset: Offset(0, -12),
            blurRadius: 40,
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 46),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 4, bottom: 14),
                decoration: BoxDecoration(
                  color: WayfareColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text('These flights set your dates', style: WayfareType.display(25)),
            const SizedBox(height: 8),
            Text(
              _plainSummary(),
              style: WayfareType.body(13.5, color: WayfareColors.subhead),
            ),
            const SizedBox(height: 18),
            _EnvelopeTable(
              envelope: envelope,
              offer: offer,
              currency: currency,
              travellers: travellers,
            ),
            if (envelope.shortDays.isNotEmpty) ...[
              const SizedBox(height: 18),
              const WayfareEyebrow(
                'What this costs you',
                color: WayfareColors.amberInkDeep,
                size: 10.5,
              ),
              const SizedBox(height: 10),
              for (final short in envelope.shortDays) ...[
                _CostCard(short: short),
                const SizedBox(height: 10),
              ],
            ],
            if (cheaperAlternative != null) ...[
              const SizedBox(height: 8),
              _TradeOffPanel(
                chosen: offer,
                alternative: cheaperAlternative!,
                currency: currency,
              ),
            ],
            const SizedBox(height: 18),
            WayfarePrimaryButton(
              label: 'Set the trip to these dates',
              onPressed: onConfirm,
              minHeight: WayfareTouch.sheetCta,
              fontSize: 15.5,
            ),
            const SizedBox(height: 10),
            WayfareSecondaryButton(
              label: 'Pick different flights',
              onPressed: onPickDifferent,
            ),
          ],
        ),
      ),
    );
  }

  /// "Flight MH123 lands 13:15 on Saturday, the return leaves 10:00 on
  /// Wednesday. That is the whole trip."
  String _plainSummary() {
    final outbound =
        offer.itineraries.where((i) => i.direction == 'outbound').firstOrNull;
    final inbound =
        offer.itineraries.where((i) => i.direction == 'return').firstOrNull;

    final arrival = outbound?.segments.lastOrNull;
    final departure = inbound?.segments.firstOrNull;
    if (arrival == null) return 'These flights set the start and end of the trip.';

    final flight = outbound!.segments.first.flightNumber;
    final lands =
        'Flight $flight lands ${timeOf(arrival.arrivesAt)} on ${_weekday(arrival.arrivesAt)}';

    if (departure == null) return '$lands. The return is not booked yet.';

    return '$lands, the return leaves ${timeOf(departure.departsAt)} on '
        '${_weekday(departure.departsAt)}. That is the whole trip.';
  }

  static String _weekday(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[date.weekday - 1];
  }
}

class _EnvelopeTable extends StatelessWidget {
  const _EnvelopeTable({
    required this.envelope,
    required this.offer,
    required this.currency,
    required this.travellers,
  });

  final DateEnvelope envelope;
  final FlightOffer offer;
  final String currency;
  final int travellers;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    final rows = <(String, String)>[
      (
        'Trip starts',
        [
          weekdayAndDate('${envelope.startDate}T00:00:00'),
          if (envelope.arrivalLocalTime != null)
            formatClock(envelope.arrivalLocalTime!),
        ]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' · '),
      ),
      (
        'Trip ends',
        [
          weekdayAndDate('${envelope.endDate}T00:00:00'),
          if (envelope.departureLocalTime != null)
            formatClock(envelope.departureLocalTime!),
        ]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' · '),
      ),
      ('Planning days', envelope.planningDaysLabel),
      (
        'Flights',
        '${formatMoney(offer.priceTotal, currency)} for $travellers · '
            '${offer.isEstimate ? 'estimate' : 'live fare'}',
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WayfareColors.surfaceAlt,
        borderRadius: theme.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(
                        top: BorderSide(color: WayfareColors.skeletonLight),
                      ),
              ),
              child: Row(
                children: [
                  Text(
                    rows[i].$1,
                    style: const TextStyle(fontSize: 14, color: WayfareColors.muted),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One affected day: what it becomes, how much of it survives, and why.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.short});

  final ShortDay short;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WayfareColors.amberSurface,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.amberBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _title(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: WayfareColors.amberInk,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                short.slotLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WayfareColors.amberInkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            short.note,
            style: WayfareType.body(13.5, color: WayfareColors.amberInk),
          ),
        ],
      ),
    );
  }

  String _title() {
    if (short.isWriteOff) {
      return short.reason == 'early_departure'
          ? 'The last day is gone'
          : 'Day ${short.day} is a write-off';
    }
    if (short.reason == 'late_arrival') {
      return short.usableSlots.contains('afternoon')
          ? 'Day ${short.day} starts after lunch'
          : 'Day ${short.day} is an evening only';
    }
    return 'The last morning is gone';
  }
}

/// Names the cheaper option *and* what taking it would actually cost.
///
/// A savings figure on its own invites the wrong trade; the point of this panel
/// is that the group can see both sides of it at once.
class _TradeOffPanel extends StatelessWidget {
  const _TradeOffPanel({
    required this.chosen,
    required this.alternative,
    required this.currency,
  });

  final FlightOffer chosen;
  final FlightOffer alternative;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final saving = chosen.priceTotal - alternative.priceTotal;

    final altArrival = alternative.itineraries
        .where((i) => i.direction == 'outbound')
        .firstOrNull
        ?.segments
        .lastOrNull
        ?.arrivesAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WayfareColors.infoBg,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.infoBorder),
      ),
      child: Text(
        _copy(saving, altArrival),
        style: WayfareType.body(13.5, color: WayfareColors.infoBody),
      ),
    );
  }

  String _copy(num saving, String? altArrival) {
    final amount = formatMoney(saving, currency);
    if (altArrival == null || altArrival.length < 16) {
      return 'A cheaper option saves $amount. Check what it does to your '
          'arrival before switching.';
    }

    final time = timeOf(altArrival);
    final hour = int.tryParse(altArrival.substring(11, 13)) ?? 0;
    final cost = hour >= 19
        ? 'costs you the whole first day — you would land at $time with only '
            'dinner left'
        : hour >= 16
            ? 'costs you the first afternoon — you would land at $time'
            : 'lands at $time instead';

    return 'The $time flight is $amount cheaper but $cost.';
  }
}

extension _FirstLast<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _ListLast<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
