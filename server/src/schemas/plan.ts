import { z } from 'zod';

/**
 * The Part B contract from the Trip Planner spec.
 *
 * One deliberate addition: `conversational_summary` carries Part A (the prose
 * the user reads). The spec has the model emit prose *outside* a fenced JSON
 * block, which means parsing it back out of free text. Folding it into the
 * schema lets us constrain the whole response with structured outputs, so a
 * malformed response becomes near-impossible rather than a retry path. The
 * two-part contract is preserved — Part A is `conversational_summary`, Part B
 * is everything else.
 */

export const PaceSchema = z.enum(['packed', 'moderate', 'relaxed']);
export const TimeOfDaySchema = z.enum(['morning', 'afternoon', 'evening']);
export const PlanStatusSchema = z.enum(['complete', 'needs_info', 'infeasible']);

/**
 * Per-category budget. The Budget tab renders two stacked bars per category —
 * what was planned against what the itinerary actually estimates — so each
 * category carries both numbers rather than a single figure.
 */
export const CategoryBudgetSchema = z.object({
  planned: z.number(),
  estimated: z.number(),
});

export const BudgetBreakdownSchema = z.object({
  lodging: CategoryBudgetSchema,
  transport: CategoryBudgetSchema,
  food: CategoryBudgetSchema,
  activities: CategoryBudgetSchema,
  buffer: CategoryBudgetSchema,
});

export const TripSummarySchema = z.object({
  title: z.string(),
  destinations: z.array(z.string()),
  start_date: z.string().nullable(),
  end_date: z.string().nullable(),
  duration_days: z.number(),
  currency: z.string(),
  total_budget: z.number().nullable(),
  budget_breakdown: BudgetBreakdownSchema,
  estimated_total_cost: z.number(),
  over_budget: z.boolean(),
  assumptions: z.array(z.string()),
});

export const PlanMemberSchema = z.object({
  id: z.string(),
  name: z.string(),
  interests: z.array(z.string()),
  pace: PaceSchema,
  dietary_restrictions: z.array(z.string()),
  accessibility_needs: z.array(z.string()),
  deal_breakers: z.array(z.string()),
});

/** Categories the Group tab renders as a pill on each conflict card. */
export const ConflictTagSchema = z.enum([
  'Pace',
  'Mobility',
  'Food',
  'Budget',
  'Interests',
]);

export const ConflictSchema = z.object({
  tag: ConflictTagSchema,
  description: z.string(),
  members_involved: z.array(z.string()),
  resolution: z.string(),
});

export const BlockSchema = z.object({
  time_of_day: TimeOfDaySchema,
  activity: z.string(),
  description: z.string(),
  location: z.string(),
  estimated_duration_minutes: z.number(),
  estimated_cost_per_person: z.number().nullable(),
  suited_for_members: z.array(z.string()),
  optional: z.boolean(),
  weather_backup: z.string().nullable(),
});

export const DaySchema = z.object({
  day: z.number(),
  date: z.string().nullable(),
  location: z.string(),
  lodging_area_suggestion: z.string().nullable(),
  blocks: z.array(BlockSchema),
  notes: z.string().nullable(),
});

/**
 * A question the planner needs answered, shaped for the design's question
 * cards: the ask, the decision it unblocks, and how to answer it.
 */
export const ClarifyingQuestionSchema = z.object({
  id: z.string(),
  question: z.string(),
  /** What changes depending on the answer — rendered under the question. */
  why: z.string(),
  answer_type: z.enum(['choice', 'text']),
  /** Populated for 'choice'; empty for 'text'. */
  options: z.array(z.string()),
  /** Hint text for 'text' questions; null for 'choice'. */
  placeholder: z.string().nullable(),
});

export const PlanSchema = z.object({
  conversational_summary: z.string(),
  status: PlanStatusSchema,
  missing_info: z.array(z.string()),
  trip: TripSummarySchema,
  members: z.array(PlanMemberSchema),
  conflicts: z.array(ConflictSchema),
  itinerary: z.array(DaySchema),
  packing_and_prep_notes: z.array(z.string()),
  verify_before_booking: z.array(z.string()),
  clarifying_questions: z.array(ClarifyingQuestionSchema),
});

export type Plan = z.infer<typeof PlanSchema>;
export type PlanDay = z.infer<typeof DaySchema>;
export type PlanBlock = z.infer<typeof BlockSchema>;

/**
 * JSON Schema handed to the Messages API as `output_config.format`.
 *
 * Structured outputs require `additionalProperties: false` and an explicit
 * `required` list on every object. Nullable fields are expressed as a type
 * union rather than an optional key, so the model must always emit the key.
 */
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
    estimated: {
      ...num,
      description: `What this itinerary actually costs for ${label}.`,
    },
  });

export const PLAN_JSON_SCHEMA = obj({
  conversational_summary: {
    ...str,
    description:
      'PART A. Written in the first person, plainly, as someone reporting what they did: what you planned and why, assumptions you made, conflicts you resolved and how, and any budget problem. Two or three short paragraphs. Lead with what you decided, not a greeting. No promotional adjectives, no exclamation marks. Do not restate the itinerary day by day — the structured fields carry it.',
  },
  status: { type: 'string', enum: ['complete', 'needs_info', 'infeasible'] },
  missing_info: {
    ...strArray,
    description: 'Only non-empty when status is needs_info.',
  },
  trip: obj({
    title: str,
    destinations: strArray,
    start_date: { ...nullableStr, description: 'YYYY-MM-DD, or null if flexible' },
    end_date: nullableStr,
    duration_days: num,
    currency: str,
    total_budget: nullableNum,
    budget_breakdown: obj({
      lodging: categoryBudget('lodging'),
      transport: categoryBudget('transport'),
      food: categoryBudget('food'),
      activities: categoryBudget('activities'),
      buffer: categoryBudget('contingency'),
    }),
    estimated_total_cost: num,
    over_budget: bool,
    assumptions: {
      ...strArray,
      description:
        'Every fact you decided for yourself rather than being told — dates, budget, trip length, region, anything. One short entry each, naming what you chose: "Four days, since no length was given". Saying it in the summary does not cover this: the summary is prose the app cannot act on, and this array is what lets the group see and correct each guess. If you assumed nothing, leave it empty.',
    },
  }),
  members: {
    type: 'array',
    items: obj({
      id: str,
      name: str,
      interests: strArray,
      pace: { type: 'string', enum: ['packed', 'moderate', 'relaxed'] },
      dietary_restrictions: strArray,
      accessibility_needs: strArray,
      deal_breakers: strArray,
    }),
  },
  conflicts: {
    type: 'array',
    items: obj({
      tag: {
        type: 'string',
        enum: ['Pace', 'Mobility', 'Food', 'Budget', 'Interests'],
        description: 'The single category this conflict is mostly about.',
      },
      description: str,
      members_involved: strArray,
      resolution: str,
    }),
  },
  itinerary: {
    type: 'array',
    items: obj({
      day: num,
      date: nullableStr,
      location: str,
      lodging_area_suggestion: nullableStr,
      blocks: {
        type: 'array',
        items: obj({
          time_of_day: { type: 'string', enum: ['morning', 'afternoon', 'evening'] },
          activity: str,
          description: str,
          location: str,
          estimated_duration_minutes: num,
          estimated_cost_per_person: nullableNum,
          suited_for_members: {
            ...strArray,
            description: 'Member ids from the members array.',
          },
          optional: bool,
          weather_backup: nullableStr,
        }),
      },
      notes: nullableStr,
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
      why: {
        ...str,
        description:
          'One sentence naming the planning decision this answer unblocks.',
      },
      answer_type: { type: 'string', enum: ['choice', 'text'] },
      options: {
        ...strArray,
        description: 'Choices when answer_type is "choice"; empty otherwise.',
      },
      placeholder: {
        ...nullableStr,
        description: 'Hint for "text" questions; null for "choice".',
      },
    }),
  },
});
