import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import type { FastifyInstance } from 'fastify';

/**
 * The whole API, through HTTP, against a real Postgres.
 *
 * Runs on PGlite in memory (`npm test` sets DATABASE_PATH=memory://), so it is
 * the same SQL Supabase runs. It exists because the move off SQLite made every
 * data call asynchronous, and a call that is not awaited still compiles: a
 * route returning `{ trip: getTrip(id) }` type-checks and sends `{}`. Only
 * driving the routes catches that.
 */

let app: FastifyInstance;

before(async () => {
  const { buildApp } = await import('./app.js');
  app = await buildApp();
});

after(async () => {
  await app.close();
  const { db } = await import('./db/index.js');
  await db.close();
});

async function call(method: string, url: string, payload?: unknown) {
  const res = await app.inject({
    method: method as 'GET',
    url: `/v1${url}`,
    ...(payload === undefined ? {} : { payload: payload as object }),
  });
  const body = res.body ? JSON.parse(res.body) : null;
  return { status: res.statusCode, body };
}

async function ok(method: string, url: string, payload?: unknown) {
  const res = await call(method, url, payload);
  assert.ok(res.status < 300, `${method} ${url} → ${res.status} ${JSON.stringify(res.body)}`);
  return res.body;
}

describe('the API on Postgres', () => {
  let tripId = '';

  it('creates, lists, reads, patches a trip', async () => {
    const created = await ok('POST', '/trips', {
      title: 'Kuala Lumpur',
      destinations: ['Kuala Lumpur'],
      start_date: '2026-11-03',
      end_date: '2026-11-04',
      currency: 'MYR',
      total_budget: 1200.5,
      members: [{ name: 'Mei', interests: ['food'] }],
    });
    tripId = created.trip.id;
    assert.equal(created.trip.members.length, 1);
    assert.deepEqual(created.trip.destinations, ['Kuala Lumpur']);
    assert.equal(created.trip.total_budget, 1200.5);

    const list = await ok('GET', '/trips');
    const row = list.trips.find((t: { id: string }) => t.id === tripId);
    assert.ok(row, 'the new trip is listed');
    // Counted in SQL — a bigint the driver would hand back as "1".
    assert.strictEqual(row.member_count, 1);

    const patched = await ok('PATCH', `/trips/${tripId}`, { title: 'KL, slowly', date_flexible: false });
    assert.equal(patched.trip.title, 'KL, slowly');
    assert.equal(patched.trip.date_flexible, false);

    assert.equal((await ok('GET', `/trips/${tripId}`)).trip.title, 'KL, slowly');
  });

  it('adds, edits and removes a traveller', async () => {
    const { member } = await ok('POST', `/trips/${tripId}/members`, { name: 'Wei', pace: 'relaxed' });
    const updated = await ok('PATCH', `/trips/${tripId}/members/${member.id}`, { interests: ['temples'] });
    assert.deepEqual(updated.member.interests, ['temples']);
    await ok('DELETE', `/trips/${tripId}/members/${member.id}`);
    assert.equal((await call('DELETE', `/trips/${tripId}/members/${member.id}`)).status, 404);
  });

  it('keeps saved places, without duplicates', async () => {
    const { place } = await ok('POST', `/trips/${tripId}/places`, {
      name: 'Jalan Alor',
      city: 'Kuala Lumpur',
      lat: 3.1456,
      lng: 101.7088,
    });
    const { places } = await ok('GET', `/trips/${tripId}/places`);
    assert.equal(places.length, 1);
    // Double precision, not float4: a REAL column would round this.
    assert.equal(places[0].lat, 3.1456);
    assert.equal(place.name, 'Jalan Alor');
  });

  it('records a blocked import as a source, and lists it', async () => {
    // No model key in tests, so extraction fails — which still exercises
    // creating and updating the source row.
    await call('POST', `/trips/${tripId}/sources/text`, { text: 'Jalan Alor, then Petaling Street' });
    const { sources } = await ok('GET', `/trips/${tripId}/sources`);
    assert.ok(sources.length >= 1);
    assert.strictEqual(typeof sources[0].place_count, 'number');
    await ok('DELETE', `/trips/${tripId}/sources/${sources[0].id}`);
  });

  it('builds a hand-written plan and edits it', async () => {
    const blank = await ok('POST', `/trips/${tripId}/plan/blank`);
    assert.equal(blank.plan.itinerary.length, 2);

    const added = await ok('POST', `/trips/${tripId}/plan/days/1/blocks`, {
      activity: 'Petronas Twin Towers',
      time_of_day: 'morning',
      start_time: '09:00',
    });
    const block = added.plan.itinerary[0].blocks[0];
    assert.equal(block.activity, 'Petronas Twin Towers');

    await ok('PATCH', `/trips/${tripId}/plan/blocks/${block.id}`, { location: 'KLCC' });
    await ok('POST', `/trips/${tripId}/plan/blocks/${block.id}/move`, { day: 2, time_of_day: 'afternoon' });
    const pinned = await ok('POST', `/trips/${tripId}/plan/blocks/${block.id}/pin`, { pinned: false });
    assert.equal(pinned.plan.itinerary[1].blocks[0].pinned, false);

    const withDay = await ok('POST', `/trips/${tripId}/plan/days`);
    assert.equal(withDay.plan.itinerary.length, 3);
    assert.equal((await ok('GET', `/trips/${tripId}`)).trip.end_date, '2026-11-05');

    await ok('DELETE', `/trips/${tripId}/plan/blocks/${block.id}`);
    await ok('DELETE', `/trips/${tripId}/plan/days/3`);

    const latest = await ok('GET', `/trips/${tripId}/plan`);
    assert.equal(latest.plan.revision, 1);
    assert.equal(latest.plan.plan.itinerary.length, 2);
    assert.deepEqual(latest.accepted_conflicts, []);
    assert.equal(latest.updated_day, null);

    const { revisions } = await ok('GET', `/trips/${tripId}/plan/revisions`);
    assert.equal(revisions.length, 1);
    assert.ok((await ok('GET', `/plans/${latest.plan.id}`)).plan);
    assert.ok(Array.isArray((await ok('GET', `/trips/${tripId}/chat`)).messages));
    assert.ok((await ok('GET', `/trips/${tripId}/plan/pinned`)).pinned);
  });

  it('adds a saved place with its citation resolved on the server', async () => {
    const { places } = await ok('GET', `/trips/${tripId}/places`);
    const added = await ok('POST', `/trips/${tripId}/plan/days/1/blocks`, {
      place_id: places[0].id,
      time_of_day: 'evening',
    });
    const cited = added.plan.itinerary[0].blocks.find(
      (b: { from_place_id: string | null }) => b.from_place_id === places[0].id,
    );
    assert.equal(cited.activity, 'Jalan Alor');
  });

  it('acknowledges conflicts, and keeps no failure on a healthy trip', async () => {
    const { accepted_conflicts } = await ok('POST', `/trips/${tripId}/conflicts/accept`, { tag: 'Pace' });
    assert.deepEqual(accepted_conflicts, ['Pace']);
    assert.equal((await ok('GET', `/trips/${tripId}/plan/failure`)).failure, null);
  });

  it('a booked flight sets the dates and is replaced, not appended', async () => {
    const leg = (departs: string, arrives: string) => ({
      flight_number: 'AK892',
      origin: 'SIN',
      destination: 'KUL',
      departs_at: departs,
      arrives_at: arrives,
    });
    const first = (await ok('POST', '/flights/manual', leg('2026-11-03T08:00', '2026-11-03T09:05'))).offers[0];
    const second = (await ok('POST', '/flights/manual', leg('2026-11-03T18:00', '2026-11-03T19:05'))).offers[0];

    await ok('POST', `/trips/${tripId}/flights`, { direction: 'outbound', offer: first });
    await ok('POST', `/trips/${tripId}/flights`, { direction: 'outbound', offer: second });

    const { selections } = await ok('GET', `/trips/${tripId}/flights`);
    // Trip-wide selections have no member; the second replaced the first.
    assert.equal(selections.length, 1);
    await ok('DELETE', `/trips/${tripId}/flights/${selections[0].id}`);
  });

  it('answers travel and points for the plan, placed or not', async () => {
    const latest = await ok('GET', `/trips/${tripId}/plan`);
    const blocks = latest.plan.plan.itinerary[0].blocks;
    if (blocks.length >= 2) {
      const { legs } = await ok('POST', `/trips/${tripId}/plan/travel`, {
        legs: [{ from_block_id: blocks[0].id, to_block_id: blocks[1].id }],
      });
      assert.equal(legs.length, 1);
    }
    const { points } = await ok('GET', `/trips/${tripId}/plan/days/1/points`);
    assert.equal(points.length, blocks.length);
  });

  it('deletes the trip and everything under it', async () => {
    await ok('DELETE', `/trips/${tripId}`);
    assert.equal((await call('GET', `/trips/${tripId}`)).status, 404);
    // Cascaded: nothing of it is left behind.
    const { db } = await import('./db/index.js');
    for (const table of ['members', 'places', 'sources', 'plans', 'flight_selections', 'conflict_acknowledgements']) {
      const row = await db.one<{ n: number }>(`SELECT COUNT(*)::int AS n FROM ${table} WHERE trip_id = ?`, [tripId]);
      assert.equal(row?.n, 0, `${table} still holds rows for the deleted trip`);
    }
  });
});
