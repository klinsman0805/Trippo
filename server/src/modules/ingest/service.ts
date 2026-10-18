import { db, newId, nowIso } from '../../db/index.js';
import { badRequest, notFound } from '../../lib/errors.js';
import type { Place } from '../../schemas/trip.js';
import { addPlaces, type PlaceInput } from '../trips/places.repo.js';
import { getTrip, touchTrip } from '../trips/repo.js';
import { genericExtractor } from './extractors/generic.js';
import { tripadvisorExtractor } from './extractors/tripadvisor.js';
import {
  extractUrlFromShareText,
  xiaohongshuExtractor,
} from './extractors/xiaohongshu.js';
import { extractPlaces } from './normalize.js';
import {
  NeedsManualInputError,
  type ExtractedContent,
  type Extractor,
  type SourceKind,
  type SourceRecord,
  type SourceStatus,
} from './types.js';

/** Order matters — the generic extractor matches everything, so it goes last. */
const EXTRACTORS: Extractor[] = [
  xiaohongshuExtractor,
  tripadvisorExtractor,
  genericExtractor,
];

export function resolveExtractor(url: URL): Extractor {
  const found = EXTRACTORS.find((e) => e.matches(url));
  // The generic extractor's matches() always returns true, so this is total.
  return found ?? genericExtractor;
}

export interface ImportResult {
  source: SourceRecord;
  summary: string | null;
  planning_notes: string[];
  places: Place[];
  /** Set when the source could not be fetched and the user must paste text. */
  manual_input_required: boolean;
  message: string | null;
}

/**
 * Import a link: fetch → extract → structure → persist candidate places.
 *
 * A blocked fetch is not an error the caller has to handle specially — the
 * source is stored with `needs_manual` status and the result says so, which
 * lets the client show a paste box against that same source row.
 */
export async function importUrl(tripId: string, rawInput: string): Promise<ImportResult> {
  await getTrip(tripId);

  // Users paste share text ("…打开【小红书】App查看… http://xhslink.com/x"),
  // not bare URLs. Pull the first URL out of whatever arrived.
  const urlText = extractUrlFromShareText(rawInput) ?? rawInput.trim();

  let url: URL;
  try {
    url = new URL(urlText);
  } catch {
    throw badRequest('invalid_url', `Could not find a valid URL in: ${rawInput.slice(0, 120)}`);
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw badRequest('invalid_url', 'Only http and https URLs can be imported.');
  }

  const extractor = resolveExtractor(url);
  const sourceId = await createSource(tripId, {
    url: url.toString(),
    kind: extractor.kind,
    status: 'pending',
  });

  let content: ExtractedContent;
  try {
    content = await extractor.extract(url);
  } catch (err) {
    if (err instanceof NeedsManualInputError) {
      await updateSource(sourceId, { status: 'needs_manual', error: err.message });
      return {
        source: await getSource(sourceId),
        summary: null,
        planning_notes: [],
        places: [],
        manual_input_required: true,
        message: err.message,
      };
    }
    const message = err instanceof Error ? err.message : 'Unknown extraction failure';
    await updateSource(sourceId, { status: 'failed', error: message });
    throw err;
  }

  await updateSource(sourceId, {
    status: 'fetched',
    title: content.title,
    author: content.author,
    raw_text: content.text,
  });

  return finishImport(tripId, sourceId, content);
}

/**
 * Import from text the user pasted themselves — the fallback path for 小红书
 * and any other source that refuses server-side reads.
 */
export async function importManualText(
  tripId: string,
  text: string,
  opts: { kind?: SourceKind; title?: string; sourceId?: string } = {},
): Promise<ImportResult> {
  await getTrip(tripId);

  if (text.trim().length < 20) {
    throw badRequest('text_too_short', 'Paste at least a sentence or two of the source text.');
  }

  const content: ExtractedContent = {
    kind: opts.kind ?? 'manual',
    title: opts.title ?? null,
    author: null,
    text: text.trim(),
    images: [],
    locationHints: [],
  };

  // Reuse the existing row when this is completing a `needs_manual` import, so
  // the user doesn't end up with two source entries for one link.
  const sourceId =
    opts.sourceId ??
    await createSource(tripId, { url: null, kind: content.kind, status: 'fetched' });

  // 404s for a bogus id — and for a real one on someone else's trip, which
  // would otherwise have this text written into their import.
  if (opts.sourceId && (await getSource(opts.sourceId)).trip_id !== tripId) {
    throw notFound('source_not_found', `No source with id ${opts.sourceId}`);
  }

  await updateSource(sourceId, {
    status: 'fetched',
    title: content.title,
    raw_text: content.text,
    error: null,
  });

  return finishImport(tripId, sourceId, content);
}

async function finishImport(
  tripId: string,
  sourceId: string,
  content: ExtractedContent,
): Promise<ImportResult> {
  let extraction;
  try {
    extraction = await extractPlaces(content);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Extraction failed';
    await updateSource(sourceId, { status: 'failed', error: message });
    throw err;
  }

  const inputs: PlaceInput[] = extraction.places.map((p) => ({
    name: p.name,
    category: p.category,
    city: p.city,
    country: p.country,
    why: p.why,
    tags: [...p.tags, ...(p.area ? [p.area] : [])],
    hours: p.hours?.length ? JSON.stringify(p.hours) : null,
    hours_source: 'source' as const,
    source_id: sourceId,
    resolved: false,
  }));

  const places = await addPlaces(tripId, inputs);
  await updateSource(sourceId, { status: 'extracted', error: null });
  await touchTrip(tripId);

  return {
    source: await getSource(sourceId),
    summary: extraction.summary,
    planning_notes: extraction.planning_notes,
    places,
    manual_input_required: false,
    message:
      places.length === 0
        ? 'No new places were found in this source. It may be a listing page, or the places may already be saved.'
        : null,
  };
}

// --- source persistence ---

async function createSource(
  tripId: string,
  data: { url: string | null; kind: SourceKind; status: SourceStatus },
): Promise<string> {
  const id = newId('src');
  const ts = nowIso();
  await db.run(
    `INSERT INTO sources (id, trip_id, url, kind, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [id, tripId, data.url, data.kind, data.status, ts, ts],
  );
  return id;
}

async function updateSource(
  id: string,
  patch: Partial<Pick<SourceRecord, 'status' | 'title' | 'author' | 'raw_text' | 'error'>>,
): Promise<void> {
  const sets: string[] = [];
  const params: Record<string, unknown> = { id, updated_at: nowIso() };
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined) continue;
    sets.push(`${key} = @${key}`);
    params[key] = value;
  }
  if (!sets.length) return;
  await db.run(`UPDATE sources SET ${sets.join(', ')}, updated_at = @updated_at WHERE id = @id`, params);
}

export async function getSource(id: string): Promise<SourceRecord> {
  const row = await db.one<SourceRecord>('SELECT * FROM sources WHERE id = ?', [id]);
  if (!row) throw notFound('source_not_found', `No source with id ${id}`);
  return row;
}

/**
 * Every source on the trip, newest first, each with how many places came out
 * of it — the one number that says whether an import was worth anything, and
 * the reason the list is worth showing at all.
 */
export async function listSources(tripId: string): Promise<(SourceRecord & { place_count: number })[]> {
  return db.query<SourceRecord & { place_count: number }>(
    `SELECT s.*, (SELECT COUNT(*)::int FROM places p WHERE p.source_id = s.id) AS place_count
       FROM sources s
      WHERE s.trip_id = ?
      ORDER BY s.created_at DESC`,
    [tripId],
  );
}

export async function deleteSource(tripId: string, id: string): Promise<void> {
  const changes = await db.run('DELETE FROM sources WHERE id = ? AND trip_id = ?', [id, tripId]);
  if (changes === 0) throw notFound('source_not_found', `No source with id ${id}`);
}
