import { db, fromJson, nowIso, toJson } from '../../db/index.js';
import type { LatLng, RouteResult } from '../geo/index.js';
import type { TravelStore } from './legs.js';

/**
 * How long a routed leg is trusted for.
 *
 * Timetables change on the scale of months, and the leg is keyed by weekday
 * and hour, so two weeks keeps a trip opened daily off the router entirely
 * without serving a timetable change for long.
 */
const LEG_TTL_MS = 14 * 24 * 60 * 60_000;

/** Geocodes barely move. A month absorbs every reopen of a trip. */
const GEO_TTL_MS = 30 * 24 * 60 * 60_000;

const fresh = (createdAt: unknown, ttl: number) =>
  typeof createdAt === 'string' && Date.now() - Date.parse(createdAt) < ttl;

export const travelStore: TravelStore = {
  async getGeo(query) {
    const row = await db.one<{ found: number; lat: number | null; lng: number | null; created_at: string }>(
      'SELECT found, lat, lng, created_at FROM geo_lookups WHERE query = ?',
      [query],
    );
    if (!row || !fresh(row.created_at, GEO_TTL_MS)) return undefined;
    return row.found && row.lat != null && row.lng != null ? { lat: row.lat, lng: row.lng } : null;
  },

  async putGeo(query, at: LatLng | null) {
    await db.run(
      `INSERT INTO geo_lookups (query, found, lat, lng, created_at)
       VALUES (@query, @found, @lat, @lng, @created_at)
       ON CONFLICT(query) DO UPDATE SET
         found = excluded.found, lat = excluded.lat, lng = excluded.lng,
         created_at = excluded.created_at`,
      {
        query,
        found: at ? 1 : 0,
        lat: at?.lat ?? null,
        lng: at?.lng ?? null,
        created_at: nowIso(),
      },
    );
  },

  async getLeg(key) {
    const row = await db.one<{ result: string | null; created_at: string }>(
      'SELECT result, created_at FROM travel_legs WHERE key = ?',
      [key],
    );
    if (!row || !fresh(row.created_at, LEG_TTL_MS)) return undefined;
    return fromJson<RouteResult | null>(row.result, null);
  },

  async putLeg(key, result: RouteResult | null) {
    await db.run(
      `INSERT INTO travel_legs (key, result, created_at) VALUES (@key, @result, @created_at)
       ON CONFLICT(key) DO UPDATE SET result = excluded.result, created_at = excluded.created_at`,
      { key, result: result ? toJson(result) : null, created_at: nowIso() },
    );
  },
};
