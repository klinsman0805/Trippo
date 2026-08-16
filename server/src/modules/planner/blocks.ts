import { db, newId, nowIso } from '../../db/index.js';
import { badRequest, notFound } from '../../lib/errors.js';
import type { Plan, PlanBlock } from '../../schemas/plan.js';
import { getTrip } from '../trips/repo.js';
import { getLatestPlan, type PlanRecord } from './service.js';

/**
 * Hand-editing an itinerary.
 *
 * Edits mutate the *latest revision in place* rather than creating a new one.
 * A revision means "the planner ran"; the Refine thread is derived from
 * revisions, so a new one per keystroke-level edit would fill the conversation
 * with bubbles nobody said. What a person types is not a negotiation with the
 * planner, it is just the plan.
 */

export type BlockInput = Partial<Omit<PlanBlock, 'id'>>;

/** Every block in the plan, with the day it sits on. */
function allBlocks(plan: Plan): { day: number; block: PlanBlock }[] {
  return plan.itinerary.flatMap((d) => d.blocks.map((block) => ({ day: d.day, block })));
}

/**
 * Give every block an id, in place.
 *
 * Plans written before blocks had identity are missing them, and so is
 * anything fresh from the model — it is not asked for an id, because it has no
 * reason to make them unique. Ids are assigned once and then persisted by the
 * first write, so the numbering never shifts under an edit.
 */
export function ensureBlockIds(plan: Plan): boolean {
  let changed = false;
  for (const day of plan.itinerary) {
    for (const block of day.blocks) {
      if (!block.id) {
        block.id = newId('blk');
        changed = true;
      }
    }
  }
  return changed;
}

/**
 * An itinerary with days but nothing in them.
 *
 * "Build it by hand" has to have somewhere to build. The days come from the
 * trip's own dates, so a hand-written plan has exactly the shape a generated
 * one would — the flight envelope stays the only thing that decides how long a
 * trip is, whoever fills it in.
 */
export function createBlankPlan(tripId: string): PlanRecord {
  const existing = getLatestPlan(tripId);
  if (existing) return existing;

  const trip = getTrip(tripId);
  const days = daysBetween(trip.start_date, trip.end_date);

  const plan: Plan = {
    conversational_summary: '',
    status: 'complete',
    missing_info: [],
    trip: {
      title: trip.title,
      destinations: trip.destinations,
      start_date: trip.start_date,
      end_date: trip.end_date,
      duration_days: days.length,
      currency: trip.currency,
      total_budget: trip.total_budget,
      budget_breakdown: {
        lodging: { planned: 0, estimated: 0 },
        transport: { planned: 0, estimated: 0 },
        food: { planned: 0, estimated: 0 },
        activities: { planned: 0, estimated: 0 },
        buffer: { planned: 0, estimated: 0 },
      },
      estimated_total_cost: 0,
      over_budget: false,
      assumptions: [],
    },
    members: [],
    conflicts: [],
    itinerary: days.map((date, i) => ({
      day: i + 1,
      date,
      location: trip.destinations[0] ?? '',
      lodging_area_suggestion: null,
      blocks: [],
      notes: null,
    })),
    packing_and_prep_notes: [],
    verify_before_booking: [],
    clarifying_questions: [],
  };

  const id = newId('plan');
  db.prepare(
    `INSERT INTO plans (id, trip_id, revision, status, summary, plan, model, user_request, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, tripId, 1, 'complete', '', JSON.stringify(plan), 'hand-written', null, nowIso());

  return getLatestPlan(tripId)!;
}

/** Inclusive list of ISO dates, or a single unnamed day when there are none. */
function daysBetween(start: string | null, end: string | null): (string | null)[] {
  if (!start || !end) return [null];
  const from = Date.parse(`${start}T00:00:00Z`);
  const to = Date.parse(`${end}T00:00:00Z`);
  if (!Number.isFinite(from) || !Number.isFinite(to) || to < from) return [start];

  const out: string[] = [];
  for (let t = from; t <= to; t += 86_400_000) {
    out.push(new Date(t).toISOString().slice(0, 10));
  }
  return out;
}

function loadPlan(tripId: string): PlanRecord {
  const record = getLatestPlan(tripId);
  if (!record) {
    throw notFound(
      'no_plan_yet',
      'This trip has no itinerary to edit yet. Generate one, or add the first activity.',
    );
  }
  return record;
}

function persist(record: PlanRecord, plan: Plan): Plan {
  recomputeCosts(plan);
  db.prepare('UPDATE plans SET plan = ?, status = ? WHERE id = ?').run(
    JSON.stringify(plan),
    plan.status,
    record.id,
  );
  return plan;
}

/**
 * Keep the trip's headline cost honest after an edit.
 *
 * The Budget tab reads `estimated_total_cost`, and a hand-added dinner that
 * never reached it would make the budget quietly wrong — which is worse than
 * showing nothing, because it looks right.
 */
function recomputeCosts(plan: Plan): void {
  const total = allBlocks(plan).reduce(
    (sum, { block }) => sum + (block.estimated_cost_per_person ?? 0),
    0,
  );
  plan.trip.estimated_total_cost = Math.round(total * 100) / 100;
  const budget = plan.trip.total_budget;
  plan.trip.over_budget = budget !== null && plan.trip.estimated_total_cost > budget;
}

export function addBlock(tripId: string, day: number, input: BlockInput): Plan {
  const record = loadPlan(tripId);
  const plan = record.plan;
  ensureBlockIds(plan);

  const target = plan.itinerary.find((d) => d.day === day);
  if (!target) {
    throw badRequest('day_not_found', `This trip has no day ${day}.`);
  }

  target.blocks.push({
    id: newId('blk'),
    time_of_day: input.time_of_day ?? 'anytime',
    activity: input.activity ?? '',
    description: input.description ?? '',
    location: input.location ?? '',
    start_time: input.start_time ?? null,
    estimated_duration_minutes: input.estimated_duration_minutes ?? null,
    estimated_cost_per_person: input.estimated_cost_per_person ?? null,
    suited_for_members: input.suited_for_members ?? [],
    optional: input.optional ?? false,
    weather_backup: input.weather_backup ?? null,
    // Written by a person, so pinned by default — the planner has to be told
    // to leave it alone before it is ever asked to replan.
    source: 'user',
    pinned: true,
  });

  sortDay(target.blocks);
  return persist(record, plan);
}

export function updateBlock(tripId: string, blockId: string, input: BlockInput): Plan {
  const record = loadPlan(tripId);
  const plan = record.plan;
  ensureBlockIds(plan);

  const found = allBlocks(plan).find((b) => b.block.id === blockId);
  if (!found) throw notFound('block_not_found', `No activity with id ${blockId}`);

  Object.assign(found.block, {
    ...input,
    // Editing the planner's work makes it yours; it should stop being replaced
    // behind your back.
    source: 'user',
    pinned: input.pinned ?? true,
  });

  const day = plan.itinerary.find((d) => d.day === found.day);
  if (day) sortDay(day.blocks);
  return persist(record, plan);
}

export function removeBlock(tripId: string, blockId: string): Plan {
  const record = loadPlan(tripId);
  const plan = record.plan;
  ensureBlockIds(plan);

  let removed = false;
  for (const day of plan.itinerary) {
    const before = day.blocks.length;
    day.blocks = day.blocks.filter((b) => b.id !== blockId);
    if (day.blocks.length !== before) removed = true;
  }
  if (!removed) throw notFound('block_not_found', `No activity with id ${blockId}`);

  return persist(record, plan);
}

export function moveBlock(
  tripId: string,
  blockId: string,
  targetDay: number,
  targetSlot: PlanBlock['time_of_day'],
): Plan {
  const record = loadPlan(tripId);
  const plan = record.plan;
  ensureBlockIds(plan);

  const found = allBlocks(plan).find((b) => b.block.id === blockId);
  if (!found) throw notFound('block_not_found', `No activity with id ${blockId}`);

  const destination = plan.itinerary.find((d) => d.day === targetDay);
  if (!destination) {
    throw badRequest('day_not_found', `This trip has no day ${targetDay}.`);
  }

  for (const day of plan.itinerary) {
    day.blocks = day.blocks.filter((b) => b.id !== blockId);
  }

  found.block.time_of_day = targetSlot;
  destination.blocks.push(found.block);
  sortDay(destination.blocks);

  return persist(record, plan);
}

/** Hand the block back to the planner without pretending it was never yours. */
export function setPinned(tripId: string, blockId: string, pinned: boolean): Plan {
  const record = loadPlan(tripId);
  const plan = record.plan;
  ensureBlockIds(plan);

  const found = allBlocks(plan).find((b) => b.block.id === blockId);
  if (!found) throw notFound('block_not_found', `No activity with id ${blockId}`);

  found.block.pinned = pinned;
  return persist(record, plan);
}

/**
 * Reorder within a day.
 *
 * Timed activities first in time order, then untimed ones in slot order, then
 * anything marked `anytime`. Ordering *across* slots is not a thing the user
 * controls — the slot decides that — so this runs on every write rather than
 * being an operation the client has to remember to request.
 */
const SLOT_ORDER: Record<PlanBlock['time_of_day'], number> = {
  morning: 0,
  afternoon: 1,
  evening: 2,
  anytime: 3,
};

export function sortDay(blocks: PlanBlock[]): void {
  blocks.sort((a, b) => {
    const slotDelta = SLOT_ORDER[a.time_of_day] - SLOT_ORDER[b.time_of_day];
    if (slotDelta !== 0) return slotDelta;
    // Within a slot, a stated time wins over one that was never given.
    if (a.start_time && b.start_time) return a.start_time.localeCompare(b.start_time);
    if (a.start_time) return -1;
    if (b.start_time) return 1;
    return 0;
  });
}

/** What the regenerate sheet reports, and what generation has to honour. */
export interface PinnedSummary {
  pinned: { day: number; block: PlanBlock }[];
  replan_days: number[];
  /** Per-person cost already committed to pinned activities. */
  committed_cost: number;
}

export function pinnedSummary(tripId: string): PinnedSummary {
  const record = getLatestPlan(tripId);
  if (!record) return { pinned: [], replan_days: [], committed_cost: 0 };

  const plan = record.plan;
  ensureBlockIds(plan);

  const pinned = allBlocks(plan).filter(({ block }) => block.pinned);
  const pinnedDays = new Set(pinned.map((p) => p.day));

  return {
    pinned,
    // Every day is replanned; the pinned blocks inside them simply survive.
    // Reporting "days 1, 2 and 4" would be a lie about days that also change.
    replan_days: plan.itinerary.map((d) => d.day).filter((d) => !pinnedDays.has(d)),
    committed_cost: pinned.reduce(
      (sum, { block }) => sum + (block.estimated_cost_per_person ?? 0),
      0,
    ),
  };
}
