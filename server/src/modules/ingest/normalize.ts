import { z } from 'zod';
import { env } from '../../config/env.js';
import { structuredCall } from '../../lib/llm.js';
import type { ExtractedContent } from './types.js';

/**
 * Turn scraped page text into structured place candidates.
 *
 * This is an extraction task, not a planning task — the model must only report
 * what the source actually says. Inventing plausible-sounding restaurants would
 * poison the candidate pool the planner later draws from, so the prompt is
 * explicit that an empty result is the correct answer for a source with no
 * concrete places in it.
 */
const SYSTEM = `You extract structured travel places from the text of a single web page, social post, or article.

Rules:
- Only extract places that the source text actually mentions. Never add well-known places the source did not name.
- A "place" is somewhere a traveller would deliberately go: a restaurant, cafe, bar, attraction, museum, park, viewpoint, market, notable neighbourhood, shop, hotel, or a specific activity at a specific location.
- The test is "would a visitor plan their day around this?", not "is this a location?". Skip civic and residential infrastructure a place merely contains — schools, hospitals, clinics, government offices, housing blocks, car parks, industrial sites, places of worship that are not visitor attractions. Encyclopedic sources list these; they are not destinations.
- Skip how people get around: bus terminals, coach operators, transit stations, taxi ranks, car hire. These are logistics, not destinations. The exception is transport that is itself worth seeing or doing — a heritage railway station admired for its architecture, a funicular, a scenic ferry — which is a "sight" or "activity" and must carry a reason in "why" that says why it is worth the visit.
- Do not extract whole countries, or cities as places in their own right — record those on each place's "city" and "country" fields instead.
- If the source names a dish, product, or brand rather than a venue, skip it.
- Reference sources (encyclopedia articles, directories) describe places without recommending them. Extract only what a visitor would actually go to, and set "why" to what the source says makes it worth the visit — if it says nothing of the kind, use null rather than paraphrasing a definition.
- "why" must paraphrase what this specific source said about the place — the reason it was recommended, a tip, a warning, a signature dish. If the source gives no reason, use null.
- Set "city" from context when the source makes it unambiguous; otherwise null. Do not guess.
- Preserve the original-language name in "name_original" when the source names a place in a non-English script, and give a romanised or English name in "name" if the source provides one, otherwise repeat the original.
- If the page contains no concrete places, return an empty array. An empty result is correct and useful; a fabricated one is not.

Also summarise the source in one or two sentences for the user's reference, and list any dates, seasons, or durations the source mentions that would affect trip planning.`;

/**
 * Note the absence of `transport`.
 *
 * Offering it invited exactly what the rules forbid: a real Wikivoyage import
 * filed a bus terminal, a coach operator and an intercity bus station as
 * places to visit. A prompt saying "skip bus depots" cannot outweigh a schema
 * saying "here is where to put them". Transport worth going to for its own
 * sake — a heritage station, a funicular — is a `sight` or an `activity`, and
 * has to earn its place on that basis.
 */
const CATEGORIES = [
  'food',
  'sight',
  'activity',
  'lodging',
  'shopping',
  'nightlife',
  'other',
] as const;

export const ExtractionSchema = z.object({
  summary: z.string(),
  planning_notes: z.array(z.string()),
  places: z.array(
    z.object({
      name: z.string(),
      name_original: z.string().nullable(),
      category: z.enum(CATEGORIES),
      city: z.string().nullable(),
      country: z.string().nullable(),
      area: z.string().nullable(),
      why: z.string().nullable(),
      tags: z.array(z.string()),
    }),
  ),
});
export type Extraction = z.infer<typeof ExtractionSchema>;

const EXTRACTION_JSON_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'planning_notes', 'places'],
  properties: {
    summary: { type: 'string', description: 'One or two sentences describing this source.' },
    planning_notes: {
      type: 'array',
      items: { type: 'string' },
      description:
        'Dates, seasons, opening-time warnings, booking requirements or durations the source mentions.',
    },
    places: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: [
          'name',
          'name_original',
          'category',
          'city',
          'country',
          'area',
          'why',
          'tags',
        ],
        properties: {
          name: { type: 'string' },
          name_original: {
            type: ['string', 'null'],
            description: 'The name in its original script, when different from `name`.',
          },
          category: { type: 'string', enum: CATEGORIES },
          city: { type: ['string', 'null'] },
          country: { type: ['string', 'null'] },
          area: {
            type: ['string', 'null'],
            description: 'Neighbourhood or district, when the source names one.',
          },
          why: { type: ['string', 'null'] },
          tags: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
};

/**
 * Cap on the text sent to the model.
 *
 * Raised from 24k after a real import: a 54k-character city guide was cut at
 * 24k, and everything a traveller most wants — the Eat and Drink sections —
 * sits near the *end* of a guide like that. It returned one restaurant for a
 * city famous for its food.
 */
const MAX_CHARS = 100_000;

/**
 * Characters kept from the head and tail when a page is still too long.
 *
 * Front-loading alone is wrong for travel writing, which buries the practical
 * sections at the bottom. Keeping both ends loses the middle, which is usually
 * history and background, rather than losing every restaurant.
 */
const HEAD_CHARS = 70_000;
const TAIL_CHARS = 30_000;

/** Trim to [MAX_CHARS], keeping both ends rather than only the beginning. */
export function clampForExtraction(text: string): string {
  if (text.length <= MAX_CHARS) return text;
  return [
    text.slice(0, HEAD_CHARS),
    '\n\n[…middle of the page omitted…]\n\n',
    text.slice(-TAIL_CHARS),
  ].join('');
}

export async function extractPlaces(content: ExtractedContent): Promise<Extraction> {
  const header = [
    `Source type: ${content.kind}`,
    content.title ? `Title: ${content.title}` : null,
    content.author ? `Author: ${content.author}` : null,
    content.locationHints.length
      ? `Location hints from the page: ${content.locationHints.join('; ')}`
      : null,
  ]
    .filter(Boolean)
    .join('\n');

  const body = clampForExtraction(content.text);

  const raw = await structuredCall({
    system: SYSTEM,
    userContent: `${header}\n\n---\n\n${body}`,
    schema: EXTRACTION_JSON_SCHEMA,
    maxOutputTokens: 16_000,
    // Extraction is mechanical, so it runs shallow on the cheaper model.
    effort: 'low',
    model: env.EXTRACTION_MODEL,
  });

  return ExtractionSchema.parse(raw);
}
