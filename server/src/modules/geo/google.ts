import { env } from '../../config/env.js';
import { TtlCache } from '../../lib/cache.js';
import { fetchWithRetry, jsonOrThrow } from '../../lib/http.js';
import type {
  GeoProvider,
  LatLng,
  ResolvedPlace,
  RouteRequest,
  RouteResult,
  TransitProvider,
  TransitStep,
} from './types.js';

/**
 * Google Maps Platform, behind the same interfaces as the OSM stack.
 *
 * Kept so the two can be compared on real queries — Google's place ranking and
 * transit coverage are better, at the cost of a key and per-call billing. Field
 * masks stay minimal because they drive that billing directly.
 */

const PLACES_BASE = 'https://places.googleapis.com/v1';
const ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';

const searchCache = new TtlCache<ResolvedPlace[]>(15 * 60_000);
const routeCache = new TtlCache<RouteResult | null>(10 * 60_000);

const SEARCH_FIELDS = [
  'places.id',
  'places.displayName',
  'places.formattedAddress',
  'places.location',
  'places.types',
  'places.rating',
  'places.googleMapsUri',
  'places.addressComponents',
].join(',');

const ROUTE_FIELDS = [
  'routes.duration',
  'routes.distanceMeters',
  'routes.legs.steps.navigationInstruction',
  'routes.legs.steps.staticDuration',
  'routes.legs.steps.travelMode',
  'routes.legs.steps.transitDetails',
].join(',');

export class GoogleGeoProvider implements GeoProvider {
  readonly name = 'google-places';

  get configured(): boolean {
    return Boolean(env.GOOGLE_MAPS_API_KEY);
  }

  async search(
    query: string,
    opts: { bias?: LatLng; limit?: number; language?: string } = {},
  ): Promise<ResolvedPlace[]> {
    const { bias, limit = 5, language = 'en' } = opts;
    const key = `google:${query}:${language}:${bias?.lat ?? ''},${bias?.lng ?? ''}`;

    return searchCache.wrap(key, async () => {
      const body: Record<string, unknown> = {
        textQuery: query,
        languageCode: language,
        maxResultCount: limit,
      };
      if (bias) {
        body.locationBias = {
          circle: {
            center: { latitude: bias.lat, longitude: bias.lng },
            radius: 30_000,
          },
        };
      }

      const res = await fetchWithRetry(`${PLACES_BASE}/places:searchText`, {
        method: 'POST',
        provider: 'google-places',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': env.GOOGLE_MAPS_API_KEY!,
          'X-Goog-FieldMask': SEARCH_FIELDS,
        },
        body: JSON.stringify(body),
      });

      const json = await jsonOrThrow<{ places?: GooglePlace[] }>(res, 'google-places');
      return (json.places ?? []).map(toResolvedPlace);
    });
  }
}

export class GoogleTransitProvider implements TransitProvider {
  readonly name = 'google-routes';

  get configured(): boolean {
    return Boolean(env.GOOGLE_MAPS_API_KEY);
  }

  async route(req: RouteRequest): Promise<RouteResult | null> {
    const key = `groutes:${req.mode}:${req.origin.lat},${req.origin.lng}->${req.destination.lat},${req.destination.lng}:${req.departure_time ?? ''}`;

    return routeCache.wrap(key, async () => {
      const body: Record<string, unknown> = {
        origin: { location: { latLng: toLatLng(req.origin) } },
        destination: { location: { latLng: toLatLng(req.destination) } },
        travelMode: req.mode,
        units: 'METRIC',
      };
      // Routes rejects departureTime for WALK and BICYCLE.
      if (req.mode === 'TRANSIT' || req.mode === 'DRIVE') {
        body.departureTime = req.departure_time ?? nextReasonableDeparture();
      }

      const res = await fetchWithRetry(ROUTES_URL, {
        method: 'POST',
        provider: 'google-routes',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': env.GOOGLE_MAPS_API_KEY!,
          'X-Goog-FieldMask': ROUTE_FIELDS,
        },
        body: JSON.stringify(body),
      });

      const json = await jsonOrThrow<{ routes?: GoogleRoute[] }>(res, 'google-routes');
      const first = json.routes?.[0];
      // No route is a legitimate answer, not an error.
      if (!first) return null;

      const steps = (first.legs ?? []).flatMap((leg) => (leg.steps ?? []).map(toStep));

      return {
        mode: req.mode,
        duration_minutes: secondsToMinutes(first.duration),
        distance_meters: first.distanceMeters ?? null,
        transfers: Math.max(steps.filter((s) => s.transit_line).length - 1, 0),
        steps,
        is_estimate: false,
        directions_url:
          `https://www.google.com/maps/dir/?api=1` +
          `&origin=${req.origin.lat},${req.origin.lng}` +
          `&destination=${req.destination.lat},${req.destination.lng}` +
          `&travelmode=${req.mode.toLowerCase()}`,
      };
    });
  }
}

function toResolvedPlace(p: GooglePlace): ResolvedPlace {
  const component = (type: string) =>
    p.addressComponents?.find((c) => c.types?.includes(type))?.longText ?? null;

  return {
    place_id: p.id,
    name: p.displayName?.text ?? '(unnamed)',
    address: p.formattedAddress ?? null,
    lat: p.location?.latitude ?? 0,
    lng: p.location?.longitude ?? 0,
    city: component('locality') ?? component('postal_town'),
    country: component('country'),
    types: p.types ?? [],
    rating: p.rating ?? null,
    maps_uri: p.googleMapsUri ?? null,
  };
}

function toStep(step: GoogleStep): TransitStep {
  const transit = step.transitDetails;
  const line = transit?.transitLine;
  return {
    mode: step.travelMode ?? 'UNKNOWN',
    instruction: step.navigationInstruction?.instructions ?? '',
    duration_minutes: secondsToMinutes(step.staticDuration),
    transit_line: line?.nameShort ?? line?.name ?? null,
    departure_stop: transit?.stopDetails?.departureStop?.name ?? null,
    arrival_stop: transit?.stopDetails?.arrivalStop?.name ?? null,
  };
}

/** Routes returns durations as `"1234s"`. */
function secondsToMinutes(value: string | undefined): number {
  if (!value) return 0;
  return Math.round(Number(value.replace('s', '')) / 60);
}

function nextReasonableDeparture(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  d.setUTCHours(10, 0, 0, 0);
  return d.toISOString();
}

const toLatLng = (p: LatLng) => ({ latitude: p.lat, longitude: p.lng });

interface GooglePlace {
  id: string;
  displayName?: { text?: string };
  formattedAddress?: string;
  location?: { latitude?: number; longitude?: number };
  types?: string[];
  rating?: number;
  googleMapsUri?: string;
  addressComponents?: { longText?: string; types?: string[] }[];
}

interface GoogleRoute {
  duration?: string;
  distanceMeters?: number;
  legs?: { steps?: GoogleStep[] }[];
}

interface GoogleStep {
  travelMode?: string;
  staticDuration?: string;
  navigationInstruction?: { instructions?: string };
  transitDetails?: {
    stopDetails?: {
      departureStop?: { name?: string };
      arrivalStop?: { name?: string };
    };
    transitLine?: { name?: string; nameShort?: string };
  };
}
