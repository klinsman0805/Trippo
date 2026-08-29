import { z } from 'zod';

/**
 * What the planner is actually asked to produce.
 *
 * The full [PlanSchema] is the app's contract, not the model's job. Most of it
 * is either something we already know — the trip's title, dates, currency,
 * member profiles, all of which we sent in the prompt — or arithmetic over the
 * rest. Asking a model to echo those back costs output tokens, which are the
 * slow and rate-limited half of a call, and gives it a chance to contradict
 * data we hold.
 *
 * So the model returns a draft: the decisions only it can make. A block is a
 * citation plus a slot — which saved place goes on which day, in what order,
 * within the flight envelope — and everything the card shows about that place
 * comes from the place record we already stored. `hydrate` turns a draft into
 * a Plan, and nothing downstream can tell the difference.
 */

export const DraftBlockSchema = z.object({
  /**
   * The tag of a saved place, e.g. `p3`, or null for somewhere the planner
   * chose itself. When set, the name, venue and reason all come from the
   * stored place rather than from the model.
   */
  place: z.string().nullable().default(null),
  /** Required when `place` is null; otherwise a short label, or empty. */
  activity: z.string().default(''),
  /** Only consulted when `place` is null — a saved place has its own. */
  location: z.string().nullable().default(null),
  time_of_day: z.enum(['morning', 'afternoon', 'evening']),
  start_time: z
    .string()
    .regex(/^\d{2}:\d{2}$/)
    .nullable()
    .default(null),
  optional: z.boolean().default(false),
  estimated_cost_per_person: z.number().nullable().default(null),
  /** One short line, when there is something worth saying that the place record does not already say. */
  note: z.string().nullable().default(null),
});

export const DraftDaySchema = z.object({
  day: z.number(),
  lodging_area_suggestion: z.string().nullable().default(null),
  notes: z.string().nullable().default(null),
  blocks: z.array(DraftBlockSchema),
});

const CategoryEstimateSchema = z.object({
  planned: z.number(),
  estimated: z.number(),
});

export const DraftSchema = z.object({
  conversational_summary: z.string(),
  status: z.enum(['complete', 'needs_info', 'infeasible']),
  missing_info: z.array(z.string()).default([]),
  assumptions: z.array(z.string()).default([]),
  budget_breakdown: z.object({
    lodging: CategoryEstimateSchema,
    transport: CategoryEstimateSchema,
    food: CategoryEstimateSchema,
    activities: CategoryEstimateSchema,
    buffer: CategoryEstimateSchema,
  }),
  conflicts: z
    .array(
      z.object({
        tag: z.enum(['Pace', 'Mobility', 'Food', 'Budget', 'Interests']),
        description: z.string(),
        members_involved: z.array(z.string()).default([]),
        resolution: z.string(),
      }),
    )
    .default([]),
  itinerary: z.array(DraftDaySchema),
  packing_and_prep_notes: z.array(z.string()).default([]),
  verify_before_booking: z.array(z.string()).default([]),
  clarifying_questions: z
    .array(
      z.object({
        id: z.string(),
        question: z.string(),
        why: z.string(),
        answer_type: z.enum(['choice', 'text']),
        options: z.array(z.string()).default([]),
        placeholder: z.string().nullable().default(null),
      }),
    )
    .default([]),
});

export type PlanDraft = z.infer<typeof DraftSchema>;
export type DraftBlock = z.infer<typeof DraftBlockSchema>;

const str = { type: 'string' } as const;
const num = { type: 'number' } as const;
const bool = { type: 'boolean' } as const;
const strArray = { type: 'array', items: str } as const;
const nullableStr = { type: ['string', 'null'] } as const;
const nullableNum = { type: ['number', 'null'] } as const;

const obj = <P extends Record<string, unknown>>(properties: P) => ({
  type: 'object' as const,
  properties,
  required: Object.keys(properties),
  additionalProperties: false as const,
});

const categoryBudget = (label: string) =>
  obj({
    planned: { ...num, description: `What the group intended to spend on ${label}.` },
    estimated: { ...num, description: `What this itinerary actually costs for ${label}.` },
  });

export const PLAN_DRAFT_JSON_SCHEMA = obj({
  conversational_summary: {
    ...str,
    description:
      'PART A. First person, plainly, as someone reporting what they did: what you planned and why, assumptions you made, conflicts you resolved, any budget problem. Two or three short paragraphs. Lead with what you decided, not a greeting. No promotional adjectives, no exclamation marks. Do not restate the itinerary day by day.',
  },
  status: { type: 'string', enum: ['complete', 'needs_info', 'infeasible'] },
  missing_info: { ...strArray, description: 'Only non-empty when status is needs_info.' },
  assumptions: {
    ...strArray,
    description:
      'Every fact you decided for yourself rather than being told. One short entry each, naming what you chose: "Four days, since no length was given". Empty if you assumed nothing.',
  },
  budget_breakdown: obj({
    lodging: categoryBudget('lodging'),
    transport: categoryBudget('transport'),
    food: categoryBudget('food'),
    activities: categoryBudget('activities'),
    buffer: categoryBudget('contingency'),
  }),
  conflicts: {
    type: 'array',
    items: obj({
      tag: {
        type: 'string',
        enum: ['Pace', 'Mobility', 'Food', 'Budget', 'Interests'],
      },
      description: str,
      members_involved: { ...strArray, description: 'Member ids.' },
      resolution: str,
    }),
  },
  itinerary: {
    type: 'array',
    items: obj({
      day: { ...num, description: 'Day number, starting at 1.' },
      lodging_area_suggestion: nullableStr,
      notes: nullableStr,
      blocks: {
        type: 'array',
        items: obj({
          place: {
            ...nullableStr,
            description:
              'The tag of a SAVED PLACE, exactly as written in square brackets in that list, e.g. "p3". Prefer these: they are what the traveller saved. Null only for somewhere you chose yourself.',
          },
          activity: {
            ...str,
            description:
              'What they are doing. Required when place is null. When place is set, leave empty unless a short label adds something the place name does not — the name, venue and reason all come from the saved place.',
          },
          location: {
            ...nullableStr,
            description: 'Venue or neighbourhood. Only used when place is null.',
          },
          time_of_day: { type: 'string', enum: ['morning', 'afternoon', 'evening'] },
          start_time: { ...nullableStr, description: 'HH:MM, 24-hour, or null.' },
          optional: bool,
          estimated_cost_per_person: {
            ...nullableNum,
            description: 'Null when you do not know — do not guess a number to fill the field.',
          },
          note: {
            ...nullableStr,
            description:
              'One short line, only when there is something worth saying that the saved place does not already say. Usually null.',
          },
        }),
      },
    }),
  },
  packing_and_prep_notes: strArray,
  verify_before_booking: {
    ...strArray,
    description: 'Time-sensitive things the user must verify before booking.',
  },
  clarifying_questions: {
    type: 'array',
    items: obj({
      id: { ...str, description: 'Short stable slug, e.g. "separate_arrivals".' },
      question: str,
      why: { ...str, description: 'What changes depending on the answer.' },
      answer_type: { type: 'string', enum: ['choice', 'text'] },
      options: strArray,
      placeholder: nullableStr,
    }),
  },
});
