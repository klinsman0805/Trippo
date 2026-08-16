import { Readability } from '@mozilla/readability';
import type { ExtractedContent, Extractor } from '../types.js';
import { NeedsManualInputError } from '../types.js';
import {
  fetchHtml,
  normalizeText,
  parseDom,
  readJsonScripts,
  readMetaTags,
} from './html.js';

/**
 * TripAdvisor.
 *
 * TripAdvisor ships rich schema.org LD+JSON on attraction, restaurant and hotel
 * pages — name, address, geo coordinates, rating. That is far better structured
 * than anything we could scrape from the DOM, so it is the primary path. List
 * pages ("Top 10 things to do in…") have no such markup, so those fall back to
 * Readability over the article body.
 *
 * TripAdvisor also fronts pages with a bot check under load; that surfaces as
 * `needs_manual` like any other blocked source.
 */
export const tripadvisorExtractor: Extractor = {
  kind: 'tripadvisor',

  matches: (url) => /(^|\.)tripadvisor\.[a-z.]+$/.test(url.hostname),

  async extract(url: URL): Promise<ExtractedContent> {
    const { html, finalUrl, status } = await fetchHtml(url);

    if (status === 403 || /captcha|are you a human|unusual traffic/i.test(html.slice(0, 4000))) {
      throw new NeedsManualInputError(
        'tripadvisor',
        'TripAdvisor served a bot check. Paste the page text instead.',
      );
    }

    const doc = parseDom(html, finalUrl);
    const meta = readMetaTags(doc);
    const entities = collectEntities(readJsonScripts(doc));

    let body = '';
    try {
      body = normalizeText(new Readability(doc).parse()?.textContent ?? '');
    } catch {
      body = '';
    }

    const structured = entities
      .map((e) => {
        const parts = [
          `Name: ${e.name}`,
          e.type ? `Type: ${e.type}` : null,
          e.address ? `Address: ${e.address}` : null,
          e.rating ? `Rating: ${e.rating}` : null,
          e.description ? `Description: ${e.description}` : null,
          e.lat != null && e.lng != null ? `Coordinates: ${e.lat},${e.lng}` : null,
        ].filter(Boolean);
        return parts.join('\n');
      })
      .join('\n\n');

    const text = normalizeText(
      [structured, body.length > 200 ? body : meta.description ?? ''].filter(Boolean).join('\n\n'),
    );

    if (text.length < 40) {
      throw new NeedsManualInputError(
        'tripadvisor',
        'Could not read this TripAdvisor page. Paste the text instead.',
      );
    }

    return {
      kind: 'tripadvisor',
      title: meta.title,
      author: 'TripAdvisor',
      text,
      images: meta.images,
      locationHints: entities.map((e) => e.address).filter((a): a is string => Boolean(a)),
    };
  },
};

interface Entity {
  name: string;
  type: string | null;
  address: string | null;
  rating: string | null;
  description: string | null;
  lat: number | null;
  lng: number | null;
}

const PLACE_TYPES = [
  'Restaurant',
  'Hotel',
  'LodgingBusiness',
  'TouristAttraction',
  'LocalBusiness',
  'Place',
  'Museum',
  'Park',
];

/** Walk LD+JSON (including @graph and arrays) for anything place-shaped. */
function collectEntities(blobs: unknown[]): Entity[] {
  const out: Entity[] = [];
  const seen = new Set<string>();

  const visit = (node: unknown, depth = 0): void => {
    if (depth > 6 || node === null || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      for (const item of node) visit(item, depth + 1);
      return;
    }

    const rec = node as Record<string, unknown>;
    const types = ([] as string[]).concat(
      (rec['@type'] as string | string[] | undefined) ?? [],
    );

    if (types.some((t) => PLACE_TYPES.includes(t)) && typeof rec.name === 'string') {
      const name = rec.name.trim();
      if (name && !seen.has(name)) {
        seen.add(name);
        out.push({
          name,
          type: types[0] ?? null,
          address: formatAddress(rec.address),
          rating: readRating(rec.aggregateRating),
          description: typeof rec.description === 'string' ? rec.description.trim() : null,
          lat: readGeo(rec.geo, 'latitude'),
          lng: readGeo(rec.geo, 'longitude'),
        });
      }
    }

    for (const value of Object.values(rec)) visit(value, depth + 1);
  };

  for (const blob of blobs) visit(blob);
  return out;
}

function formatAddress(address: unknown): string | null {
  if (typeof address === 'string') return address.trim() || null;
  if (typeof address !== 'object' || address === null) return null;
  const a = address as Record<string, unknown>;
  const parts = [
    a.streetAddress,
    a.addressLocality,
    a.addressRegion,
    a.postalCode,
    a.addressCountry,
  ].filter((v): v is string => typeof v === 'string' && v.trim().length > 0);
  return parts.length ? parts.join(', ') : null;
}

function readRating(node: unknown): string | null {
  if (typeof node !== 'object' || node === null) return null;
  const r = node as Record<string, unknown>;
  const value = r.ratingValue;
  const count = r.reviewCount ?? r.ratingCount;
  if (value == null) return null;
  return count != null ? `${value} (${count} reviews)` : String(value);
}

function readGeo(node: unknown, key: 'latitude' | 'longitude'): number | null {
  if (typeof node !== 'object' || node === null) return null;
  const value = (node as Record<string, unknown>)[key];
  const num = typeof value === 'string' ? Number(value) : value;
  return typeof num === 'number' && Number.isFinite(num) ? num : null;
}
