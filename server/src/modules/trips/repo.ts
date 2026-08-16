import { db, fromJson, newId, nowIso, toJson } from '../../db/index.js';
import { notFound } from '../../lib/errors.js';
import type {
  Member,
  MemberInput,
  Place,
  Trip,
  TripInput,
} from '../../schemas/trip.js';

type Row = Record<string, unknown>;

function rowToMember(r: Row): Member {
  return {
    id: r.id as string,
    trip_id: r.trip_id as string,
    name: r.name as string,
    departure_city: (r.departure_city as string) ?? undefined,
    interests: fromJson<string[]>(r.interests, []),
    pace: (r.pace as Member['pace']) ?? 'moderate',
    budget_sensitivity: (r.budget_sensitivity as string) ?? undefined,
    dietary_restrictions: fromJson<string[]>(r.dietary_restrictions, []),
    accessibility_needs: fromJson<string[]>(r.accessibility_needs, []),
    deal_breakers: fromJson<string[]>(r.deal_breakers, []),
    wants: fromJson<string[]>(r.wants, []),
    avoids: fromJson<string[]>(r.avoids, []),
    created_at: r.created_at as string,
  };
}

function rowToTrip(r: Row, members: Member[]): Trip {
  return {
    id: r.id as string,
    title: r.title as string,
    destinations: fromJson<string[]>(r.destinations, []),
    start_date: (r.start_date as string) ?? null,
    end_date: (r.end_date as string) ?? null,
    date_flexible: Boolean(r.date_flexible),
    currency: r.currency as string,
    total_budget: (r.total_budget as number) ?? null,
    budget_basis: r.budget_basis as Trip['budget_basis'],
    purpose: (r.purpose as string) ?? null,
    hard_constraints: fromJson<string[]>(r.hard_constraints, []),
    notes: (r.notes as string) ?? null,
    created_at: r.created_at as string,
    updated_at: r.updated_at as string,
    members,
  };
}

export function rowToPlace(r: Row): Place {
  return {
    id: r.id as string,
    trip_id: r.trip_id as string,
    source_id: (r.source_id as string) ?? null,
    name: r.name as string,
    category: (r.category as string) ?? null,
    city: (r.city as string) ?? null,
    country: (r.country as string) ?? null,
    address: (r.address as string) ?? null,
    lat: (r.lat as number) ?? null,
    lng: (r.lng as number) ?? null,
    google_place_id: (r.google_place_id as string) ?? null,
    why: (r.why as string) ?? null,
    tags: fromJson<string[]>(r.tags, []),
    resolved: Boolean(r.resolved),
    created_at: r.created_at as string,
  };
}

const insertMemberStmt = db.prepare(`
  INSERT INTO members (id, trip_id, name, departure_city, interests, pace,
    budget_sensitivity, dietary_restrictions, accessibility_needs, deal_breakers,
    wants, avoids, created_at)
  VALUES (@id, @trip_id, @name, @departure_city, @interests, @pace,
    @budget_sensitivity, @dietary_restrictions, @accessibility_needs, @deal_breakers,
    @wants, @avoids, @created_at)
`);

export function addMember(tripId: string, input: MemberInput): Member {
  const id = newId('mem');
  insertMemberStmt.run({
    id,
    trip_id: tripId,
    name: input.name,
    departure_city: input.departure_city ?? null,
    interests: toJson(input.interests),
    pace: input.pace,
    budget_sensitivity: input.budget_sensitivity ?? null,
    dietary_restrictions: toJson(input.dietary_restrictions),
    accessibility_needs: toJson(input.accessibility_needs),
    deal_breakers: toJson(input.deal_breakers),
    wants: toJson(input.wants),
    avoids: toJson(input.avoids),
    created_at: nowIso(),
  });
  return getMember(id);
}

export function getMember(id: string): Member {
  const row = db.prepare('SELECT * FROM members WHERE id = ?').get(id) as Row | undefined;
  if (!row) throw notFound('member_not_found', `No member with id ${id}`);
  return rowToMember(row);
}

const MEMBER_PATCHABLE = new Set([
  'name',
  'departure_city',
  'interests',
  'pace',
  'budget_sensitivity',
  'dietary_restrictions',
  'accessibility_needs',
  'deal_breakers',
  'wants',
  'avoids',
]);

const MEMBER_JSON_FIELDS = new Set([
  'interests',
  'dietary_restrictions',
  'accessibility_needs',
  'deal_breakers',
  'wants',
  'avoids',
]);

/**
 * Update a traveller in place.
 *
 * Changing pace or access needs alters what the planner has to reconcile, so
 * the caller is expected to surface that the conflicts are now stale.
 */
export function updateMember(id: string, patch: Record<string, unknown>): Member {
  getMember(id); // 404s if missing

  const sets: string[] = [];
  const params: Record<string, unknown> = { id };

  for (const [key, value] of Object.entries(patch)) {
    if (!MEMBER_PATCHABLE.has(key) || value === undefined) continue;
    sets.push(`${key} = @${key}`);
    params[key] = MEMBER_JSON_FIELDS.has(key) ? toJson(value) : (value ?? null);
  }

  if (sets.length > 0) {
    db.prepare(`UPDATE members SET ${sets.join(', ')} WHERE id = @id`).run(params);
  }
  return getMember(id);
}

export function deleteMember(id: string): void {
  const res = db.prepare('DELETE FROM members WHERE id = ?').run(id);
  if (res.changes === 0) throw notFound('member_not_found', `No member with id ${id}`);
}

export function createTrip(input: TripInput): Trip {
  const id = newId('trip');
  const ts = nowIso();

  const tx = db.transaction(() => {
    db.prepare(
      `INSERT INTO trips (id, title, destinations, start_date, end_date, date_flexible,
         currency, total_budget, budget_basis, purpose, hard_constraints, notes,
         created_at, updated_at)
       VALUES (@id, @title, @destinations, @start_date, @end_date, @date_flexible,
         @currency, @total_budget, @budget_basis, @purpose, @hard_constraints, @notes,
         @created_at, @updated_at)`,
    ).run({
      id,
      title: input.title,
      destinations: toJson(input.destinations),
      start_date: input.start_date ?? null,
      end_date: input.end_date ?? null,
      date_flexible: input.date_flexible ? 1 : 0,
      currency: input.currency,
      total_budget: input.total_budget ?? null,
      budget_basis: input.budget_basis,
      purpose: input.purpose ?? null,
      hard_constraints: toJson(input.hard_constraints),
      notes: input.notes ?? null,
      created_at: ts,
      updated_at: ts,
    });

    for (const m of input.members) addMember(id, m);
  });
  tx();

  return getTrip(id);
}

export function getTrip(id: string): Trip {
  const row = db.prepare('SELECT * FROM trips WHERE id = ?').get(id) as Row | undefined;
  if (!row) throw notFound('trip_not_found', `No trip with id ${id}`);
  const memberRows = db
    .prepare('SELECT * FROM members WHERE trip_id = ? ORDER BY created_at')
    .all(id) as Row[];
  return rowToTrip(row, memberRows.map(rowToMember));
}

/**
 * Trip list for the picker.
 *
 * Members are counted rather than hydrated — the list only needs "3 travellers",
 * and loading every member of every trip to render one number would grow with
 * the account. `member_count` is on the row; `members` stays empty.
 */
export function listTrips(): (Trip & { member_count: number })[] {
  const rows = db
    .prepare(
      `SELECT t.*, (SELECT COUNT(*) FROM members m WHERE m.trip_id = t.id) AS member_count
       FROM trips t
       ORDER BY t.updated_at DESC`,
    )
    .all() as Row[];

  return rows.map((r) => ({
    ...rowToTrip(r, []),
    member_count: Number(r.member_count ?? 0),
  }));
}

const PATCHABLE = new Set([
  'title',
  'destinations',
  'start_date',
  'end_date',
  'date_flexible',
  'currency',
  'total_budget',
  'budget_basis',
  'purpose',
  'hard_constraints',
  'notes',
]);

export function updateTrip(id: string, patch: Record<string, unknown>): Trip {
  getTrip(id); // 404s if missing

  const sets: string[] = [];
  const params: Record<string, unknown> = { id, updated_at: nowIso() };

  for (const [key, value] of Object.entries(patch)) {
    if (!PATCHABLE.has(key) || value === undefined) continue;
    sets.push(`${key} = @${key}`);
    if (key === 'destinations' || key === 'hard_constraints') params[key] = toJson(value);
    else if (key === 'date_flexible') params[key] = value ? 1 : 0;
    else params[key] = value ?? null;
  }

  if (sets.length > 0) {
    db.prepare(
      `UPDATE trips SET ${sets.join(', ')}, updated_at = @updated_at WHERE id = @id`,
    ).run(params);
  }
  return getTrip(id);
}

export function deleteTrip(id: string): void {
  const res = db.prepare('DELETE FROM trips WHERE id = ?').run(id);
  if (res.changes === 0) throw notFound('trip_not_found', `No trip with id ${id}`);
}

/** Touch updated_at so trip lists sort by real activity, not just edits. */
export function touchTrip(id: string): void {
  db.prepare('UPDATE trips SET updated_at = ? WHERE id = ?').run(nowIso(), id);
}
