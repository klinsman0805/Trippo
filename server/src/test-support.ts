import assert from 'node:assert/strict';
import { env } from './config/env.js';

/**
 * Several tests depend on the model being unreachable.
 *
 * They drive the import and plan routes for what happens *around* the model —
 * the source row, the ownership check, the rate-limit counter — and expect each
 * call to fail fast without one. With a key configured the extractor really
 * runs, invents places nobody asked for, and the assertions that count records
 * drift by however many it found. The failure looks like a broken ownership
 * check and isn't one.
 *
 * `npm test` blanks GEMINI_API_KEY to arrange this. `.env` is still loaded —
 * `loadEnvFile` leaves a variable that is already set alone, including an empty
 * one — so running the files any other way picks the real key back up. Hence
 * this check: a clear message beats an off-by-a-place-count.
 */
export function requireNoModelKey(): void {
  assert.ok(
    !env.GEMINI_API_KEY,
    'These tests need the model unreachable. Run them with `npm test`, which sets GEMINI_API_KEY= for the run.',
  );
}
