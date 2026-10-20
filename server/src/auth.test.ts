import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import type { FastifyInstance } from 'fastify';
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK } from 'jose';
import { supabaseVerifier } from './lib/auth.js';
import { requireNoModelKey } from './test-support.js';

/**
 * Two people, each trying every way the API offers to reach the other's trip.
 *
 * Tokens are real: signed with an ES256 key, the asymmetric kind Supabase
 * issues, and checked by the same verifier production uses — only the key set
 * is local instead of fetched.
 */

const SUPABASE = 'https://test-project.supabase.co';
const ISSUER = `${SUPABASE}/auth/v1`;

let app: FastifyInstance;
let sign: (claims: Record<string, unknown>, opts?: { issuer?: string; expires?: string }) => Promise<string>;

before(async () => {
  requireNoModelKey();
  const { publicKey, privateKey } = await generateKeyPair('ES256');
  const jwk: JWK = { ...(await exportJWK(publicKey)), kid: 'test', alg: 'ES256' };
  sign = (claims, opts = {}) =>
    new SignJWT({ aud: 'authenticated', role: 'authenticated', ...claims })
      .setProtectedHeader({ alg: 'ES256', kid: 'test' })
      .setIssuer(opts.issuer ?? ISSUER)
      .setIssuedAt()
      .setExpirationTime(opts.expires ?? '1h')
      .sign(privateKey);

  const { buildApp } = await import('./app.js');
  app = await buildApp(
    supabaseVerifier({ supabaseUrl: SUPABASE, keys: createLocalJWKSet({ keys: [jwk] }) }),
  );
});

after(async () => {
  await app.close();
  const { db } = await import('./db/index.js');
  await db.close();
});

const tokens: Record<string, string> = {};
const as = async (user: string, anonymous = false) =>
  (tokens[user] ??= await sign({ sub: user, is_anonymous: anonymous }));

async function call(token: string | null, method: string, url: string, payload?: unknown) {
  const res = await app.inject({
    method: method as 'GET',
    url,
    headers: token ? { authorization: `Bearer ${token}` } : {},
    ...(payload === undefined ? {} : { payload: payload as object }),
  });
  return { status: res.statusCode, body: res.body ? JSON.parse(res.body) : null };
}

describe('who is asking', () => {
  it('turns away a request with no token, a forged one, or an expired one', async () => {
    assert.equal((await call(null, 'GET', '/v1/trips')).status, 401);
    assert.equal((await call('not-a-jwt', 'GET', '/v1/trips')).status, 401);
    assert.equal((await call(await sign({ sub: 'u' }, { expires: '-1m' }), 'GET', '/v1/trips')).status, 401);
    assert.equal(
      (await call(await sign({ sub: 'u' }, { issuer: 'https://other.supabase.co/auth/v1' }), 'GET', '/v1/trips')).status,
      401,
    );
  });

  it('turns away the app\'s own anon key, which names no user', async () => {
    const anonKey = await sign({ role: 'anon', aud: 'anon' });
    const res = await call(anonKey, 'GET', '/v1/trips');
    assert.equal(res.status, 401);
    assert.equal(res.body.error.code, 'invalid_token');
  });

  it('lets an anonymous sign-in plan a trip — no account needed for the first one', async () => {
    const res = await call(await as('anon-1', true), 'POST', '/v1/trips', { title: 'First trip' });
    assert.equal(res.status, 201);
  });

  it('leaves the health check open', async () => {
    assert.equal((await call(null, 'GET', '/health')).status, 200);
  });
});

describe('a trip is its owner\'s alone', () => {
  let aTrip = '';
  let bTrip = '';
  const aIds: Record<string, string> = {};

  before(async () => {
    const a = await as('user-a');
    const b = await as('user-b');

    aTrip = (await call(a, 'POST', '/v1/trips', {
      title: "A's trip",
      destinations: ['Penang'],
      start_date: '2026-12-01',
      end_date: '2026-12-02',
      members: [{ name: 'Ah Meng' }],
    })).body.trip.id;
    bTrip = (await call(b, 'POST', '/v1/trips', { title: "B's trip" })).body.trip.id;

    const trip = (await call(a, 'GET', `/v1/trips/${aTrip}`)).body.trip;
    aIds.member = trip.members[0].id;
    aIds.place = (await call(a, 'POST', `/v1/trips/${aTrip}/places`, { name: 'Gurney Drive' })).body.place.id;
    await call(a, 'POST', `/v1/trips/${aTrip}/sources/text`, { text: 'Gurney Drive hawker centre' });
    aIds.source = (await call(a, 'GET', `/v1/trips/${aTrip}/sources`)).body.sources[0].id;
    const offer = (await call(a, 'POST', '/v1/flights/manual', {
      flight_number: 'AK6100',
      origin: 'KUL',
      destination: 'PEN',
      departs_at: '2026-12-01T08:00',
      arrives_at: '2026-12-01T09:00',
    })).body.offers[0];
    aIds.selection = (await call(a, 'POST', `/v1/trips/${aTrip}/flights`, { direction: 'outbound', offer })).body.selection.id;
    await call(a, 'POST', `/v1/trips/${aTrip}/plan/blank`);
    aIds.plan = (await call(a, 'GET', `/v1/trips/${aTrip}/plan`)).body.plan.id;
  });

  it('lists only your own trips', async () => {
    const ids = (await call(await as('user-b'), 'GET', '/v1/trips')).body.trips.map((t: { id: string }) => t.id);
    assert.ok(ids.includes(bTrip));
    assert.ok(!ids.includes(aTrip));
  });

  it("answers someone else's trip as if it did not exist, on every route", async () => {
    const b = await as('user-b');
    const attempts: [string, string, unknown?][] = [
      ['GET', `/v1/trips/${aTrip}`],
      ['PATCH', `/v1/trips/${aTrip}`, { title: 'mine now' }],
      ['DELETE', `/v1/trips/${aTrip}`],
      ['GET', `/v1/trips/${aTrip}/plan`],
      ['GET', `/v1/trips/${aTrip}/places`],
      ['GET', `/v1/trips/${aTrip}/sources`],
      ['GET', `/v1/trips/${aTrip}/flights`],
      ['GET', `/v1/trips/${aTrip}/chat`],
      ['POST', `/v1/trips/${aTrip}/members`, { name: 'Intruder' }],
      ['POST', `/v1/trips/${aTrip}/plan/days`],
      ['GET', `/v1/trips/${aTrip}/plan/days/1/points`],
      ['GET', `/v1/plans/${aIds.plan}`],
    ];
    for (const [method, url, payload] of attempts) {
      const res = await call(b, method, url, payload);
      assert.equal(res.status, 404, `${method} ${url} answered ${res.status}`);
    }
    // And nothing changed.
    const a = await as('user-a');
    assert.equal((await call(a, 'GET', `/v1/trips/${aTrip}`)).body.trip.title, "A's trip");
  });

  it("can't reach another trip's records through your own trip's address", async () => {
    const b = await as('user-b');
    const attempts: [string, string, unknown?][] = [
      ['PATCH', `/v1/trips/${bTrip}/members/${aIds.member}`, { name: 'Renamed' }],
      ['DELETE', `/v1/trips/${bTrip}/members/${aIds.member}`],
      ['DELETE', `/v1/trips/${bTrip}/places/${aIds.place}`],
      ['DELETE', `/v1/trips/${bTrip}/sources/${aIds.source}`],
      ['DELETE', `/v1/trips/${bTrip}/flights/${aIds.selection}`],
      // Pasting text into someone else's blocked import.
      ['POST', `/v1/trips/${bTrip}/sources/text`, { text: 'Overwriting your import with my own text', source_id: aIds.source }],
    ];
    for (const [method, url, payload] of attempts) {
      const res = await call(b, method, url, payload);
      assert.equal(res.status, 404, `${method} ${url} answered ${res.status} ${JSON.stringify(res.body)}`);
    }

    // Every one of A's records is still there, unchanged.
    const a = await as('user-a');
    const trip = (await call(a, 'GET', `/v1/trips/${aTrip}`)).body.trip;
    assert.equal(trip.members[0].name, 'Ah Meng');
    assert.equal((await call(a, 'GET', `/v1/trips/${aTrip}/places`)).body.places.length, 1);
    assert.equal((await call(a, 'GET', `/v1/trips/${aTrip}/sources`)).body.sources.length, 1);
    assert.equal((await call(a, 'GET', `/v1/trips/${aTrip}/flights`)).body.selections.length, 1);
  });

  it("won't book a flight for a traveller on someone else's trip", async () => {
    const b = await as('user-b');
    const offer = (await call(b, 'POST', '/v1/flights/manual', {
      flight_number: 'AK6100',
      origin: 'KUL',
      destination: 'PEN',
      departs_at: '2026-12-01T08:00',
      arrives_at: '2026-12-01T09:00',
    })).body.offers[0];
    const res = await call(b, 'POST', `/v1/trips/${bTrip}/flights`, {
      direction: 'outbound',
      offer,
      member_id: aIds.member,
    });
    assert.equal(res.status, 404);
  });
});

describe('how often', () => {
  it('limits model calls per person, and only for that person', async () => {
    const c = await as('user-c');
    const trip = (await call(c, 'POST', '/v1/trips', { title: 'Busy', destinations: ['Ipoh'] })).body.trip.id;

    // No model key here, so each attempt fails fast — but it still counts.
    let last = 0;
    for (let i = 0; i < 21; i++) last = (await call(c, 'POST', `/v1/trips/${trip}/plan`)).status;
    const limited = await call(c, 'POST', `/v1/trips/${trip}/plan`);
    assert.equal(limited.status, 429);
    assert.equal(limited.body.error.code, 'rate_limited');
    assert.notEqual(last, 0);

    // Someone else is unaffected, and so are the cheap routes.
    const d = await as('user-d');
    const theirs = (await call(d, 'POST', '/v1/trips', { title: 'Calm', destinations: ['Ipoh'] })).body.trip.id;
    assert.notEqual((await call(d, 'POST', `/v1/trips/${theirs}/plan`)).status, 429);
    assert.equal((await call(c, 'GET', `/v1/trips/${trip}`)).status, 200);
  });
});

describe('moving trips off the anonymous user a device started with', () => {
  it("takes an anonymous device's trips, and leaves it with none", async () => {
    const device = await as('transfer-anon', true);
    const me = await as('transfer-me');

    const trip = (await call(device, 'POST', '/v1/trips', { title: 'Planned before signing in' })).body
      .trip.id;

    const res = await call(me, 'POST', '/v1/account/transfer', {
      from_access_token: device,
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.moved, 1);

    // The trip answers to its new owner, and the old one is a stranger to it.
    assert.equal((await call(me, 'GET', `/v1/trips/${trip}`)).status, 200);
    assert.equal((await call(device, 'GET', `/v1/trips/${trip}`)).status, 404);
  });

  it('moves nothing belonging to anybody else', async () => {
    const device = await as('transfer-anon-2', true);
    const bystander = await as('transfer-bystander');
    const me = await as('transfer-me-2');

    const theirs = (await call(bystander, 'POST', '/v1/trips', { title: 'Not yours' })).body.trip.id;
    await call(device, 'POST', '/v1/trips', { title: 'Mine' });

    assert.equal(
      (await call(me, 'POST', '/v1/account/transfer', { from_access_token: device })).body.moved,
      1,
    );
    // Untouched, and still theirs.
    assert.equal((await call(bystander, 'GET', `/v1/trips/${theirs}`)).status, 200);
    assert.equal((await call(me, 'GET', `/v1/trips/${theirs}`)).status, 404);
  });

  it('will not empty a real account, only an anonymous one', async () => {
    // The restriction the whole design rests on: possession of a token is
    // proof enough for a device's own throwaway user, and nowhere near
    // enough for somebody's account.
    const victim = await as('transfer-victim');
    const trip = (await call(victim, 'POST', '/v1/trips', { title: 'Years of planning' })).body.trip.id;

    const thief = await as('transfer-thief');
    const res = await call(thief, 'POST', '/v1/account/transfer', { from_access_token: victim });

    assert.equal(res.status, 401);
    assert.equal(res.body.error.code, 'not_anonymous');
    assert.equal((await call(victim, 'GET', `/v1/trips/${trip}`)).status, 200);
  });

  it('turns away a token that is forged, expired or for another project', async () => {
    const me = await as('transfer-me-3');
    const bad = [
      'not-a-jwt-at-all',
      await sign({ sub: 'ghost', is_anonymous: true }, { expires: '-1m' }),
      await sign({ sub: 'ghost', is_anonymous: true }, { issuer: 'https://other.supabase.co/auth/v1' }),
    ];
    for (const token of bad) {
      const res = await call(me, 'POST', '/v1/account/transfer', { from_access_token: token });
      assert.equal(res.status, 401, token.slice(0, 12));
    }
  });

  it('is content when there is nothing to do', async () => {
    // What the device that did the linking sees: the identity attached to the
    // user it already was, so both tokens name the same person.
    const me = await as('transfer-me-4');
    const res = await call(me, 'POST', '/v1/account/transfer', { from_access_token: me });
    assert.equal(res.status, 200);
    assert.equal(res.body.moved, 0);
  });

  it('needs a caller of its own, like every other route', async () => {
    const device = await as('transfer-anon-3', true);
    assert.equal(
      (await call(null, 'POST', '/v1/account/transfer', { from_access_token: device })).status,
      401,
    );
  });

  it('asks for the token it needs', async () => {
    const me = await as('transfer-me-5');
    assert.equal((await call(me, 'POST', '/v1/account/transfer', {})).status, 400);
  });
});

describe('a project still on a shared secret', () => {
  it('verifies HS256 tokens with it', async () => {
    const secret = 'a-test-secret-that-is-long-enough';
    const verify = supabaseVerifier({ supabaseUrl: SUPABASE, jwtSecret: secret });
    const token = await new SignJWT({ sub: 'user-hs', aud: 'authenticated' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer(ISSUER)
      .setExpirationTime('1h')
      .sign(new TextEncoder().encode(secret));

    assert.deepEqual(await verify(`Bearer ${token}`), { userId: 'user-hs', anonymous: false });
    await assert.rejects(verify(`Bearer ${token}x`));
  });
});
