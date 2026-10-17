import { env } from '../../config/env.js';
import { db, newId, nowIso } from '../../db/index.js';
import { notFound, unavailable } from '../../lib/errors.js';
import { AeroDataBoxProvider } from './aerodatabox.js';
import { AmadeusProvider } from './amadeus.js';
import { MockFlightProvider } from './mock.js';
import type { FlightOffer, FlightProvider, ScheduleProvider } from './types.js';

let provider: FlightProvider | null = null;

export function flightProvider(): FlightProvider {
  if (provider) return provider;

  if (env.FLIGHT_PROVIDER === 'amadeus') {
    const amadeus = new AmadeusProvider();
    if (!amadeus.configured) {
      throw unavailable(
        'flights_unavailable',
        'FLIGHT_PROVIDER is "amadeus" but AMADEUS_CLIENT_ID/SECRET are not set. Set them, or switch FLIGHT_PROVIDER to "mock".',
      );
    }
    provider = amadeus;
  } else {
    provider = new MockFlightProvider();
  }

  return provider;
}

let schedules: ScheduleProvider | null = null;

/**
 * Who answers "what does this flight number do on this date".
 *
 * Configured apart from the fare provider, because the two are different
 * products from different vendors — see `ScheduleProvider`.
 */
export function scheduleProvider(): ScheduleProvider {
  if (schedules) return schedules;

  if (env.SCHEDULE_PROVIDER === 'aerodatabox') {
    const adb = new AeroDataBoxProvider();
    if (!adb.configured) {
      throw unavailable(
        'schedules_unavailable',
        'SCHEDULE_PROVIDER is "aerodatabox" but AERODATABOX_API_KEY is not set. Set it, or switch SCHEDULE_PROVIDER to "mock".',
      );
    }
    schedules = adb;
  } else if (env.SCHEDULE_PROVIDER === 'amadeus') {
    const amadeus = new AmadeusProvider();
    if (!amadeus.configured) {
      throw unavailable(
        'schedules_unavailable',
        'SCHEDULE_PROVIDER is "amadeus" but AMADEUS_CLIENT_ID/SECRET are not set.',
      );
    }
    schedules = amadeus;
  } else {
    schedules = new MockFlightProvider();
  }

  return schedules;
}

// --- selected flights, which anchor the trip's dates ---

export interface StoredSelection {
  id: string;
  trip_id: string;
  member_id: string | null;
  direction: 'outbound' | 'return';
  offer: FlightOffer;
  created_at: string;
}

/**
 * Store a chosen flight, replacing any previous choice for the same direction
 * and traveller.
 *
 * Replacing rather than appending matters: the trip's date envelope is derived
 * from the stored selections, and an appended second outbound would leave the
 * first one deciding the dates. Changing your mind about a flight has to
 * actually change the trip.
 */
export async function saveSelection(
  tripId: string,
  direction: 'outbound' | 'return',
  offer: FlightOffer,
  memberId?: string | null,
): Promise<StoredSelection> {
  const id = newId('fls');

  await db.tx(async (q) => {
    // IS NOT DISTINCT FROM: equal, counting two nulls as equal — a trip-wide
    // selection has no member, and must still replace the last trip-wide one.
    await q.run(
      `DELETE FROM flight_selections
       WHERE trip_id = ? AND direction = ? AND member_id IS NOT DISTINCT FROM ?`,
      [tripId, direction, memberId ?? null],
    );

    await q.run(
      `INSERT INTO flight_selections (id, trip_id, member_id, direction, offer, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [id, tripId, memberId ?? null, direction, JSON.stringify(offer), nowIso()],
    );
  });

  return await getSelection(id);
}

export async function getSelection(id: string): Promise<StoredSelection> {
  const row = await db.one('SELECT * FROM flight_selections WHERE id = ?', [id]);
  if (!row) throw notFound('selection_not_found', `No flight selection with id ${id}`);
  return rowToSelection(row);
}

export async function listSelections(tripId: string): Promise<StoredSelection[]> {
  const rows = await db.query('SELECT * FROM flight_selections WHERE trip_id = ? ORDER BY created_at', [
    tripId,
  ]);
  return rows.map(rowToSelection);
}

export async function deleteSelection(id: string): Promise<void> {
  const changes = await db.run('DELETE FROM flight_selections WHERE id = ?', [id]);
  if (changes === 0) {
    throw notFound('selection_not_found', `No flight selection with id ${id}`);
  }
}

function rowToSelection(row: Record<string, unknown>): StoredSelection {
  return {
    id: row.id as string,
    trip_id: row.trip_id as string,
    member_id: (row.member_id as string) ?? null,
    direction: row.direction as 'outbound' | 'return',
    offer: JSON.parse(row.offer as string) as FlightOffer,
    created_at: row.created_at as string,
  };
}

export * from './types.js';
