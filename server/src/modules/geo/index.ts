import { env } from '../../config/env.js';
import { unavailable } from '../../lib/errors.js';
import { GoogleGeoProvider, GoogleTransitProvider } from './google.js';
import {
  haversineMetres,
  OSM_ATTRIBUTION,
  PhotonGeoProvider,
  SAME_DAY_RADIUS_M,
  TransitousProvider,
  walkMinutes,
} from './osm.js';
import type {
  GeoProvider,
  LatLng,
  ProviderAttribution,
  ProximityEntry,
  TransitProvider,
} from './types.js';

/**
 * Provider selection, driven by MAPS_PROVIDER.
 *
 * `osm` is the default: free, no key, no quota. `google` is kept behind the
 * same interfaces so the two can be compared without touching route code.
 */

/**
 * Types that say "somewhere you can go", in both providers' vocabularies.
 *
 * Google marks every venue `establishment`, usually alongside
 * `point_of_interest`. Photon reports the OSM key, where a venue is an
 * `amenity`, `tourism`, `shop` or `leisure`.
 */
const A_VENUE = new Set([
  'establishment',
  'point_of_interest',
  'amenity',
  'tourism',
  'shop',
  'leisure',
]);

/**
 * Types that describe where something *is* rather than somewhere to go.
 *
 * Google's `route` is the one that started this: asked for Pantai Malindo, a
 * beach it does not list, it answered with the road that runs past it. A road
 * is a plausible-looking answer to any query, which is exactly what makes it
 * dangerous — the place would have been stored as resolved, carrying the
 * beach's name and the road's coordinates, and the card would then have
 * claimed it came from the traveller's own link.
 */
const NOT_A_VENUE = new Set([
  // Google
  'route',
  'street_address',
  'postal_code',
  'political',
  'locality',
  'sublocality',
  'neighborhood',
  'administrative_area_level_1',
  'administrative_area_level_2',
  // OSM, via Photon
  'highway',
  'boundary',
  'place',
  'landuse',
  'waterway',
  'railway',
]);

/**
 * Whether a geocoding result is a place at all, rather than a road or an area.
 *
 * Deliberately not a name comparison. A saved post romanises as it likes — a
 * Balik Pulau tea house came back as "Qing Huan Chinese Tea House" for a query
 * of "Kwang Lian Teahouse" — so judging by name would throw away the matches
 * that make the lookup worth doing. What the provider says the result *is*
 * does not have that problem.
 *
 * Silence is not refusal: a provider that reports no types at all is taken at
 * its word, because refusing on no evidence loses real places.
 */
export function isVisitable(types: string[]): boolean {
  if (!types.length) return true;
  if (types.some((t) => A_VENUE.has(t))) return true;
  return !types.some((t) => NOT_A_VENUE.has(t));
}

let geo: GeoProvider | null = null;
let transit: TransitProvider | null = null;

export function geoProvider(): GeoProvider {
  if (geo) return geo;

  if (env.MAPS_PROVIDER === 'google') {
    const google = new GoogleGeoProvider();
    if (!google.configured) {
      throw unavailable(
        'maps_unavailable',
        'MAPS_PROVIDER is "google" but GOOGLE_MAPS_API_KEY is not set. Set it, or switch MAPS_PROVIDER to "osm".',
      );
    }
    geo = google;
  } else {
    geo = new PhotonGeoProvider();
  }
  return geo;
}

export function transitProvider(): TransitProvider {
  if (transit) return transit;

  if (env.MAPS_PROVIDER === 'google') {
    const google = new GoogleTransitProvider();
    if (!google.configured) {
      throw unavailable(
        'maps_unavailable',
        'MAPS_PROVIDER is "google" but GOOGLE_MAPS_API_KEY is not set. Set it, or switch MAPS_PROVIDER to "osm".',
      );
    }
    transit = google;
  } else {
    transit = new TransitousProvider();
  }
  return transit;
}

/** Attribution the client must display for the active provider. */
export function attribution(): ProviderAttribution | null {
  return env.MAPS_PROVIDER === 'google' ? null : { ...OSM_ATTRIBUTION };
}

/**
 * Pairwise proximity between places.
 *
 * Deliberately geometric rather than routed. Grouping a day needs "near or not
 * near", and straight-line distance answers that — with no API call, no quota,
 * no element cap and no failure mode. Provider choice does not affect it.
 */
export function proximityMatrix(
  origins: LatLng[],
  destinations: LatLng[],
): ProximityEntry[] {
  const entries: ProximityEntry[] = [];

  for (let i = 0; i < origins.length; i++) {
    for (let j = 0; j < destinations.length; j++) {
      const from = origins[i]!;
      const to = destinations[j]!;
      const metres = haversineMetres(from, to);

      entries.push({
        origin_index: i,
        destination_index: j,
        distance_meters: Math.round(metres),
        walk_minutes: walkMinutes(metres),
        same_day_feasible: metres <= SAME_DAY_RADIUS_M,
      });
    }
  }

  return entries;
}

export { SAME_DAY_RADIUS_M, estimateRoute, haversineMetres } from './osm.js';
export * from './types.js';
