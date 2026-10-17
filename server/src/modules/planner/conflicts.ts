import { db, nowIso } from '../../db/index.js';

/**
 * "Looks good" acknowledgements on conflict cards.
 *
 * Stored per (trip, tag) rather than per array index, because regenerating a
 * plan reorders the conflicts array — an index-keyed record would silently
 * reattach the group's acknowledgement to a different conflict.
 */
export async function setAcknowledged(tripId: string, tag: string, accepted: boolean): Promise<void> {
  if (!accepted) {
    await db.run('DELETE FROM conflict_acknowledgements WHERE trip_id = ? AND tag = ?', [tripId, tag]);
    return;
  }
  await db.run(
    `INSERT INTO conflict_acknowledgements (trip_id, tag, accepted, updated_at)
     VALUES (?, ?, 1, ?)
     ON CONFLICT(trip_id, tag) DO UPDATE SET accepted = 1, updated_at = excluded.updated_at`,
    [tripId, tag, nowIso()],
  );
}

/** Tags the group has accepted, for the client to mark those cards done. */
export async function listAcknowledged(tripId: string): Promise<string[]> {
  const rows = await db.query<{ tag: string }>(
    'SELECT tag FROM conflict_acknowledgements WHERE trip_id = ? AND accepted = 1',
    [tripId],
  );
  return rows.map((r) => r.tag);
}
