import 'dart:convert';

import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/state/wayfare_controller.dart';
import 'package:trippo/screens/wayfare/itinerary/activity_sheet.dart';
import 'package:trippo/screens/wayfare/itinerary/activity_sheets.dart';
import 'package:trippo/screens/wayfare/itinerary/day_editing.dart';
import 'package:trippo/screens/wayfare/itinerary/regenerate_sheet.dart';
import 'package:trippo/screens/wayfare/trip_tab.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  WayfarePlatform platform = WayfarePlatform.ios,
}) async {
  // The theme goes at MaterialApp.builder, exactly as the real app does.
  // A drag lifts the card into the app's Overlay, which sits *above* the
  // route — a theme provided inside `home` would be invisible to it, and the
  // card would assert mid-drag.
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, inner) => WayfareTheme(
        platform: platform,
        child: inner ?? const SizedBox.shrink(),
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Future<void> tapDown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

PlanBlock block({
  String id = 'blk_1',
  String activity = 'Hawker dinner at New Lane',
  TimeOfDay slot = TimeOfDay.evening,
  String source = 'planner',
  String? startTime,
  num? duration,
  String location = '',
  num? cost,
}) =>
    PlanBlock(
      id: id,
      timeOfDay: slot,
      activity: activity,
      description: '',
      location: location,
      estimatedDurationMinutes: duration,
      suitedForMembers: const [],
      optional: false,
      startTime: startTime,
      source: source,
      pinned: source == 'user',
      estimatedCostPerPerson: cost,
    );

/// A controller holding one day: [morningCount] morning activities plus one
/// in the afternoon, so slot grouping is observable.
WayfareController editableController({
  int morningCount = 2,
  List<Map<String, dynamic>>? recorder,
}) {
  final client = recorder == null
      ? ApiClient(baseUrl: 'http://localhost:0')
      : ApiClient(
          baseUrl: 'http://stub',
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            recorder.add({'path': request.url.path, ...body});
            // The plan the server would return is irrelevant here; the test is
            // about what the drag asks for.
            return http.Response(
              jsonEncode({
                'plan': {
                  'status': 'complete',
                  'trip': {'currency': 'MYR'},
                  'itinerary': <dynamic>[],
                },
              }),
              200,
            );
          }),
        );

  final controller = WayfareController(TrippoApi(client), 'trip_test');
  controller.trip = Trip(
    id: 'trip_test',
    title: 'Ipoh',
    destinations: const ['Ipoh'],
    currency: 'MYR',
    updatedAt: DateTime(2026, 11, 1),
  );
  controller.plan = Plan(
    conversationalSummary: '',
    status: PlanStatus.complete,
    trip: TripSummary.fromJson(const {'currency': 'MYR'}),
    itinerary: [
      PlanDay(
        day: 1,
        location: 'Ipoh',
        blocks: [
          for (var i = 0; i < morningCount; i++)
            block(
              id: 'm$i',
              activity: 'Morning thing $i',
              slot: TimeOfDay.morning,
            ),
          block(id: 'a1', activity: 'Cave temple', slot: TimeOfDay.afternoon),
        ],
      ),
    ],
  );
  controller.loading = false;
  return controller;
}

void main() {
  group('The activity card', () {
    testWidgets('a hand-written one is marked, a planned one is not',
        (tester) async {
      await pump(
        tester,
        Column(
          children: [
            ActivityCard(
              block: block(source: 'user'),
              members: const [],
              currency: 'MYR',
            ),
            ActivityCard(
              block: block(id: 'blk_2', activity: 'Penang Hill'),
              members: const [],
              currency: 'MYR',
            ),
          ],
        ),
      );

      // Exactly one Yours pill — the mark is the only difference between a
      // hand-written activity and a generated one.
      expect(find.text('YOURS'), findsOneWidget);
    });

    testWidgets('a stated time prints, a missing one leaves no gap',
        (tester) async {
      await pump(
        tester,
        ActivityCard(
          block: block(startTime: '19:00'),
          members: const [],
          currency: 'MYR',
        ),
      );

      expect(find.text('7:00 PM'), findsOneWidget);
      expect(find.text('EVENING'), findsOneWidget);
    });

    testWidgets('a title-only activity is a complete card, not a stub',
        (tester) async {
      await pump(
        tester,
        ActivityCard(
          block: block(activity: 'Find a barber', source: 'user'),
          members: const [],
          currency: 'MYR',
        ),
      );

      expect(find.text('Find a barber'), findsOneWidget);
      // No duration, no venue, so the footer row is absent rather than empty.
      expect(find.textContaining(' · '), findsNothing);
    });

    testWidgets('duration and venue take the footer when there is no group',
        (tester) async {
      await pump(
        tester,
        ActivityCard(
          block: block(duration: 90, location: 'Singapore Botanic Gardens'),
          members: const [],
          currency: 'MYR',
        ),
      );

      expect(find.text('1h 30m · Singapore Botanic Gardens'), findsOneWidget);
    });
  });

  group('Adding an activity', () {
    testWidgets('opens collapsed, and a title alone is enough', (tester) async {
      Map<String, dynamic>? saved;
      await pump(
        tester,
        ActivitySheet(
          day: 3,
          onSave: (a) => saved = a,
          onCancel: () {},
        ),
      );

      // The fast path is what is visible; everything else is one tap away.
      expect(find.text('Part of the day'), findsOneWidget);
      expect(find.text('Anytime'), findsOneWidget);
      expect(find.text('Add description, duration, cost'), findsOneWidget);
      expect(find.text('Cost per person'), findsNothing);
      expect(find.textContaining('A title is enough'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Find a barber');
      await tester.pumpAndSettle();
      await tapDown(tester, find.text('Add to day 3'));

      expect(saved!['activity'], 'Find a barber');
      expect(saved!['start_time'], isNull);
      expect(saved!['estimated_duration_minutes'], isNull);
      expect(
        saved!['estimated_cost_per_person'],
        isNull,
        reason: 'a blank cost must stay blank, not become zero',
      );
    });

    testWidgets('the CTA names the day, and is dead without a title',
        (tester) async {
      var saves = 0;
      await pump(
        tester,
        ActivitySheet(day: 2, onSave: (_) => saves++, onCancel: () {}),
      );

      expect(find.text('Add to day 2'), findsOneWidget);
      await tapDown(tester, find.text('Add to day 2'));
      expect(saves, 0);
    });

    testWidgets('the disclosure reveals the rest', (tester) async {
      await pump(
        tester,
        ActivitySheet(day: 1, onSave: (_) {}, onCancel: () {}),
      );

      await tapDown(tester, find.text('Add description, duration, cost'));

      expect(find.text('How long'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.textContaining('the card reads free'), findsOneWidget);
      expect(find.text('Optional activity'), findsOneWidget);
    });
  });

  group('Editing an activity', () {
    testWidgets('prefills, opens expanded, and explains the pin',
        (tester) async {
      await pump(
        tester,
        ActivitySheet(
          day: 3,
          existing: block(source: 'user', startTime: '19:00', duration: 120),
          onSave: (_) {},
          onCancel: () {},
          onRemove: () {},
        ),
      );

      expect(find.text('Hawker dinner at New Lane'), findsWidgets);
      expect(find.text('You added this · evening, day 3'), findsOneWidget);
      expect(find.textContaining('the planner leaves it alone'), findsOneWidget);
      // Expanded, because by now you know what you came for.
      expect(find.text('How long'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Remove this activity from day 3'), findsOneWidget);
    });

    testWidgets('editing a planned activity warns it becomes yours',
        (tester) async {
      await pump(
        tester,
        ActivitySheet(
          day: 3,
          existing: block(source: 'planner'),
          onSave: (_) {},
          onCancel: () {},
        ),
      );

      expect(find.text('Planned · evening, day 3'), findsOneWidget);
      expect(find.textContaining('it becomes yours'), findsOneWidget);
    });
  });

  group('Removing an activity', () {
    testWidgets('names what the day loses and what it then costs',
        (tester) async {
      await pump(
        tester,
        RemoveActivitySheet(
          block: block(cost: 40),
          day: 3,
          slotBecomesEmpty: true,
          dayCostBefore: 58,
          currency: 'MYR',
          onRemove: () {},
          onKeep: () {},
        ),
      );

      expect(find.text('Becomes empty'), findsOneWidget);
      expect(find.text('RM 58 → RM 18 pp'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
      // The button names the thing rather than saying a bare "Remove".
      expect(
        find.textContaining('Remove hawker dinner at'),
        findsOneWidget,
      );
    });

    testWidgets('a slot with others left does not claim to empty',
        (tester) async {
      await pump(
        tester,
        RemoveActivitySheet(
          block: block(cost: 40),
          day: 3,
          slotBecomesEmpty: false,
          dayCostBefore: 58,
          currency: 'MYR',
          onRemove: () {},
          onKeep: () {},
        ),
      );

      expect(find.text('Becomes empty'), findsNothing);
      expect(find.text('Still has others'), findsOneWidget);
    });
  });

  group('Empty and open days', () {
    testWidgets('an empty day invites rather than explains', (tester) async {
      await pump(
        tester,
        EmptyDayCard(
          day: 2,
          otherPlannedDays: 3,
          onAddFirst: () {},
          onAskPlanner: () {},
        ),
      );

      expect(find.text('Day 2 is empty'), findsOneWidget);
      expect(find.textContaining('not filled this one in yet'), findsOneWidget);
      expect(find.text('Add the first activity'), findsOneWidget);
      expect(find.text('Ask the planner to fill day 2'), findsOneWidget);

      // It must never borrow the short-day voice, which explains a constraint.
      expect(find.textContaining('flight'), findsNothing);
      expect(find.textContaining('lands too late'), findsNothing);
    });

    testWidgets('an open slot is one quiet line, not three empty boxes',
        (tester) async {
      await pump(
        tester,
        OpenSlotLine(slots: const [TimeOfDay.afternoon], onTap: () {}),
      );

      expect(find.text('The afternoon is open — add something'), findsOneWidget);
    });

    testWidgets('two open slots read as one sentence', (tester) async {
      await pump(
        tester,
        OpenSlotLine(
          slots: const [TimeOfDay.morning, TimeOfDay.evening],
          onTap: () {},
        ),
      );

      expect(
        find.text('The morning and the evening are open — add something'),
        findsOneWidget,
      );
    });
  });

  group('Moving an activity', () {
    testWidgets('lists other days, marks empty ones, restates the destination',
        (tester) async {
      int? movedDay;
      TimeOfDay? movedSlot;

      await pump(
        tester,
        MoveActivitySheet(
          block: block(),
          fromDay: 3,
          days: const [
            (day: 1, date: '2026-09-12', blockCount: 3),
            (day: 2, date: '2026-09-13', blockCount: 0),
            (day: 3, date: '2026-09-14', blockCount: 2),
          ],
          onMove: (d, s) {
            movedDay = d;
            movedSlot = s;
          },
          onCancel: () {},
        ),
      );

      // The day you are on is not a destination.
      expect(find.text('Day 3'), findsNothing);
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('3 activities'), findsOneWidget);

      // Cancel says what staying means.
      expect(find.text('Leave it on day 3'), findsOneWidget);
      expect(find.text('Pick a day'), findsOneWidget);

      await tapDown(tester, find.text('Day 2'));
      await tapDown(tester, find.text('Morning'));
      expect(find.text('Move to day 2, morning'), findsOneWidget);

      await tapDown(tester, find.text('Move to day 2, morning'));
      expect(movedDay, 2);
      expect(movedSlot, TimeOfDay.morning);
    });
  });

  group('Regenerating', () {
    PinnedSummary summary({int count = 2, bool honours = true}) =>
        PinnedSummary.fromJson({
          'pinned': [
            for (var i = 0; i < count; i++)
              {
                'id': 'blk_$i',
                'day': 3,
                'activity': 'Dinner with Wei',
                'time_of_day': 'evening',
                'estimated_cost_per_person': 45,
              },
          ],
          'replan_days': [1, 2, 4],
          'committed_cost': 45 * count,
          'honours_pinned': honours,
        });

    testWidgets('states what is kept, replanned and already committed',
        (tester) async {
      await pump(
        tester,
        RegenerateSheet(
          summary: summary(),
          currency: 'MYR',
          onKeepMine: () {},
          onReplaceEverything: () {},
          onUnpin: (_) {},
          onCancel: () {},
        ),
      );

      expect(find.text('2 activities on day 3'), findsOneWidget);
      expect(find.text('days 1, 2 and 4'), findsOneWidget);
      expect(find.text('RM 90 pp'), findsOneWidget);
      expect(find.text('Replan around what I wrote'), findsOneWidget);

      // The cost of the one-way path is in its label, not behind it.
      expect(
        find.text('Replan everything — replaces your two activities'),
        findsOneWidget,
      );
      expect(find.text('Unpin'), findsNWidgets(2));
    });

    testWidgets('without a backend that honours pins, there is no keep option',
        (tester) async {
      await pump(
        tester,
        RegenerateSheet(
          summary: summary(honours: false),
          currency: 'MYR',
          onKeepMine: () {},
          onReplaceEverything: () {},
          onUnpin: (_) {},
          onCancel: () {},
        ),
      );

      // The design is explicit: a promise the planner cannot keep must not be
      // offered at all.
      expect(find.text('Replan around what I wrote'), findsNothing);
      expect(
        find.text('Replan everything — replaces your two activities'),
        findsOneWidget,
      );
    });
  });

  group('Reordering within a slot', () {
    /// A day in edit mode, so the grips and reorderable lists are live.
    Widget dayInEditMode(WayfareController controller) => TripTab(
          controller: controller,
          onAddActivity: (_) {},
          onEditActivity: (_) {},
          onRemoveActivity: (_) {},
          onMoveActivity: (_) {},
          onChangeDayCount: () {},
        );

    testWidgets('the grip offers an explicit menu, not only a drag',
        (tester) async {
      final controller = editableController();
      controller.startEditingDay(1);

      await pump(tester, dayInEditMode(controller));

      // Drag is unreachable by keyboard and awkward with a screen reader, so
      // the same grip has to work by tapping.
      expect(find.byType(ReorderGrip), findsNWidgets(3));
      await tapDown(tester, find.byType(ReorderGrip).first);

      expect(find.text('Move down'), findsOneWidget);
      expect(find.text('Move up'), findsOneWidget);
    });

    testWidgets('the first item cannot move up, the last cannot move down',
        (tester) async {
      final controller = editableController();
      controller.startEditingDay(1);
      await pump(tester, dayInEditMode(controller));

      await tapDown(tester, find.byType(ReorderGrip).first);
      final up = tester.widget<PopupMenuItem<int>>(
        find.widgetWithText(PopupMenuItem<int>, 'Move up'),
      );
      expect(up.enabled, isFalse);
      final down = tester.widget<PopupMenuItem<int>>(
        find.widgetWithText(PopupMenuItem<int>, 'Move down'),
      );
      expect(down.enabled, isTrue);
    });

    testWidgets('each slot reorders separately, so a drag cannot cross slots',
        (tester) async {
      final controller = editableController();
      controller.startEditingDay(1);
      await pump(tester, dayInEditMode(controller));

      // Two morning activities and one afternoon → two independent lists.
      expect(find.byType(ReorderableListView), findsNWidgets(2));
    });

    testWidgets('a lone activity in a slot has nothing to reorder against',
        (tester) async {
      final controller = editableController(morningCount: 1);
      controller.startEditingDay(1);
      await pump(tester, dayInEditMode(controller));

      // Both slots hold one thing, so every grip is inert rather than
      // offering an action that would do nothing.
      final grips = tester.widgetList<ReorderGrip>(find.byType(ReorderGrip));
      expect(grips.every((g) => !g.canMoveUp && !g.canMoveDown), isTrue);
    });

    testWidgets('dragging a card down reorders it within its slot',
        (tester) async {
      final requests = <Map<String, dynamic>>[];
      final controller = editableController(
        recorder: requests,
        morningCount: 3,
      );
      controller.startEditingDay(1);
      await pump(tester, dayInEditMode(controller));

      // Drag the first morning card past the second. The gesture itself is
      // what is under test here — the menu path is covered above, and this is
      // the half no amount of callback wiring can stand in for.
      final handle = find.byType(ReorderableDragStartListener).first;
      final start = tester.getCenter(handle);
      final gesture = await tester.startGesture(start, pointer: 7);
      await tester.pump(const Duration(milliseconds: 100));
      for (final dy in const [30.0, 140.0, 260.0]) {
        await gesture.moveTo(start + Offset(0, dy));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        requests,
        isNotEmpty,
        reason: 'the drag must actually reach the server',
      );
      expect(requests.last['path'], contains('/blocks/m0/reorder'));
      expect(
        requests.last['to_index'],
        greaterThan(0),
        reason: 'dragging down must not land back where it started',
      );
    });

    testWidgets('reading mode has no grips at all', (tester) async {
      final controller = editableController();
      await pump(tester, dayInEditMode(controller));

      expect(find.byType(ReorderGrip), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
    });
  });

  group('Swipe actions', () {
    testWidgets('a swipe reveals edit and delete, and neither fires on a tap',
        (tester) async {
      var edits = 0;
      var deletes = 0;

      await pump(
        tester,
        SwipeableActivity(
          onEdit: () => edits++,
          onDelete: () => deletes++,
          child: ActivityCard(
            block: block(),
            members: const [],
            currency: 'MYR',
          ),
        ),
      );

      // Reading stays risk-free: the actions sit behind the card, so nothing
      // is reachable until the card is deliberately moved off them.
      await tester.tap(find.text('Delete'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(edits, 0);
      expect(deletes, 0);

      await tester.drag(
        find.byType(ActivityCard),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        deletes,
        1,
        reason: 'delete opens the confirmation; it does not remove anything',
      );

      await tester.drag(find.byType(ActivityCard), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(edits, 1);
    });
  });

  group('Day edit mode', () {
    testWidgets('announces itself and offers a way out', (tester) async {
      var done = false;
      await pump(tester, DayEditingBar(day: 3, onDone: () => done = true));

      expect(
        find.text('Editing day 3 — tap an activity to change it'),
        findsOneWidget,
      );
      await tapDown(tester, find.text('Done'));
      expect(done, isTrue);
    });

    testWidgets('the quick composer says where things land', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        QuickAddComposer(
          controller: controller,
          slot: TimeOfDay.afternoon,
          value: '',
          onChanged: (_) {},
          onSubmit: () {},
          onOpenFullSheet: () {},
        ),
      );

      expect(find.text('Type an activity…'), findsOneWidget);
      expect(
        find.textContaining('Lands in the afternoon you are looking at'),
        findsOneWidget,
      );
      expect(find.text('Add with time, venue and cost'), findsOneWidget);
    });
  });
}
