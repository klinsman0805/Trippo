import { db, nowIso } from '../../db/index.js';
import { AppError } from '../../lib/errors.js';

/**
 * The last planning attempt that produced nothing.
 *
 * The design's failed state promises two things: an honest account of what
 * stopped, and reassurance that nothing was lost. Both have to come from real
 * records rather than from copy — which is why this stores what actually
 * survived (the last good revision) alongside why the attempt ended.
 *
 * A planning run is atomic: a revision is written or it is not. So there is no
 * such thing as "days 1 and 2 were planned" in this system, and the state is
 * worded against revisions instead. See `plan_failed.dart` for the client half.
 */
export interface PlanFailure {
  trip_id: string;
  /** Machine-readable, for the client to branch on. */
  reason_code: string;
  /** One plain sentence naming what went wrong. Shown as-is. */
  reason: string;
  /** The provider's own message, kept for support rather than for display. */
  detail: string | null;
  elapsed_ms: number;
  /** Revision still on the trip, or null when nothing was ever planned. */
  last_good_revision: number | null;
  /** Days in that revision, so the client can say what is still there. */
  last_good_days: number | null;
  /** The refinement being attempted, when the failure came from one. */
  user_request: string | null;
  /** ISO timestamp — the `STOPPED AT 14:32` eyebrow. */
  at: string;
}

export function recordFailure(
  tripId: string,
  err: unknown,
  opts: {
    elapsedMs: number;
    lastGoodRevision: number | null;
    userRequest: string | null;
  },
): void {
  const code = err instanceof AppError ? err.code : 'unknown';
  const detail = err instanceof Error ? err.message : String(err);

  db.prepare(
    `INSERT INTO plan_failures
       (trip_id, reason_code, detail, elapsed_ms, last_good_revision, user_request, created_at)
     VALUES (@trip_id, @reason_code, @detail, @elapsed_ms, @last_good_revision, @user_request, @created_at)
     ON CONFLICT(trip_id) DO UPDATE SET
       reason_code = excluded.reason_code,
       detail = excluded.detail,
       elapsed_ms = excluded.elapsed_ms,
       last_good_revision = excluded.last_good_revision,
       user_request = excluded.user_request,
       created_at = excluded.created_at`,
  ).run({
    trip_id: tripId,
    reason_code: code,
    detail,
    elapsed_ms: Math.round(opts.elapsedMs),
    last_good_revision: opts.lastGoodRevision,
    user_request: opts.userRequest,
    created_at: nowIso(),
  });
}

/** Called after a revision lands — the failure is no longer the current state. */
export function clearFailure(tripId: string): void {
  db.prepare('DELETE FROM plan_failures WHERE trip_id = ?').run(tripId);
}

export function getFailure(tripId: string): PlanFailure | null {
  const row = db.prepare('SELECT * FROM plan_failures WHERE trip_id = ?').get(tripId) as
    | Record<string, unknown>
    | undefined;
  if (!row) return null;

  const revision = (row.last_good_revision as number) ?? null;
  const elapsed = Number(row.elapsed_ms ?? 0);

  return {
    trip_id: row.trip_id as string,
    reason_code: row.reason_code as string,
    reason: describeReason(row.reason_code as string, (row.detail as string) ?? '', elapsed),
    detail: (row.detail as string) ?? null,
    elapsed_ms: elapsed,
    last_good_revision: revision,
    last_good_days: revision === null ? null : daysInRevision(tripId, revision),
    user_request: (row.user_request as string) ?? null,
    at: row.created_at as string,
  };
}

/**
 * The failure in the same plain register as the rest of the product.
 *
 * The design's example — `Timed out at 4m 00s` — sets the bar: name the thing
 * that happened and, where it helps, the number that goes with it. No error
 * codes, no apologies, no advice; the actions below it carry the advice.
 */
function describeReason(code: string, detail: string, elapsedMs: number): string {
  const lower = detail.toLowerCase();

  if (code === 'planner_unavailable') {
    return 'The planner is not configured on this server';
  }
  if (code === 'plan_validation_failed' || code === 'plan_unknown_member_ids') {
    return 'The planner returned something unusable, twice';
  }
  if (/quota|rate.?limit|429|resource.?exhausted/.test(lower)) {
    return "This project's model quota is used up for now";
  }
  if (/api.?key|permission|unauthenticated|401|403/.test(lower)) {
    return 'The model rejected the API key';
  }
  if (/timeout|timed out|etimedout|abort/.test(lower)) {
    return `Timed out at ${formatElapsed(elapsedMs)}`;
  }
  if (/econnrefused|enotfound|network|fetch failed|socket/.test(lower)) {
    return 'The connection to the model dropped';
  }

  // An instant failure is a refusal, not a stall. Saying "stopped responding
  // after 0s" about a request that came back in 300ms is both wrong and
  // useless — it points at the network when the problem is the request.
  if (elapsedMs < INSTANT_FAILURE_MS) {
    return code === 'upstream_error'
      ? 'The model rejected the request'
      : 'The request was rejected before planning started';
  }

  if (code === 'upstream_error') {
    return `The model stopped responding after ${formatElapsed(elapsedMs)}`;
  }
  return `Stopped after ${formatElapsed(elapsedMs)}`;
}

/**
 * Under this, nothing was attempted — the call was refused at the door. Set
 * well above a fast round trip and well below any real planning run, which
 * takes tens of seconds at minimum.
 */
const INSTANT_FAILURE_MS = 5_000;

/** `4m 00s`, matching the design. Under a minute stays in seconds. */
export function formatElapsed(ms: number): string {
  const totalSeconds = Math.round(ms / 1000);
  if (totalSeconds < 60) return `${totalSeconds}s`;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}m ${String(seconds).padStart(2, '0')}s`;
}

function daysInRevision(tripId: string, revision: number): number | null {
  const row = db
    .prepare('SELECT plan FROM plans WHERE trip_id = ? AND revision = ?')
    .get(tripId, revision) as { plan?: string } | undefined;
  if (!row?.plan) return null;
  try {
    const parsed = JSON.parse(row.plan) as { itinerary?: unknown[] };
    return Array.isArray(parsed.itinerary) ? parsed.itinerary.length : null;
  } catch {
    return null;
  }
}
