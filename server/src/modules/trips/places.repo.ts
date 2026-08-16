import { db, newId, nowIso, toJson } from '../../db/index.js';
import { notFound } from '../../lib/errors.js';
import type { Place } from '../../schemas/trip.js';
import { rowToPlace } from './repo.js';

export interface PlaceInput {
  name: string;
  category?: string | null;
  city?: string | null;
  country?: string | null;
  address?: string | null;
  lat?: number | null;
  lng?: number | null;
  google_place_id?: string | null;
  why?: string | null;
  tags?: string[];
  source_id?: string | null;
  resolved?: boolean;
}

const insert = db.prepare(`
  INSERT INTO places (id, trip_id, source_id, name, category, city, country, address,
    lat, lng, google_place_id, why, tags, resolved, created_at)
  VALUES (@id, @trip_id, @source_id, @name, @category, @city, @country, @address,
    @lat, @lng, @google_place_id, @why, @tags, @resolved, @created_at)
`);

export function addPlace(tripId: string, input: PlaceInput): Place {
  const id = newId('plc');
  insert.run({
    id,
    trip_id: tripId,
    source_id: input.source_id ?? null,
    name: input.name,
    category: input.category ?? null,
    city: input.city ?? null,
    country: input.country ?? null,
    address: input.address ?? null,
    lat: input.lat ?? null,
    lng: input.lng ?? null,
    google_place_id: input.google_place_id ?? null,
    why: input.why ?? null,
    tags: toJson(input.tags ?? []),
    resolved: input.resolved ? 1 : 0,
    created_at: nowIso(),
  });
  return getPlace(id);
}

/**
 * Insert many places, skipping ones that duplicate an existing name in the same
 * city. Importing several 小红书 posts about the same city otherwise produces
 * the same restaurant five times.
 */
export function addPlaces(tripId: string, inputs: PlaceInput[]): Place[] {
  const existing = new Set(
    (db.prepare('SELECT name, city FROM places WHERE trip_id = ?').all(tripId) as {
      name: string;
      city: string | null;
    }[]).map((r) => dedupeKey(r.name, r.city)),
  );

  const created: Place[] = [];
  const tx = db.transaction(() => {
    for (const input of inputs) {
      const key = dedupeKey(input.name, input.city ?? null);
      if (existing.has(key)) continue;
      existing.add(key);
      created.push(addPlace(tripId, input));
    }
  });
  tx();
  return created;
}

const dedupeKey = (name: string, city: string | null) =>
  `${name.trim().toLowerCase()}|${(city ?? '').trim().toLowerCase()}`;

export function getPlace(id: string): Place {
  const row = db.prepare('SELECT * FROM places WHERE id = ?').get(id);
  if (!row) throw notFound('place_not_found', `No place with id ${id}`);
  return rowToPlace(row as Record<string, unknown>);
}

export function listPlaces(tripId: string): Place[] {
  const rows = db
    .prepare('SELECT * FROM places WHERE trip_id = ? ORDER BY created_at')
    .all(tripId) as Record<string, unknown>[];
  return rows.map(rowToPlace);
}

export function deletePlace(id: string): void {
  const res = db.prepare('DELETE FROM places WHERE id = ?').run(id);
  if (res.changes === 0) throw notFound('place_not_found', `No place with id ${id}`);
}

/** Attach geocoding results once a place has been resolved against Places API. */
export function markResolved(
  id: string,
  data: { lat: number; lng: number; address: string | null; google_place_id: string; city?: string | null },
): Place {
  db.prepare(
    `UPDATE places SET lat = @lat, lng = @lng, address = @address,
       google_place_id = @google_place_id, city = COALESCE(@city, city), resolved = 1
     WHERE id = @id`,
  ).run({
    id,
    lat: data.lat,
    lng: data.lng,
    address: data.address,
    google_place_id: data.google_place_id,
    city: data.city ?? null,
  });
  return getPlace(id);
}
