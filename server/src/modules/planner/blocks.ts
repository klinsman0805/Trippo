import { db, newId, nowIso } from '../../db/index.js';
import { badRequest, notFound } from '../../lib/errors.js';
import type { Plan, PlanBlock } from '../../schemas/plan.js';
import { getTrip, updateTrip } from '../trips/repo.js';
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

/**
 * Remove one day, and shorten the trip to match.
 *
 * Both halves are required. Dropping the day alone would leave the trip's
 * dates a day longer, and the next reconcile — triggered by any flight change
 * — would put an empty day straight back.
 *
 * The trip's *end* moves, never its start: a day removed from the middle
 * renumbers what follows, which is the same shape as losing the last day.
 */
export function deleteDay(tripId: string, day: number): Plan {
  const record = loadPlan(tripId);
  const plan = record.plan;
  ensureBlockIds(plan);

  if (plan.itinerary.length <= 1) {
    throw badRequest('last_day', 'A trip needs at least one day.');
  }
  if (!plan.itinerary.some((d) => d.day === day)) {
    throw badRequest('day_not_found', `This trip has no day ${day}.`);
  }

  plan.itinerary = plan.itinerary.filter((d) => d.day !== day);

  const trip = getTrip(tripId);
  if (trip.start_date && trip.end_date) {
    const end = Date.parse(`${trip.end_date}T00:00:00Z`) - 86_400_000;
    const newEnd = new Date(end).toISOString().slice(0, 10);
    updateTrip(tripId, { end_date: newEnd });
    plan.trip.end_date = newEnd;

    const dates = daysBetween(trip.start_date, newEnd);
    plan.itinerary.forEach((d, i) => {
      d.day = i + 1;
      d.date = dates[i] ?? null;
    });
  } else {
    plan.itinerary.forEach((d, i) => {
      d.day = i + 1;
    });
  }

  plan.trip.duration_days = plan.itinerary.length;
  return persist(record, plan);
}

/**
 * Make the itinerary's days match the trip's dates.
 *
 * Changing flights changes how long the trip is, and the stored plan does not
 * know that. Shortening 26–30 Sep to 26–29 left a day 5 on screen that no
 * longer existed. Days are added empty and removed from the end, and anything
 * planned on a day that survives is untouched.
 *
 * Returns null when nothing needed doing, so callers can avoid a pointless
 * write.
 */
export function reconcileDays(tripId: string): Plan | null {
  const record = getLatestPlan(tripId);
  if (!record) return null;

  const trip = getTrip(tripId);
  const dates = daysBetween(trip.start_date, trip.end_date);
  const plan = record.plan;
  ensureBlockIds(plan);

  const wanted = dates.length;
  const have = plan.itinerary.length;
  // No dates on the trip means nothing to reconcile against — a hand-built
  // plan with its own days must not be truncated to one.
  if (!trip.start_date || !trip.end_date) return null;

  let changed = false;

  if (have > wanted) {
    // Trimmed from the end, which is where the removed days are: a shorter
    // return moves the last day, never the first.
    plan.itinerary = plan.itinerary.slice(0, wanted);
    changed = true;
  } else if (have < wanted) {
    for (let day = have + 1; day <= wanted; day++) {
      plan.itinerary.push({
        day,
        date: dates[day - 1] ?? null,
        location: trip.destinations[0] ?? '',
        lodging_area_suggestion: null,
        blocks: [],
        notes: null,
      });
    }
    changed = true;
  }

  // Dates shift even when the count does not — a flight moved a day later
  // keeps five days but renumbers all of them.
  plan.itinerary.forEach((day, i) => {
    const date = dates[i] ?? null;
    if (day.date !== date) {
      day.date = date;
      changed = true;
    }
    if (day.day !== i + 1) {
      day.day = i + 1;
      changed = true;
    }
  });

  if (!changed) return null;
  plan.trip.start_date = trip.start_date;
  plan.trip.end_date = trip.end_date;
  plan.trip.duration_days = wanted;
  return persist(record, plan);
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
  if (input.start_time) applyTimeOrder(target.blocks, input.time_of_day ?? 'anytime');
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
  if (day) {
    sortDay(day.blocks);
    // Only when the edit touched the time — otherwise a save would quietly
    // undo a drag the user made a moment earlier.
    if ('start_time' in input) applyTimeOrder(day.blocks, found.block.time_of_day);
  }
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
 * Order within a day.
 *
 * Slot decides the grouping; **array order decides the rest**. Nothing stores
 * an explicit index — the stored array *is* the order, which is why a drag
 * needs no new field and cannot drift out of sync with what is rendered.
 *
 * The sort is by slot only, and JS sorts are stable, so two activities in the
 * same slot keep whatever order they were put in. That is what makes an
 * explicit reorder survive every later write.
 */
const SLOT_ORDER: Record<PlanBlock['time_of_day'], number> = {
  morning: 0,
  afternoon: 1,
  evening: 2,
  anytime: 3,
};

export function sortDay(blocks: PlanBlock[]): void {
  blocks.sort((a, b) => SLOT_ORDER[a.time_of_day] - SLOT_ORDER[b.time_of_day]);
}

/**
 * Put one slot in time order: stated times first and ascending, then the rest
 * in the order they were already in.
 *
 * Run only when a time is set or changed, never on every write. "The day
 * orders itself by time" is what happens when you give it one — it is not a
 * rule that should quietly undo a drag afterwards.
 */
export function applyTimeOrder(blocks: PlanBlock[], slot: PlanBlock['time_of_day']): void {
  const inSlot = blocks.filter((b) => b.time_of_day === slot);
  const ordered = [...inSlot].sort((a, b) => {
    if (a.start_time && b.start_time) return a.start_time.localeCompare(b.start_time);
    if (a.start_time) return -1;
    if (b.start_time) return 1;
    return 0;
  });

  let i = 0;
  for (let j = 0; j < blocks.length; j++) {
    if (blocks[j]!.time_of_day === slot) blocks[j] = ordered[i++]!;
  }
}

/**
 * Move one activity within its own slot.
 *
 * Across slots is not the user's to set — the slot decides that — so a drag
 * can only ever rearrange siblings. `toIndex` counts within the slot, not
 * within the day, so the client never has to reason about the day's whole
 * array.
 */
export function reorderBlock(tripId: string, blockId: string, toIndex: number): Plan {
  const record = loadPlan(tripId);
  const plan = record.plan;
  ensureBlockIds(plan);

  const found = allBlocks(plan).find((b) => b.block.id === blockId);
  if (!found) throw notFound('block_not_found', `No activity with id ${blockId}`);

  const day = plan.itinerary.find((d) => d.day === found.day);
  if (!day) throw notFound('block_not_found', `No activity with id ${blockId}`);

  const slot = found.block.time_of_day;
  const siblings = day.blocks.filter((b) => b.time_of_day === slot);
  const from = siblings.findIndex((b) => b.id === blockId);
  if (from < 0) throw notFound('block_not_found', `No activity with id ${blockId}`);

  const target = Math.max(0, Math.min(toIndex, siblings.length - 1));
  if (target === from) return plan;

  const [moved] = siblings.splice(from, 1);
  siblings.splice(target, 0, moved!);

  // Write the reordered siblings back into the positions the slot already
  // occupies, so activities in other slots do not shift underneath.
  let i = 0;
  for (let j = 0; j < day.blocks.length; j++) {
    if (day.blocks[j]!.time_of_day === slot) day.blocks[j] = siblings[i++]!;
  }

  return persist(record, plan);
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
