import { estimateRoute, haversineMetres } from '../geo/index.js';
import type {
  GeoProvider,
  LatLng,
  RouteResult,
  TransitProvider,
  TravelMode,
} from '../geo/index.js';
import type { Plan, PlanBlock } from '../../schemas/plan.js';
import type { Place, Trip } from '../../schemas/trip.js';

/**
 * Travel time between consecutive activities.
 *
 * The question this answers is the one a generated itinerary never does: can
 * this day physically happen. Every rule below leans the same way — a missing
 * number is acceptable, a confident wrong one is not, because the app's whole
 * claim is that what it shows is true.
 */

/** Below this, the leg is walked. Transit for a ten-minute stroll is noise. */
export const WALK_UNDER_M = 1_200;

/**
 * A geocode further than this from every trip destination is rejected.
 *
 * Free-text geocoding of a planner's label ("Breakfast at Village Park") will
 * sometimes land on a namesake in another country. Showing a two-hour leg to
 * it would be exactly the failure the research found in other planners —
 * Narita answered with Mount Fuji — so the leg is left unknown instead.
 */
export const MAX_FROM_DESTINATION_M = 60_000;

/** Two activities closer than this are the same place: no leg to state. */
export const SAME_PLACE_M = 80;

export type Vehicle = 'walk' | 'train' | 'bus' | 'ferry' | 'car' | 'transit';

export interface LegRequest {
  from_block_id: string;
  to_block_id: string;
}

export interface TravelLeg {
  from_block_id: string;
  to_block_id: string;
  /**
   * `ok` has a duration. `same_place` has nothing worth printing. `unplaced`
   * means one end could not be put on a map with any confidence, and the
   * client says so rather than inventing a figure.
   */
  status: 'ok' | 'same_place' | 'unplaced';
  /** Which end failed, when one did. */
  unplaced: 'from' | 'to' | 'both' | null;
  minutes: number | null;
  distance_meters: number | null;
  vehicle: Vehicle | null;
  /** The line the longest ride is on — "Kelana Jaya Line" — when known. */
  line: string | null;
  /**
   * Straight-line arithmetic rather than a routed answer. The client words
   * these as "about", never as a timetable.
   */
  is_estimate: boolean;
  directions_url: string | null;
}

/** What `computeLegs` needs from the world. Injected so tests need no network. */
export interface TravelDeps {
  geo: GeoProvider;
  transit: TransitProvider;
  store: TravelStore;
  /** Persist a geocode onto a saved place, so it is only ever looked up once. */
  markPlaceResolved(place: Place, at: LatLng, address: string | null, providerId: string): void;
  now: () => Date;
  warn?: (message: string) => void;
}

export interface TravelStore {
  /** `undefined` for "never asked", `null` for "asked, nothing found". */
  getGeo(query: string): LatLng | null | undefined;
  putGeo(query: string, at: LatLng | null): void;
  getLeg(key: string): RouteResult | null | undefined;
  putLeg(key: string, result: RouteResult | null): void;
}

/**
 * Legs for the requested pairs of the plan's blocks.
 *
 * Pairs come from the client because only the client knows what it is
 * drawing: hiding optional activities changes which cards are adjacent, and a
 * server-side guess at the order would be a second, disagreeing account of it.
 */
export async function computeLegs(
  trip: Trip,
  plan: Plan,
  places: Place[],
  pairs: LegRequest[],
  deps: TravelDeps,
): Promise<TravelLeg[]> {
  const blocks = new Map<string, { block: PlanBlock; day: Plan['itinerary'][number] }>();
  for (const day of plan.itinerary) {
    for (const block of day.blocks) blocks.set(block.id, { block, day });
  }
  const placesById = new Map(places.map((p) => [p.id, p]));

  // One lookup per distinct query per request, however many legs share it.
  const inFlight = new Map<string, Promise<LatLng | null>>();
  const geocode = (query: string, bias?: LatLng): Promise<LatLng | null> => {
    const key = normaliseQuery(query);
    if (!key) return Promise.resolve(null);
    let pending = inFlight.get(key);
    if (!pending) {
      pending = geocodeOnce(key, bias, deps);
      inFlight.set(key, pending);
    }
    return pending;
  };

  const anchors = (
    await Promise.all(trip.destinations.filter(Boolean).map((d) => geocode(d)))
  ).filter((a): a is LatLng => a !== null);

  // Biasing toward the trip's first destination is what turns "Village Park"
  // into the one in Damansara rather than the first namesake on Earth. The
  // plausibility check below still has the last word.
  const bias = anchors[0];

  const plausible = (at: LatLng | null): LatLng | null => {
    if (!at) return null;
    // No anchor at all means the destination itself could not be found; the
    // check has nothing to measure against, so it does not get to veto.
    if (anchors.length === 0) return at;
    return anchors.some((a) => haversineMetres(a, at) <= MAX_FROM_DESTINATION_M)
      ? at
      : null;
  };

  const locate = async (block: PlanBlock, dayLocation: string): Promise<LatLng | null> => {
    const place = block.from_place_id ? placesById.get(block.from_place_id) : undefined;
    if (place) {
      if (place.lat != null && place.lng != null) {
        return plausible({ lat: place.lat, lng: place.lng });
      }
      const at = plausible(
        await geocode(withPlace(place.name, place.city ?? dayLocation ?? trip.destinations[0]), bias),
      );
      if (at) deps.markPlaceResolved(place, at, place.address, `geo:${at.lat},${at.lng}`);
      return at;
    }
    const label = block.location.trim() || block.activity.trim();
    return plausible(await geocode(withPlace(label, dayLocation || trip.destinations[0]), bias));
  };

  return runLimited(pairs, 2, async (pair): Promise<TravelLeg> => {
    const from = blocks.get(pair.from_block_id);
    const to = blocks.get(pair.to_block_id);
    if (!from || !to) return unplaced(pair, !from && !to ? 'both' : !from ? 'from' : 'to');

    const [a, b] = await Promise.all([
      locate(from.block, from.day.location),
      locate(to.block, to.day.location),
    ]);
    if (!a || !b) return unplaced(pair, !a && !b ? 'both' : !a ? 'from' : 'to');

    const distance = haversineMetres(a, b);
    if (distance < SAME_PLACE_M) {
      return { ...base(pair), status: 'same_place', distance_meters: Math.round(distance) };
    }

    const mode = modeFor(distance);
    const departure = departureFor(from.block, from.day.date, a.lng, deps.now());
    const route = await routeOnce(mode, a, b, departure, deps);
    return fromRoute(pair, route);
  });
}

// --- the rules, each small enough to test on its own ---

export function modeFor(distanceMetres: number): TravelMode {
  return distanceMetres < WALK_UNDER_M ? 'WALK' : 'TRANSIT';
}

/**
 * When the traveller would leave [from], as an RFC3339 instant.
 *
 * Transit routing needs a time, and the real one is unknowable: trip dates are
 * often months out, past the end of any published timetable. So the leg is
 * routed on the *next* occurrence of the same weekday, at the hour the
 * traveller would plausibly leave — a weekday morning and a Sunday night have
 * different services, and that is the difference worth keeping.
 *
 * The local hour is converted with an offset from longitude. It is crude (KL
 * reads as UTC+7, not +8) but its only job is to land inside service hours
 * rather than at 3am, and it does that everywhere it matters.
 */
export function departureFor(
  from: Pick<PlanBlock, 'start_time' | 'estimated_duration_minutes' | 'time_of_day'>,
  dayDate: string | null,
  lng: number,
  now: Date,
): string {
  let minutes: number;
  const start = parseClock(from.start_time);
  if (start != null) {
    minutes = start + (from.estimated_duration_minutes ?? 90);
  } else {
    // When you would be leaving that part of the day, not arriving in it.
    minutes = { morning: 11 * 60 + 30, afternoon: 16 * 60, evening: 20 * 60, anytime: 13 * 60 }[
      from.time_of_day
    ];
  }

  const target = dayDate ? new Date(`${dayDate}T00:00:00Z`).getUTCDay() : null;
  const day = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
  if (target != null && Number.isFinite(target)) {
    while (day.getUTCDay() !== target) day.setUTCDate(day.getUTCDate() + 1);
  }

  const offsetMinutes = Math.round(lng / 15) * 60;
  return new Date(day.getTime() + (minutes - offsetMinutes) * 60_000).toISOString();
}

/**
 * Stable across days: keyed by weekday and local hour rather than the date,
 * because the date in [departureFor] moves forward every day the trip is
 * opened and the answer, for practical purposes, does not.
 */
export function legKey(mode: TravelMode, a: LatLng, b: LatLng, departure: string, lng: number): string {
  const local = new Date(Date.parse(departure) + Math.round(lng / 15) * 3_600_000);
  return `${mode}:${fmt(a)}->${fmt(b)}:${local.getUTCDay()}-${local.getUTCHours()}`;
}

/** What the traveller is mostly on: the longest non-walking step decides it. */
export function vehicleFor(route: RouteResult): { vehicle: Vehicle; line: string | null } {
  if (route.mode === 'WALK') return { vehicle: 'walk', line: null };
  if (route.mode === 'DRIVE') return { vehicle: 'car', line: null };
  if (route.mode === 'BICYCLE') return { vehicle: 'transit', line: null };

  const rides = route.steps.filter((s) => s.mode !== 'WALK' && s.mode !== 'WALKING');
  if (route.steps.length > 0 && rides.length === 0) return { vehicle: 'walk', line: null };

  const longest = rides.reduce<(typeof rides)[number] | null>(
    (best, s) => (!best || s.duration_minutes > best.duration_minutes ? s : best),
    null,
  );
  if (!longest) return { vehicle: 'transit', line: null };
  return { vehicle: vehicleFromMode(longest.mode), line: longest.transit_line };
}

function vehicleFromMode(mode: string): Vehicle {
  const m = mode.toUpperCase();
  if (/BUS|COACH/.test(m)) return 'bus';
  if (/FERRY|BOAT/.test(m)) return 'ferry';
  if (/RAIL|SUBWAY|METRO|TRAM|TRAIN|MONORAIL|FUNICULAR|SUBURBAN|LONG_DISTANCE|HIGHSPEED/.test(m)) {
    return 'train';
  }
  if (/CAR|TAXI|DRIVE/.test(m)) return 'car';
  return 'transit';
}

/** "Breakfast at Village Park" → "Breakfast at Village Park, Kuala Lumpur". */
export function withPlace(label: string, city: string | null | undefined): string {
  const text = label.trim();
  const place = (city ?? '').split('·')[0]?.trim() ?? '';
  if (!text) return '';
  if (!place || text.toLowerCase().includes(place.toLowerCase())) return text;
  return `${text}, ${place}`;
}

export function normaliseQuery(query: string): string {
  return query.trim().toLowerCase().replace(/\s+/g, ' ');
}

// --- plumbing ---

async function geocodeOnce(
  query: string,
  bias: LatLng | undefined,
  deps: TravelDeps,
): Promise<LatLng | null> {
  const known = deps.store.getGeo(query);
  if (known !== undefined) return known;
  try {
    const [match] = await deps.geo.search(query, bias ? { limit: 1, bias } : { limit: 1 });
    const at = match ? { lat: match.lat, lng: match.lng } : null;
    deps.store.putGeo(query, at);
    return at;
  } catch (err) {
    // Not remembered: a geocoder that was down is not a place that was not
    // found, and the next request should get to ask again.
    deps.warn?.(`[travel] geocode failed for "${query}": ${messageOf(err)}`);
    return null;
  }
}

async function routeOnce(
  mode: TravelMode,
  a: LatLng,
  b: LatLng,
  departure: string,
  deps: TravelDeps,
): Promise<RouteResult> {
  const key = legKey(mode, a, b, departure, a.lng);
  const known = deps.store.getLeg(key);
  if (known) return known;

  const request = { origin: a, destination: b, mode, departure_time: departure };
  let route: RouteResult | null;
  try {
    route = await deps.transit.route(request);
  } catch (err) {
    deps.warn?.(`[travel] routing failed, estimating instead: ${messageOf(err)}`);
    return estimateRoute(request);
  }
  // A router with no answer between two real points in one city is a gap in
  // its coverage, not proof the trip is impossible — so it is estimated, and
  // flagged as one. Only a real answer is kept for next time.
  if (!route) return estimateRoute(request);
  if (!route.is_estimate) deps.store.putLeg(key, route);
  return route;
}

function fromRoute(pair: LegRequest, route: RouteResult): TravelLeg {
  const { vehicle, line } = vehicleFor(route);
  return {
    ...base(pair),
    status: 'ok',
    minutes: Math.max(route.duration_minutes, 1),
    distance_meters: route.distance_meters,
    vehicle,
    line,
    is_estimate: route.is_estimate,
    directions_url: route.directions_url,
  };
}

function base(pair: LegRequest): TravelLeg {
  return {
    from_block_id: pair.from_block_id,
    to_block_id: pair.to_block_id,
    status: 'ok',
    unplaced: null,
    minutes: null,
    distance_meters: null,
    vehicle: null,
    line: null,
    is_estimate: false,
    directions_url: null,
  };
}

function unplaced(pair: LegRequest, which: 'from' | 'to' | 'both'): TravelLeg {
  return { ...base(pair), status: 'unplaced', unplaced: which };
}

/** Order-preserving map with at most [limit] calls in flight. */
async function runLimited<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const out = new Array<R>(items.length);
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i]!);
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return out;
}

function parseClock(value: string | null | undefined): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(value ?? '');
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

const fmt = (p: LatLng) => `${p.lat.toFixed(5)},${p.lng.toFixed(5)}`;
const messageOf = (err: unknown) => (err instanceof Error ? err.message : String(err));
