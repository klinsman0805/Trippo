import { z } from 'zod';

/**
 * Provider-neutral geo types.
 *
 * Both the OSM stack and Google produce these shapes, so routes and the planner
 * never know which one is configured.
 */

export const LatLngSchema = z.object({ lat: z.number(), lng: z.number() });
export type LatLng = z.infer<typeof LatLngSchema>;

export const TravelModeSchema = z.enum(['TRANSIT', 'WALK', 'DRIVE', 'BICYCLE']);
export type TravelMode = z.infer<typeof TravelModeSchema>;

export interface ResolvedPlace {
  /** Provider-scoped id — `photon:node/123` or a Google place id. */
  place_id: string;
  name: string;
  address: string | null;
  lat: number;
  lng: number;
  city: string | null;
  country: string | null;
  /** Provider's own categorisation, kept verbatim for debugging. */
  types: string[];
  /** Google-only; null on OSM, which has no rating data. */
  rating: number | null;
  /** A link the user can open for hours and reviews. */
  maps_uri: string | null;
}

export interface TransitStep {
  mode: string;
  instruction: string;
  duration_minutes: number;
  transit_line: string | null;
  departure_stop: string | null;
  arrival_stop: string | null;
}

export interface RouteResult {
  mode: TravelMode;
  duration_minutes: number;
  distance_meters: number | null;
  transfers: number | null;
  steps: TransitStep[];
  /**
   * True when the duration is a straight-line estimate rather than a real
   * routed answer. The UI must not present an estimate as a timetable.
   */
  is_estimate: boolean;
  /** Deep link to a maps app for live, turn-by-turn directions. */
  directions_url: string;
}

export interface ProximityEntry {
  origin_index: number;
  destination_index: number;
  /** Straight-line distance — what day-grouping actually needs. */
  distance_meters: number;
  /** Rough walking time from that distance. Not a routed duration. */
  walk_minutes: number;
  /** Whether these two are close enough to sit in the same day. */
  same_day_feasible: boolean;
}

export const RouteRequestSchema = z.object({
  origin: LatLngSchema,
  destination: LatLngSchema,
  mode: TravelModeSchema.default('TRANSIT'),
  /** RFC3339. Transit routing is meaningless without a time. */
  departure_time: z.string().datetime().optional(),
});
export type RouteRequest = z.infer<typeof RouteRequestSchema>;

export interface GeoProvider {
  readonly name: string;
  /** False when the provider needs credentials it doesn't have. */
  readonly configured: boolean;
  search(
    query: string,
    opts?: { bias?: LatLng; limit?: number; language?: string },
  ): Promise<ResolvedPlace[]>;
}

export interface TransitProvider {
  readonly name: string;
  readonly configured: boolean;
  /** Null when no route exists — a legitimate answer, not an error. */
  route(req: RouteRequest): Promise<RouteResult | null>;
}

/** Attribution the UI must display. ODbL requires it for OSM-derived data. */
export interface ProviderAttribution {
  text: string;
  url: string;
}
