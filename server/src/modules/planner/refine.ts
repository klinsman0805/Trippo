import { badRequest } from '../../lib/errors.js';
import { importUrl, type ImportResult } from '../ingest/service.js';
import { listPlaces } from '../trips/places.repo.js';
import { getTrip } from '../trips/repo.js';
import { generatePlan, getLatestPlan, type PlanRecord } from './service.js';

/**
 * A Refine-tab turn.
 *
 * The composer is a plain text box, so a turn can be three different things:
 * a pasted link, a pasted article, or an instruction. Detecting which one
 * keeps the design's single input honest — the user never has to know which
 * mode they're in.
 */
export interface RefineResult {
  plan: PlanRecord | null;
  /** Present when the turn contained a link we imported. */
  import: ImportResult | null;
  /** What the assistant says back, when no plan was generated. */
  reply: string | null;
  /** True when the source was blocked and we need the user to paste the text. */
  awaiting_paste: boolean;
  pending_source_id: string | null;
}

const URL_PATTERN = /https?:\/\/[^\s，,。、]+/i;

export function findUrl(text: string): string | null {
  return URL_PATTERN.exec(text)?.[0] ?? null;
}

/**
 * Handle one Refine turn.
 *
 * Importing does not immediately regenerate the plan. Pasting three links in a
 * row would otherwise trigger three full planning runs, each superseded by the
 * next — minutes of latency and cost for two throwaway revisions. Instead the
 * import reports what it found and offers to work it in, which is also the more
 * honest conversational move.
 */
export async function refine(
  tripId: string,
  message: string,
  opts: { pendingSourceId?: string | null } = {},
): Promise<RefineResult> {
  const trip = getTrip(tripId);
  const text = message.trim();
  if (!text) throw badRequest('empty_message', 'Say something to refine the plan.');

  // A pasted body of text completing a previously blocked import.
  if (opts.pendingSourceId) {
    const { importManualText } = await import('../ingest/service.js');
    const result = await importManualText(tripId, text, {
      sourceId: opts.pendingSourceId,
    });
    return {
      plan: null,
      import: result,
      reply: describeImport(result),
      awaiting_paste: false,
      pending_source_id: null,
    };
  }

  const url = findUrl(text);
  if (url) {
    const result = await importUrl(tripId, text);

    if (result.manual_input_required) {
      return {
        plan: null,
        import: result,
        reply:
          `${result.message ?? 'That site blocked the import.'} ` +
          'Open the post, copy its text, and paste it here — I\'ll read it from that.',
        awaiting_paste: true,
        pending_source_id: result.source.id,
      };
    }

    return {
      plan: null,
      import: result,
      reply: describeImport(result),
      awaiting_paste: false,
      pending_source_id: null,
    };
  }

  // Not a link — a planning instruction. Mention unused imports so places the
  // group saved don't quietly sit there never making it into a plan.
  const request = withUnusedPlacesNote(tripId, text);
  const plan = await generatePlan(tripId, request);

  return {
    plan,
    import: null,
    reply: null,
    awaiting_paste: false,
    pending_source_id: null,
  };
}

function describeImport(result: ImportResult): string {
  const places = result.places;
  if (places.length === 0) {
    return (
      result.message ??
      'I read that, but found no specific places in it. If there are spots you want, name them and I\'ll add them.'
    );
  }

  // Group by city so the reply reads like a person summarising, not a dump.
  const byCity = new Map<string, number>();
  for (const p of places) {
    const key = p.city ?? 'unspecified';
    byCity.set(key, (byCity.get(key) ?? 0) + 1);
  }

  const where = [...byCity.entries()]
    .filter(([city]) => city !== 'unspecified')
    .map(([city, n]) => `${n} in ${city}`)
    .join(', ');

  const noun = places.length === 1 ? 'place' : 'places';
  const lead = `Found ${places.length} ${noun} in that${where ? ` — ${where}` : ''}.`;
  const names = places.slice(0, 4).map((p) => p.name).join(', ');
  const more = places.length > 4 ? `, and ${places.length - 4} more` : '';

  return `${lead} ${names}${more}. Want me to work them into the plan?`;
}

/**
 * Append a note listing saved places the current plan hasn't used, so a
 * "work them in" reply actually has something concrete to act on.
 */
function withUnusedPlacesNote(tripId: string, request: string): string {
  const latest = getLatestPlan(tripId);
  const places = listPlaces(tripId);
  if (places.length === 0) return request;

  const used = new Set<string>();
  if (latest) {
    for (const day of latest.plan.itinerary) {
      for (const block of day.blocks) {
        used.add(block.activity.toLowerCase());
        used.add(block.location.toLowerCase());
      }
    }
  }

  const unused = places.filter(
    (p) => ![...used].some((u) => u.includes(p.name.toLowerCase())),
  );
  if (unused.length === 0) return request;

  const list = unused
    .slice(0, 25)
    .map((p) => `- ${p.name}${p.city ? ` (${p.city})` : ''}${p.why ? ` — ${p.why}` : ''}`)
    .join('\n');

  return `${request}\n\nSaved places not yet in the plan:\n${list}`;
}
