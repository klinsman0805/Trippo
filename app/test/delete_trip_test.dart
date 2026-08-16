import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/screens/trip_list_screen.dart';

/// Deleting a trip is the most destructive thing in the app — it cascades to
/// members, imported sources, flight selections and every plan revision. These
/// pin the confirmation in place, and specifically that a dismissed or
/// cancelled dialog deletes nothing.
void main() {
  /// Records every DELETE the screen actually issues.
  late List<String> deleted;

  TrippoApi stubbedApi({int memberCount = 3}) {
    deleted = [];

    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.path);
        return http.Response('', 204);
      }
      if (request.url.path.endsWith('/health')) {
        return http.Response(jsonEncode({'features': {}}), 200);
      }
      return http.Response(
        jsonEncode({
          'trips': [
            {
              'id': 'trip_1',
              'title': 'Portugal, Slowly',
              'destinations': ['Lisbon'],
              'currency': 'EUR',
              'member_count': memberCount,
              'updated_at': '2026-09-01T00:00:00.000Z',
            },
          ],
        }),
        200,
      );
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
        home: TripListScreen(api: api, onOpenTrip: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the trash icon asks first and names what goes', (tester) async {
    await pumpList(tester, stubbedApi());

    expect(find.text('Portugal, Slowly'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Portugal, Slowly?'), findsOneWidget);
    // The stakes are the cascade, not the one row the icon sits beside.
    expect(find.textContaining("3 travellers' preferences"), findsOneWidget);
    expect(find.textContaining('every plan it has produced'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);

    // Nothing has happened yet.
    expect(deleted, isEmpty);
  });

  testWidgets('"Keep it" deletes nothing', (tester) async {
    await pumpList(tester, stubbedApi());

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(deleted, isEmpty);
    expect(find.text('Portugal, Slowly'), findsOneWidget);
  });

  testWidgets('dismissing by tapping away deletes nothing', (tester) async {
    await pumpList(tester, stubbedApi());

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Barrier tap — the safe answer has to be the default on every path out,
    // not only on the button that says so.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(deleted, isEmpty);
  });

  testWidgets('confirming issues exactly one delete', (tester) async {
    await pumpList(tester, stubbedApi());

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, ['/v1/trips/trip_1']);
  });

  testWidgets('a trip with no travellers does not claim any', (tester) async {
    await pumpList(tester, stubbedApi(memberCount: 0));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('preferences'), findsNothing);
    expect(find.textContaining('every plan it has produced'), findsOneWidget);
  });

  testWidgets('one traveller reads as singular', (tester) async {
    await pumpList(tester, stubbedApi(memberCount: 1));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining("1 traveller's preferences"), findsOneWidget);
  });
}
