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

export { SAME_DAY_RADIUS_M } from './osm.js';
export * from './types.js';
