import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/design/tokens.dart';
import 'package:trippo/models/flight.dart';
import 'package:trippo/screens/wayfare/flights/flights_screen.dart';
import 'package:trippo/screens/wayfare/flights/consequence_sheet.dart';
import 'package:trippo/screens/wayfare/flights/offer_card.dart';
import 'package:trippo/screens/wayfare/trip_tab.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  WayfarePlatform platform = WayfarePlatform.ios,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WayfareTheme(
        platform: platform,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

FlightOffer offer({required bool isEstimate, num total = 1182}) =>
    FlightOffer.fromJson({
      'id': 'o1',
      'provider': isEstimate ? 'mock' : 'amadeus',
      'is_estimate': isEstimate,
      'price_total': total,
      'price_per_traveler': total / 3,
      'currency': 'MYR',
      'cabin': 'ECONOMY',
      'itineraries': [
        {
          'direction': 'outbound',
          'duration_minutes': 75,
          'stops': 0,
          'segments': [
            {
              'origin': 'KUL',
              'destination': 'SIN',
              'departs_at': '2026-09-12T12:00:00',
              'arrives_at': '2026-09-12T13:15:00',
              'flight_number': 'MH123',
              'duration_minutes': 75,
            },
          ],
        },
        {
          'direction': 'return',
          'duration_minutes': 70,
          'stops': 0,
          'segments': [
            {
              'origin': 'SIN',
              'destination': 'KUL',
              'departs_at': '2026-09-16T10:00:00',
              'arrives_at': '2026-09-16T11:10:00',
              'flight_number': 'MH188',
              'duration_minutes': 70,
            },
          ],
        },
      ],
    });

void main() {
  group('Estimate treatment', () {
    testWidgets('an estimate carries all four signals and a hedged CTA',
        (tester) async {
      await pump(
        tester,
        FlightOfferCard(
          offer: offer(isEstimate: true, total: 786),
          currency: 'MYR',
          onSelect: () {},
        ),
      );

      // 1. tilde prefix on the amount
      expect(find.text('~RM 786'), findsOneWidget);

      // 2. price ink muted rather than full ink
      final price = tester.widget<Text>(find.text('~RM 786'));
      expect(price.style?.color, WayfareColors.estimatePrice);

      // 4. the band, in words, adjacent to the price
      expect(find.text('ESTIMATE'), findsOneWidget);
      expect(
        find.textContaining('cannot be booked'),
        findsOneWidget,
      );

      // The CTA promises only the times, never a booking.
      expect(find.text('Use these times anyway'), findsOneWidget);
      expect(find.text('Use these flights'), findsNothing);
      // And the live-fare confirmation must not appear.
      expect(find.text('Live fare from the carrier'), findsNothing);
    });

    testWidgets('a live fare is confirmed and gets the full CTA',
        (tester) async {
      await pump(
        tester,
        FlightOfferCard(
          offer: offer(isEstimate: false),
          currency: 'MYR',
          onSelect: () {},
        ),
      );

      expect(find.text('RM 1,182'), findsOneWidget);
      final price = tester.widget<Text>(find.text('RM 1,182'));
      expect(price.style?.color, WayfareColors.ink);

      expect(find.text('Live fare from the carrier'), findsOneWidget);
      expect(find.text('ESTIMATE'), findsNothing);
      expect(find.text('Use these flights'), findsOneWidget);
    });

    testWidgets('legs read as times, route and meta', (tester) async {
      await pump(
        tester,
        FlightOfferCard(
          offer: offer(isEstimate: false),
          currency: 'MYR',
          onSelect: () {},
        ),
      );

      expect(find.text('OUT'), findsOneWidget);
      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('12:00 PM → 1:15 PM'), findsOneWidget);
      expect(find.text('KUL → SIN'), findsOneWidget);
      expect(find.textContaining('1h 15m · non-stop'), findsOneWidget);
      // Carrier code resolved to a name rather than left as "MH".
      expect(find.text('Malaysia Airlines'), findsOneWidget);
      expect(find.text('MH123 · MH188 return'), findsOneWidget);
    });

    testWidgets('a consequence warning shows before selection', (tester) async {
      await pump(
        tester,
        FlightOfferCard(
          offer: offer(isEstimate: false),
          currency: 'MYR',
          onSelect: () {},
          consequenceWarning: 'The 10:00 return means the last morning is gone.',
        ),
      );

      expect(
        find.text('The 10:00 return means the last morning is gone.'),
        findsOneWidget,
      );
    });
  });

  group('Unavailable', () {
    testWidgets('reads as a status, not an error', (tester) async {
      await pump(tester, const FlightsUnavailableView(checkedAt: '09:12'));

      expect(find.text('Flight search is switched off'), findsOneWidget);
      expect(
        find.textContaining('everything else on this trip works as normal'),
        findsOneWidget,
      );
      expect(find.textContaining('Checked at 09:12'), findsOneWidget);
      expect(find.text('Set the dates by hand'), findsOneWidget);
      expect(find.text('Paste a booking confirmation'), findsOneWidget);
    });
  });

  group('Consequence sheet', () {
    DateEnvelope worked() => DateEnvelope.fromJson({
          'start_date': '2026-09-12',
          'end_date': '2026-09-16',
          'arrival_local_time': '13:15',
          'departure_local_time': '10:00',
          'total_days': 5,
          'planning_days': 4,
          'short_days': [
            {
              'day': 1,
              'date': '2026-09-12',
              'usable_slots': ['afternoon', 'evening'],
              'lost_slots': ['morning'],
              'reason': 'late_arrival',
              'at': '13:15',
              'note': 'The flight lands at 13:15.',
            },
            {
              'day': 5,
              'date': '2026-09-16',
              'usable_slots': <String>[],
              'lost_slots': ['morning', 'afternoon', 'evening'],
              'reason': 'early_departure',
              'at': '10:00',
              'note': 'A 10:00 departure.',
            },
          ],
        });

    testWidgets('states the times plainly and names what each day loses',
        (tester) async {
      await pump(
        tester,
        ConsequenceSheet(
          offer: offer(isEstimate: false),
          envelope: worked(),
          currency: 'MYR',
          travellers: 3,
          onConfirm: () {},
          onPickDifferent: () {},
        ),
      );

      expect(find.text('These flights set your dates'), findsOneWidget);
      // The sub-line names both times and says that is the whole trip.
      expect(
        find.textContaining('lands 1:15 PM on Saturday'),
        findsOneWidget,
      );
      expect(find.textContaining('That is the whole trip'), findsOneWidget);

      // Envelope table, with the design's own figures.
      expect(find.text('Planning days'), findsOneWidget);
      expect(find.text('4 days · 1 short at each end'), findsOneWidget);
      expect(find.textContaining('RM 1,182 for 3'), findsOneWidget);
      expect(find.textContaining('live fare'), findsOneWidget);

      // What this costs you — one card per affected day, with slot counts.
      expect(find.text('WHAT THIS COSTS YOU'), findsOneWidget);
      expect(find.text('2 of 3 slots'), findsOneWidget);
      expect(find.text('0 of 3 slots'), findsOneWidget);
      expect(find.text('Day 1 starts after lunch'), findsOneWidget);
      expect(find.text('The last day is gone'), findsOneWidget);

      expect(find.text('Set the trip to these dates'), findsOneWidget);
      expect(find.text('Pick different flights'), findsOneWidget);
    });

    testWidgets('the trade-off names the cost, not just the saving',
        (tester) async {
      final cheaper = FlightOffer.fromJson({
        'id': 'o2',
        'is_estimate': false,
        'price_total': 786,
        'price_per_traveler': 262,
        'currency': 'MYR',
        'itineraries': [
          {
            'direction': 'outbound',
            'duration_minutes': 81,
            'stops': 0,
            'segments': [
              {
                'origin': 'KUL',
                'destination': 'SIN',
                'departs_at': '2026-09-12T18:40:00',
                'arrives_at': '2026-09-12T20:01:00',
                'flight_number': 'TR455',
                'duration_minutes': 81,
              },
            ],
          },
        ],
      });

      await pump(
        tester,
        ConsequenceSheet(
          offer: offer(isEstimate: false),
          envelope: worked(),
          currency: 'MYR',
          travellers: 3,
          cheaperAlternative: cheaper,
          onConfirm: () {},
          onPickDifferent: () {},
        ),
      );

      // Both halves of the trade: the saving AND what it takes away.
      expect(find.textContaining('RM 396 cheaper'), findsOneWidget);
      expect(find.textContaining('costs you the whole first day'), findsOneWidget);
    });

    testWidgets('no cheaper option means no trade-off panel', (tester) async {
      await pump(
        tester,
        ConsequenceSheet(
          offer: offer(isEstimate: false),
          envelope: worked(),
          currency: 'MYR',
          travellers: 3,
          onConfirm: () {},
          onPickDifferent: () {},
        ),
      );
      expect(find.textContaining('cheaper'), findsNothing);
    });
  });

  group('Short-day band', () {
    testWidgets('says what the day became and why, without padding it',
        (tester) async {
      final short = ShortDay.fromJson({
        'day': 1,
        'date': '2026-09-12',
        'usable_slots': ['afternoon', 'evening'],
        'lost_slots': ['morning'],
        'reason': 'late_arrival',
        'at': '13:15',
        'note': 'MH123 lands at 13:15 and the MRT takes 45 minutes.',
      });

      await pump(
        tester,
        ShortDayBand(short: short, flightLabel: 'Flight MH123'),
      );

      expect(find.text('SHORT DAY · FLIGHT MH123'), findsOneWidget);
      // The band reads 12-hour; `at` stays 24-hour in the data behind it.
      expect(
        find.text('Day 1 runs from 1:15 PM, not the morning.'),
        findsOneWidget,
      );
      // The explanation is worth reading once, so it stays folded away until
      // asked for — the headline above already carries the finding. It is
      // collapsed to nothing rather than removed, so that expanding can
      // animate; measure the band rather than looking for the widget.
      expect(
        find.textContaining('rather than pretending it exists'),
        findsOneWidget,
      );
      final collapsed = tester.getSize(find.byType(ShortDayBand)).height;

      await tester.tap(find.byType(ShortDayBand));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(ShortDayBand)).height,
        greaterThan(collapsed),
      );
      // The band explains the constraint; it does not also try to sell a
      // different flight from inside the itinerary.
      expect(find.text('See other flights'), findsNothing);
    });
  });

  group('Envelope', () {
    test('short days carry usable slots and a slot label', () {
      final envelope = DateEnvelope.fromJson({
        'start_date': '2026-09-12',
        'end_date': '2026-09-16',
        'arrival_local_time': '13:15',
        'departure_local_time': '10:00',
        'total_days': 5,
        'planning_days': 4,
        'short_days': [
          {
            'day': 1,
            'date': '2026-09-12',
            'usable_slots': ['afternoon', 'evening'],
            'lost_slots': ['morning'],
            'reason': 'late_arrival',
            'at': '13:15',
            'note': 'The flight lands at 13:15.',
          },
          {
            'day': 5,
            'date': '2026-09-16',
            'usable_slots': <String>[],
            'lost_slots': ['morning', 'afternoon', 'evening'],
            'reason': 'early_departure',
            'at': '10:00',
            'note': 'A 10:00 departure.',
          },
        ],
      });

      // The design's own figures.
      expect(envelope.planningDays, 4);
      expect(envelope.planningDaysLabel, '4 days · 1 short at each end');
      expect(envelope.shortDayFor(1)!.slotLabel, '2 of 3 slots');
      expect(envelope.shortDayFor(5)!.slotLabel, '0 of 3 slots');
      // A day with nothing usable is a write-off, not merely short.
      expect(envelope.shortDayFor(1)!.isWriteOff, isFalse);
      expect(envelope.shortDayFor(5)!.isWriteOff, isTrue);
      expect(envelope.shortDayFor(3), isNull);
    });
  });
}
