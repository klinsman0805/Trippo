import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/travel.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/itinerary/day_map_screen.dart';
import 'package:trippo/screens/wayfare/trip_tab.dart';
import 'package:trippo/state/wayfare_controller.dart';

/// Points from a table; travel always the same train. Records what it was
/// asked, and can be told to fail.
class _FakeApi extends TrippoApi {
  _FakeApi(this.placed) : super(ApiClient(baseUrl: 'http://localhost:0'));

  /// Block id → (lat, lng). Anything missing is unplaced.
  final Map<String, (double, double)> placed;
  final List<int> pointRequests = [];
  bool fail = false;

  @override
  Future<DayPoints> dayPoints(String tripId, int day) async {
    pointRequests.add(day);
    if (fail) throw ApiException(statusCode: 503, code: 'down', message: 'down');
    return DayPoints(
      points: {
        for (final id in const ['a', 'b', 'c', 'any'])
          id: placed[id] == null
              ? BlockPoint(blockId: id)
              : BlockPoint(blockId: id, lat: placed[id]!.$1, lng: placed[id]!.$2),
      },
      anchorLat: 3.139,
      anchorLng: 101.6869,
      attribution: '© OpenStreetMap contributors',
    );
  }

  @override
  Future<({List<TravelLeg> legs, String? attribution})> travelLegs(
    String tripId,
    List<({String from, String to})> pairs,
  ) async =>
      (
        legs: [
          for (final p in pairs)
            TravelLeg(
              fromBlockId: p.from,
              toBlockId: p.to,
              status: LegStatus.ok,
              minutes: 12,
              vehicle: Vehicle.train,
            ),
        ],
        attribution: '© OpenStreetMap contributors',
      );
}

Map<String, dynamic> _block(String id, String slot, {String? location}) => {
      'id': id,
      'time_of_day': slot,
      'activity': 'Activity $id',
      'description': '',
      'location': location ?? 'Place $id',
      'estimated_duration_minutes': null,
      'estimated_cost_per_person': 10,
      'suited_for_members': <String>[],
      'optional': false,
      'weather_backup': null,
    };

Plan _plan() => Plan.fromJson({
      'conversational_summary': '',
      'status': 'complete',
      'trip': {'currency': 'MYR'},
      'itinerary': [
        {
          'day': 1,
          'date': '2026-11-03',
          'location': 'Kuala Lumpur',
          'blocks': [
            _block('c', 'evening'),
            _block('any', 'anytime'),
            _block('a', 'morning'),
            _block('b', 'afternoon'),
          ],
        },
        {
          'day': 2,
          'date': '2026-11-04',
          'location': 'Kuala Lumpur',
          'blocks': <dynamic>[],
        },
      ],
      'clarifying_questions': <String>[],
    });

WayfareController _controller(TrippoApi api) {
  final controller = WayfareController(api, 'trip_kl');
  controller.trip = Trip(
    id: 'trip_kl',
    title: 'KL',
    destinations: const ['Kuala Lumpur'],
    startDate: '2026-11-03',
    endDate: '2026-11-04',
    currency: 'MYR',
    members: const [],
    updatedAt: DateTime(2026, 10, 1),
  );
  controller.plan = _plan();
  controller.loading = false;
  return controller;
}

Future<void> _pumpMap(WidgetTester tester, WayfareController controller) async {
  // A phone-shaped surface, so the sheet has the height it has on a phone.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: WayfareTheme(
        platform: WayfarePlatform.ios,
        child: DayMapScreen(controller: controller),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// A pin, by what it announces.
Finder _pin(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );

const _klcc = (3.1579, 101.7116);
const _alor = (3.1456, 101.7088);
const _market = (3.1455, 101.6955);

void main() {
  group('The map\'s list', () {
    test('runs in the day\'s order, with anytime stops after it', () {
      final controller = _controller(_FakeApi(const {}));
      final day = controller.plan!.itinerary.first;

      expect(controller.mapOrderOn(day).map((b) => b.id), ['a', 'b', 'c', 'any']);
    });

    testWidgets('numbers stops in order and pins only the placed ones',
        (tester) async {
      final api = _FakeApi(const {'a': _klcc, 'c': _market});
      await _pumpMap(tester, _controller(api));

      expect(api.pointRequests, [1]);
      expect(_pin('Stop 1: Activity a'), findsOneWidget);
      // b could not be placed, so it has no pin at all...
      expect(_pin('Stop 2: Activity b'), findsNothing);
      // ...and numbers keep the day's order across the gap: 3 stays 3.
      expect(_pin('Stop 3: Activity c'), findsOneWidget);

      // Pull the sheet up: at rest it shows the first stops, and the list
      // only builds what is on screen.
      await tester.drag(find.text('Activity a'), const Offset(0, -500));
      await tester.pumpAndSettle();
      // Every stop is in the list, placed or not; the unplaced ones say so.
      for (final id in ['a', 'b', 'c', 'any']) {
        expect(find.text('Activity $id'), findsOneWidget);
      }
      expect(find.text("Not on the map — couldn't place it"), findsNWidgets(2));
    });

    testWidgets('travel between stops is the same as on the Trip tab',
        (tester) async {
      await _pumpMap(tester, _controller(_FakeApi(const {'a': _klcc, 'b': _alor, 'c': _market})));
      await tester.pump();

      // a→b and b→c; nothing into the anytime stop.
      expect(find.text('12 min by train'), findsNWidgets(2));
    });

    testWidgets('a day with nothing placed says so, rather than a blank map',
        (tester) async {
      await _pumpMap(tester, _controller(_FakeApi(const {})));

      expect(find.textContaining('None of this day’s stops could be placed'),
          findsOneWidget);
    });

    testWidgets('a failed lookup offers to try again, and does', (tester) async {
      final api = _FakeApi(const {'a': _klcc})..fail = true;
      await _pumpMap(tester, _controller(api));

      expect(find.text("Couldn't load where these are."), findsOneWidget);

      api.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.pointRequests, [1, 1]);
      expect(find.text("Couldn't load where these are."), findsNothing);
    });

    testWidgets('switching day in the sheet moves the whole app to that day',
        (tester) async {
      final api = _FakeApi(const {'a': _klcc});
      final controller = _controller(api);
      await _pumpMap(tester, controller);

      await tester.tap(find.text('Day 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.selectedDay, 2);
      expect(api.pointRequests, [1, 2]);
      expect(find.text('Nothing planned on this day yet.'), findsOneWidget);
    });
  });

  group('The way in', () {
    Future<void> pumpTrip(WidgetTester tester, WayfareController controller,
        {VoidCallback? onOpenMap}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WayfareTheme(
            platform: WayfarePlatform.ios,
            child: Scaffold(
              body: TripTab(
                controller: controller,
                onAddActivity: (_) {},
                onEditActivity: (_) {},
                onRemoveActivity: (_) {},
                onAnswerQuestions: () {},
                onOpenMap: onOpenMap,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a day with stops carries the map pill', (tester) async {
      var opened = false;
      await pumpTrip(tester, _controller(_FakeApi(const {})), onOpenMap: () => opened = true);

      await tester.tap(find.byType(MapPill));
      expect(opened, isTrue);
    });

    testWidgets('an empty day has nothing to map, so no pill', (tester) async {
      final controller = _controller(_FakeApi(const {}));
      controller.selectDay(2);
      await pumpTrip(tester, controller, onOpenMap: () {});

      expect(find.byType(MapPill), findsNothing);
    });
  });
}

