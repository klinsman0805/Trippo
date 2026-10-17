import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/travel.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/trip_tab.dart';
import 'package:trippo/state/wayfare_controller.dart';

/// Answers travel requests from a function, and remembers what it was asked.
class _FakeApi extends TrippoApi {
  _FakeApi(this.answer) : super(ApiClient(baseUrl: 'http://localhost:0'));

  final TravelLeg Function(String from, String to) answer;
  final List<List<({String from, String to})>> requests = [];
  bool fail = false;

  @override
  Future<({List<TravelLeg> legs, String? attribution})> travelLegs(
    String tripId,
    List<({String from, String to})> pairs,
  ) async {
    requests.add(pairs);
    if (fail) {
      throw ApiException(statusCode: 503, code: 'down', message: 'down');
    }
    return (
      legs: [for (final p in pairs) answer(p.from, p.to)],
      attribution: '© OpenStreetMap contributors',
    );
  }
}

TravelLeg _train(String from, String to, {int minutes = 22}) => TravelLeg(
      fromBlockId: from,
      toBlockId: to,
      status: LegStatus.ok,
      minutes: minutes,
      vehicle: Vehicle.train,
      line: 'Kelana Jaya Line',
    );

TravelLeg _walk(String from, String to) => TravelLeg(
      fromBlockId: from,
      toBlockId: to,
      status: LegStatus.ok,
      minutes: 9,
      vehicle: Vehicle.walk,
      isEstimate: true,
    );

Map<String, dynamic> _block(
  String id,
  String slot, {
  bool optional = false,
  String? location,
}) =>
    {
      'id': id,
      'time_of_day': slot,
      'activity': 'Activity $id',
      'description': '',
      'location': location ?? 'Place $id',
      'estimated_duration_minutes': null,
      'estimated_cost_per_person': 10,
      'suited_for_members': <String>[],
      'optional': optional,
      'weather_backup': null,
    };

Plan _plan(List<Map<String, dynamic>> blocks) => Plan.fromJson({
      'conversational_summary': '',
      'status': 'complete',
      'trip': {'currency': 'MYR'},
      'itinerary': [
        {
          'day': 1,
          'date': '2026-11-03',
          'location': 'Kuala Lumpur',
          'blocks': blocks,
        },
      ],
      'clarifying_questions': <String>[],
    });

WayfareController _controller(TrippoApi api, Plan plan) {
  final controller = WayfareController(api, 'trip_kl');
  controller.trip = Trip(
    id: 'trip_kl',
    title: 'KL',
    destinations: const ['Kuala Lumpur'],
    startDate: '2026-11-03',
    endDate: '2026-11-03',
    currency: 'MYR',
    members: const [],
    updatedAt: DateTime(2026, 10, 1),
  );
  controller.plan = plan;
  controller.loading = false;
  return controller;
}

Future<void> _pump(WidgetTester tester, WayfareController controller) async {
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
          ),
        ),
      ),
    ),
  );
  // The first frame asks; the next frames draw the answer growing in.
  await tester.pumpAndSettle();
}

void main() {
  group('How a leg reads', () {
    test('a routed ride names its vehicle and line', () {
      expect(travelPhrase(_train('a', 'b')), '22 min by train · Kelana Jaya Line');
    });

    test('an estimate says so, every time', () {
      // The `~` is what stops a straight-line guess reading as a timetable.
      expect(travelPhrase(_walk('a', 'b')), '~9 min walk');
      expect(
        travelPhrase(const TravelLeg(
          fromBlockId: 'a',
          toBlockId: 'b',
          status: LegStatus.ok,
          minutes: 25,
          vehicle: Vehicle.transit,
          isEstimate: true,
        )),
        '~25 min by transit',
      );
    });

    test('an hour or more reads in hours', () {
      expect(travelPhrase(_train('a', 'b', minutes: 75)), '1h 15m by train · Kelana Jaya Line');
    });
  });

  group('Which cards travel connects', () {
    test('in drawn order, skipping anytime and hidden optional ones', () {
      final controller = _controller(
        _FakeApi(_train),
        _plan([
          _block('eve', 'evening'),
          _block('any', 'anytime'),
          _block('am', 'morning'),
          _block('opt', 'afternoon', optional: true),
          _block('pm', 'afternoon'),
        ]),
      );
      final day = controller.plan!.itinerary.single;

      expect(controller.travelChainOn(day).map((b) => b.id), ['am', 'opt', 'pm', 'eve']);

      controller.showOptional = false;
      expect(controller.travelChainOn(day).map((b) => b.id), ['am', 'pm', 'eve']);
    });
  });

  group('Travel on the day', () {
    testWidgets('a leg arrives between the two cards it joins', (tester) async {
      final api = _FakeApi(_train);
      final controller = _controller(
        api,
        _plan([_block('a', 'morning'), _block('b', 'afternoon')]),
      );

      await _pump(tester, controller);

      expect(api.requests.single, [(from: 'a', to: 'b')]);
      expect(find.text('22 min by train · Kelana Jaya Line'), findsOneWidget);
      // The day's total leads the meta line, ahead of the money.
      expect(find.text('22m travel · RM 20 pp planned'), findsOneWidget);
      // ODbL: the credit is on screen wherever the times are.
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);

      // Above the second card, below the first — it is the gap between them.
      final first = tester.getTopLeft(find.text('Activity a')).dy;
      final leg = tester.getTopLeft(find.text('22 min by train · Kelana Jaya Line')).dy;
      final second = tester.getTopLeft(find.text('Activity b')).dy;
      expect(leg, greaterThan(first));
      expect(leg, lessThan(second));
    });

    testWidgets('a day with one activity asks for nothing', (tester) async {
      final api = _FakeApi(_train);
      await _pump(tester, _controller(api, _plan([_block('a', 'morning')])));

      expect(api.requests, isEmpty);
      expect(find.text('RM 10 pp planned'), findsOneWidget);
    });

    testWidgets('an unplaceable stop is named, and the total admits it',
        (tester) async {
      final api = _FakeApi((from, to) => to == 'c'
          ? TravelLeg(
              fromBlockId: from,
              toBlockId: to,
              status: LegStatus.unplaced,
              unplacedEnd: 'to',
            )
          : _train(from, to));
      final controller = _controller(
        api,
        _plan([
          _block('a', 'morning'),
          _block('b', 'afternoon'),
          _block('c', 'evening'),
        ]),
      );

      await _pump(tester, controller);

      // Named, so the fix — give it a real address — is obvious.
      expect(
        find.text("Travel time unknown — couldn't place Activity c"),
        findsOneWidget,
      );
      // A floor, not a promise.
      expect(find.text('22m+ travel · RM 30 pp planned'), findsOneWidget);
    });

    testWidgets('two cards at the same spot draw no connector', (tester) async {
      final api = _FakeApi((from, to) => TravelLeg(
            fromBlockId: from,
            toBlockId: to,
            status: LegStatus.samePlace,
          ));
      await _pump(
        tester,
        _controller(api, _plan([_block('a', 'morning'), _block('b', 'afternoon')])),
      );

      expect(find.byType(TravelConnector), findsOneWidget);
      expect(find.byIcon(Icons.train_outlined), findsNothing);
      expect(find.byIcon(Icons.directions_walk), findsNothing);
      // Nothing to add up, so the meta line is the money alone.
      expect(find.text('RM 20 pp planned'), findsOneWidget);
    });

    testWidgets('a long hop is called out', (tester) async {
      final api = _FakeApi((f, t) => _train(f, t, minutes: 80));
      await _pump(
        tester,
        _controller(api, _plan([_block('a', 'morning'), _block('b', 'afternoon')])),
      );

      expect(
        tester.semantics.find(find.byIcon(Icons.train_outlined)).label,
        '1h 20m by train · Kelana Jaya Line. A long hop.',
      );
    });

    testWidgets('a failed fetch leaves the day as it was', (tester) async {
      final api = _FakeApi(_train)..fail = true;
      await _pump(
        tester,
        _controller(api, _plan([_block('a', 'morning'), _block('b', 'afternoon')])),
      );

      expect(find.textContaining('by train'), findsNothing);
      expect(find.text('RM 20 pp planned'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsNothing);

      // And it does not keep asking on every rebuild.
      controller(tester).toggleOptional();
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(1));
    });

    testWidgets('hiding an optional stop asks for the leg that skips it',
        (tester) async {
      final api = _FakeApi(_train);
      final controller = _controller(
        api,
        _plan([
          _block('a', 'morning'),
          _block('opt', 'afternoon', optional: true),
          _block('c', 'evening'),
        ]),
      );

      await _pump(tester, controller);
      expect(api.requests.single, [(from: 'a', to: 'opt'), (from: 'opt', to: 'c')]);

      controller.toggleOptional();
      await tester.pumpAndSettle();

      expect(api.requests.last, [(from: 'a', to: 'c')]);
    });

    test('moving an activity elsewhere is a new leg, not the old one', () async {
      final api = _FakeApi(_train);
      final controller = _controller(
        api,
        _plan([_block('a', 'morning'), _block('b', 'afternoon')]),
      );

      controller.ensureTravelFor(controller.plan!.itinerary.single);
      await Future<void>.delayed(Duration.zero);
      expect(controller.travelOn(controller.plan!.itinerary.single)!.minutes, 22);

      // Same block id, different place: the old time would be a lie.
      controller.plan = _plan([
        _block('a', 'morning'),
        _block('b', 'afternoon', location: 'Batu Caves'),
      ]);
      final moved = controller.plan!.itinerary.single;
      expect(controller.travelOn(moved), isNull);

      controller.ensureTravelFor(moved);
      expect(api.requests, hasLength(2));
    });
  });
}

/// The controller behind the pumped Trip tab.
WayfareController controller(WidgetTester tester) =>
    tester.widget<TripTab>(find.byType(TripTab)).controller;
