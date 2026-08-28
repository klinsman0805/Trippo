import 'dart:convert';

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/design/widgets.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/state/wayfare_controller.dart';
import 'package:trippo/screens/wayfare/itinerary/activity_sheet.dart';
import 'package:trippo/screens/wayfare/formatting.dart';
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

/// The Trip tab for one day. Grips and reorderable lists are always live —
/// there is no mode to enter.
Widget dayFor(WayfareController controller) => TripTab(
      controller: controller,
      onAddActivity: (_) {},
      onEditActivity: (_) {},
      onRemoveActivity: (_) {},
    );

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

  group('Slot and start time', () {
    test('a stated time decides the part of the day', () {
      // 9:00 AM filed under Afternoon is not a preference — it is two answers
      // to the same question, which the sheet used to allow.
      expect(slotForTime('09:00'), TimeOfDay.morning);
      expect(slotForTime('11:59'), TimeOfDay.morning);
      expect(slotForTime('12:00'), TimeOfDay.afternoon);
      expect(slotForTime('16:59'), TimeOfDay.afternoon);
      expect(slotForTime('17:00'), TimeOfDay.evening);
      expect(slotForTime('23:30'), TimeOfDay.evening);
      // Midnight belongs to the morning it starts, not the evening before.
      expect(slotForTime('00:15'), TimeOfDay.morning);
    });

    testWidgets('an activity with a time shows the slot as decided for it',
        (tester) async {
      await pump(
        tester,
        ActivitySheet(
          day: 1,
          // Stored as afternoon but timed at 9 AM — an older activity allowed
          // to disagree with itself. Opening it corrects the slot.
          existing: block(
            source: 'user',
            slot: TimeOfDay.afternoon,
            startTime: '09:00',
          ),
          onSave: (_) {},
          onCancel: () {},
        ),
      );

      expect(
        find.textContaining('Set by the start time'),
        findsOneWidget,
      );
      expect(find.text('9:00 AM'), findsOneWidget);
      // Morning is the one now selected, and every button is frozen: the
      // stated time already answered this.
      final morning = tester.semantics.find(find.text('Morning'));
      expect(morning.flagsCollection.isSelected, Tristate.isTrue);
      expect(morning.flagsCollection.isEnabled, Tristate.isFalse);
      expect(
        tester.semantics
            .find(find.text('Afternoon'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
    });

    testWidgets('without a time, the part of the day is yours to pick',
        (tester) async {
      Map<String, dynamic>? saved;
      await pump(
        tester,
        ActivitySheet(day: 1, onSave: (a) => saved = a, onCancel: () {}),
      );

      expect(find.textContaining('Set by the start time'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Wander');
      await tapDown(tester, find.text('Evening'));
      await tapDown(tester, find.text('Add to day 1'));

      expect(saved!['time_of_day'], 'evening');
      expect(saved!['start_time'], isNull);
    });
  });

  group('Closing a sheet by dragging it down', () {
    /// Opens the sheet the way the app does — as a real modal route, so that
    /// dismissing it is the route popping rather than a callback firing.
    Future<void> openSheet(WidgetTester tester, {PlanBlock? existing}) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, inner) => WayfareTheme(
            platform: WayfarePlatform.ios,
            child: inner ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ActivitySheet(
                      day: 1,
                      existing: existing,
                      onSave: (_) {},
                      onCancel: () {},
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivitySheet), findsOneWidget);
    }

    testWidgets('a pull on the grabber closes it', (tester) async {
      await openSheet(tester);

      await tester.drag(find.byType(WayfareSheetGrabber), const Offset(0, 220));
      await tester.pumpAndSettle();

      expect(find.byType(ActivitySheet), findsNothing);
    });

    testWidgets('a pull from the body closes it when already at the top',
        (tester) async {
      await openSheet(tester);

      await tester.drag(find.text('Part of the day'), const Offset(0, 220));
      await tester.pumpAndSettle();

      expect(find.byType(ActivitySheet), findsNothing);
    });

    testWidgets('a short pull springs back instead', (tester) async {
      await openSheet(tester);

      await tester.drag(find.byType(WayfareSheetGrabber), const Offset(0, 30));
      await tester.pumpAndSettle();

      expect(find.byType(ActivitySheet), findsOneWidget);
      // And back where it started, not left hanging 30px down.
      expect(
        tester.widget<Transform>(
          find
              .descendant(
                of: find.byType(WayfareDismissibleSheet),
                matching: find.byType(Transform),
              )
              .first,
        ).transform.getTranslation().y,
        0,
      );
    });

    testWidgets('a pull mid-list scrolls the body and leaves the sheet open',
        (tester) async {
      await openSheet(tester);

      // Scroll down so there is content above, then pull down: that is the
      // list's gesture, not the sheet's.
      await tester.drag(find.text('Venue'), const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Venue'), const Offset(0, 60));
      await tester.pumpAndSettle();

      expect(find.byType(ActivitySheet), findsOneWidget);
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

  group('Order within a slot', () {
    testWidgets('is the start time\'s to decide, not the finger\'s',
        (tester) async {
      final controller = editableController();
      await pump(tester, dayFor(controller));

      // Hand-dragging is out: the grip lost its gesture to the page's own
      // scroll often enough that it read as broken, and an order the times
      // contradict is worse than no order at all. A card moves by being
      // given a time.
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
    });

    testWidgets('every card can still be swiped to edit or delete',
        (tester) async {
      final controller = editableController();
      await pump(tester, dayFor(controller));

      expect(find.byType(SwipeableActivity), findsNWidgets(3));
    });
  });

  group('Adding and removing days', () {
    /// A trip is a contiguous range of dates, so removing a middle day does
    /// not leave a gap — it shifts every later day onto a different date.
    test('only the ends can be removed, and each moves its own end', () {
      final controller = editableController();
      controller.plan = Plan(
        conversationalSummary: '',
        status: PlanStatus.complete,
        trip: TripSummary.fromJson(const {'currency': 'MYR'}),
        itinerary: [
          for (var day = 1; day <= 4; day++)
            PlanDay(day: day, location: 'Bangkok', blocks: const []),
        ],
      );

      expect(controller.canDeleteDay(1), isTrue);
      expect(controller.canDeleteDay(4), isTrue);
      expect(controller.canDeleteDay(2), isFalse);
      expect(controller.canDeleteDay(3), isFalse);

      // Dropping the first day starts the trip later; the last, ends it sooner.
      expect(controller.deletingMovesStart(1), isTrue);
      expect(controller.deletingMovesStart(4), isFalse);
    });

    test('a one-day trip cannot lose its only day', () {
      final controller = editableController();
      controller.plan = Plan(
        conversationalSummary: '',
        status: PlanStatus.complete,
        trip: TripSummary.fromJson(const {'currency': 'MYR'}),
        itinerary: [PlanDay(day: 1, location: 'Bangkok', blocks: const [])],
      );

      expect(controller.canDeleteDay(1), isFalse);
    });


    testWidgets('the day buttons are gone from the day itself', (tester) async {
      final controller = editableController();
      await pump(tester, dayFor(controller));

      // Both moved to the header. At the end of a full day they sat further
      // from the thumb the more there was on it.
      expect(find.text('Add an activity'), findsNothing);
      expect(find.text('Add or remove a day'), findsNothing);
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

}
