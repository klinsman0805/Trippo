import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/screens/trip_list_screen.dart';

/// What the server says about itself, and how slowly it says it.
///
/// The delay is the point: every cold start spends a moment waiting on
/// /health, and what the list shows during that moment is the whole subject
/// of these tests.
TrippoApi stubbedApi({
  Map<String, dynamic>? features,
  Completer<void>? holdHealth,
}) {
  final client = MockClient((req) async {
    if (req.url.path.endsWith('/health')) {
      await holdHealth?.future;
      return http.Response(
        jsonEncode({
          'status': 'ok',
          'features': features ??
              {'planner': true, 'maps': true, 'flight_provider': 'mock'},
        }),
        200,
      );
    }
    return http.Response(jsonEncode({'trips': <dynamic>[]}), 200);
  });
  return TrippoApi(ApiClient(baseUrl: 'http://stub', client: client));
}

Future<void> pumpList(WidgetTester tester, TrippoApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => WayfareTheme(
        platform: WayfarePlatform.ios,
        child: child ?? const SizedBox.shrink(),
      ),
      home: TripListScreen(api: api, onOpenTrip: (_, _, _) {}),
    ),
  );
}

void main() {
  group('What the list says about the server before it has asked', () {
    testWidgets('nothing — not that everything is off', (tester) async {
      final hold = Completer<void>();
      await pumpList(tester, stubbedApi(holdHealth: hold));
      await tester.pump(); // first frame, /health still in flight

      // This is the bug. An unanswered /health read as an empty map, and an
      // empty map answers "false" to every question — so a cold start opened
      // by telling people their planner and maps were misconfigured, a second
      // before saying otherwise.
      expect(find.textContaining('Planning is off'), findsNothing);
      expect(find.textContaining('Maps and transit are off'), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('and once it has asked, only what is actually true',
        (tester) async {
      await pumpList(tester, stubbedApi());
      await tester.pumpAndSettle();

      expect(find.textContaining('Planning is off'), findsNothing);
      expect(find.text('Flight prices are mock estimates'), findsOne);
    });

    testWidgets('a feature that really is off is still named', (tester) async {
      await pumpList(
        tester,
        stubbedApi(features: {
          'planner': false,
          'maps': true,
          'flight_provider': 'amadeus',
        }),
      );
      await tester.pumpAndSettle();

      // Silence while unknown must not become silence once known: the notice
      // earns its place by naming the variable somebody has to go and set.
      expect(find.textContaining('no GEMINI_API_KEY set'), findsOne);
      expect(find.text('Flight prices are mock estimates'), findsNothing);
    });
  });
}
