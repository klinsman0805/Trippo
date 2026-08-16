import { env } from '../../config/env.js';
import { TtlCache } from '../../lib/cache.js';
import { fetchWithRetry, jsonOrThrow } from '../../lib/http.js';
import type {
  GeoProvider,
  LatLng,
  ResolvedPlace,
  RouteRequest,
  RouteResult,
  TransitProvider,
  TransitStep,
} from './types.js';

/**
 * OpenStreetMap stack: Photon for geocoding, MOTIS/Transitous for transit.
 *
 * Both are free and need no credentials. Neither offers an SLA, so every call
 * degrades to a usable answer rather than throwing — a trip planner that breaks
 * because a community geocoder is down is worse than one that says "couldn't
 * find that".
 *
 * OSM data is ODbL: the client must display [OSM_ATTRIBUTION].
 */

export const OSM_ATTRIBUTION = {
  text: '© OpenStreetMap contributors',
  url: 'https://www.openstreetmap.org/copyright',
} as const;

/**
 * Both services require an identifying User-Agent and reject generic ones —
 * Transitous answers a default UA with a 403 naming its usage policy. Sending
 * something that identifies this app is the price of the free tier, and the
 * polite thing regardless.
 */
const USER_AGENT = 'Trippo/0.1 (group trip planner; +https://github.com/trippo)';

const searchCache = new TtlCache<ResolvedPlace[]>(15 * 60_000);
const routeCache = new TtlCache<RouteResult | null>(10 * 60_000);

// --- geocoding ---

export class PhotonGeoProvider implements GeoProvider {
  readonly name = 'photon';
  /** Public instance needs no key; a self-hosted URL can be set instead. */
  readonly configured = true;

  async search(
    query: string,
    opts: { bias?: LatLng; limit?: number; language?: string } = {},
  ): Promise<ResolvedPlace[]> {
    const { bias, limit = 5, language = 'en' } = opts;
    const key = `photon:${query}:${language}:${bias?.lat ?? ''},${bias?.lng ?? ''}`;

    return searchCache.wrap(key, async () => {
      const params = new URLSearchParams({
        q: query,
        limit: String(limit),
        lang: language,
      });
      // Biasing by the trip's city is what makes "that ramen place" resolvable.
      if (bias) {
        params.set('lat', String(bias.lat));
        params.set('lon', String(bias.lng));
      }

      const res = await fetchWithRetry(`${env.PHOTON_URL}/api/?${params}`, {
        provider: 'photon',
        retries: 1,
        headers: { 'User-Agent': USER_AGENT },
      });

      const body = await jsonOrThrow<PhotonResponse>(res, 'photon');
      return (body.features ?? []).map(toResolvedPlace);
    });
  }
}

interface PhotonResponse {
  features?: {
    geometry?: { coordinates?: [number, number] };
    properties?: Record<string, unknown>;
  }[];
}

function toResolvedPlace(feature: {
  geometry?: { coordinates?: [number, number] };
  properties?: Record<string, unknown>;
}): ResolvedPlace {
  const p = feature.properties ?? {};
  const [lon, lat] = feature.geometry?.coordinates ?? [0, 0];

  const str = (v: unknown): string | null =>
    typeof v === 'string' && v.trim() ? v.trim() : null;

  // Photon splits the address across fields; the UI wants one line.
  const address = [
    [str(p.housenumber), str(p.street)].filter(Boolean).join(' ') || null,
    str(p.district),
    str(p.city) ?? str(p.county),
    str(p.postcode),
    str(p.country),
  ]
    .filter(Boolean)
    .join(', ');

  const osmType = str(p.osm_type);
  const osmId = p.osm_id != null ? String(p.osm_id) : null;

  return {
    place_id: osmType && osmId ? `photon:${osmType}${osmId}` : `photon:${lat},${lon}`,
    name: str(p.name) ?? str(p.street) ?? str(p.city) ?? '(unnamed)',
    address: address || null,
    lat: lat ?? 0,
    lng: lon ?? 0,
    city: str(p.city) ?? str(p.county) ?? null,
    country: str(p.country),
    types: [str(p.osm_key), str(p.osm_value)].filter((v): v is string => Boolean(v)),
    // OSM has no ratings, and inventing one would be worse than showing none.
    rating: null,
    maps_uri:
      osmType && osmId
        ? `https://www.openstreetmap.org/${expandOsmType(osmType)}/${osmId}`
        : null,
  };
}

const expandOsmType = (t: string): string =>
  ({ N: 'node', W: 'way', R: 'relation' })[t] ?? 'node';

// --- transit ---

export class TransitousProvider implements TransitProvider {
  readonly name = 'transitous';
  readonly configured = true;

  async route(req: RouteRequest): Promise<RouteResult | null> {
    const key = `motis:${req.mode}:${fmt(req.origin)}->${fmt(req.destination)}:${req.departure_time ?? ''}`;

    return routeCache.wrap(key, async () => {
      // MOTIS only does transit and its own street legs. Anything else falls
      // back to a straight-line estimate rather than a wrong answer.
      if (req.mode !== 'TRANSIT') return estimateRoute(req);

      const params = new URLSearchParams({
        fromPlace: `${req.origin.lat},${req.origin.lng}`,
        toPlace: `${req.destination.lat},${req.destination.lng}`,
        time: req.departure_time ?? nextReasonableDeparture(),
      });

      let body: MotisPlan;
      try {
        const res = await fetchWithRetry(`${env.MOTIS_URL}/api/v1/plan?${params}`, {
          provider: 'transitous',
          retries: 1,
          timeoutMs: 12_000,
          headers: { 'User-Agent': USER_AGENT },
        });
        body = await jsonOrThrow<MotisPlan>(res, 'transitous');
      } catch (err) {
        // A community instance with no SLA will occasionally be slow or down,
        // and a straight-line estimate beats an error screen. But a 4xx is a
        // bug or a policy violation on our side and would otherwise masquerade
        // as permanent "degradation", so it is surfaced rather than swallowed.
        const message = err instanceof Error ? err.message : String(err);
        if (/HTTP 4\d\d/.test(message)) throw err;
        console.warn(`[transitous] falling back to estimate: ${message}`);
        return estimateRoute(req);
      }

      const best = (body.itineraries ?? [])[0];
      if (!best) return null;

      return {
        mode: 'TRANSIT',
        duration_minutes: Math.round((best.duration ?? 0) / 60),
        distance_meters: null,
        transfers: best.transfers ?? 0,
        steps: (best.legs ?? []).map(toStep),
        is_estimate: false,
        directions_url: directionsUrl(req),
      };
    });
  }
}

interface MotisPlan {
  itineraries?: {
    duration?: number;
    transfers?: number;
    legs?: MotisLeg[];
  }[];
}

interface MotisLeg {
  mode?: string;
  duration?: number;
  from?: { name?: string };
  to?: { name?: string };
  routeShortName?: string;
  routeLongName?: string;
}

function toStep(leg: MotisLeg): TransitStep {
  const line = leg.routeShortName ?? leg.routeLongName ?? null;
  const from = leg.from?.name ?? null;
  const to = leg.to?.name ?? null;
  const mode = (leg.mode ?? 'UNKNOWN').toUpperCase();

  const instruction =
    mode === 'WALK'
      ? `Walk${to ? ` to ${to}` : ''}`
      : `${titleCase(mode)}${line ? ` ${line}` : ''}${from ? ` from ${from}` : ''}${to ? ` to ${to}` : ''}`;

  return {
    mode,
    instruction,
    duration_minutes: Math.round((leg.duration ?? 0) / 60),
    transit_line: line,
    departure_stop: from,
    arrival_stop: to,
  };
}

const titleCase = (s: string) => s.charAt(0) + s.slice(1).toLowerCase();

/**
 * Straight-line fallback, clearly flagged.
 *
 * Used for walking/driving/cycling and whenever the transit router is
 * unreachable. The 1.35 factor approximates real street distance against the
 * crow-flies line.
 */
function estimateRoute(req: RouteRequest): RouteResult {
  const metres = haversineMetres(req.origin, req.destination) * 1.35;
  const speedKmh = { WALK: 4.8, BICYCLE: 15, DRIVE: 28, TRANSIT: 20 }[req.mode] ?? 4.8;

  return {
    mode: req.mode,
    duration_minutes: Math.max(Math.round(metres / 1000 / speedKmh * 60), 1),
    distance_meters: Math.round(metres),
    transfers: null,
    steps: [],
    is_estimate: true,
    directions_url: directionsUrl(req),
  };
}

/**
 * A link to a real maps app.
 *
 * Live departures, disruptions and the traveller's actual location all belong
 * to their maps app, not to a route we computed at planning time.
 */
function directionsUrl(req: RouteRequest): string {
  const mode = { TRANSIT: 'transit', WALK: 'walking', DRIVE: 'driving', BICYCLE: 'bicycling' }[
    req.mode
  ];
  return (
    `https://www.google.com/maps/dir/?api=1` +
    `&origin=${req.origin.lat},${req.origin.lng}` +
    `&destination=${req.destination.lat},${req.destination.lng}` +
    `&travelmode=${mode}`
  );
}

function nextReasonableDeparture(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  d.setUTCHours(10, 0, 0, 0);
  return d.toISOString();
}

const fmt = (p: LatLng) => `${p.lat.toFixed(5)},${p.lng.toFixed(5)}`;

// --- proximity ---

const EARTH_RADIUS_M = 6_371_000;

/** Great-circle distance in metres. */
export function haversineMetres(a: LatLng, b: LatLng): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

/**
 * Two places can share a day when they're within this far apart.
 *
 * Grouping a day only needs "near or not near" — the difference between a 19
 * and a 23 minute ride never changes the answer, which is why this needs no
 * routing API at all.
 */
export const SAME_DAY_RADIUS_M = 5_000;

/** Rough walking minutes for a straight-line distance. */
export const walkMinutes = (metres: number): number =>
  Math.max(Math.round((metres * 1.35) / 1000 / 4.8 * 60), 1);
