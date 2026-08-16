/**
 * Seeds the design handoff's sample trip — Portugal, Slowly.
 *
 * This exists so the UI can be exercised without an ANTHROPIC_API_KEY. The
 * itinerary text is the prototype's invented sample content, inserted directly
 * as a plan revision rather than generated. Real trips come from the planner.
 *
 *   npx tsx scripts/seed-demo.ts
 */
import { db, newId, nowIso } from '../src/db/index.js';
import { PlanSchema } from '../src/schemas/plan.js';
import { createTrip } from '../src/modules/trips/repo.js';

const trip = createTrip({
  title: 'Portugal, Slowly',
  destinations: ['Lisbon', 'Sintra', 'Porto'],
  start_date: '2026-09-12',
  end_date: '2026-09-16',
  date_flexible: false,
  currency: 'EUR',
  total_budget: 4200,
  budget_basis: 'total',
  purpose: 'A slow late-summer trip between three friends with very different paces.',
  hard_constraints: [],
  members: [
    {
      name: 'Maya Okonkwo',
      interests: ['Food markets', 'Museums', 'Live music'],
      pace: 'packed',
      dietary_restrictions: ['Vegetarian'],
      accessibility_needs: [],
      deal_breakers: [],
      wants: [],
      avoids: [],
    },
    {
      name: 'Diego Ferreira',
      interests: ['Surfing', 'Hiking', 'Wine'],
      pace: 'moderate',
      dietary_restrictions: [],
      accessibility_needs: [],
      deal_breakers: [],
      wants: [],
      avoids: [],
    },
    {
      name: 'Ruth Adler',
      interests: ['Architecture', 'Slow mornings', 'Photography'],
      pace: 'relaxed',
      dietary_restrictions: ['Gluten-free'],
      accessibility_needs: ['Limited stairs'],
      deal_breakers: [],
      wants: [],
      avoids: [],
    },
  ],
});

const [maya, diego, ruth] = trip.members.map((m) => m.id);
const everyone = [maya!, diego!, ruth!];

const plan = PlanSchema.parse({
  conversational_summary:
    "I built this around Ruth's slow mornings and Maya's packed pace — nothing starts before 10, and the optional slots are where you two split. Every shared meal is à la carte so both diets order freely. Ask me for any change.",
  status: 'complete',
  missing_info: [],
  trip: {
    title: 'Portugal, Slowly',
    destinations: ['Lisbon', 'Sintra', 'Porto'],
    start_date: '2026-09-12',
    end_date: '2026-09-16',
    duration_days: 5,
    currency: 'EUR',
    total_budget: 4200,
    budget_breakdown: {
      lodging: { planned: 1740, estimated: 1844 },
      transport: { planned: 610, estimated: 641 },
      food: { planned: 890, estimated: 837 },
      activities: { planned: 540, estimated: 605 },
      buffer: { planned: 420, estimated: 420 },
    },
    estimated_total_cost: 4347,
    over_budget: true,
    assumptions: [
      'Mid-range lodging in central, level-access neighbourhoods',
      'Lisbon–Porto by train rather than a domestic flight',
    ],
  },
  members: [
    {
      id: maya,
      name: 'Maya Okonkwo',
      interests: ['Food markets', 'Museums', 'Live music'],
      pace: 'packed',
      dietary_restrictions: ['Vegetarian'],
      accessibility_needs: [],
      deal_breakers: [],
    },
    {
      id: diego,
      name: 'Diego Ferreira',
      interests: ['Surfing', 'Hiking', 'Wine'],
      pace: 'moderate',
      dietary_restrictions: [],
      accessibility_needs: [],
      deal_breakers: [],
    },
    {
      id: ruth,
      name: 'Ruth Adler',
      interests: ['Architecture', 'Slow mornings', 'Photography'],
      pace: 'relaxed',
      dietary_restrictions: ['Gluten-free'],
      accessibility_needs: ['Limited stairs'],
      deal_breakers: [],
    },
  ],
  conflicts: [
    {
      tag: 'Pace',
      description: 'Maya wants every day full; Ruth needs slow mornings.',
      members_involved: [maya, ruth],
      resolution:
        'Nothing starts before 10:00 and every second slot is optional — Maya adds the extra stop, Ruth joins at lunch. No shared meal is ever optional.',
    },
    {
      tag: 'Mobility',
      description:
        "Diego's outdoor picks and the Sintra climbs clash with Ruth's limited stairs need.",
      members_involved: [diego, ruth],
      resolution:
        'Both are optional and paired with a level-access alternative at the same time and place: a café hour at Matosinhos, the garden path at Regaleira.',
    },
    {
      tag: 'Food',
      description: 'Maya is vegetarian; Ruth is gluten-free.',
      members_involved: [maya, ruth],
      resolution:
        'Every shared meal is à la carte at a venue that has confirmed those diets. Set-menu places are only booked for optional evenings.',
    },
  ],
  itinerary: [
    {
      day: 1,
      date: '2026-09-12',
      location: 'Lisbon · Alfama',
      lodging_area_suggestion: 'Alfama — central, tram access, level streets near the river',
      blocks: [
        {
          time_of_day: 'morning',
          activity: 'Land in Lisbon, settle into Alfama',
          description:
            'Metro from the airport, bags down, then a flat orientation loop — no hills on day one.',
          location: 'Alfama',
          estimated_duration_minutes: 180,
          estimated_cost_per_person: 12,
          suited_for_members: everyone,
          optional: false,
          weather_backup: null,
        },
        {
          time_of_day: 'afternoon',
          activity: 'Grazing lunch at Time Out Market',
          description:
            'Everyone orders their own; vegetarian and gluten-free stalls both confirmed.',
          location: 'Cais do Sodré',
          estimated_duration_minutes: 120,
          estimated_cost_per_person: 28,
          suited_for_members: everyone,
          optional: false,
          weather_backup: 'Indoor market — no backup needed',
        },
        {
          time_of_day: 'evening',
          activity: 'Fado in a small Alfama tavern',
          description: "Maya's music pick. Reserved ground-floor seats, 21:00 set.",
          location: 'Alfama',
          estimated_duration_minutes: 150,
          estimated_cost_per_person: 35,
          suited_for_members: everyone,
          optional: false,
          weather_backup: null,
        },
      ],
      notes: 'Kept light after the flight; nothing scheduled before 11:00.',
    },
    {
      day: 2,
      date: '2026-09-13',
      location: 'Lisbon · Graça',
      lodging_area_suggestion: null,
      blocks: [
        {
          time_of_day: 'morning',
          activity: 'Gulbenkian Museum',
          description:
            'Opens at 10 so nobody has to rush. Lifts throughout, quiet garden to sit in.',
          location: 'Avenidas Novas',
          estimated_duration_minutes: 150,
          estimated_cost_per_person: 18,
          suited_for_members: [maya!, ruth!],
          optional: true,
          weather_backup: 'Indoors either way',
        },
        {
          time_of_day: 'afternoon',
          activity: 'Tram 28 up to Graça + azulejo workshop',
          description:
            'Two hours of hands-on tile painting; the studio is level access from the street.',
          location: 'Graça',
          estimated_duration_minutes: 210,
          estimated_cost_per_person: 45,
          suited_for_members: everyone,
          optional: false,
          weather_backup: null,
        },
        {
          time_of_day: 'evening',
          activity: 'Sunset drinks at Senhora do Monte',
          description: 'Loose plan — skip it if the tile workshop ran long.',
          location: 'Graça',
          estimated_duration_minutes: 90,
          estimated_cost_per_person: 22,
          suited_for_members: [maya!, diego!],
          optional: true,
          weather_backup: 'Skip if wet — the viewpoint is exposed',
        },
      ],
      notes: null,
    },
    {
      day: 3,
      date: '2026-09-14',
      location: 'Sintra',
      lodging_area_suggestion: null,
      blocks: [
        {
          time_of_day: 'morning',
          activity: 'Train to Sintra, Quinta da Regaleira',
          description:
            'Pre-booked 10:30 entry. Ruth takes the garden path while the others do the initiation well.',
          location: 'Sintra',
          estimated_duration_minutes: 240,
          estimated_cost_per_person: 32,
          suited_for_members: everyone,
          optional: false,
          weather_backup: 'Palace interiors if it rains',
        },
        {
          time_of_day: 'afternoon',
          activity: 'Pena Palace terraces',
          description: 'Shuttle bus to the upper gate to skip the climb.',
          location: 'Sintra',
          estimated_duration_minutes: 150,
          estimated_cost_per_person: 24,
          suited_for_members: [maya!, diego!],
          optional: true,
          weather_backup: null,
        },
        {
          time_of_day: 'evening',
          activity: 'Wine flight in Colares',
          description:
            "Diego's pick — six sand-vine pours, small plates, back in Lisbon by 22:30.",
          location: 'Colares',
          estimated_duration_minutes: 150,
          estimated_cost_per_person: 30,
          suited_for_members: [diego!, ruth!],
          optional: true,
          weather_backup: null,
        },
      ],
      notes: 'Longest travel day — Sintra hills are the main accessibility pinch point.',
    },
    {
      day: 4,
      date: '2026-09-15',
      location: 'Porto',
      lodging_area_suggestion: 'Ribeira — walkable, but ask for a lift in the building',
      blocks: [
        {
          time_of_day: 'morning',
          activity: 'Early train to Porto',
          description: '08:10 Alfa Pendular, seats together, coffee on board.',
          location: 'Lisbon → Porto',
          estimated_duration_minutes: 200,
          estimated_cost_per_person: 42,
          suited_for_members: everyone,
          optional: false,
          weather_backup: null,
        },
        {
          time_of_day: 'afternoon',
          activity: 'Surf lesson at Matosinhos',
          description:
            'Two-hour beginner class with board hire. Others get a level-ground café hour on the same promenade.',
          location: 'Matosinhos',
          estimated_duration_minutes: 180,
          estimated_cost_per_person: 55,
          suited_for_members: [diego!],
          optional: true,
          weather_backup: 'Café hour for everyone if the swell is off',
        },
        {
          time_of_day: 'evening',
          activity: 'Long table dinner on Cais da Ribeira',
          description: 'Booked for 20:00 with no set menu, so both diets order freely.',
          location: 'Ribeira',
          estimated_duration_minutes: 150,
          estimated_cost_per_person: 38,
          suited_for_members: everyone,
          optional: false,
          weather_backup: null,
        },
      ],
      notes: null,
    },
    {
      day: 5,
      date: '2026-09-16',
      location: 'Porto · Douro',
      lodging_area_suggestion: null,
      blocks: [
        {
          time_of_day: 'morning',
          activity: 'Livraria Lello + café crawl',
          description: 'Timed 09:30 ticket, then three cafés in eight walkable blocks.',
          location: 'Porto centre',
          estimated_duration_minutes: 180,
          estimated_cost_per_person: 16,
          suited_for_members: [maya!, ruth!],
          optional: true,
          weather_backup: null,
        },
        {
          time_of_day: 'afternoon',
          activity: 'Douro valley cellar tour',
          description: 'Minibus pickup, lift to the tasting room, back at the hotel by 18:00.',
          location: 'Vila Nova de Gaia',
          estimated_duration_minutes: 240,
          estimated_cost_per_person: 48,
          suited_for_members: everyone,
          optional: false,
          weather_backup: 'Cellars are indoors',
        },
        {
          time_of_day: 'evening',
          activity: 'Transfer to the airport',
          description: 'Pre-booked van for three plus luggage; 21:55 flight home.',
          location: 'Porto airport',
          estimated_duration_minutes: 60,
          estimated_cost_per_person: 14,
          suited_for_members: everyone,
          optional: false,
          weather_backup: null,
        },
      ],
      notes: 'Nothing booked after 18:00 — the transfer needs a clear run.',
    },
  ],
  packing_and_prep_notes: [
    'Flat-soled shoes — Lisbon and Porto are both cobbled throughout',
    'A light layer for the evenings; September nights near the water are cool',
  ],
  verify_before_booking: [
    'Quinta da Regaleira 10:30 entry slots for your date',
    'That the Colares cellar can seat a gluten-free guest',
    'Shuttle-bus running times to the Pena upper gate',
  ],
  clarifying_questions: [],
});

db.prepare(
  `INSERT INTO plans (id, trip_id, revision, status, summary, plan, model, user_request, created_at)
   VALUES (?, ?, 1, ?, ?, ?, 'seed', NULL, ?)`,
).run(
  newId('plan'),
  trip.id,
  plan.status,
  plan.conversational_summary,
  JSON.stringify(plan),
  nowIso(),
);

console.log(`Seeded "${trip.title}"  →  ${trip.id}`);
console.log(`  ${trip.members.length} travellers, ${plan.itinerary.length} days`);
console.log(
  `  budget ${plan.trip.total_budget} ${plan.trip.currency}, estimated ${plan.trip.estimated_total_cost} (over: ${plan.trip.over_budget})`,
);
