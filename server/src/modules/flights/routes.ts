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
import { reconcileDays } from '../planner/blocks.js';
import { FlightLookupSchema, FlightSearchSchema, type FlightOffer } from './types.js';

/**
 * Dates around the one asked for that the provider says this flight operates.
 *
 * A week either side: far enough to catch a day misremembered, near enough
 * that the list stays readable. Costs one extra request, and only on the
 * failure path.
 */
async function nearbyDates(
  provider: { operatingDates?: (n: string, from: string, to: string) => Promise<string[] | null> },
  flightNumber: string,
  around: string,
): Promise<string[]> {
  if (!provider.operatingDates) return [];
  const shift = (days: number) =>
    new Date(Date.parse(`${around}T00:00:00Z`) + days * 86_400_000)
      .toISOString()
      .slice(0, 10);
  const dates = await provider.operatingDates(flightNumber, shift(-7), shift(7));
  return dates ?? [];
}

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

    if (offers.length > 0) return { found: true, offers, nearby_dates: [] };

    // Empty is not the end of the road. Schedule feeds have gaps — this one is
    // missing dates for AK893 that Cirium carries — so we offer the dates we
    // do hold and let the traveller overrule us either way. Telling someone
    // holding a valid ticket to "check the number" is the worst answer here.
    const nearby = await nearbyDates(provider, parsed.data.flight_number, parsed.data.scheduled_date);
    return { found: false, offers: [], nearby_dates: nearby };
  });

  const ManualFlightBody = z.object({
    flight_number: z.string().trim().min(2).max(8),
    origin: z.string().length(3).toUpperCase(),
    destination: z.string().length(3).toUpperCase(),
    /** Local wall-clock at each airport, as everywhere else in this codebase. */
    departs_at: z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/),
    arrives_at: z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/),
    direction: z.enum(['outbound', 'return']).default('outbound'),
  });

  /**
   * A flight the traveller entered themselves.
   *
   * The escape hatch for when our schedule source does not have their flight.
   * They are reading a boarding pass; it outranks our data. The result is
   * shaped exactly like a looked-up one so nothing downstream — envelope,
   * short days, the itinerary — can tell the difference.
   */
  app.post('/flights/manual', async (req) => {
    const parsed = ManualFlightBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid flight details', parsed.error.flatten());
    }
    const d = parsed.data;
    const pad = (t: string) => (t.length === 16 ? `${t}:00` : t);
    const departs = pad(d.departs_at);
    const arrives = pad(d.arrives_at);

    const offer: FlightOffer = {
      id: `manual-${d.flight_number}-${departs}`,
      provider: 'traveller',
      is_estimate: false,
      booked: true,
      price_total: 0,
      price_per_traveler: 0,
      currency: 'USD',
      cabin: 'ECONOMY',
      seats_available: null,
      itineraries: [
        {
          direction: d.direction,
          // Local times in two zones cannot be subtracted, and we were not
          // told the zones — so no duration is claimed rather than a wrong one.
          duration_minutes: 0,
          stops: 0,
          segments: [
            {
              origin: d.origin,
              destination: d.destination,
              departs_at: departs,
              arrives_at: arrives,
              carrier_code: d.flight_number.slice(0, 2).toUpperCase(),
              flight_number: d.flight_number.replace(/\s+/g, '').toUpperCase(),
              duration_minutes: 0,
              aircraft: null,
            },
          ],
        },
      ],
      last_ticketing_date: null,
    };

    return { found: true, offers: [offer], nearby_dates: [] };
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
      // And the itinerary has to follow. Changing 26–30 Sep to 26–29 left a
      // day 5 on screen that the trip no longer had.
      reconcileDays(req.params.id);
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
