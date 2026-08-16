import { db, nowIso } from '../../db/index.js';

/**
 * "Looks good" acknowledgements on conflict cards.
 *
 * Stored per (trip, tag) rather than per array index, because regenerating a
 * plan reorders the conflicts array — an index-keyed record would silently
 * reattach the group's acknowledgement to a different conflict.
 */
export function setAcknowledged(tripId: string, tag: string, accepted: boolean): void {
  if (!accepted) {
    db.prepare('DELETE FROM conflict_acknowledgements WHERE trip_id = ? AND tag = ?').run(
      tripId,
      tag,
    );
    return;
  }
  db.prepare(
    `INSERT INTO conflict_acknowledgements (trip_id, tag, accepted, updated_at)
     VALUES (?, ?, 1, ?)
     ON CONFLICT(trip_id, tag) DO UPDATE SET accepted = 1, updated_at = excluded.updated_at`,
  ).run(tripId, tag, nowIso());
}

/** Tags the group has accepted, for the client to mark those cards done. */
export function listAcknowledged(tripId: string): string[] {
  const rows = db
    .prepare('SELECT tag FROM conflict_acknowledgements WHERE trip_id = ? AND accepted = 1')
    .all(tripId) as { tag: string }[];
  return rows.map((r) => r.tag);
}
