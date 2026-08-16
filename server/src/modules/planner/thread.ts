import type { Plan, PlanDay } from '../../schemas/plan.js';
import { listPlans, type PlanRecord } from './service.js';

export interface ChatMessage {
  role: 'user' | 'bot';
  text: string;
  /** The plan revision this message belongs to. */
  revision: number;
  created_at: string;
}

/**
 * The Refine tab's conversation, derived from stored plan revisions rather than
 * kept in a separate messages table.
 *
 * Every revision already holds both halves of an exchange: `user_request` is
 * what the group asked for, `summary` is what the planner said back. Deriving
 * the thread keeps a single source of truth — a message can't drift out of sync
 * with the plan it produced, and deleting a revision can't orphan a bubble.
 */
export function chatThread(tripId: string): ChatMessage[] {
  const revisions = listPlans(tripId).slice().reverse(); // oldest first
  const messages: ChatMessage[] = [];

  for (const rev of revisions) {
    // The first plan has no request behind it — it's the opening statement.
    if (rev.user_request) {
      messages.push({
        role: 'user',
        text: rev.user_request,
        revision: rev.revision,
        created_at: rev.created_at,
      });
    }
    messages.push({
      role: 'bot',
      text: rev.summary,
      revision: rev.revision,
      created_at: rev.created_at,
    });
  }

  return messages;
}

/**
 * Which day the latest refinement actually changed.
 *
 * Drives the "Updated from your last chat request." notice on the Trip tab.
 * Returns null for the first revision, or when a refinement changed nothing in
 * the itinerary (a budget question, say, which only alters the prose).
 */
export function updatedDay(tripId: string): number | null {
  const revisions = listPlans(tripId); // newest first
  const [latest, previous] = revisions;
  if (!latest || !previous) return null;

  const before = new Map(previous.plan.itinerary.map((d) => [d.day, d]));

  for (const day of latest.plan.itinerary) {
    const prior = before.get(day.day);
    if (!prior) return day.day; // a day that didn't exist before
    if (dayFingerprint(day) !== dayFingerprint(prior)) return day.day;
  }
  return null;
}

/**
 * A day's comparable content. Deliberately ignores fields that can be reworded
 * without the plan meaningfully changing (descriptions, notes) so that a
 * regenerated-but-equivalent day doesn't light up as "updated".
 */
function dayFingerprint(day: PlanDay): string {
  return day.blocks
    .map((b) =>
      [
        b.time_of_day,
        b.activity,
        b.optional ? 'opt' : 'req',
        b.estimated_cost_per_person ?? '',
        [...b.suited_for_members].sort().join(','),
      ].join('|'),
    )
    .join('||');
}

/** Blocks whose day changed, for clients that want to highlight them. */
export function changedBlockActivities(latest: Plan, previous: Plan, day: number): string[] {
  const now = latest.itinerary.find((d) => d.day === day);
  const before = previous.itinerary.find((d) => d.day === day);
  if (!now) return [];
  if (!before) return now.blocks.map((b) => b.activity);

  const priorActivities = new Set(before.blocks.map((b) => b.activity));
  return now.blocks.map((b) => b.activity).filter((a) => !priorActivities.has(a));
}

export type { PlanRecord };
