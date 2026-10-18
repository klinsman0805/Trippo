import { db, newId, nowIso, toJson, type Queryable } from '../../db/index.js';
import { notFound } from '../../lib/errors.js';
import type { HoursSource, Place } from '../../schemas/trip.js';
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
  /** Serialised `OpeningHours`; see the `hours` column. */
  hours?: string | null;
  hours_source?: HoursSource | null;
  source_id?: string | null;
  resolved?: boolean;
}

const INSERT = `
  INSERT INTO places (id, trip_id, source_id, name, category, city, country, address,
    lat, lng, google_place_id, why, tags, hours, hours_source, resolved, created_at)
  VALUES (@id, @trip_id, @source_id, @name, @category, @city, @country, @address,
    @lat, @lng, @google_place_id, @why, @tags, @hours, @hours_source, @resolved, @created_at)
`;

export async function addPlace(tripId: string, input: PlaceInput, q: Queryable = db): Promise<Place> {
  const id = newId('plc');
  await q.run(INSERT, {
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
    hours: input.hours ?? null,
    hours_source: input.hours ? input.hours_source ?? 'source' : null,
    resolved: input.resolved ? 1 : 0,
    created_at: nowIso(),
  });
  return await getPlace(id, q);
}

/**
 * Insert many places, skipping ones that duplicate an existing name in the same
 * city. Importing several 小红书 posts about the same city otherwise produces
 * the same restaurant five times.
 */
export async function addPlaces(tripId: string, inputs: PlaceInput[]): Promise<Place[]> {
  return db.tx(async (q) => {
    const existing = new Set(
      (
        await q.query<{ name: string; city: string | null }>(
          'SELECT name, city FROM places WHERE trip_id = ?',
          [tripId],
        )
      ).map((r) => dedupeKey(r.name, r.city)),
    );

    const created: Place[] = [];
    for (const input of inputs) {
      const key = dedupeKey(input.name, input.city ?? null);
      if (existing.has(key)) continue;
      existing.add(key);
      created.push(await addPlace(tripId, input, q));
    }
    return created;
  });
}

const dedupeKey = (name: string, city: string | null) =>
  `${name.trim().toLowerCase()}|${(city ?? '').trim().toLowerCase()}`;

export async function getPlace(id: string, q: Queryable = db): Promise<Place> {
  const row = await q.one('SELECT * FROM places WHERE id = ?', [id]);
  if (!row) throw notFound('place_not_found', `No place with id ${id}`);
  return rowToPlace(row);
}

export async function listPlaces(tripId: string): Promise<Place[]> {
  const rows = await db.query('SELECT * FROM places WHERE trip_id = ? ORDER BY created_at', [tripId]);
  return rows.map(rowToPlace);
}

export async function deletePlace(tripId: string, id: string): Promise<void> {
  const changes = await db.run('DELETE FROM places WHERE id = ? AND trip_id = ?', [id, tripId]);
  if (changes === 0) throw notFound('place_not_found', `No place with id ${id}`);
}

/**
 * Attach geocoding results once a place has been resolved against Places API.
 *
 * Hours are taken only when the provider gave some, and they replace a post's:
 * the provider is answering about the business, while the post is one
 * visitor's note from whenever they wrote it. A provider that knows no hours
 * leaves whatever the post said alone rather than clearing it — COALESCE
 * rather than an overwrite — because silence is not a correction.
 */
export async function markResolved(
  id: string,
  data: {
    lat: number;
    lng: number;
    address: string | null;
    google_place_id: string;
    city?: string | null;
    hours?: string | null;
  },
): Promise<Place> {
  await db.run(
    `UPDATE places SET lat = @lat, lng = @lng, address = @address,
       google_place_id = @google_place_id, city = COALESCE(@city, city),
       hours = COALESCE(@hours, hours),
       hours_source = CASE WHEN @hours IS NULL THEN hours_source ELSE 'places' END,
       resolved = 1
     WHERE id = @id`,
    {
      id,
      lat: data.lat,
      lng: data.lng,
      address: data.address,
      google_place_id: data.google_place_id,
      city: data.city ?? null,
      hours: data.hours ?? null,
    },
  );
  return await getPlace(id);
}
