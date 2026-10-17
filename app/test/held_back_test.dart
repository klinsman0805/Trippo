import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/sources/held_back_sheet.dart';
import 'package:trippo/screens/wayfare/trip_tab.dart';
import 'package:trippo/state/wayfare_controller.dart';

const _title = '吉隆坡3天2夜旅游攻略';

Map<String, dynamic> _block(String id, String slot, {String? placeId}) => {
      'id': id,
      'time_of_day': slot,
      'activity': 'Activity $id',
      'description': '',
      'location': '',
      'estimated_duration_minutes': null,
      'estimated_cost_per_person': 10,
      'suited_for_members': <String>[],
      'optional': false,
      'weather_backup': null,
      'from_place_id': placeId,
      'from_source_title': placeId == null ? null : _title,
    };

Plan _plan({bool withMarket = false}) => Plan.fromJson({
      'conversational_summary': '',
      'status': 'complete',
      'trip': {'currency': 'MYR'},
      'itinerary': [
        {
          'day': 1,
          'location': 'Kuala Lumpur',
          'blocks': [
            _block('a', 'morning'),
            _block('b', 'afternoon', placeId: 'plc_alor'),
          ],
        },
        {
          'day': 2,
          'location': 'Kuala Lumpur',
          'blocks': [
            _block('c', 'morning'),
            if (withMarket) _block('d', 'afternoon', placeId: 'plc_market'),
          ],
        },
      ],
      'clarifying_questions': <String>[],
    });

const _places = [
  Place(id: 'plc_alor', name: 'Jalan Alor', category: 'food', sourceId: 'src_1'),
  Place(
    id: 'plc_market',
    name: 'Central Market',
    category: 'shopping',
    why: 'Batik and kopi upstairs',
    sourceId: 'src_1',
  ),
  Place(id: 'plc_hou', name: 'Thean Hou Temple', category: 'sight', sourceId: 'src_1'),
];

/// Adding a place answers with a plan that now cites it.
class _FakeApi extends TrippoApi {
  _FakeApi() : super(ApiClient(baseUrl: 'http://localhost:0'));

  final List<(int, Map<String, dynamic>)> added = [];

  @override
  Future<Plan> addActivity(String tripId, int day, Map<String, dynamic> activity) async {
    added.add((day, activity));
    return _plan(withMarket: true);
  }
}

WayfareController _controller(TrippoApi api) {
  final controller = WayfareController(api, 'trip_kl');
  controller.trip = Trip(
    id: 'trip_kl',
    title: 'KL',
    destinations: const ['Kuala Lumpur'],
    currency: 'MYR',
    members: const [],
    updatedAt: DateTime(2026, 10, 1),
  );
  controller.plan = _plan();
  controller.importedPlaces = _places;
  controller.sourceTitles = const {'src_1': _title};
  controller.loading = false;
  return controller;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WayfareTheme(
        platform: WayfarePlatform.ios,
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Which saved places the plan used', () {
    test('each cited place knows its day; the rest are held back', () {
      final controller = _controller(_FakeApi());

      expect(controller.dayOfPlace('plc_alor'), 1);
      expect(controller.dayOfPlace('plc_market'), isNull);
      expect(
        controller.heldBackPlaces.map((p) => p.id),
        ['plc_market', 'plc_hou'],
      );
    });

    test('with no plan, nothing is held back from it', () {
      final controller = _controller(_FakeApi())..plan = null;
      // A place cannot be left out of a plan that does not exist yet; every
      // saved place counts as unused, which the Trip tab never shows then.
      expect(controller.dayOfPlace('plc_alor'), isNull);
    });
  });

  group('The line at the foot of a day', () {
    testWidgets('counts what was left out and opens it', (tester) async {
      var opened = false;
      await _pump(
        tester,
        TripTab(
          controller: _controller(_FakeApi()),
          onAddActivity: (_) {},
          onEditActivity: (_) {},
          onRemoveActivity: (_) {},
          onAnswerQuestions: () {},
          onShowHeldBack: () => opened = true,
        ),
      );

      expect(find.text('2 places you saved aren’t in this plan'), findsOneWidget);
      await tester.tap(find.byType(HeldBackLine));
      expect(opened, isTrue);
    });

    testWidgets('says nothing when the plan used everything', (tester) async {
      final controller = _controller(_FakeApi())
        ..importedPlaces = [_places.first];
      await _pump(
        tester,
        TripTab(
          controller: controller,
          onAddActivity: (_) {},
          onEditActivity: (_) {},
          onRemoveActivity: (_) {},
          onAnswerQuestions: () {},
          onShowHeldBack: () {},
        ),
      );

      expect(find.byType(HeldBackLine), findsNothing);
    });
  });

  group('Putting one in the plan', () {
    testWidgets('lists them with their source, and adds where you choose',
        (tester) async {
      final api = _FakeApi();
      final controller = _controller(api);
      await _pump(tester, HeldBackSheet(controller: controller, day: 2));

      expect(find.text('Central Market'), findsOneWidget);
      expect(find.text('Shopping · Batik and kopi upstairs'), findsOneWidget);
      expect(find.text('From $_title'), findsNWidgets(2));

      // Add asks for the part of the day rather than guessing it.
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      expect(find.text('Afternoon'), findsOneWidget);

      await tester.tap(find.text('Afternoon'));
      await tester.pumpAndSettle();

      // Only the place's id goes up; the citation is the server's to make.
      expect(api.added.single.$1, 2);
      expect(api.added.single.$2, {'place_id': 'plc_market', 'time_of_day': 'afternoon'});

      // Now cited by the plan, so no longer held back.
      expect(find.text('Central Market'), findsNothing);
      expect(find.text('Thean Hou Temple'), findsOneWidget);
    });

    testWidgets('cancel closes the choice without adding', (tester) async {
      final api = _FakeApi();
      await _pump(tester, HeldBackSheet(controller: _controller(api), day: 1));

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Morning'), findsNothing);
      expect(api.added, isEmpty);
    });
  });
}
