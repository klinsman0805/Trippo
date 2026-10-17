import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest, notFound } from '../../lib/errors.js';
import { attribution, geoProvider, transitProvider } from '../geo/index.js';
import { getLatestPlan } from '../planner/service.js';
import { listPlaces, markResolved } from '../trips/places.repo.js';
import { getTrip } from '../trips/repo.js';
import { computeLegs } from './legs.js';
import { sqliteTravelStore } from './store.js';

const TravelBody = z.object({
  /**
   * Consecutive activities as the client draws them. Capped well above a real
   * day — a day with forty legs is not a day — so one request cannot queue a
   * free router for minutes.
   */
  legs: z
    .array(z.object({ from_block_id: z.string().min(1), to_block_id: z.string().min(1) }))
    .min(1)
    .max(40),
});

export async function travelRoutes(app: FastifyInstance): Promise<void> {
  /**
   * Travel time for each requested pair of the latest plan's activities.
   *
   * A POST rather than a GET because the pairs are the client's: which cards
   * are adjacent depends on whether optional activities are shown, and only
   * the screen knows that.
   */
  app.post<{ Params: { id: string } }>('/trips/:id/plan/travel', async (req) => {
    const trip = getTrip(req.params.id);
    const parsed = TravelBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      throw badRequest('validation_error', 'Expected { legs: [{ from_block_id, to_block_id }] }', parsed.error.flatten());
    }

    const record = getLatestPlan(trip.id);
    if (!record) throw notFound('no_plan_yet', 'This trip has no plan yet.');

    const legs = await computeLegs(trip, record.plan, listPlaces(trip.id), parsed.data.legs, {
      geo: geoProvider(),
      transit: transitProvider(),
      store: sqliteTravelStore,
      markPlaceResolved: (place, at, address, providerId) =>
        markResolved(place.id, {
          lat: at.lat,
          lng: at.lng,
          address,
          google_place_id: providerId,
        }),
      now: () => new Date(),
      warn: (message) => req.log.warn(message),
    });

    return { legs, attribution: attribution() };
  });
}
