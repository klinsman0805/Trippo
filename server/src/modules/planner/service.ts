import { db, newId, nowIso } from '../../db/index.js';
import { env } from '../../config/env.js';
import { structuredCall } from '../../lib/llm.js';
import { notFound, unprocessable } from '../../lib/errors.js';
import { PLAN_JSON_SCHEMA, PlanSchema, type Plan } from '../../schemas/plan.js';
import { listSelections } from '../flights/index.js';
import { listSources } from '../ingest/service.js';
import { listPlaces } from '../trips/places.repo.js';
import type { Place } from '../../schemas/trip.js';
import { getTrip, touchTrip } from '../trips/repo.js';
import { ensureBlockIds, pinnedSummary, sortDay } from './blocks.js';
import { buildPlannerContext, placeTag } from './context.js';
import { clearFailure, recordFailure } from './failure.js';
import { VOYAGER_SYSTEM_PROMPT } from './prompt.js';

export interface PlanRecord {
  id: string;
  trip_id: string;
  revision: number;
  status: Plan['status'];
  summary: string;
  plan: Plan;
  model: string;
  user_request: string | null;
  created_at: string;
}

/**
 * Generate (or refine) a plan.
 *
 * `userRequest` carries a refinement like "make day 3 more relaxed". Per the
 * spec, refinements return the whole updated plan rather than a diff, so the
 * client can replace its state wholesale.
 */
export async function generatePlan(
  tripId: string,
  userRequest: string | null,
): Promise<PlanRecord> {
  const trip = getTrip(tripId);
  const places = listPlaces(tripId);
  const flights = listSelections(tripId);

  const previous = getLatestPlan(tripId);
  let context = buildPlannerContext(trip, places, flights, userRequest);

  // Anything the user wrote and kept pinned is a fixed point, not a
  // suggestion. It is described to the planner as already-occupied time so it
  // plans around it, and re-inserted afterwards so the result is authoritative
  // rather than dependent on the model having complied.
  const { pinned } = pinnedSummary(tripId);
  if (pinned.length) {
    context += `\n\n## ALREADY PLANNED BY THE TRAVELLER — DO NOT CHANGE OR REPLACE\nThese slots are taken. Plan around them, do not duplicate them, and do not emit them in your own output. Budget for them: they are already counted in the trip's cost.\n\n${pinned
      .map(
        ({ day, block }) =>
          `- Day ${day}, ${block.time_of_day}${
            block.start_time ? ` at ${block.start_time}` : ''
          }: ${block.activity}${block.location ? ` (${block.location})` : ''}`,
      )
      .join('\n')}`;
  }

  // On a refinement, show the model what it produced last time so it edits
  // rather than starts over — otherwise day 5 silently changes when the user
  // only asked about day 3.
  if (previous && userRequest) {
    context += `\n\n## CURRENT PLAN (revision ${previous.revision})\nThis is the plan you produced previously. Apply the requested change and return the complete updated plan, keeping everything else stable unless the change requires otherwise.\n\n${JSON.stringify(
      previous.plan,
      null,
      2,
    )}`;
  }

  // Every failure is recorded here rather than at the route, so a refinement
  // and an answered question produce the same recoverable state as a first
  // attempt — the failed screen should never depend on which door you came in.
  const startedAt = Date.now();
  let plan: Plan;
  try {
    plan = await callPlanner(context, trip.members.map((m) => m.id));
  } catch (err) {
    recordFailure(tripId, err, {
      elapsedMs: Date.now() - startedAt,
      lastGoodRevision: previous?.revision ?? null,
      userRequest,
    });
    throw err;
  }

  attributePlaces(plan, places, tripId);

  const record = savePlan(tripId, reinstatePinned(plan, pinned), userRequest);
  clearFailure(tripId);
  return record;
}

/**
 * Records which saved place each block came from, so a card can say so.
 *
 * Two passes, both of which check our own data rather than believing the
 * model: the tag it cited is looked up in the list we gave it, and anything
 * uncited is matched by name against the same list. A citation the traveller
 * can see has to be a fact — "from the 小红书 post you saved" is a claim about
 * provenance, and getting it wrong is worse than saying nothing.
 */
function attributePlaces(plan: Plan, places: Place[], tripId: string): void {
  const byTag = new Map(places.map((p, i) => [placeTag(i), p]));
  // Names are matched case- and punctuation-insensitively, and a place is
  // keyed under its alternative names too: the model writes "Wong Ah Wah"
  // where the post said "Wong Ah Wah (Ming Ji Grilled Fish)" more often than
  // not, and the full string would then never appear in the block.
  const byName = new Map<string, Place>();
  for (const place of places) {
    for (const alias of aliases(place.name)) {
      byName.set(alias, place);
    }
  }
  const sourceTitles = new Map(
    listSources(tripId).map((s) => [s.id, s.title ?? s.url ?? 'a pasted note']),
  );

  for (const day of plan.itinerary) {
    for (const block of day.blocks) {
      const cited = block.from_place ? byTag.get(block.from_place.trim()) : undefined;
      const matched = cited ?? matchByName(block, byName);
      // Consumed either way: it is the model's working, not the answer.
      block.from_place = null;

      if (!matched) continue;
      block.from_place_id = matched.id;
      block.from_source_title = matched.source_id
        ? sourceTitles.get(matched.source_id) ?? null
        : null;
    }
  }
}

/** A saved place named in the block's title or venue, if there is one. */
function matchByName(
  block: { activity: string; location: string },
  byName: Map<string, Place>,
): Place | undefined {
  const haystack = normalise(`${block.activity} ${block.location}`);
  if (!haystack) return undefined;

  const exact = byName.get(normalise(block.location)) ?? byName.get(normalise(block.activity));
  if (exact) return exact;

  // Longest first, so "Pavilion Bukit Bintang" wins over a hypothetical
  // "Pavilion" rather than whichever happened to be stored first.
  const candidates = [...byName.entries()].sort((a, b) => b[0].length - a[0].length);
  for (const [name, place] of candidates) {
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
 * before any bracket or dash, which is what a shortened reference keeps.
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

/**
 * One planner call plus, on a validation failure, exactly one corrective retry.
 *
 * Structured outputs make a *shape* failure very unlikely, so the retry mostly
 * catches semantic problems the JSON schema can't express — chiefly member ids
 * that don't exist, which would break the client's per-member filtering.
 */
async function callPlanner(context: string, validMemberIds: string[]): Promise<Plan> {
  const attempt = async (extraInstruction?: string): Promise<Plan> => {
    const raw = await structuredCall({
      system: VOYAGER_SYSTEM_PROMPT,
      userContent: extraInstruction ? `${context}\n\n${extraInstruction}` : context,
      schema: PLAN_JSON_SCHEMA,
      maxOutputTokens: 32_000,
      effort: env.PLANNER_EFFORT,
    });

    const parsed = PlanSchema.safeParse(raw);
    if (!parsed.success) {
      throw unprocessable(
        'plan_validation_failed',
        'The planner returned a plan that failed validation.',
        parsed.error.flatten(),
      );
    }

    const badIds = unknownMemberIds(parsed.data, validMemberIds);
    if (badIds.length) {
      throw unprocessable(
        'plan_unknown_member_ids',
        `The plan referenced member ids that do not exist: ${badIds.join(', ')}`,
      );
    }

    return parsed.data;
  };

  try {
    return await attempt();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return attempt(
      `## CORRECTION\nYour previous response was rejected: ${message}\nReturn a corrected plan. Every id in "members" and in each block's "suited_for_members" must be one of exactly these ids: ${validMemberIds.join(', ')}.`,
    );
  }
}

function unknownMemberIds(plan: Plan, validIds: string[]): string[] {
  // A trip with no members yet can't be checked against anything.
  if (validIds.length === 0) return [];

  const valid = new Set(validIds);
  const seen = new Set<string>();

  for (const member of plan.members) {
    if (!valid.has(member.id)) seen.add(member.id);
  }
  for (const day of plan.itinerary) {
    for (const block of day.blocks) {
      for (const id of block.suited_for_members) {
        if (!valid.has(id)) seen.add(id);
      }
    }
  }
  return [...seen];
}

// --- persistence ---

/**
 * Put the traveller's pinned activities back into the freshly planned days.
 *
 * The prompt asks the model to work around them, but a prompt is a request.
 * This makes it true regardless: the pinned block is re-inserted, and anything
 * the model produced in the same slot is left alone beside it rather than
 * dropped — a double-booked slot is visible and fixable, whereas silently
 * deleting the model's work would hide a planning failure.
 */
function reinstatePinned(
  plan: Plan,
  pinned: { day: number; block: Plan['itinerary'][number]['blocks'][number] }[],
): Plan {
  if (!pinned.length) return plan;
  ensureBlockIds(plan);

  for (const { day, block } of pinned) {
    const target = plan.itinerary.find((d) => d.day === day);
    if (!target) continue;
    // The model was told not to emit these; if it did anyway, drop the copy
    // rather than showing the activity twice.
    target.blocks = target.blocks.filter(
      (b) => b.activity.trim().toLowerCase() !== block.activity.trim().toLowerCase(),
    );
    target.blocks.push(block);
    sortDay(target.blocks);
  }

  return plan;
}

function savePlan(tripId: string, plan: Plan, userRequest: string | null): PlanRecord {
  const revision = (getLatestPlan(tripId)?.revision ?? 0) + 1;
  const id = newId('plan');
  // The model is not asked for block ids, so they are minted here — before the
  // plan is ever stored, so nothing downstream sees an identity-less block.
  ensureBlockIds(plan);

  db.prepare(
    `INSERT INTO plans (id, trip_id, revision, status, summary, plan, model, user_request, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    tripId,
    revision,
    plan.status,
    plan.conversational_summary,
    JSON.stringify(plan),
    env.PLANNER_MODEL,
    userRequest,
    nowIso(),
  );

  touchTrip(tripId);
  return getPlan(id);
}

export function getPlan(id: string): PlanRecord {
  const row = db.prepare('SELECT * FROM plans WHERE id = ?').get(id);
  if (!row) throw notFound('plan_not_found', `No plan with id ${id}`);
  return rowToPlan(row as Record<string, unknown>);
}

export function getLatestPlan(tripId: string): PlanRecord | null {
  const row = db
    .prepare('SELECT * FROM plans WHERE trip_id = ? ORDER BY revision DESC LIMIT 1')
    .get(tripId);
  return row ? rowToPlan(row as Record<string, unknown>) : null;
}

export function listPlans(tripId: string): PlanRecord[] {
  const rows = db
    .prepare('SELECT * FROM plans WHERE trip_id = ? ORDER BY revision DESC')
    .all(tripId) as Record<string, unknown>[];
  return rows.map(rowToPlan);
}

function rowToPlan(row: Record<string, unknown>): PlanRecord {
  return {
    id: row.id as string,
    trip_id: row.trip_id as string,
    revision: row.revision as number,
    status: row.status as Plan['status'],
    summary: row.summary as string,
    plan: JSON.parse(row.plan as string) as Plan,
    model: row.model as string,
    user_request: (row.user_request as string) ?? null,
    created_at: row.created_at as string,
  };
}
