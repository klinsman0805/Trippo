import { db, newId, nowIso } from '../../db/index.js';
import { env } from '../../config/env.js';
import { structuredCall } from '../../lib/llm.js';
import { notFound, unprocessable } from '../../lib/errors.js';
import { PLAN_JSON_SCHEMA, PlanSchema, type Plan } from '../../schemas/plan.js';
import { listSelections } from '../flights/index.js';
import { listPlaces } from '../trips/places.repo.js';
import { getTrip, touchTrip } from '../trips/repo.js';
import { buildPlannerContext } from './context.js';
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

  const record = savePlan(tripId, plan, userRequest);
  clearFailure(tripId);
  return record;
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

function savePlan(tripId: string, plan: Plan, userRequest: string | null): PlanRecord {
  const revision = (getLatestPlan(tripId)?.revision ?? 0) + 1;
  const id = newId('plan');

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
