import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/screens/wayfare/trip_tab.dart';
import 'package:trippo/state/wayfare_controller.dart';

/// The real finding, from the 小红书 KL import that exposed the bug: the note
/// gave ICC Pudu's hours as 6am–2pm and the plan put the stop at 18:00.
const _iccPudu = PlanClosure(
  day: 1,
  blockId: 'blk_icc',
  activity: 'ICC Pudu',
  at: '18:00',
  note: 'ICC Pudu is open 06:00–14:00, but this is at 18:00.',
  closedAllDay: false,
);

const _rexOnMonday = PlanClosure(
  day: 2,
  blockId: 'blk_rex',
  activity: 'REXKL',
  at: '11:00',
  note: 'REXKL is closed on Mondays.',
  closedAllDay: true,
);

Map<String, dynamic> _block(String id, String? at) => {
      'id': id,
      'time_of_day': 'morning',
      'activity': 'Activity $id',
      'description': '',
      'location': '',
      'start_time': at,
      'estimated_duration_minutes': null,
      'estimated_cost_per_person': null,
      'suited_for_members': <String>[],
      'optional': false,
      'weather_backup': null,
      'from_place_id': 'plc_$id',
      'from_source_title': null,
    };

Plan _plan({String marketAt = '09:00'}) => Plan.fromJson({
      'conversational_summary': '',
      'status': 'complete',
      'trip': {'currency': 'MYR'},
      'itinerary': [
        {
          'day': 1,
          'location': 'Kuala Lumpur',
          'blocks': [_block('kafei', '08:30'), _block('icc', marketAt)],
        },
      ],
      'clarifying_questions': <String>[],
    });

/// Counts how often the check is asked for, which is the point of the test.
class _FakeApi extends TrippoApi {
  _FakeApi() : super(ApiClient(baseUrl: 'http://localhost:0'));

  int asked = 0;
  List<PlanClosure> answer = const [_iccPudu];

  @override
  Future<List<PlanClosure>> planClosures(String tripId) async {
    asked++;
    return answer;
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WayfareTheme(
        platform: WayfarePlatform.ios,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('The band for stops timed when the place is shut', () {
    testWidgets('says which stop, and when it is actually open', (tester) async {
      await _pump(tester, const ClosedStopsBand(closures: [_iccPudu]));

      // Not behind a tap: the plan is wrong about something it was told, and
      // there is nothing for the traveller to weigh up.
      expect(find.text('ICC Pudu is open 06:00–14:00, but this is at 18:00.'), findsOne);
      // WayfareEyebrow upper-cases what it is given.
      expect(find.text('CLOSED THEN'), findsOne);
    });

    testWidgets('counts them when a day has more than one', (tester) async {
      await _pump(tester, const ClosedStopsBand(closures: [_iccPudu, _rexOnMonday]));

      expect(find.text('CLOSED THEN · 2 STOPS'), findsOne);
      expect(find.textContaining('closed on Mondays'), findsOne);
    });
  });

  group('Asking the server for the check', () {
    WayfareController controller(TrippoApi api) =>
        WayfareController(api, 'trip_kl')..plan = _plan();

    test('each day sees only its own findings', () async {
      final c = controller(_FakeApi())..closures = const [_iccPudu, _rexOnMonday];

      expect(c.closuresFor(1).single.activity, 'ICC Pudu');
      expect(c.closuresFor(2).single.activity, 'REXKL');
      expect(c.closuresFor(3), isEmpty);
    });

    test('asks once for a plan whose timing has not moved', () async {
      final api = _FakeApi();
      final c = controller(api);

      // Three day pages build either side of a swipe; that must not be three
      // requests.
      c.ensureClosures();
      await Future<void>.delayed(Duration.zero);
      c.ensureClosures();
      c.ensureClosures();
      await Future<void>.delayed(Duration.zero);

      expect(api.asked, 1);
      expect(c.closures.single.activity, 'ICC Pudu');
    });

    test('asks again once a stop has been retimed', () async {
      final api = _FakeApi();
      final c = controller(api);

      c.ensureClosures();
      await Future<void>.delayed(Duration.zero);

      // The traveller moves the market into its hours. The old answer is now
      // a lie, so it has to be re-asked rather than kept.
      api.answer = const [];
      c.plan = _plan(marketAt: '07:00');
      c.ensureClosures();
      await Future<void>.delayed(Duration.zero);

      expect(api.asked, 2);
      expect(c.closures, isEmpty);
    });

    test('a failed check leaves the plan readable', () async {
      final api = _ThrowingApi();
      final c = controller(api)..closures = const [_iccPudu];

      c.ensureClosures();
      await Future<void>.delayed(Duration.zero);

      // Better a plan with no check than no plan.
      expect(c.closures, isEmpty);
    });
  });
}

class _ThrowingApi extends TrippoApi {
  _ThrowingApi() : super(ApiClient(baseUrl: 'http://localhost:0'));

  @override
  Future<List<PlanClosure>> planClosures(String tripId) async =>
      throw ApiException(statusCode: 500, code: 'boom', message: 'nope');
}
