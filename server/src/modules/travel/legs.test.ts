import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { GeoProvider, LatLng, RouteRequest, RouteResult, TransitProvider } from '../geo/index.js';
import type { Plan, PlanBlock } from '../../schemas/plan.js';
import type { Place, Trip } from '../../schemas/trip.js';
import {
  computeLegs,
  departureFor,
  legKey,
  locateDay,
  modeFor,
  vehicleFor,
  withPlace,
  type TravelDeps,
  type TravelStore,
} from './legs.js';

// --- fixtures: Kuala Lumpur, where the planner was tested live ---

const KLCC: LatLng = { lat: 3.1579, lng: 101.7116 };
const PAVILION: LatLng = { lat: 3.149, lng: 101.7134 }; // ~1 km from KLCC
const CENTRAL_MARKET: LatLng = { lat: 3.1455, lng: 101.6955 }; // ~2.2 km
const KL: LatLng = { lat: 3.139, lng: 101.6869 };
const FUJI: LatLng = { lat: 35.3606, lng: 138.7274 }; // the namesake far away

const trip = {
  id: 'trip_1',
  title: 'KL',
  destinations: ['Kuala Lumpur'],
  start_date: '2026-11-03',
  end_date: '2026-11-05',
  members: [],
} as unknown as Trip;

function block(id: string, over: Partial<PlanBlock> = {}): PlanBlock {
  return {
    id,
    time_of_day: 'morning',
    activity: id,
    description: '',
    location: '',
    start_time: null,
    estimated_duration_minutes: null,
    estimated_cost_per_person: null,
    suited_for_members: [],
    optional: false,
    weather_backup: null,
    source: 'planner',
    pinned: false,
    from_place_id: null,
    from_source_title: null,
    from_place: null,
    ...over,
  } as PlanBlock;
}

function planOf(...blocks: PlanBlock[]): Plan {
  return {
    itinerary: [
      {
        day: 1,
        date: '2026-11-03',
        location: 'Kuala Lumpur',
        lodging_area_suggestion: null,
        blocks,
        notes: null,
      },
    ],
  } as unknown as Plan;
}

/** Geocoder that answers from a table, and records what it was asked. */
function fakeGeo(table: Record<string, LatLng>): GeoProvider & {
  asked: string[];
  biases: Map<string, LatLng | undefined>;
} {
  const asked: string[] = [];
  const biases = new Map<string, LatLng | undefined>();
  return {
    name: 'fake',
    configured: true,
    asked,
    biases,
    async search(query, opts) {
      asked.push(query);
      biases.set(query, opts?.bias);
      const at = table[query.toLowerCase()];
      return at
        ? [
            {
              place_id: `fake:${query}`,
              name: query,
              address: null,
              lat: at.lat,
              lng: at.lng,
              city: null,
              country: null,
              types: [],
              rating: null,
              maps_uri: null,
            },
          ]
        : [];
    },
  };
}

function fakeTransit(answer: (req: RouteRequest) => RouteResult | null): TransitProvider & {
  calls: RouteRequest[];
} {
  const calls: RouteRequest[] = [];
  return {
    name: 'fake',
    configured: true,
    calls,
    async route(req) {
      calls.push(req);
      return answer(req);
    },
  };
}

function memoryStore(): TravelStore {
  const geo = new Map<string, LatLng | null>();
  const legs = new Map<string, RouteResult | null>();
  return {
    getGeo: async (q) => (geo.has(q) ? geo.get(q)! : undefined),
    putGeo: async (q, at) => void geo.set(q, at),
    getLeg: async (k) => (legs.has(k) ? legs.get(k)! : undefined),
    putLeg: async (k, r) => void legs.set(k, r),
  };
}

const train = (minutes: number): RouteResult => ({
  mode: 'TRANSIT',
  duration_minutes: minutes,
  distance_meters: null,
  transfers: 0,
  steps: [
    { mode: 'WALK', instruction: 'Walk', duration_minutes: 4, transit_line: null, departure_stop: null, arrival_stop: null },
    { mode: 'SUBWAY', instruction: 'Subway', duration_minutes: minutes - 6, transit_line: 'Kelana Jaya Line', departure_stop: 'KLCC', arrival_stop: 'Pasar Seni' },
    { mode: 'WALK', instruction: 'Walk', duration_minutes: 2, transit_line: null, departure_stop: null, arrival_stop: null },
  ],
  is_estimate: false,
  directions_url: 'https://maps.example/dir',
});

function deps(geo: GeoProvider, transit: TransitProvider, over: Partial<TravelDeps> = {}): TravelDeps {
  return {
    geo,
    transit,
    store: memoryStore(),
    markPlaceResolved: async () => {},
    now: () => new Date('2026-10-17T03:00:00Z'), // a Saturday
    ...over,
  };
}

const baseTable = {
  'kuala lumpur': KL,
  'klcc park, kuala lumpur': KLCC,
  'pavilion bukit bintang, kuala lumpur': PAVILION,
  'central market, kuala lumpur': CENTRAL_MARKET,
};

// --- the rules ---

describe('modeFor', () => {
  it('walks a short hop and rides anything longer', () => {
    assert.equal(modeFor(400), 'WALK');
    assert.equal(modeFor(1_199), 'WALK');
    assert.equal(modeFor(1_200), 'TRANSIT');
  });
});

describe('departureFor', () => {
  const now = new Date('2026-10-17T03:00:00Z'); // Saturday

  it('routes on the next same weekday, never the trip date itself', () => {
    // 3 Nov 2026 is a Tuesday — months out, past most published timetables.
    const at = new Date(departureFor({ start_time: null, estimated_duration_minutes: null, time_of_day: 'morning' }, '2026-11-03', KL.lng, now));
    assert.equal(at.getUTCDay(), 2);
    assert.ok(at.getTime() > now.getTime());
    assert.ok(at.getTime() - now.getTime() < 8 * 24 * 3_600_000);
  });

  it('leaves at the end of a stated activity, in local time', () => {
    // 09:00 for two hours in KL (lng ≈ UTC+7 by this rule) → 11:00 local.
    const at = new Date(departureFor({ start_time: '09:00', estimated_duration_minutes: 120, time_of_day: 'morning' }, null, KL.lng, now));
    assert.equal((at.getUTCHours() + 7) % 24, 11);
  });

  it('with no time, leaves when that part of the day ends', () => {
    const at = new Date(departureFor({ start_time: null, estimated_duration_minutes: null, time_of_day: 'evening' }, null, KL.lng, now));
    assert.equal((at.getUTCHours() + 7) % 24, 20);
  });
});

describe('legKey', () => {
  it('does not change as the routed date moves forward a week', () => {
    const a = legKey('TRANSIT', KLCC, CENTRAL_MARKET, '2026-10-20T04:30:00Z', KL.lng);
    const b = legKey('TRANSIT', KLCC, CENTRAL_MARKET, '2026-10-27T04:30:00Z', KL.lng);
    assert.equal(a, b);
  });
});

describe('vehicleFor', () => {
  it('names what the longest ride is on, and its line', () => {
    assert.deepEqual(vehicleFor(train(22)), { vehicle: 'train', line: 'Kelana Jaya Line' });
  });

  it('a transit answer that is all walking is a walk', () => {
    const walkOnly = { ...train(12), steps: [train(12).steps[0]!] };
    assert.equal(vehicleFor(walkOnly).vehicle, 'walk');
  });

  it('an estimate with no steps is transit, unnamed', () => {
    assert.deepEqual(vehicleFor({ ...train(20), steps: [], is_estimate: true }), { vehicle: 'transit', line: null });
  });
});

describe('withPlace', () => {
  it('adds the city unless the label already has it', () => {
    assert.equal(withPlace('Central Market', 'Kuala Lumpur'), 'Central Market, Kuala Lumpur');
    assert.equal(withPlace('Petronas, Kuala Lumpur', 'Kuala Lumpur'), 'Petronas, Kuala Lumpur');
    // Day locations read "Lisbon · Alfama"; the city is the part before.
    assert.equal(withPlace('Time Out Market', 'Lisbon · Cais do Sodré'), 'Time Out Market, Lisbon');
  });
});

// --- the whole thing, against fakes ---

describe('computeLegs', () => {
  it('walks a short hop and rides a longer one', async () => {
    const plan = planOf(
      block('a', { location: 'KLCC Park' }),
      block('b', { location: 'Pavilion Bukit Bintang' }),
      block('c', { location: 'Central Market', time_of_day: 'afternoon' }),
    );
    const transit = fakeTransit((req) => (req.mode === 'TRANSIT' ? train(22) : null));

    const [walk, ride] = await computeLegs(
      trip,
      plan,
      [],
      [
        { from_block_id: 'a', to_block_id: 'b' },
        { from_block_id: 'b', to_block_id: 'c' },
      ],
      deps(fakeGeo(baseTable), transit),
    );

    assert.equal(walk!.status, 'ok');
    assert.equal(walk!.vehicle, 'walk');
    assert.equal(walk!.is_estimate, true);

    assert.equal(ride!.status, 'ok');
    assert.equal(ride!.vehicle, 'train');
    assert.equal(ride!.line, 'Kelana Jaya Line');
    assert.equal(ride!.minutes, 22);
    assert.equal(ride!.is_estimate, false);
  });

  it('refuses a geocode that landed in another country', async () => {
    // "Fuji Ramen" resolving to the mountain is the planner-grade failure the
    // whole check exists for: a two-hour leg would be confidently wrong.
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { location: 'Fuji Ramen' }));
    const geo = fakeGeo({ ...baseTable, 'fuji ramen, kuala lumpur': FUJI });

    const [leg] = await computeLegs(trip, plan, [], [{ from_block_id: 'a', to_block_id: 'b' }], deps(geo, fakeTransit(() => train(30))));

    assert.equal(leg!.status, 'unplaced');
    assert.equal(leg!.unplaced, 'to');
    assert.equal(leg!.minutes, null);
  });

  it('looks each stop up near the destination, not anywhere on Earth', async () => {
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { location: 'Central Market' }));
    const geo = fakeGeo(baseTable);

    await computeLegs(trip, plan, [], [{ from_block_id: 'a', to_block_id: 'b' }], deps(geo, fakeTransit(() => train(20))));

    assert.deepEqual(geo.biases.get('central market, kuala lumpur'), KL);
    // The destination itself is the anchor, so it is looked up unbiased.
    assert.equal(geo.biases.get('kuala lumpur'), undefined);
  });

  it('says which end it could not place, and asks the router nothing', async () => {
    const plan = planOf(block('a', { location: 'Somewhere vague' }), block('b', { location: 'KLCC Park' }));
    const transit = fakeTransit(() => train(10));

    const [leg] = await computeLegs(trip, plan, [], [{ from_block_id: 'a', to_block_id: 'b' }], deps(fakeGeo(baseTable), transit));

    assert.equal(leg!.status, 'unplaced');
    assert.equal(leg!.unplaced, 'from');
    assert.equal(transit.calls.length, 0);
  });

  it('a saved place uses its stored point and is never geocoded again', async () => {
    const place = { id: 'plc_1', name: 'Jalan Alor', city: 'Kuala Lumpur', lat: PAVILION.lat, lng: PAVILION.lng, address: null } as Place;
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { from_place_id: 'plc_1', location: 'Jalan Alor' }));
    const geo = fakeGeo(baseTable);

    const [leg] = await computeLegs(trip, plan, [place], [{ from_block_id: 'a', to_block_id: 'b' }], deps(geo, fakeTransit(() => null)));

    assert.equal(leg!.status, 'ok');
    assert.ok(!geo.asked.some((q) => q.toLowerCase().includes('jalan alor')));
  });

  it('an unresolved saved place is geocoded once and written back', async () => {
    const place = { id: 'plc_1', name: 'Central Market', city: 'Kuala Lumpur', lat: null, lng: null, address: null } as Place;
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { from_place_id: 'plc_1' }));
    const written: LatLng[] = [];

    await computeLegs(trip, plan, [place], [{ from_block_id: 'a', to_block_id: 'b' }], deps(fakeGeo(baseTable), fakeTransit(() => train(20)), {
      markPlaceResolved: async (_p, at) => void written.push(at),
    }));

    assert.deepEqual(written, [CENTRAL_MARKET]);
  });

  it('two cards at the same spot have no leg to state', async () => {
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { location: 'KLCC Park', time_of_day: 'afternoon' }));
    const transit = fakeTransit(() => train(5));

    const [leg] = await computeLegs(trip, plan, [], [{ from_block_id: 'a', to_block_id: 'b' }], deps(fakeGeo(baseTable), transit));

    assert.equal(leg!.status, 'same_place');
    assert.equal(transit.calls.length, 0);
  });

  it('a router with no answer gives a flagged estimate, not a blank', async () => {
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { location: 'Central Market' }));

    const [leg] = await computeLegs(trip, plan, [], [{ from_block_id: 'a', to_block_id: 'b' }], deps(fakeGeo(baseTable), fakeTransit(() => null)));

    assert.equal(leg!.status, 'ok');
    assert.equal(leg!.is_estimate, true);
    assert.ok((leg!.minutes ?? 0) > 0);
  });

  it('a router that throws degrades the one leg, not the request', async () => {
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { location: 'Central Market' }));
    const transit: TransitProvider = { name: 'down', configured: true, route: async () => { throw new Error('HTTP 503'); } };

    const [leg] = await computeLegs(trip, plan, [], [{ from_block_id: 'a', to_block_id: 'b' }], deps(fakeGeo(baseTable), transit));

    assert.equal(leg!.status, 'ok');
    assert.equal(leg!.is_estimate, true);
  });

  it('a routed leg is kept, so the second ask never reaches the router', async () => {
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { location: 'Central Market' }));
    const transit = fakeTransit(() => train(22));
    const shared = deps(fakeGeo(baseTable), transit);
    const pair = [{ from_block_id: 'a', to_block_id: 'b' }];

    await computeLegs(trip, plan, [], pair, shared);
    await computeLegs(trip, plan, [], pair, shared);

    assert.equal(transit.calls.length, 1);
  });

  it('a block that is no longer in the plan is unplaced, not an error', async () => {
    const plan = planOf(block('a', { location: 'KLCC Park' }));

    const [leg] = await computeLegs(trip, plan, [], [{ from_block_id: 'a', to_block_id: 'gone' }], deps(fakeGeo(baseTable), fakeTransit(() => null)));

    assert.equal(leg!.status, 'unplaced');
    assert.equal(leg!.unplaced, 'to');
  });
});

describe('locateDay', () => {
  it('returns every activity, placed or not, in the day\'s order', async () => {
    const plan = planOf(
      block('a', { location: 'KLCC Park' }),
      block('b', { location: 'Somewhere vague' }),
      block('c', { location: 'Central Market' }),
    );

    const { points, anchor } = await locateDay(trip, plan, [], 1, deps(fakeGeo(baseTable), fakeTransit(() => null)));

    assert.deepEqual(anchor, KL);
    assert.deepEqual(points.map((p) => [p.block_id, p.status]), [
      ['a', 'placed'],
      ['b', 'unplaced'],
      ['c', 'placed'],
    ]);
    assert.equal(points[0]!.lat, KLCC.lat);
    // Unplaced means no coordinates at all — not a guess at the city centre.
    assert.equal(points[1]!.lat, null);
  });

  it('agrees with the travel times about where a stop is', async () => {
    // A pin on the map and the leg beside it come from one locator, so the
    // namesake abroad that the leg refuses is refused on the map too.
    const plan = planOf(block('a', { location: 'KLCC Park' }), block('b', { location: 'Fuji Ramen' }));
    const geo = fakeGeo({ ...baseTable, 'fuji ramen, kuala lumpur': FUJI });

    const { points } = await locateDay(trip, plan, [], 1, deps(geo, fakeTransit(() => null)));

    assert.equal(points[1]!.status, 'unplaced');
  });

  it('a day the plan does not have is empty, not an error', async () => {
    const { points } = await locateDay(trip, planOf(block('a')), [], 9, deps(fakeGeo(baseTable), fakeTransit(() => null)));
    assert.deepEqual(points, []);
  });
});
