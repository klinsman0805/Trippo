import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/models/plan.dart';
import 'package:trippo/models/trip.dart';

void main() {
  group('Plan parsing', () {
    test('parses a plan and resolves member names for split blocks', () {
      final plan = Plan.fromJson({
        'conversational_summary': 'Here is your plan.',
        'status': 'complete',
        'missing_info': <String>[],
        'trip': {
          'title': 'Lisbon',
          'destinations': ['Lisbon, Portugal'],
          'start_date': null,
          'end_date': null,
          'duration_days': 5,
          'currency': 'USD',
          'total_budget': 3000,
          'budget_breakdown': {
            'lodging': {'planned': 900, 'estimated': 954},
            'transport': {'planned': 600, 'estimated': 630},
            'food': {'planned': 750, 'estimated': 705},
            'activities': {'planned': 500, 'estimated': 560},
            'buffer': {'planned': 250, 'estimated': 250},
          },
          'estimated_total_cost': 2850,
          'over_budget': false,
          'assumptions': ['Mid-range lodging assumed'],
        },
        'members': [
          {
            'id': 'ana',
            'name': 'Ana',
            'interests': ['food'],
            'pace': 'moderate',
            'dietary_restrictions': <String>[],
            'accessibility_needs': <String>[],
            'deal_breakers': <String>[],
          },
          {
            'id': 'marcus',
            'name': 'Marcus',
            'interests': ['nightlife'],
            'pace': 'packed',
            'dietary_restrictions': <String>[],
            'accessibility_needs': <String>[],
            'deal_breakers': <String>[],
          },
        ],
        'conflicts': [
          {
            'tag': 'Pace',
            'description': 'Marcus wants packed, Ana wants moderate',
            'members_involved': ['marcus', 'ana'],
            'resolution': 'Evenings optional',
          },
        ],
        'itinerary': [
          {
            'day': 1,
            'date': null,
            'location': 'Lisbon',
            'lodging_area_suggestion': 'Baixa/Chiado',
            'blocks': [
              {
                'time_of_day': 'evening',
                'activity': 'Fado show',
                'description': 'Traditional music',
                'location': 'Alfama',
                'estimated_duration_minutes': 150,
                'estimated_cost_per_person': 55,
                'suited_for_members': ['marcus'],
                'optional': true,
                'weather_backup': null,
              },
            ],
            'notes': 'Light first day',
          },
        ],
        'packing_and_prep_notes': ['Flat shoes'],
        'verify_before_booking': ['Opening hours'],
        'clarifying_questions': <String>[],
      });

      expect(plan.status, PlanStatus.complete);
      expect(plan.shouldRenderItinerary, isTrue);
      expect(plan.conflicts, hasLength(1));
      expect(plan.trip.overBudget, isFalse);

      final block = plan.itinerary.single.blocks.single;
      expect(block.optional, isTrue);
      expect(block.timeOfDay, TimeOfDay.evening);
      // A block for fewer than all members is a split-group activity.
      expect(block.suitedForMembers.length, lessThan(plan.members.length));
      expect(plan.nameForMember('marcus'), 'Marcus');
      // Unknown ids fall back to the raw id rather than throwing.
      expect(plan.nameForMember('ghost'), 'ghost');

      expect(plan.conflicts.single.tag, 'Pace');
      // Day cost is the sum of its blocks, per person.
      expect(plan.itinerary.single.costPerPerson(), 55);
      expect(plan.itinerary.single.costPerPerson(includeOptional: false), 0);
    });

    test('budget categories keep planned and estimated apart', () {
      final breakdown = BudgetBreakdown.fromJson({
        'lodging': {'planned': 900, 'estimated': 954},
        'transport': {'planned': 600, 'estimated': 630},
        'food': {'planned': 750, 'estimated': 705},
        'activities': {'planned': 500, 'estimated': 560},
        'buffer': {'planned': 250, 'estimated': 250},
      });

      // Order is fixed so the bars don't reshuffle between revisions.
      expect(
        breakdown.categories.map((c) => c.name),
        ['lodging', 'transport', 'food', 'activities', 'buffer'],
      );
      // Every bar is drawn against the largest figure across all categories.
      expect(breakdown.peak, 954);

      final lodging = breakdown.categories.first;
      expect(lodging.isOver, isTrue);
      expect(lodging.delta, 54);

      final food = breakdown.categories[2];
      expect(food.isOver, isFalse);
      expect(food.delta, -45);

      // Buffer untouched reads as "on plan", not as a zero-width bar.
      expect(breakdown.categories.last.isOnPlan, isTrue);
    });

    test('needs_info suppresses itinerary rendering', () {
      final plan = Plan.fromJson({
        'conversational_summary': 'I need a few details first.',
        'status': 'needs_info',
        'missing_info': ['total budget', 'travel dates'],
        'trip': <String, dynamic>{},
        'members': <dynamic>[],
        'conflicts': <dynamic>[],
        'itinerary': <dynamic>[],
        'packing_and_prep_notes': <String>[],
        'verify_before_booking': <String>[],
        'clarifying_questions': [
          {
            'id': 'travel_dates',
            'question': 'When are you travelling?',
            'why': 'Fixes the day count and the season.',
            'answer_type': 'text',
            'options': <String>[],
            'placeholder': 'e.g. 7 days in late October',
          },
        ],
      });

      expect(plan.status, PlanStatus.needsInfo);
      expect(plan.shouldRenderItinerary, isFalse);
      expect(plan.missingInfo, contains('total budget'));

      // Questions carry the decision they unblock and how to answer them.
      final q = plan.clarifyingQuestions.single;
      expect(q.question, 'When are you travelling?');
      expect(q.why, isNotEmpty);
      expect(q.isChoice, isFalse);
      expect(q.placeholder, isNotNull);
    });
  });

  group('Source parsing', () {
    test('flags a blocked source as needing manual input', () {
      final source = TripSource.fromJson({
        'id': 'src_1',
        'kind': 'xiaohongshu',
        'status': 'needs_manual',
        'url': 'http://xhslink.com/a/abc',
        'error': 'login wall',
      });

      expect(source.needsManualInput, isTrue);
      expect(source.status, SourceStatus.needsManual);
    });

    test('an extracted source does not ask for manual input', () {
      final source = TripSource.fromJson({
        'id': 'src_2',
        'kind': 'web',
        'status': 'extracted',
      });

      expect(source.needsManualInput, isFalse);
    });
  });
}
