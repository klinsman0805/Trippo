import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/design/tokens.dart';
import 'package:trippo/design/widgets.dart';
import 'package:trippo/models/flight.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/budget_tab.dart';
import 'package:trippo/screens/wayfare/group_tab.dart';
import 'package:trippo/screens/wayfare/refine_tab.dart';
import 'package:trippo/screens/wayfare/trip_tab.dart';
import 'package:trippo/state/wayfare_controller.dart';

/// Renders a tab against a controller whose state is set directly — no network,
/// since `build` never touches the API.
Future<void> pumpTab(
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

WayfareController buildController({
  List<Member> members = const [],
  Plan? plan,
  List<ChatMessage> messages = const [],
}) {
  final controller = WayfareController(
    TrippoApi(ApiClient(baseUrl: 'http://localhost:0')),
    'trip_test',
  );
  controller.trip = Trip(
    id: 'trip_test',
    title: 'Portugal, Slowly',
    destinations: const ['Lisbon', 'Sintra', 'Porto'],
    startDate: '2026-09-12',
    endDate: '2026-09-16',
    currency: 'EUR',
    totalBudget: 4200,
    members: members,
    updatedAt: DateTime(2026, 9, 1),
  );
  controller.plan = plan;
  controller.messages = messages;
  controller.loading = false;
  return controller;
}

const _maya = Member(
  id: 'm1',
  name: 'Maya Okonkwo',
  interests: ['Food markets', 'Museums'],
  pace: Pace.packed,
  dietaryRestrictions: ['Vegetarian'],
);
const _diego = Member(
  id: 'm2',
  name: 'Diego Ferreira',
  interests: ['Surfing'],
  pace: Pace.moderate,
);
const _ruth = Member(
  id: 'm3',
  name: 'Ruth Adler',
  interests: ['Architecture'],
  pace: Pace.relaxed,
  dietaryRestrictions: ['Gluten-free'],
  accessibilityNeeds: ['Limited stairs'],
);

Plan samplePlan({bool overBudget = true}) => Plan.fromJson({
      'conversational_summary': 'Built around slow mornings.',
      'status': 'complete',
      'missing_info': <String>[],
      'trip': {
        'title': 'Portugal, Slowly',
        'destinations': ['Lisbon'],
        'start_date': '2026-09-12',
        'end_date': '2026-09-16',
        'duration_days': 5,
        'currency': 'EUR',
        'total_budget': 4200,
        'budget_breakdown': {
          'lodging': {'planned': 1740, 'estimated': 1844},
          'transport': {'planned': 610, 'estimated': 641},
          'food': {'planned': 890, 'estimated': 837},
          'activities': {'planned': 540, 'estimated': 605},
          'buffer': {'planned': 420, 'estimated': 420},
        },
        'estimated_total_cost': overBudget ? 4347 : 3900,
        'over_budget': overBudget,
        'assumptions': <String>[],
      },
      'members': [
        {
          'id': 'm1',
          'name': 'Maya Okonkwo',
          'interests': <String>[],
          'pace': 'packed',
          'dietary_restrictions': <String>[],
          'accessibility_needs': <String>[],
          'deal_breakers': <String>[],
        },
        {
          'id': 'm3',
          'name': 'Ruth Adler',
          'interests': <String>[],
          'pace': 'relaxed',
          'dietary_restrictions': <String>[],
          'accessibility_needs': <String>[],
          'deal_breakers': <String>[],
        },
      ],
      'conflicts': [
        {
          'tag': 'Pace',
          'description': 'Maya wants every day full; Ruth needs slow mornings.',
          'members_involved': ['m1', 'm3'],
          'resolution': 'Nothing starts before 10:00.',
        },
      ],
      'itinerary': [
        {
          'day': 1,
          'date': '2026-09-12',
          'location': 'Lisbon · Alfama',
          'lodging_area_suggestion': 'Alfama',
          'blocks': [
            {
              'time_of_day': 'morning',
              'activity': 'Land in Lisbon, settle into Alfama',
              'description': 'Metro from the airport.',
              'location': 'Alfama',
              'estimated_duration_minutes': 180,
              'estimated_cost_per_person': 12,
              'suited_for_members': ['m1', 'm3'],
              'optional': false,
              'weather_backup': null,
            },
            {
              'time_of_day': 'evening',
              'activity': 'Sunset drinks at Senhora do Monte',
              'description': 'Skip if the workshop ran long.',
              'location': 'Graça',
              'estimated_duration_minutes': 90,
              'estimated_cost_per_person': 22,
              'suited_for_members': ['m1'],
              'optional': true,
              'weather_backup': null,
            },
          ],
          'notes': null,
        },
      ],
      'packing_and_prep_notes': <String>[],
      'verify_before_booking': <String>[],
      'clarifying_questions': <String>[],
    });

/// Which flight a short day blames.
///
/// A day cut short at the start is the arriving flight's doing; one cut short
/// at the end is the departing flight's. Labelling both with the outbound
/// number told the user the wrong aircraft ended their last day.
void _shortDayLabels() {
  test('a short day names the flight that actually caused it', () {
    final controller = buildController();
    controller.outboundFlightLabel = 'Flight AK892';
    controller.returnFlightLabel = 'Flight AK893';

    final arrival = ShortDay.fromJson(const {
      'day': 1,
      'date': '2026-09-26',
      'usable_slots': ['evening'],
      'lost_slots': ['morning', 'afternoon'],
      'reason': 'late_arrival',
      'at': '18:10',
      'note': '',
    });
    final departure = ShortDay.fromJson(const {
      'day': 5,
      'date': '2026-09-30',
      'usable_slots': ['morning', 'afternoon'],
      'lost_slots': ['evening'],
      'reason': 'early_departure',
      'at': '18:45',
      'note': '',
    });

    expect(controller.flightLabelFor(arrival), 'Flight AK892');
    expect(controller.flightLabelFor(departure), 'Flight AK893');
  });
}

void main() {
  _shortDayLabels();
  group('Trip tab', () {
    testWidgets('renders day chips, costs and the optional badge',
        (tester) async {
      final controller = buildController(
        members: const [_maya, _diego, _ruth],
        plan: samplePlan(),
      );
      await pumpTab(tester, TripTab(
          controller: controller,
          onAddActivity: (_) {},
          onEditActivity: (_) {},
          onRemoveActivity: (_) {},
        ));

      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Lisbon · Alfama'), findsOneWidget);
      // Day cost is the sum of both blocks, per person.
      expect(find.text('€34 pp planned'), findsOneWidget);
      expect(find.text('€12 pp'), findsOneWidget);
      expect(find.text('OPTIONAL'), findsOneWidget);
      expect(find.text('Hide optional activities'), findsOneWidget);
    });

    testWidgets('hiding optional drops the block and its cost', (tester) async {
      final controller = buildController(
        members: const [_maya, _diego, _ruth],
        plan: samplePlan(),
      );
      controller.showOptional = false;
      await pumpTab(tester, TripTab(
          controller: controller,
          onAddActivity: (_) {},
          onEditActivity: (_) {},
          onRemoveActivity: (_) {},
        ));

      expect(find.text('Sunset drinks at Senhora do Monte'), findsNothing);
      expect(find.text('€12 pp planned'), findsOneWidget);
      expect(find.text('Show optional activities'), findsOneWidget);
    });

    testWidgets('a block for a subset of members names them, not "Everyone"',
        (tester) async {
      final controller = buildController(
        members: const [_maya, _diego, _ruth],
        plan: samplePlan(),
      );
      await pumpTab(tester, TripTab(
          controller: controller,
          onAddActivity: (_) {},
          onEditActivity: (_) {},
          onRemoveActivity: (_) {},
        ));

      // The morning block covers 2 of 3 travellers → names, not "Everyone".
      expect(find.text('Maya, Ruth'), findsOneWidget);
      expect(find.text('Everyone'), findsNothing);
    });

    testWidgets('shows the updated notice only on the changed day',
        (tester) async {
      final controller = buildController(
        members: const [_maya, _ruth],
        plan: samplePlan(),
      );
      controller.updatedDay = 1;
      await pumpTab(tester, TripTab(
          controller: controller,
          onAddActivity: (_) {},
          onEditActivity: (_) {},
          onRemoveActivity: (_) {},
        ));

      expect(find.text('Updated from your last chat request.'), findsOneWidget);
    });
  });

  group('Budget tab', () {
    testWidgets('over budget shows the overspend and both bar sets',
        (tester) async {
      final controller = buildController(
        members: const [_maya, _diego, _ruth],
        plan: samplePlan(),
      );
      await pumpTab(tester, BudgetTab(controller: controller));

      expect(find.text('OVER BUDGET'), findsOneWidget);
      expect(find.text('€147 over'), findsOneWidget);
      expect(find.text('€4,347 estimated'), findsOneWidget);
      expect(find.text('€4,200 budget'), findsOneWidget);
      expect(find.text('€1,449 each'), findsOneWidget);

      // Per-category planned/estimated pairs.
      expect(find.text('planned €1,740'), findsOneWidget);
      expect(find.text('est. €1,844'), findsOneWidget);
      expect(find.text('+€104'), findsOneWidget); // lodging over
      expect(find.text('−€53'), findsOneWidget); // food under
      expect(find.text('on plan'), findsOneWidget); // buffer untouched
    });

    testWidgets('under budget flips the headline and colours', (tester) async {
      final controller = buildController(
        members: const [_maya, _diego, _ruth],
        plan: samplePlan(overBudget: false),
      );
      await pumpTab(tester, BudgetTab(controller: controller));

      expect(find.text('UNDER BUDGET'), findsOneWidget);
      expect(find.text('€300 to spare'), findsOneWidget);
    });
  });

  group('Group tab', () {
    testWidgets('empty state prompts for the first traveller', (tester) async {
      final controller = buildController();
      await pumpTab(tester, GroupTab(controller: controller));

      expect(find.text('No travellers yet'), findsOneWidget);
      expect(find.text('Add the first traveller'), findsOneWidget);
    });

    testWidgets('one traveller still plans, and says what a second adds',
        (tester) async {
      final controller = buildController(members: const [_maya]);
      await pumpTab(tester, GroupTab(controller: controller));

      // Travellers tailor the plan; they do not gate it. What they buy you is
      // stated as an invitation rather than as a requirement.
      expect(controller.canGenerate, isTrue);
      expect(
        find.text(
          'Add a second traveller and the planner starts balancing between you.',
        ),
        findsOneWidget,
      );
      expect(find.text('Two travellers minimum'), findsNothing);

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Generate itinerary'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('a trip with no destination is what actually blocks Generate',
        (tester) async {
      final controller = buildController(members: const [_maya, _diego]);
      controller.trip = Trip(
        id: 'trip_test',
        title: 'Untitled',
        destinations: const [],
        currency: 'EUR',
        members: const [_maya, _diego],
        updatedAt: DateTime(2026, 9, 1),
      );

      await pumpTab(tester, GroupTab(controller: controller));

      expect(controller.canGenerate, isFalse);
      expect(
        find.text('Add a destination first — the planner needs somewhere to go.'),
        findsOneWidget,
      );
    });

    testWidgets('travellers render with pace, interests and needs',
        (tester) async {
      final controller = buildController(members: const [_maya, _diego, _ruth]);
      await pumpTab(tester, GroupTab(controller: controller));

      expect(find.text('Maya Okonkwo'), findsOneWidget);
      expect(find.text('Packed'), findsOneWidget);
      expect(find.text('Food markets · Museums'), findsOneWidget);
      expect(find.text('Vegetarian'), findsOneWidget);
      // Someone with no needs says so rather than leaving a gap.
      expect(find.text('No dietary or access needs'), findsOneWidget);
      expect(find.text('Limited stairs'), findsNothing);
      expect(find.text('Gluten-free · Limited stairs'), findsOneWidget);
      expect(find.text('Generate itinerary'), findsOneWidget);
    });

    testWidgets('conflicts render with tag, resolution and both actions',
        (tester) async {
      final controller = buildController(
        members: const [_maya, _diego, _ruth],
        plan: samplePlan(),
      );
      await pumpTab(tester, GroupTab(controller: controller));

      expect(find.text('WHERE YOU DIFFER'), findsOneWidget);
      expect(find.text('PACE'), findsOneWidget);
      expect(find.text("HOW IT'S HANDLED"), findsOneWidget);
      expect(find.text('Nothing starts before 10:00.'), findsOneWidget);
      expect(find.text('Looks good'), findsOneWidget);
      expect(find.text('Discuss'), findsOneWidget);
      // A plan exists, so the CTA offers a regenerate.
      expect(find.text('Regenerate itinerary'), findsOneWidget);
    });

    testWidgets('accepted conflict flips the button label', (tester) async {
      final controller = buildController(
        members: const [_maya, _ruth],
        plan: samplePlan(),
      );
      controller.acceptedConflicts = {'Pace'};
      await pumpTab(tester, GroupTab(controller: controller));

      expect(find.text('✓ Accepted'), findsOneWidget);
      expect(find.text('Looks good'), findsNothing);
    });
  });

  group('Refine tab', () {
    testWidgets('renders both bubble roles', (tester) async {
      final controller = buildController(
        members: const [_maya, _ruth],
        messages: const [
          ChatMessage(role: 'bot', text: 'I built this around slow mornings.'),
          ChatMessage(role: 'user', text: 'Make day 3 more relaxed'),
        ],
      );
      await pumpTab(tester, RefineTab(controller: controller));

      expect(find.text('I built this around slow mornings.'), findsOneWidget);
      expect(find.text('Make day 3 more relaxed'), findsOneWidget);
    });

    testWidgets('thinking indicator appears only while a turn is in flight',
        (tester) async {
      final controller = buildController(members: const [_maya, _ruth]);
      await pumpTab(tester, RefineTab(controller: controller));
      expect(find.byType(WayfarePulsingDots), findsNothing);

      controller.thinking = true;
      await pumpTab(tester, RefineTab(controller: controller));
      expect(find.byType(WayfarePulsingDots), findsOneWidget);

      // The dots animate on a repeating controller, so settle would never
      // finish — pump a fixed frame instead.
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Platform dress', () {
    testWidgets('radii differ between iOS and Android', (tester) async {
      late WayfareTheme captured;
      for (final platform in WayfarePlatform.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: WayfareTheme(
              platform: platform,
              child: Builder(
                builder: (context) {
                  captured = WayfareTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        if (platform == WayfarePlatform.ios) {
          expect(captured.radius, 14);
          expect(captured.pillRadius, 14);
          expect(captured.sheetRadius, 20);
          expect(captured.sendButtonColor, WayfareColors.ink);
        } else {
          expect(captured.radius, 16);
          expect(captured.pillRadius, 999);
          expect(captured.sheetRadius, 28);
          expect(captured.sendButtonColor, WayfareColors.accent);
        }
      }
    });
  });
}
