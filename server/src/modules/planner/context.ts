import type { Place, Trip } from '../../schemas/trip.js';
import { deriveTripEnvelope, envelopeInstructions } from '../flights/envelope.js';
import type { StoredSelection } from '../flights/index.js';
import { parseHours, type OpeningHours, type Weekday } from './hours.js';

/**
 * Assemble the user turn: everything the planner knows about this trip.
 *
 * Deliberately prose rather than JSON. The model reasons better over a briefing
 * than over a serialized record, and prose lets us attach the *provenance* of
 * each place ("saved from a 小红书 post because …"), which is what keeps the
 * plan traceable to something a member actually asked for.
 */
export function buildPlannerContext(
  trip: Trip,
  places: Place[],
  flights: StoredSelection[],
  userRequest: string | null,
): string {
  const sections: string[] = [];

  sections.push(section('TRIP CONTEXT', tripLines(trip)));
  sections.push(section('MEMBER PROFILES', memberLines(trip)));

  const flightBlock = flightLines(flights);
  if (flightBlock.length) sections.push(section('BOOKED / SELECTED FLIGHTS', flightBlock));

  const placeBlock = placeLines(places);
  if (placeBlock.length) {
    sections.push(
      section(
        'SAVED PLACES (imported by the group from links they shared)',
        [
          'These came from posts, guides and reviews the members saved. Treat them as expressed interest — prefer them over generic attractions, but drop any that do not fit the schedule, budget or a member constraint, and say so in the summary.',
          'Each is prefixed with a tag in square brackets. When a block you write uses one of these places, set that block\'s `from_place` to the tag exactly as written, e.g. "p3". Leave `from_place` null for anything you chose yourself — a wrong tag is worse than none, because the traveller is shown which of their own links an activity came from.',
        'Where a place shows OPEN hours, those came from the source and are checked against your `start_time` after you answer. Schedule it inside them or leave it out — a stop timed when the place is shut is reported to the traveller as an error, not a warning.',
          '',
          ...placeBlock,
        ],
      ),
    );
  }

  sections.push(
    section('YOUR TASK', [
      userRequest?.trim()
        ? `The group asks: ${userRequest.trim()}`
        : 'Produce the initial itinerary for this trip.',
      '',
      'Return the full object every time, including all unchanged days.',
    ]),
  );

  return sections.join('\n\n');
}

const section = (heading: string, lines: string[]): string =>
  [`## ${heading}`, ...lines].join('\n');

function tripLines(trip: Trip): string[] {
  const budget =
    trip.total_budget == null
      ? 'Budget: not stated — ask for it'
      : `Budget: ${trip.total_budget} ${trip.currency} ${
          trip.budget_basis === 'per_person' ? 'per person' : 'total for the group'
        }`;

  const dates =
    trip.start_date && trip.end_date
      ? `Dates: ${trip.start_date} to ${trip.end_date}${
          trip.date_flexible ? ' (flexible)' : ' (fixed)'
        } — ${nightsBetween(trip.start_date, trip.end_date)} nights`
      : `Dates: not fixed yet${trip.date_flexible ? ' (flexible window)' : ''}`;

  return [
    `Title: ${trip.title}`,
    `Destinations: ${trip.destinations.length ? trip.destinations.join(', ') : 'not decided — the group may want help choosing'}`,
    dates,
    budget,
    `Currency: ${trip.currency}`,
    `Group size: ${trip.members.length} ${trip.members.length === 1 ? 'traveller' : 'travellers'}`,
    trip.purpose ? `Purpose: ${trip.purpose}` : null,
    trip.hard_constraints.length
      ? `Hard constraints: ${trip.hard_constraints.join('; ')}`
      : null,
    trip.notes ? `Organiser notes: ${trip.notes}` : null,
  ].filter((l): l is string => l !== null);
}

function memberLines(trip: Trip): string[] {
  if (!trip.members.length) {
    return ['No members have been added yet — you need at least the group size and composition.'];
  }

  return trip.members.map((m) => {
    const facts = [
      `pace ${m.pace}`,
      m.departure_city ? `departing from ${m.departure_city}` : null,
      m.interests.length ? `interests: ${m.interests.join(', ')}` : null,
      m.budget_sensitivity ? `budget: ${m.budget_sensitivity}` : null,
      m.dietary_restrictions.length
        ? `DIETARY: ${m.dietary_restrictions.join(', ')}`
        : null,
      m.accessibility_needs.length
        ? `ACCESSIBILITY: ${m.accessibility_needs.join(', ')}`
        : null,
      m.deal_breakers.length ? `deal-breakers: ${m.deal_breakers.join(', ')}` : null,
      m.wants.length ? `specifically wants: ${m.wants.join(', ')}` : null,
      m.avoids.length ? `wants to avoid: ${m.avoids.join(', ')}` : null,
    ].filter(Boolean);

    // The id is what the model must echo in suited_for_members.
    return `- ${m.name} (id: ${m.id}) — ${facts.join('; ')}`;
  });
}

function flightLines(flights: StoredSelection[]): string[] {
  if (!flights.length) return [];

  const envelope = deriveTripEnvelope(flights.map((f) => f.offer));
  const lines = flights.map((f) => {
    const it = f.offer.itineraries.find((i) => i.direction === f.direction);
    const first = it?.segments[0];
    const last = it?.segments.at(-1);
    if (!first || !last) return `- ${f.direction}: (no segment detail)`;
    const price = f.offer.is_estimate
      ? `~${f.offer.price_per_traveler} ${f.offer.currency} per traveller (ESTIMATE, not a real fare)`
      : `${f.offer.price_per_traveler} ${f.offer.currency} per traveller`;
    return `- ${f.direction}: ${first.origin} ${first.departs_at} → ${last.destination} ${last.arrives_at}, ${it?.stops ?? 0} stop(s), ${price}`;
  });

  if (envelope) {
    const instructions = envelopeInstructions(envelope);
    if (instructions.length) {
      lines.push('');
      lines.push(...instructions);
    }
  }

  return lines;
}

/**
 * The tag the model cites a place by.
 *
 * Short and positional rather than the real id: a `plc_9f3c…` in the prompt is
 * thirty tokens of noise per place and something the model will mistype. The
 * caller maps the tag back to the real place afterwards.
 */
export function placeTag(index: number): string {
  return `p${index + 1}`;
}

function placeLines(places: Place[]): string[] {
  if (!places.length) return [];

  // Group by city so the model sees the geographic shape of the pool at a glance.
  const byCity = new Map<string, Place[]>();
  for (const p of places) {
    const key = p.city ?? 'Unspecified location';
    const bucket = byCity.get(key);
    if (bucket) bucket.push(p);
    else byCity.set(key, [p]);
  }

  // Tags follow the original order, not the grouped one, so the caller can
  // resolve them by index against the same array it passed in.
  const tagOf = new Map(places.map((p, i) => [p.id, placeTag(i)]));

  const lines: string[] = [];
  for (const [city, group] of byCity) {
    lines.push(`### ${city}`);
    for (const p of group) {
      const hours = parseHours(p.hours);
      const bits = [
        p.category ? `[${p.category}]` : null,
        p.address ?? null,
        p.lat != null && p.lng != null ? `(${p.lat.toFixed(4)}, ${p.lng.toFixed(4)})` : null,
        // Stated before the reason, because it is a constraint rather than
        // colour: a block scheduled outside these is checked and reported.
        hours ? `OPEN ${hoursSummary(hours)}` : null,
        p.why ? `— ${p.why}` : null,
      ].filter(Boolean);
      lines.push(`- [${tagOf.get(p.id)}] ${p.name} ${bits.join(' ')}`.trimEnd());
    }
    lines.push('');
  }
  return lines;
}

const DAY_LETTERS: Record<Weekday, string> = {
  mon: 'Mon',
  tue: 'Tue',
  wed: 'Wed',
  thu: 'Thu',
  fri: 'Fri',
  sat: 'Sat',
  sun: 'Sun',
};

const WEEK: Weekday[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/** "daily 10:00-22:00", or "Mon,Tue,Wed 10:00-18:30; Sat,Sun 09:00-18:30". */
function hoursSummary(hours: OpeningHours): string {
  return hours
    .map((w) => {
      const days = WEEK.filter((d) => w.days.includes(d));
      const label = days.length === 7 ? 'daily' : days.map((d) => DAY_LETTERS[d]).join(',');
      return `${label} ${w.opens}-${w.closes}`;
    })
    .join('; ');
}

function nightsBetween(start: string, end: string): number {
  const ms = Date.parse(`${end}T00:00:00Z`) - Date.parse(`${start}T00:00:00Z`);
  return Math.max(Math.round(ms / 86_400_000), 0);
}
