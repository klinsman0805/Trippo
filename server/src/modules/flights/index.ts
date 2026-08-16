import { env } from '../../config/env.js';
import { db, newId, nowIso } from '../../db/index.js';
import { notFound, unavailable } from '../../lib/errors.js';
import { AmadeusProvider } from './amadeus.js';
import { MockFlightProvider } from './mock.js';
import type { FlightOffer, FlightProvider } from './types.js';

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
export function saveSelection(
  tripId: string,
  direction: 'outbound' | 'return',
  offer: FlightOffer,
  memberId?: string | null,
): StoredSelection {
  const id = newId('fls');

  const tx = db.transaction(() => {
    db.prepare(
      `DELETE FROM flight_selections
       WHERE trip_id = ? AND direction = ?
         AND (member_id IS ? OR member_id = ?)`,
    ).run(tripId, direction, memberId ?? null, memberId ?? null);

    db.prepare(
      `INSERT INTO flight_selections (id, trip_id, member_id, direction, offer, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
    ).run(id, tripId, memberId ?? null, direction, JSON.stringify(offer), nowIso());
  });
  tx();

  return getSelection(id);
}

export function getSelection(id: string): StoredSelection {
  const row = db.prepare('SELECT * FROM flight_selections WHERE id = ?').get(id) as
    | Record<string, unknown>
    | undefined;
  if (!row) throw notFound('selection_not_found', `No flight selection with id ${id}`);
  return rowToSelection(row);
}

export function listSelections(tripId: string): StoredSelection[] {
  const rows = db
    .prepare('SELECT * FROM flight_selections WHERE trip_id = ? ORDER BY created_at')
    .all(tripId) as Record<string, unknown>[];
  return rows.map(rowToSelection);
}

export function deleteSelection(id: string): void {
  const res = db.prepare('DELETE FROM flight_selections WHERE id = ?').run(id);
  if (res.changes === 0) {
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
