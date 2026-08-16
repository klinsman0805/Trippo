import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/plan.dart';
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
  await tester.pumpWidget(
    MaterialApp(
      home: WayfareTheme(
        platform: platform,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
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

      expect(find.text('19:00'), findsOneWidget);
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
