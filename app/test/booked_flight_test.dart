import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/flights/booked_flight_screen.dart';

/// Someone with a booking is not shopping. These pin the two things that makes
/// true: the flow asks only for what is on their confirmation email, and it
/// never puts a price on a ticket they have already paid for.
void main() {
  late List<Map<String, dynamic>> lookups;
  late List<Map<String, dynamic>> selections;

  TrippoApi api({bool found = true}) {
    lookups = [];
    selections = [];

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      if (request.url.path.endsWith('/flights/by-number')) {
        lookups.add(body);
        if (!found) return http.Response(jsonEncode({'found': false, 'offer': null}), 200);
        return http.Response(
          jsonEncode({
            'found': true,
            'offer': {
              'id': 'booked-MH123',
              'provider': 'mock',
              'is_estimate': false,
              'booked': true,
              'price_total': 0,
              'price_per_traveler': 0,
              'currency': 'USD',
              'cabin': 'ECONOMY',
              'itineraries': [
                {
                  'direction': body['direction'],
                  'duration_minutes': 75,
                  'stops': 0,
                  'segments': [
                    {
                      'origin': 'KUL',
                      'destination': 'SIN',
                      'departs_at': '2026-09-12T12:00:00',
                      'arrives_at': '2026-09-12T13:15:00',
                      'flight_number': body['flight_number'],
                      'duration_minutes': 75,
                    },
                  ],
                },
              ],
            },
          }),
          200,
        );
      }

      selections.add(body);
      return http.Response(jsonEncode({'date_envelope': null}), 201);
    });

    return TrippoApi(ApiClient(baseUrl: 'http://stub', client: client));
  }

  final trip = Trip(
    id: 'trip_1',
    title: 'Singapore',
    destinations: const ['Singapore'],
    currency: 'MYR',
    updatedAt: DateTime(2026, 9, 1),
  );

  Future<void> pump(WidgetTester tester, TrippoApi client) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => WayfareTheme(
          platform: WayfarePlatform.ios,
          child: child ?? const SizedBox.shrink(),
        ),
        home: BookedFlightScreen(
          api: client,
          trip: trip,
          onConfirmed: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Types a flight number and picks a date from the Material picker.
  Future<void> fillOutbound(WidgetTester tester, String number) async {
    await tester.enterText(find.byType(TextField).first, number);
    await tester.pump();
    await tester.tap(find.text('Pick a date').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks only for the number and the date', (tester) async {
    await pump(tester, api());

    expect(find.text('Your booked flight'), findsOneWidget);
    expect(find.textContaining('on your confirmation email'), findsOneWidget);
    // Getting there is required; coming back is not.
    expect(find.text('GETTING THERE'), findsOneWidget);
    expect(find.text('COMING BACK'), findsOneWidget);
    expect(find.text('optional'), findsOneWidget);

    // Nothing about cabin, travellers, or price — they already booked.
    expect(find.textContaining('Economy'), findsNothing);
    expect(find.text('Find my flight'), findsOneWidget);
  });

  testWidgets('a found flight shows times and explicitly no fare',
      (tester) async {
    final client = api();
    await pump(tester, client);
    await fillOutbound(tester, 'MH123');

    await tester.tap(find.text('Find my flight'));
    await tester.pumpAndSettle();

    expect(lookups.single['flight_number'], 'MH123');
    expect(find.text('12:00 → 13:15'), findsOneWidget);
    expect(find.textContaining('KUL → SIN'), findsOneWidget);
    expect(find.text('Already booked — no fare shown'), findsOneWidget);

    // Looking up is not committing — the second press is what writes.
    expect(selections, isEmpty);
    expect(find.text('Use these dates'), findsOneWidget);
  });

  testWidgets('confirming stores the leg', (tester) async {
    final client = api();
    await pump(tester, client);
    await fillOutbound(tester, 'MH123');

    await tester.tap(find.text('Find my flight'));
    await tester.pumpAndSettle();

    // The found-flight card pushes the CTA below the fold.
    await tester.ensureVisible(find.text('Use these dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use these dates'));
    await tester.pumpAndSettle();

    expect(selections.single['direction'], 'outbound');
    expect(
      (selections.single['offer'] as Map)['booked'],
      isTrue,
      reason: 'the stored offer must stay marked as booked, not as a fare',
    );
  });

  testWidgets('an unknown number fails against the field, not as an outage',
      (tester) async {
    await pump(tester, api(found: false));
    await fillOutbound(tester, 'ZZ999');

    await tester.tap(find.text('Find my flight'));
    await tester.pumpAndSettle();

    expect(find.textContaining("We can't find ZZ999"), findsOneWidget);
    // Names the real cause, rather than implying the service is broken.
    expect(
      find.textContaining('listed under the airline that operates them'),
      findsOneWidget,
    );
    expect(find.textContaining('went wrong'), findsNothing);
  });

  testWidgets('the CTA is dead until there is something to look up',
      (tester) async {
    final client = api();
    await pump(tester, client);

    await tester.tap(find.text('Find my flight'));
    await tester.pumpAndSettle();
    expect(lookups, isEmpty);
  });
}
