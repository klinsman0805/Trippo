import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest } from '../../lib/errors.js';
import {
  attribution,
  geoProvider,
  LatLngSchema,
  proximityMatrix,
  RouteRequestSchema,
  SAME_DAY_RADIUS_M,
  transitProvider,
  TravelModeSchema,
} from '../geo/index.js';
import { listPlaces } from '../trips/places.repo.js';
import { getTrip } from '../trips/repo.js';

export async function transitRoutes(app: FastifyInstance): Promise<void> {
  app.post('/transit/route', async (req) => {
    const parsed = RouteRequestSchema.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid route request', parsed.error.flatten());
    }
    const provider = transitProvider();
    const result = await provider.route(parsed.data);

    return {
      provider: provider.name,
      attribution: attribution(),
      route: result,
      message: result ? null : 'No route found for this mode between these points.',
    };
  });

  /** Route between two free-text places, geocoding both first. */
  const NamedRouteBody = z.object({
    from: z.string().min(1),
    to: z.string().min(1),
    mode: TravelModeSchema.default('TRANSIT'),
    departure_time: z.string().datetime().optional(),
  });

  app.post('/transit/route-by-name', async (req) => {
    const parsed = NamedRouteBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Expected { from, to }', parsed.error.flatten());
    }
    const { from, to, mode, departure_time } = parsed.data;

    const geo = geoProvider();
    const [[origin], [destination]] = await Promise.all([
      geo.search(from, { limit: 1 }),
      geo.search(to, { limit: 1 }),
    ]);
    if (!origin) throw badRequest('geocode_failed', `Could not find a location for "${from}"`);
    if (!destination) throw badRequest('geocode_failed', `Could not find a location for "${to}"`);

    const route = await transitProvider().route({
      origin: { lat: origin.lat, lng: origin.lng },
      destination: { lat: destination.lat, lng: destination.lng },
      mode,
      departure_time,
    });

    return { origin, destination, route, attribution: attribution() };
  });

  const MatrixBody = z.object({
    origins: z.array(LatLngSchema).min(1).max(50),
    destinations: z.array(LatLngSchema).min(1).max(50),
  });

  /**
   * Pairwise proximity. Geometric, not routed — see the note on the trip
   * endpoint below for why.
   */
  app.post('/transit/proximity', async (req) => {
    const parsed = MatrixBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid proximity request', parsed.error.flatten());
    }
    return {
      same_day_radius_meters: SAME_DAY_RADIUS_M,
      entries: proximityMatrix(parsed.data.origins, parsed.data.destinations),
    };
  });

  /**
   * Proximity between a trip's own resolved places — the shape the planner
   * cares about when deciding which places share a day.
   *
   * This is straight-line distance, not routed travel time, and deliberately
   * so: grouping a day needs "near or not near", and the difference between a
   * 19- and a 23-minute ride never changes that answer. It costs nothing, has
   * no quota, and cannot fail.
   */
  app.get<{ Params: { id: string }; Querystring: { limit?: string } }>(
    '/trips/:id/places/proximity',
    async (req) => {
      getTrip(req.params.id);

      const limit = Math.min(Number(req.query.limit ?? 50) || 50, 50);
      const places = listPlaces(req.params.id)
        .filter((p) => p.resolved && p.lat != null && p.lng != null)
        .slice(0, limit);

      if (places.length < 2) {
        return {
          places,
          entries: [],
          same_day_radius_meters: SAME_DAY_RADIUS_M,
          message: 'Need at least 2 resolved places. Run POST /trips/:id/places/resolve first.',
        };
      }

      const points = places.map((p) => ({ lat: p.lat!, lng: p.lng! }));

      return {
        places: places.map((p) => ({ id: p.id, name: p.name, lat: p.lat, lng: p.lng })),
        entries: proximityMatrix(points, points),
        same_day_radius_meters: SAME_DAY_RADIUS_M,
        message: null,
      };
    },
  );
}
