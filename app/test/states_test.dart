import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/needs_info.dart';
import 'package:trippo/screens/wayfare/plan_failed.dart';
import 'package:trippo/screens/wayfare/traveller_sheet.dart';

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

/// These screens are taller than the test viewport, so anything below the fold
/// has to be scrolled to before it can be tapped.
Future<void> tapDown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

PlanFailure failure({
  int? revision,
  int? days,
  String reason = 'Timed out at 4m 00s',
}) =>
    PlanFailure.fromJson({
      'reason_code': 'upstream_error',
      'reason': reason,
      'elapsed_ms': 240000,
      'at': DateTime(2026, 8, 4, 14, 32).toIso8601String(),
      'last_good_revision': revision,
      'last_good_days': days,
    });

ClarifyingQuestion question({
  required String id,
  required String text,
  String type = 'text',
  List<String> options = const [],
}) =>
    ClarifyingQuestion.fromJson({
      'id': id,
      'question': text,
      'why': 'It changes which day the airport transfer lands on.',
      'answer_type': type,
      'options': options,
      'placeholder': 'e.g. 14:30',
    });

void main() {
  group('Planner failure', () {
    testWidgets('with a surviving revision, says what is still there',
        (tester) async {
      await pump(
        tester,
        PlanFailedView(
          failure: failure(revision: 2, days: 5),
          onRetry: () {},
          onDismiss: () {},
          onFinishByHand: () {},
        ),
      );

      expect(find.text('The planner stopped partway'), findsOneWidget);
      expect(find.text('STOPPED AT 14:32'), findsOneWidget);

      // The reassurance is the load-bearing half — say it in the body, not
      // only in a fact row.
      expect(find.textContaining('nothing replaced what you had'), findsOneWidget);
      expect(find.textContaining('nothing you entered was lost'), findsOneWidget);

      expect(find.text('Still on the trip'), findsOneWidget);
      expect(find.text('Revision 2 · 5 days'), findsOneWidget);
      expect(find.text('Timed out at 4m 00s'), findsOneWidget);
      expect(find.text('All saved'), findsOneWidget);

      // Keeping what survived is the primary action; retry is secondary.
      expect(find.text('Keep revision 2'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Change something first'), findsOneWidget);
    });

    testWidgets('with nothing planned yet, offers no hollow "keep" action',
        (tester) async {
      await pump(
        tester,
        PlanFailedView(
          failure: failure(),
          onRetry: () {},
          onDismiss: () {},
          onFinishByHand: () {},
        ),
      );

      expect(find.textContaining('Nothing was planned before it stopped'),
          findsOneWidget);
      expect(find.text('Nothing planned yet'), findsOneWidget);
      // Nothing to keep, so nothing offering to keep it.
      expect(find.textContaining('Keep revision'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('never claims days it cannot have planned', (tester) async {
      await pump(
        tester,
        PlanFailedView(
          failure: failure(revision: 2, days: 5),
          onRetry: () {},
          onDismiss: () {},
          onFinishByHand: () {},
        ),
      );

      // A run writes one whole revision or none, so partial-day copy would be
      // a promise the system cannot keep.
      expect(find.textContaining('planned days'), findsNothing);
      expect(find.textContaining('Days 1–2'), findsNothing);
      expect(find.textContaining('Carry on from day'), findsNothing);
    });

    testWidgets('the reason is whatever actually happened', (tester) async {
      await pump(
        tester,
        PlanFailedView(
          failure: failure(reason: "This project's model quota is used up for now"),
          onRetry: () {},
          onDismiss: () {},
          onFinishByHand: () {},
        ),
      );

      expect(
        find.text("This project's model quota is used up for now"),
        findsOneWidget,
      );
      expect(find.textContaining('Timed out'), findsNothing);
    });
  });

  group('Needs info', () {
    final questions = [
      question(id: 'q1', text: 'Is everyone arriving on the same flight?'),
      question(
        id: 'q2',
        text: 'Where are you staying?',
      ),
      question(
        id: 'q3',
        text: "Is Ruth's limited-stairs need firm?",
        type: 'choice',
        options: ['Firm', 'Prefer to avoid', 'Not an issue'],
      ),
    ];

    testWidgets('counts the answers live and names what each unblocks',
        (tester) async {
      await pump(
        tester,
        NeedsInfoView(
          questions: questions,
          answers: const {'q1': 'Yes, all three'},
          onAnswer: (_, _) {},
          onSend: () {},
          onSkip: () {},
        ),
      );

      expect(find.text('THREE ANSWERS NEEDED'), findsOneWidget);
      expect(find.textContaining("won't guess on these"), findsOneWidget);

      // Numbered cards, each with its consequence line.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        find.text('It changes which day the airport transfer lands on.'),
        findsNWidgets(3),
      );

      // The CTA says exactly what pressing it sends.
      expect(find.text('Send 1 of 3 answers'), findsOneWidget);
      expect(find.text('Plan without these'), findsOneWidget);
    });

    testWidgets('a choice question renders chips, a text one an input',
        (tester) async {
      await pump(
        tester,
        NeedsInfoView(
          questions: questions,
          answers: const {},
          onAnswer: (_, _) {},
          onSend: () {},
          onSkip: () {},
        ),
      );

      expect(find.text('Firm'), findsOneWidget);
      expect(find.text('Not an issue'), findsOneWidget);
      // Two text questions, so two inputs.
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('with nothing answered, Send is disabled but skipping is not',
        (tester) async {
      var sent = false;
      var skipped = false;

      await pump(
        tester,
        NeedsInfoView(
          questions: questions,
          answers: const {},
          onAnswer: (_, _) {},
          onSend: () => sent = true,
          onSkip: () => skipped = true,
        ),
      );

      expect(find.text('Send answers'), findsOneWidget);
      await tapDown(tester, find.text('Send answers'));
      expect(sent, isFalse);

      // Skipping is always available — the group is never trapped by a
      // question they cannot answer.
      await tapDown(tester, find.text('Plan without these'));
      expect(skipped, isTrue);
    });

    testWidgets('tapping the chosen chip again clears it', (tester) async {
      String? cleared;
      await pump(
        tester,
        NeedsInfoView(
          questions: questions,
          answers: const {'q3': 'Firm'},
          onAnswer: (id, answer) => cleared = '$id=$answer',
          onSend: () {},
          onSkip: () {},
        ),
      );

      await tester.tap(find.text('Firm'));
      expect(cleared, 'q3=');
    });
  });

  group('Edit traveller', () {
    final ruth = Member(
      id: 'm3',
      name: 'Ruth Adler',
      interests: const ['Architecture'],
      pace: Pace.relaxed,
      dietaryRestrictions: const ['Gluten-free'],
      accessibilityNeeds: const ['Limited stairs'],
      createdAt: DateTime(2026, 8, 4),
    );

    testWidgets('prefills every field and names the person', (tester) async {
      await pump(
        tester,
        TravellerSheet(
          existing: ruth,
          onSave: (_) {},
          onCancel: () {},
          onRemove: () {},
        ),
      );

      // Twice: the identity header naming who this is, and the prefilled
      // name field they can edit.
      expect(find.text('Ruth Adler'), findsNWidgets(2));
      expect(find.text('Added 4 August'), findsOneWidget);

      // Free-text needs come back as the comma-joined text they were typed as.
      expect(find.text('Gluten-free'), findsOneWidget);
      expect(find.text('Limited stairs'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Save traveller'), findsNothing);
    });

    testWidgets('names the concrete thing an edit puts at stake',
        (tester) async {
      await pump(
        tester,
        TravellerSheet(
          existing: ruth,
          optionalForMember: const [(day: 4, activity: 'Surf lesson')],
          onSave: (_) {},
          onCancel: () {},
          onRemove: () {},
        ),
      );

      expect(find.textContaining('re-checks the conflicts'), findsOneWidget);
      expect(
        find.textContaining(
          "Day 4's surf lesson is the only thing currently marked optional",
        ),
        findsOneWidget,
      );
    });

    testWidgets('with nothing optional, says so rather than implying stakes',
        (tester) async {
      await pump(
        tester,
        TravellerSheet(
          existing: ruth,
          onSave: (_) {},
          onCancel: () {},
          onRemove: () {},
        ),
      );

      expect(
        find.textContaining('Nothing in the plan is currently marked optional'),
        findsOneWidget,
      );
    });

    testWidgets('removal is named, unfilled, and confirmed', (tester) async {
      var removed = false;

      await pump(
        tester,
        TravellerSheet(
          existing: ruth,
          onSave: (_) {},
          onCancel: () {},
          onRemove: () => removed = true,
        ),
      );

      expect(find.text('Remove Ruth from the trip'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);

      await tapDown(tester, find.text('Remove Ruth from the trip'));

      // The tap opens a confirmation rather than removing anyone.
      expect(removed, isFalse);
      expect(find.text('Remove Ruth?'), findsOneWidget);

      await tester.tap(find.text('Keep them'));
      await tester.pumpAndSettle();
      expect(removed, isFalse);

      await tapDown(tester, find.text('Remove Ruth from the trip'));
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });

    testWidgets('an edit carries through the fields it does not show',
        (tester) async {
      final withHiddenFields = Member(
        id: 'm3',
        name: 'Ruth Adler',
        pace: Pace.relaxed,
        dealBreakers: const ['No overnight buses'],
        wants: const ['A rest day'],
        departureCity: 'Kuala Lumpur',
        createdAt: DateTime(2026, 8, 4),
      );

      Member? saved;
      await pump(
        tester,
        TravellerSheet(
          existing: withHiddenFields,
          onSave: (m) => saved = m,
          onCancel: () {},
          onRemove: () {},
        ),
      );

      await tapDown(tester, find.text('Save changes'));

      // Saving from a sheet that never showed these must not clear them.
      expect(saved!.dealBreakers, ['No overnight buses']);
      expect(saved!.wants, ['A rest day']);
      expect(saved!.departureCity, 'Kuala Lumpur');
      expect(saved!.id, 'm3');
    });

    testWidgets('adding still works from the same component', (tester) async {
      await pump(
        tester,
        TravellerSheet(onSave: (_) {}, onCancel: () {}),
      );

      expect(find.text('Add a traveller'), findsOneWidget);
      expect(find.text('Save traveller'), findsOneWidget);
      // No identity header, no removal, no knock-on panel when there is no
      // person yet to have consequences.
      expect(find.textContaining('Added '), findsNothing);
      expect(find.textContaining('Remove'), findsNothing);
      expect(find.textContaining('re-checks the conflicts'), findsNothing);
    });
  });

  group('Failure model', () {
    test('stopped-at renders as local wall-clock time', () {
      final f = PlanFailure.fromJson({
        'reason_code': 'upstream_error',
        'reason': 'Timed out at 4m 00s',
        'elapsed_ms': 240000,
        'at': DateTime(2026, 8, 4, 9, 5).toIso8601String(),
        'last_good_revision': null,
      });

      expect(f.stoppedAtLabel, '09:05');
      expect(f.hasFallback, isFalse);
    });
  });
}
