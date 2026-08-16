import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/flights/booked_flight_screen.dart';

/// Someone with a booking is not shopping. These pin what that means: the flow
/// asks for the flight number before anything else, dates come after, the
/// traveller confirms which departure they were on, and no price is ever shown
/// for a ticket they have already paid for.
///
/// Times are local to their own airport throughout — AK892 leaving KUL at
/// 16:55 (GMT+8) and the way home leaving at 18:45 (GMT+7) both read as the
/// boarding pass does.
void main() {
  late List<Map<String, dynamic>> lookups;
  late List<Map<String, dynamic>> selections;

  Map<String, dynamic> offer({
    required String number,
    required String direction,
    required String date,
    required String departs,
    required String arrives,
    String origin = 'KUL',
    String destination = 'BKK',
    String? arrivesDate,
  }) =>
      {
        'id': 'booked-$number-$departs',
        'provider': 'mock',
        'is_estimate': false,
        'booked': true,
        'price_total': 0,
        'price_per_traveler': 0,
        'currency': 'USD',
        'cabin': 'ECONOMY',
        'itineraries': [
          {
            'direction': direction,
            'duration_minutes': 195,
            'stops': 0,
            'segments': [
              {
                'origin': origin,
                'destination': destination,
                'departs_at': '${date}T$departs:00',
                'arrives_at': '${arrivesDate ?? date}T$arrives:00',
                'flight_number': number,
                'duration_minutes': 195,
              },
            ],
          },
        ],
      };

  /// [departuresPerDay] drives the "which departure" step: 0 is a number the
  /// schedule has never heard of, 2 is a number that flies twice that day.
  TrippoApi api({
    int departuresPerDay = 1,
    List<String> nearbyDates = const ['2026-09-27', '2026-09-30'],
  }) {
    lookups = [];
    selections = [];

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      if (request.url.path.endsWith('/flights/by-number')) {
        lookups.add(body);
        final number = body['flight_number'] as String;
        final date = body['scheduled_date'] as String;
        final direction = body['direction'] as String;
        final isReturn = direction == 'return';

        final offers = [
          if (departuresPerDay >= 1)
            offer(
              number: number,
              direction: direction,
              date: date,
              // The real AK892: 16:55 out of KUL, 18:45 on the way home.
              departs: isReturn ? '18:45' : '16:55',
              arrives: isReturn ? '21:50' : '18:05',
              origin: isReturn ? 'BKK' : 'KUL',
              destination: isReturn ? 'KUL' : 'BKK',
            ),
          if (departuresPerDay >= 2)
            offer(
              number: number,
              direction: direction,
              date: date,
              departs: '23:40',
              arrives: '02:35',
              arrivesDate: '2026-09-27',
            ),
        ];

        return http.Response(
          jsonEncode({
            'found': offers.isNotEmpty,
            'offers': offers,
            // What the schedule does have for this number, when it has nothing
            // for the date asked.
            'nearby_dates': offers.isEmpty ? nearbyDates : const <String>[],
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
    title: 'Bangkok',
    destinations: const ['Bangkok'],
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

  /// Types the outbound number and starts the lookup.
  Future<void> findFlight(
    WidgetTester tester,
    String outbound, {
    String? back,
  }) async {
    await tester.enterText(find.byType(TextField).first, outbound);
    if (back != null) {
      await tester.enterText(find.byType(TextField).last, back);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find my flight'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDown(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Opens the platform picker and accepts the date it opens on.
  ///
  /// Deliberately does not spin the wheel: what matters here is the flow and
  /// the bounds, and the bound is asserted directly off the widget rather
  /// than by trying to scroll past it.
  Future<void> pickDate(WidgetTester tester) async {
    await tapDown(tester, find.text('Choose a date'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the flight number before any date', (tester) async {
    await pump(tester, api());

    expect(find.text('FLIGHT NUMBERS'), findsOneWidget);
    expect(find.textContaining('Dates come next'), findsOneWidget);

    // No date question yet — nothing to date.
    expect(find.text('Choose a date'), findsNothing);
  });

  testWidgets('the date step waits for the button, not for typing',
      (tester) async {
    await pump(tester, api());

    await tester.enterText(find.byType(TextField).first, 'AK89');
    await tester.pumpAndSettle();

    // A heading that rewrites itself mid-number reads as a bug.
    expect(find.textContaining('take off?'), findsNothing);
    expect(find.text('Choose a date'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'AK892');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find my flight'));
    await tester.pumpAndSettle();

    expect(find.text('When does AK892 take off?'), findsOneWidget);
    expect(find.text('Choose a date'), findsOneWidget);
    // Trips are planned weeks out, so these would be the two dates nobody picks.
    expect(find.text('Today'), findsNothing);
    expect(find.text('Tomorrow'), findsNothing);
  });

  testWidgets('the button is dead until there is a number', (tester) async {
    await pump(tester, api());

    await tester.tap(find.text('Find my flight'));
    await tester.pumpAndSettle();
    expect(find.textContaining('take off?'), findsNothing);
  });

  testWidgets('picking a date lists that day\'s departures, no price',
      (tester) async {
    await pump(tester, api());
    await findFlight(tester, 'AK892');
    await pickDate(tester);

    expect(lookups.single['flight_number'], 'AK892');
    expect(lookups.single['direction'], 'outbound');

    expect(find.textContaining('only AK892 that day'), findsOneWidget);
    expect(find.text('4:55 PM → 6:05 PM'), findsOneWidget);
    expect(find.textContaining('KUL → BKK'), findsOneWidget);
    // Nothing has been committed by looking.
    expect(selections, isEmpty);
  });

  testWidgets('two departures are both offered and one must be chosen',
      (tester) async {
    await pump(tester, api(departuresPerDay: 2));
    await findFlight(tester, 'AK892');
    await pickDate(tester);

    expect(find.textContaining('AK892 flies 2 times that day'), findsOneWidget);
    expect(find.text('4:55 PM → 6:05 PM'), findsOneWidget);
    expect(find.text('11:40 PM → 2:35 AM'), findsOneWidget);
    // A landing on the next day changes which day the trip starts, so it says so.
    expect(find.text('+1 day'), findsOneWidget);
  });

  testWidgets('choosing a departure then prompts about the return',
      (tester) async {
    await pump(tester, api());
    await findFlight(tester, 'AK892');
    await pickDate(tester);
    await tapDown(tester, find.text('4:55 PM → 6:05 PM'));

    expect(find.text('Flying back?'), findsOneWidget);
    expect(find.textContaining('Skip it if this is one way'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);

    // Confirming is not offered until the return question is settled.
    expect(find.text('Use these dates'), findsNothing);
  });

  testWidgets('skipping the return goes straight to confirming', (tester) async {
    await pump(tester, api());
    await findFlight(tester, 'AK892');
    await pickDate(tester);
    await tapDown(tester, find.text('4:55 PM → 6:05 PM'));
    await tapDown(tester, find.text('Skip for now'));

    expect(find.text('Use these dates'), findsOneWidget);

    await tapDown(tester, find.text('Use these dates'));
    expect(selections.length, 1);
    expect(selections.single['direction'], 'outbound');
    expect((selections.single['offer'] as Map)['booked'], isTrue);
  });

  testWidgets('the return is asked for only once the outbound is settled',
      (tester) async {
    await pump(tester, api());
    await findFlight(tester, 'AK892');

    // One boarding pass at a time: no return field until the outbound is done.
    expect(find.text('Flying back?'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await pickDate(tester);
    await tapDown(tester, find.text('4:55 PM → 6:05 PM'));

    // Now the question appears, with the field inside it rather than pointing
    // back up the screen at a box that was already there.
    expect(find.text('Flying back?'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'AK893');
    await tester.pumpAndSettle();
    await tapDown(tester, find.text('Find the return flight'));

    expect(find.text('When does AK893 take off?'), findsOneWidget);
    expect(
      find.textContaining('is closed off'),
      findsOneWidget,
      reason: 'the return cannot leave before the outbound arrives',
    );

    // And the picker itself enforces it, not just the sentence under it.
    await tapDown(tester, find.text('Choose a date'));
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    final outboundDay = DateTime.parse(
      lookups.first['scheduled_date'] as String,
    );
    expect(picker.minimumDate, outboundDay);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(lookups.last['direction'], 'return');
    // The return's own local time, not converted into the outbound's zone.
    expect(find.text('6:45 PM → 9:50 PM'), findsOneWidget);

    await tapDown(tester, find.text('6:45 PM → 9:50 PM'));
    await tapDown(tester, find.text('Use these dates'));

    expect(selections.map((s) => s['direction']), ['outbound', 'return']);
  });

  testWidgets('a flight our schedule lacks is not the traveller\'s fault',
      (tester) async {
    await pump(tester, api(departuresPerDay: 0));
    await findFlight(tester, 'AK893');
    await pickDate(tester);

    // Our feed is demonstrably incomplete — it misses dates other sources
    // carry — so this must never read as "you got it wrong".
    expect(find.text('NOT IN OUR SCHEDULE'), findsOneWidget);
    expect(find.textContaining('Our flight data has gaps'), findsOneWidget);
    expect(find.textContaining('Check the number'), findsNothing);
    expect(find.textContaining('went wrong'), findsNothing);

    // The dates we do have, offered as one tap each.
    expect(find.text('27 September'), findsOneWidget);
    expect(find.text('30 September'), findsOneWidget);

    // And a way through regardless of what our data says.
    expect(find.text('Enter the times myself'), findsOneWidget);
  });

  testWidgets('with no alternatives, it still defers to the booking',
      (tester) async {
    await pump(tester, api(departuresPerDay: 0, nearbyDates: const []));
    await findFlight(tester, 'AK893');
    await pickDate(tester);

    expect(
      find.textContaining('If your booking says otherwise, your booking is '
          'right'),
      findsOneWidget,
    );
    expect(find.text('Enter the times myself'), findsOneWidget);
  });

  testWidgets('a chosen leg can be changed without starting over',
      (tester) async {
    await pump(tester, api());
    await findFlight(tester, 'AK892');
    await pickDate(tester);
    await tapDown(tester, find.text('4:55 PM → 6:05 PM'));

    expect(find.text('Change'), findsOneWidget);
    await tapDown(tester, find.text('Change'));

    // Back to the date question, with the number still typed in.
    expect(find.text('When does AK892 take off?'), findsOneWidget);
    expect(find.text('Use these dates'), findsNothing);
  });
}
