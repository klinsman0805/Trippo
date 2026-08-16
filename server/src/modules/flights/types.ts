import { z } from 'zod';

export const FlightSearchSchema = z
  .object({
    origin: z.string().length(3).toUpperCase(),
    destination: z.string().length(3).toUpperCase(),
    departure_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    return_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    adults: z.number().int().min(1).max(9).default(1),
    cabin: z.enum(['ECONOMY', 'PREMIUM_ECONOMY', 'BUSINESS', 'FIRST']).default('ECONOMY'),
    non_stop: z.boolean().default(false),
    currency: z.string().length(3).default('USD'),
    max_results: z.number().int().min(1).max(50).default(10),
  })
  .refine(
    (v) => !v.return_date || v.return_date >= v.departure_date,
    { message: 'return_date must not be before departure_date', path: ['return_date'] },
  );

export type FlightSearch = z.infer<typeof FlightSearchSchema>;

/**
 * Looking up a flight the group has already booked.
 *
 * A different question from search: they are not shopping, they are telling us
 * when they land. So this takes the flight number off their booking and
 * returns the schedule — never a price, because the price is already paid and
 * inventing one would be worse than showing nothing.
 */
export const FlightLookupSchema = z.object({
  /** `MH123`, `mh 123`, `MH 0123` — normalised before it reaches a provider. */
  flight_number: z
    .string()
    .trim()
    .regex(/^[A-Za-z0-9]{2}\s?\d{1,4}$/, 'Expected a flight number like MH123')
    .transform((v) => v.replace(/\s+/g, '').toUpperCase()),
  scheduled_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  /** Set when looking up the way home, so the leg is labelled correctly. */
  direction: z.enum(['outbound', 'return']).default('outbound'),
});

export type FlightLookup = z.infer<typeof FlightLookupSchema>;

export interface FlightSegment {
  origin: string;
  destination: string;
  /** Local departure time at the origin airport, ISO 8601 without offset. */
  departs_at: string;
  arrives_at: string;
  carrier_code: string;
  flight_number: string;
  duration_minutes: number;
  aircraft: string | null;
}

export interface FlightItinerary {
  direction: 'outbound' | 'return';
  duration_minutes: number;
  stops: number;
  segments: FlightSegment[];
}

export interface FlightOffer {
  id: string;
  provider: string;
  /** True when prices are synthetic and must not be shown as real fares. */
  is_estimate: boolean;
  /**
   * True when this came from a booking the group already holds, rather than
   * from shopping. The price fields are then meaningless — they paid what they
   * paid, and we were not there — so the client must show no figure at all.
   */
  booked: boolean;
  price_total: number;
  price_per_traveler: number;
  currency: string;
  cabin: string;
  seats_available: number | null;
  itineraries: FlightItinerary[];
  /** When the provider's quote stops being valid, if it says. */
  last_ticketing_date: string | null;
}

export interface AirportMatch {
  iata: string;
  name: string;
  city: string | null;
  country: string | null;
  lat: number | null;
  lng: number | null;
}

export interface FlightProvider {
  readonly name: string;
  /** False when the adapter is configured but its credentials are missing. */
  readonly configured: boolean;
  search(query: FlightSearch): Promise<FlightOffer[]>;
  searchAirports(keyword: string): Promise<AirportMatch[]>;
  /**
   * Every departure that flight number makes on that date.
   *
   * A list rather than one result: a number can operate more than once a day,
   * and even when it doesn't, showing the times back lets the traveller
   * confirm they picked the right date before it becomes their trip. Empty
   * means no such flight that day — a wrong digit, usually, which has to stay
   * distinguishable from an outage.
   */
  lookupFlights(query: FlightLookup): Promise<FlightItinerary[]>;
}
