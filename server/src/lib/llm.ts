import { GoogleGenAI } from '@google/genai';
import { env } from '../config/env.js';
import { unavailable, UpstreamError } from './errors.js';

/**
 * The one place the app talks to a language model.
 *
 * Kept as a narrow seam — every caller asks for "JSON matching this schema" and
 * nothing else — so swapping providers is a single-file change. Currently
 * Google Gemini via `@google/genai`.
 */

let client: GoogleGenAI | null = null;

function gemini(): GoogleGenAI {
  if (!env.GEMINI_API_KEY) {
    throw unavailable(
      'planner_unavailable',
      'GEMINI_API_KEY is not configured, so AI features are disabled.',
    );
  }
  client ??= new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
  return client;
}

/**
 * How hard the model should think. Gemini exposes discrete levels rather than a
 * token budget, so the app's own notion of effort maps onto those.
 */
export type Effort = 'minimal' | 'low' | 'medium' | 'high';

export interface StructuredCallOptions {
  system: string;
  userContent: string;
  /** JSON Schema the response must conform to. */
  schema: Record<string, unknown>;
  maxOutputTokens?: number;
  effort?: Effort;
  /** Overrides the configured model — used to run cheap tasks on a small one. */
  model?: string;
}

/**
 * One structured-output call, returning the raw parsed JSON.
 *
 * `response_format` constrains the model to the schema, so the response is
 * valid JSON by construction. Callers still validate with Zod, because a schema
 * guarantees shape, not sense.
 */
export async function structuredCall(opts: StructuredCallOptions): Promise<unknown> {
  const {
    system,
    userContent,
    schema,
    maxOutputTokens = 32_000,
    effort = 'high',
    model = env.PLANNER_MODEL,
  } = opts;

  // Resolved before the try so a missing key stays a 503 "not configured"
  // rather than being re-wrapped as a 502 upstream failure.
  const ai = gemini();

  let response;
  const startedAt = Date.now();
  try {
    response = await ai.interactions.create(
      {
        model,
        system_instruction: system,
        input: userContent,
        response_format: {
          type: 'text',
          mime_type: 'application/json',
          schema,
        },
        generation_config: {
          thinking_level: effort,
          max_output_tokens: maxOutputTokens,
        },
      },
      // Without this the call has no ceiling. A slow run held the socket open
      // for as long as the provider felt like taking, the app sat on its
      // generating screen with nothing to show, and there was no failure
      // recorded anywhere to explain it.
      { timeout: env.PLANNER_TIMEOUT_MS, maxRetries: 0 },
    );
  } catch (err) {
    const elapsed = Math.round((Date.now() - startedAt) / 1000);
    const message = err instanceof Error ? err.message : '';
    // A timeout is a different problem from a rejected key or an exhausted
    // quota, and the fix is different too, so it says which one happened.
    if (elapsed * 1000 >= env.PLANNER_TIMEOUT_MS * 0.9) {
      throw new UpstreamError(
        'gemini',
        `The model did not answer within ${Math.round(
          env.PLANNER_TIMEOUT_MS / 1000,
        )}s (gave up after ${elapsed}s). It is running slowly right now — trying again often works, and a shorter trip asks less of it.`,
      );
    }
    // Otherwise surface the provider's own message — quota and key errors are
    // the common failures here and the text is the actionable part.
    throw new UpstreamError('gemini', message || 'The model request failed.');
  }

  const text = response.output_text?.trim();
  if (!text) {
    throw new UpstreamError(
      'gemini',
      'The model returned no content. This usually means the response hit the token limit or was blocked by a safety filter.',
    );
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new UpstreamError(
      'gemini',
      `Model returned unparseable JSON: ${text.slice(0, 300)}`,
    );
  }
}
