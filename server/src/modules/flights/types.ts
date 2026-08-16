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
}
