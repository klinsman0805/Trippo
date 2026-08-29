import type { Place, Trip } from '../../schemas/trip.js';
import type { Plan, PlanBlock } from '../../schemas/plan.js';
import type { PlanDraft } from '../../schemas/plan-draft.js';
import { placeTag } from './context.js';

/**
 * Turns the planner's draft into the plan the rest of the app reads.
 *
 * Everything reconstructed here was already ours: the trip's identity and
 * dates come from the trip record, the member profiles from its members, the
 * totals from arithmetic over the draft's own numbers, and a block's name,
 * venue and reason from the saved place it cites. Asking the model to repeat
 * any of it would cost output tokens — the slow, rate-limited half of a call —
 * and let it contradict data we hold.
 *
 * Attribution is resolved here rather than trusted: a cited tag is looked up
 * in the list we sent, and an uncited block is matched by name against the
 * same list. Only a place that resolves against our own data is claimed on a
 * card, because "from your link" is a statement about our records.
 */
export function hydrate(
  draft: PlanDraft,
  trip: Trip,
  places: Place[],
  sourceTitles: Map<string, string>,
): Plan {
  const byTag = new Map(places.map((p, i) => [placeTag(i), p]));
  const byName = new Map<string, Place>();
  for (const place of places) {
    for (const alias of aliases(place.name)) byName.set(alias, place);
  }

  const itinerary = draft.itinerary.map((day) => ({
    day: day.day,
    // Dates are the trip's, applied by position. The model has no better
    // source for them than the range we gave it, and every mistake it could
    // make here is one `reconcileDays` would immediately have to undo.
    date: null as string | null,
    location: trip.destinations[0] ?? '',
    lodging_area_suggestion: day.lodging_area_suggestion,
    notes: day.notes,
    blocks: day.blocks.map((block): PlanBlock => {
      const cited = block.place ? byTag.get(block.place.trim()) : undefined;
      const matched = cited ?? matchByName(block.activity, block.location ?? '', byName);

      return {
        id: '',
        time_of_day: block.time_of_day,
        // A cited place carries its own name; a label is only used when the
        // model had something to add.
        activity: block.activity.trim() || matched?.name || '',
        description: block.note ?? matched?.why ?? '',
        location:
          matched?.address ?? matched?.name ?? block.location ?? '',
        start_time: block.start_time,
        estimated_duration_minutes: null,
        estimated_cost_per_person: block.estimated_cost_per_person,
        // Group planning is off, and the draft no longer carries per-member
        // fit. An empty list is the honest value, not a guess.
        suited_for_members: [],
        optional: block.optional,
        weather_backup: null,
        source: 'planner' as const,
        pinned: false,
        from_place_id: matched?.id ?? null,
        from_source_title: matched?.source_id
          ? sourceTitles.get(matched.source_id) ?? null
          : null,
        from_place: null,
      };
    }),
  }));

  const b = draft.budget_breakdown;
  const estimatedTotal =
    b.lodging.estimated +
    b.transport.estimated +
    b.food.estimated +
    b.activities.estimated +
    b.buffer.estimated;

  return {
    conversational_summary: draft.conversational_summary,
    status: draft.status,
    missing_info: draft.missing_info,
    trip: {
      title: trip.title,
      destinations: trip.destinations,
      start_date: trip.start_date,
      end_date: trip.end_date,
      duration_days: draft.itinerary.length,
      currency: trip.currency,
      total_budget: trip.total_budget,
      budget_breakdown: b,
      estimated_total_cost: estimatedTotal,
      // Arithmetic, not judgement. The model used to be asked for this and
      // could disagree with its own figures.
      over_budget: trip.total_budget != null && estimatedTotal > trip.total_budget,
      assumptions: draft.assumptions,
    },
    members: trip.members.map((m) => ({
      id: m.id,
      name: m.name,
      interests: m.interests ?? [],
      pace: m.pace,
      dietary_restrictions: m.dietary_restrictions ?? [],
      accessibility_needs: m.accessibility_needs ?? [],
      deal_breakers: m.deal_breakers ?? [],
    })),
    conflicts: draft.conflicts,
    itinerary,
    packing_and_prep_notes: draft.packing_and_prep_notes,
    verify_before_booking: draft.verify_before_booking,
    clarifying_questions: draft.clarifying_questions,
  };
}

/**
 * The previous plan, written back in the draft's vocabulary.
 *
 * A refinement has to show the model what it produced last time, and sending
 * the hydrated plan would send back everything hydration just added — member
 * profiles, trip identity, each place's stored description — as input tokens,
 * in fields the model is no longer allowed to emit. This is the same itinerary
 * in the shape it is being asked to return.
 */
export function toDraftView(
  plan: Plan,
  places: Place[],
): Array<{ day: number; blocks: unknown[] }> {
  const tagOf = new Map(places.map((p, i) => [p.id, placeTag(i)]));

  return plan.itinerary.map((day) => ({
    day: day.day,
    blocks: day.blocks.map((block) => ({
      place: block.from_place_id ? tagOf.get(block.from_place_id) ?? null : null,
      activity: block.activity,
      time_of_day: block.time_of_day,
      start_time: block.start_time,
      optional: block.optional,
      estimated_cost_per_person: block.estimated_cost_per_person,
      // Marked so the model does not quietly replace something the traveller
      // wrote; the pinned section states the rule.
      written_by_traveller: block.source === 'user' ? true : undefined,
    })),
  }));
}

/** A saved place named in the block's title or venue, if there is one. */
function matchByName(
  activity: string,
  location: string,
  byName: Map<string, Place>,
): Place | undefined {
  const haystack = normalise(`${activity} ${location}`);
  if (!haystack) return undefined;

  const exact = byName.get(normalise(location)) ?? byName.get(normalise(activity));
  if (exact) return exact;

  // Longest first, so "Pavilion Bukit Bintang" wins over a hypothetical
  // "Pavilion" rather than whichever happened to be stored first.
  for (const [name, place] of [...byName.entries()].sort((a, b) => b[0].length - a[0].length)) {
    // Short names produce false positives inside longer words — "VCR" would
    // match "discover" — so they only count as whole words.
    if (name.length < 6) {
      if (new RegExp(`\\b${escapeRegExp(name)}\\b`).test(haystack)) return place;
      continue;
    }
    if (haystack.includes(name)) return place;
  }
  return undefined;
}

/**
 * The forms a place's name might be written in: the whole thing, and the part
 * before any bracket or dash, which is what a shortened reference keeps — the
 * model writes "Wong Ah Wah" where the post said "Wong Ah Wah (Ming Ji Grilled
 * Fish)" more often than not.
 */
function aliases(name: string): string[] {
  const full = normalise(name);
  const short = normalise(name.split(/[(（\-–—|]/)[0] ?? '');
  // Two words minimum for the short form. A one-word head like "Wat" would
  // collect every temple in the city.
  const useShort = short && short !== full && short.split(' ').length >= 2;
  return useShort ? [full, short] : [full];
}

function normalise(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
