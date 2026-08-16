import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { MemberInputSchema, TripInputSchema, TripPatchSchema } from '../../schemas/trip.js';
import { badRequest } from '../../lib/errors.js';
import * as repo from './repo.js';
import * as placesRepo from './places.repo.js';

const parse = <S extends z.ZodTypeAny>(schema: S, body: unknown): z.output<S> => {
  const result = schema.safeParse(body);
  if (!result.success) {
    throw badRequest('validation_error', 'Request body failed validation', result.error.flatten());
  }
  return result.data;
};

export async function tripRoutes(app: FastifyInstance): Promise<void> {
  app.get('/trips', async () => ({ trips: repo.listTrips() }));

  app.post('/trips', async (req, reply) => {
    const trip = repo.createTrip(parse(TripInputSchema, req.body));
    reply.code(201);
    return { trip };
  });

  app.get<{ Params: { id: string } }>('/trips/:id', async (req) => ({
    trip: repo.getTrip(req.params.id),
  }));

  app.patch<{ Params: { id: string } }>('/trips/:id', async (req) => ({
    trip: repo.updateTrip(req.params.id, parse(TripPatchSchema, req.body)),
  }));

  app.delete<{ Params: { id: string } }>('/trips/:id', async (req, reply) => {
    repo.deleteTrip(req.params.id);
    reply.code(204);
  });

  // --- members ---

  app.post<{ Params: { id: string } }>('/trips/:id/members', async (req, reply) => {
    repo.getTrip(req.params.id);
    const member = repo.addMember(req.params.id, parse(MemberInputSchema, req.body));
    reply.code(201);
    return { member };
  });

  app.patch<{ Params: { id: string; memberId: string } }>(
    '/trips/:id/members/:memberId',
    async (req) => ({
      member: repo.updateMember(
        req.params.memberId,
        parse(MemberInputSchema.partial(), req.body),
      ),
      // Editing pace or access needs changes what the planner reconciled, so
      // the client should offer a regenerate rather than leave stale conflicts.
      conflicts_may_be_stale: true,
    }),
  );

  app.delete<{ Params: { id: string; memberId: string } }>(
    '/trips/:id/members/:memberId',
    async (req, reply) => {
      repo.deleteMember(req.params.memberId);
      reply.code(204);
    },
  );

  // --- saved places (the candidate pool the planner draws from) ---

  app.get<{ Params: { id: string } }>('/trips/:id/places', async (req) => ({
    places: placesRepo.listPlaces(req.params.id),
  }));

  const PlaceBody = z.object({
    name: z.string().min(1),
    category: z.string().nullish(),
    city: z.string().nullish(),
    country: z.string().nullish(),
    address: z.string().nullish(),
    lat: z.number().nullish(),
    lng: z.number().nullish(),
    google_place_id: z.string().nullish(),
    why: z.string().nullish(),
    tags: z.array(z.string()).default([]),
  });

  app.post<{ Params: { id: string } }>('/trips/:id/places', async (req, reply) => {
    repo.getTrip(req.params.id);
    const place = placesRepo.addPlace(req.params.id, parse(PlaceBody, req.body));
    reply.code(201);
    return { place };
  });

  app.delete<{ Params: { placeId: string } }>(
    '/trips/:id/places/:placeId',
    async (req, reply) => {
      placesRepo.deletePlace(req.params.placeId);
      reply.code(204);
    },
  );
}
