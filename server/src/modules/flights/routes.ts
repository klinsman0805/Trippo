import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest } from '../../lib/errors.js';
import { getTrip, updateTrip } from '../trips/repo.js';
import {
  deleteSelection,
  flightProvider,
  listSelections,
  scheduleProvider,
  saveSelection,
} from './index.js';
import { deriveTripEnvelope } from './envelope.js';
import { FlightLookupSchema, FlightSearchSchema, type FlightOffer } from './types.js';

export async function flightRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Querystring: { q?: string } }>('/flights/airports', async (req) => {
    const q = req.query.q?.trim();
    if (!q || q.length < 2) {
      throw badRequest('missing_query', 'Provide ?q= with at least 2 characters.');
    }
    return { airports: await flightProvider().searchAirports(q) };
  });

  /**
   * Look up a flight the group has already booked.
   *
   * Returns offer-shaped records so the rest of the pipeline — envelope,
   * selection, short days — is identical to a searched flight. The difference
   * is `booked: true` and zeroed prices, which the client renders as "already
   * booked" rather than as a fare. Making up a number here would put a figure
   * in the budget that nobody is going to pay.
   *
   * A list, because the traveller picks the departure they actually took.
   */
  app.post('/flights/by-number', async (req) => {
    const parsed = FlightLookupSchema.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest(
        'validation_error',
        'Expected { flight_number, scheduled_date }',
        parsed.error.flatten(),
      );
    }

    const provider = scheduleProvider();
    const itineraries = await provider.lookupFlights(parsed.data);

    // An empty list is a normal answer, not an error: a mistyped digit is the
    // common case and the client shows it inline against the field.
    const offers: FlightOffer[] = itineraries.map((itinerary, i) => ({
      id: `booked-${parsed.data.flight_number}-${parsed.data.scheduled_date}-${i}`,
      provider: provider.name,
      is_estimate: false,
      booked: true,
      price_total: 0,
      price_per_traveler: 0,
      currency: 'USD',
      cabin: 'ECONOMY',
      seats_available: null,
      itineraries: [itinerary],
      last_ticketing_date: null,
    }));

    return { found: offers.length > 0, offers };
  });

  app.post('/flights/search', async (req) => {
    const parsed = FlightSearchSchema.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid flight search', parsed.error.flatten());
    }
    const provider = flightProvider();
    const offers = await provider.search(parsed.data);
    return {
      provider: provider.name,
      // Surfaced so the client can label estimates rather than imply real fares.
      estimates_only: offers.every((o) => o.is_estimate),
      offers,
    };
  });

  /**
   * What an offer would do to the trip, without committing to it.
   *
   * The consequence sheet asks the group to confirm before the dates move, so
   * this derives the envelope without persisting a selection — better than
   * writing and rolling back if they choose differently.
   */
  app.post('/flights/envelope-preview', async (req) => {
    const parsed = z.object({ offer: z.record(z.unknown()) }).safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Expected { offer }', parsed.error.flatten());
    }
    return {
      date_envelope: deriveTripEnvelope([parsed.data.offer as never]),
    };
  });

  app.get<{ Params: { id: string } }>('/trips/:id/flights', async (req) => {
    const selections = listSelections(req.params.id);
    return {
      selections,
      date_envelope: deriveTripEnvelope(selections.map((s) => s.offer)),
    };
  });

  const SelectBody = z.object({
    direction: z.enum(['outbound', 'return']),
    member_id: z.string().nullish(),
    offer: z.record(z.unknown()),
    /** Write the derived arrival/departure dates onto the trip. */
    apply_dates_to_trip: z.boolean().default(true),
  });

  app.post<{ Params: { id: string } }>('/trips/:id/flights', async (req, reply) => {
    getTrip(req.params.id);

    const parsed = SelectBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid selection', parsed.error.flatten());
    }

    const selection = saveSelection(
      req.params.id,
      parsed.data.direction,
      parsed.data.offer as never,
      parsed.data.member_id,
    );

    const selections = listSelections(req.params.id);
    const envelope = deriveTripEnvelope(selections.map((s) => s.offer));

    // Selecting flights is what pins a trip's dates — that's the whole point of
    // the flight step, so by default it writes back to the trip.
    if (envelope && parsed.data.apply_dates_to_trip) {
      updateTrip(req.params.id, {
        start_date: envelope.start_date,
        end_date: envelope.end_date,
        date_flexible: false,
      });
    }

    reply.code(201);
    return { selection, date_envelope: envelope };
  });

  app.delete<{ Params: { selectionId: string } }>(
    '/trips/:id/flights/:selectionId',
    async (req, reply) => {
      deleteSelection(req.params.selectionId);
      reply.code(204);
    },
  );
}
