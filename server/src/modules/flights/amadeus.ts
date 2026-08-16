import { env } from '../../config/env.js';
import { fetchWithRetry, jsonOrThrow } from '../../lib/http.js';
import { UpstreamError } from '../../lib/errors.js';
import type {
  AirportMatch,
  FlightItinerary,
  FlightLookup,
  FlightOffer,
  FlightProvider,
  FlightSearch,
  FlightSegment,
} from './types.js';

/**
 * Amadeus Self-Service adapter (Flight Offers Search v2 + Airport & City Search).
 *
 * Point AMADEUS_BASE_URL at test.api.amadeus.com while developing — the test
 * environment returns a cached subset of real inventory, so prices are
 * directional rather than bookable. `is_estimate` is set accordingly, and the
 * client must surface that: showing a test-environment fare as a real price is
 * exactly the kind of false confidence the planner spec forbids.
 */
export class AmadeusProvider implements FlightProvider {
  readonly name = 'amadeus';

  private token: { value: string; expiresAt: number } | null = null;

  get configured(): boolean {
    return Boolean(env.AMADEUS_CLIENT_ID && env.AMADEUS_CLIENT_SECRET);
  }

  private get isTestEnvironment(): boolean {
    return env.AMADEUS_BASE_URL.includes('test.api');
  }

  private async accessToken(): Promise<string> {
    // Refresh 60s early so a token never expires mid-flight.
    if (this.token && this.token.expiresAt > Date.now() + 60_000) return this.token.value;

    if (!this.configured) {
      throw new UpstreamError('amadeus', 'Amadeus credentials are not configured.');
    }

    const res = await fetchWithRetry(`${env.AMADEUS_BASE_URL}/v1/security/oauth2/token`, {
      method: 'POST',
      provider: 'amadeus',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: env.AMADEUS_CLIENT_ID!,
        client_secret: env.AMADEUS_CLIENT_SECRET!,
      }),
    });

    const body = await jsonOrThrow<{ access_token: string; expires_in: number }>(
      res,
      'amadeus',
    );
    this.token = {
      value: body.access_token,
      expiresAt: Date.now() + body.expires_in * 1000,
    };
    return this.token.value;
  }

  private async get<T>(path: string, params: Record<string, string>): Promise<T> {
    const token = await this.accessToken();
    const url = `${env.AMADEUS_BASE_URL}${path}?${new URLSearchParams(params)}`;
    const res = await fetchWithRetry(url, {
      provider: 'amadeus',
      headers: { Authorization: `Bearer ${token}` },
    });
    return jsonOrThrow<T>(res, 'amadeus');
  }

  async search(query: FlightSearch): Promise<FlightOffer[]> {
    const params: Record<string, string> = {
      originLocationCode: query.origin,
      destinationLocationCode: query.destination,
      departureDate: query.departure_date,
      adults: String(query.adults),
      travelClass: query.cabin,
      currencyCode: query.currency,
      max: String(query.max_results),
    };
    if (query.return_date) params.returnDate = query.return_date;
    if (query.non_stop) params.nonStop = 'true';

    const body = await this.get<{ data?: AmadeusOffer[] }>('/v2/shopping/flight-offers', params);
    return (body.data ?? []).map((offer) => this.toOffer(offer, query));
  }

  /**
   * On-Demand Flight Status, which answers "what does this flight number do on
   * this date" — a schedule question, not a shopping one.
   *
   * A 404 or an empty payload means no such flight that day. That is returned
   * as null rather than thrown: a mistyped digit is the ordinary case here and
   * must not read to the user as the service being down.
   */
  async lookupFlight(query: FlightLookup): Promise<FlightItinerary | null> {
    const carrierCode = query.flight_number.slice(0, 2);
    const number = query.flight_number.slice(2).replace(/^0+/, '');

    let body: { data?: AmadeusScheduledFlight[] };
    try {
      body = await this.get<{ data?: AmadeusScheduledFlight[] }>('/v2/schedule/flights', {
        carrierCode,
        flightNumber: number,
        scheduledDepartureDate: query.scheduled_date,
      });
    } catch (err) {
      if (err instanceof UpstreamError && err.upstreamStatus === 404) return null;
      throw err;
    }

    const points = body.data?.[0]?.flightPoints ?? [];
    if (points.length < 2) return null;

    const first = points[0]!;
    const last = points[points.length - 1]!;
    const departsAt = first.departure?.timings?.[0]?.value;
    const arrivesAt = last.arrival?.timings?.[0]?.value;
    if (!departsAt || !arrivesAt) return null;

    // Amadeus returns local times with an offset; the rest of this codebase
    // treats flight times as local-to-their-airport and reads them off the
    // string, so the offset is trimmed rather than converted.
    const departs = departsAt.slice(0, 19);
    const arrives = arrivesAt.slice(0, 19);

    return {
      direction: query.direction,
      duration_minutes: minutesBetween(departs, arrives),
      // The schedule feed describes one marketed flight number; a codeshare
      // with a stop still arrives when it arrives, which is all the envelope
      // needs.
      stops: Math.max(points.length - 2, 0),
      segments: [
        {
          origin: first.iataCode,
          destination: last.iataCode,
          departs_at: departs,
          arrives_at: arrives,
          carrier_code: carrierCode,
          flight_number: query.flight_number,
          duration_minutes: minutesBetween(departs, arrives),
          aircraft: null,
        },
      ],
    };
  }

  async searchAirports(keyword: string): Promise<AirportMatch[]> {
    const body = await this.get<{ data?: AmadeusLocation[] }>('/v1/reference-data/locations', {
      keyword,
      subType: 'AIRPORT,CITY',
      'page[limit]': '10',
    });

    return (body.data ?? []).map((loc) => ({
      iata: loc.iataCode,
      name: loc.name,
      city: loc.address?.cityName ?? null,
      country: loc.address?.countryName ?? null,
      lat: loc.geoCode?.latitude ?? null,
      lng: loc.geoCode?.longitude ?? null,
    }));
  }

  private toOffer(raw: AmadeusOffer, query: FlightSearch): FlightOffer {
    const itineraries: FlightItinerary[] = (raw.itineraries ?? []).map((it, index) => {
      const segments: FlightSegment[] = (it.segments ?? []).map((seg) => ({
        origin: seg.departure.iataCode,
        destination: seg.arrival.iataCode,
        departs_at: seg.departure.at,
        arrives_at: seg.arrival.at,
        carrier_code: seg.carrierCode,
        flight_number: `${seg.carrierCode}${seg.number}`,
        duration_minutes: parseIsoDuration(seg.duration),
        aircraft: seg.aircraft?.code ?? null,
      }));

      return {
        direction: index === 0 ? 'outbound' : 'return',
        duration_minutes: parseIsoDuration(it.duration),
        stops: Math.max(segments.length - 1, 0),
        segments,
      };
    });

    const total = Number(raw.price?.grandTotal ?? raw.price?.total ?? 0);

    return {
      id: raw.id,
      provider: this.name,
      is_estimate: this.isTestEnvironment,
      booked: false,
      price_total: total,
      price_per_traveler: query.adults > 0 ? round2(total / query.adults) : total,
      currency: raw.price?.currency ?? query.currency,
      cabin:
        raw.travelerPricings?.[0]?.fareDetailsBySegment?.[0]?.cabin ?? query.cabin,
      seats_available: raw.numberOfBookableSeats ?? null,
      itineraries,
      last_ticketing_date: raw.lastTicketingDate ?? null,
    };
  }
}

/** `PT12H30M` → 750. Amadeus uses ISO 8601 durations throughout. */
export function parseIsoDuration(value: string | undefined): number {
  if (!value) return 0;
  const match = /^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?$/.exec(value);
  if (!match) return 0;
  const [, d, h, m] = match;
  return Number(d ?? 0) * 1440 + Number(h ?? 0) * 60 + Number(m ?? 0);
}

const round2 = (n: number) => Math.round(n * 100) / 100;

// Minimal shapes for the fields this adapter reads.
interface AmadeusOffer {
  id: string;
  numberOfBookableSeats?: number;
  lastTicketingDate?: string;
  price?: { total?: string; grandTotal?: string; currency?: string };
  itineraries?: {
    duration?: string;
    segments?: {
      departure: { iataCode: string; at: string };
      arrival: { iataCode: string; at: string };
      carrierCode: string;
      number: string;
      duration?: string;
      aircraft?: { code?: string };
    }[];
  }[];
  travelerPricings?: { fareDetailsBySegment?: { cabin?: string }[] }[];
}

/** Subset of the On-Demand Flight Status payload this adapter reads. */
interface AmadeusScheduledFlight {
  flightPoints?: {
    iataCode: string;
    departure?: { timings?: { qualifier: string; value: string }[] };
    arrival?: { timings?: { qualifier: string; value: string }[] };
  }[];
}

interface AmadeusLocation {
  iataCode: string;
  name: string;
  address?: { cityName?: string; countryName?: string };
  geoCode?: { latitude?: number; longitude?: number };
}

/** Both are local wall-clock strings, so this is plain arithmetic on the date. */
function minutesBetween(from: string, to: string): number {
  const ms = Date.parse(`${to}Z`) - Date.parse(`${from}Z`);
  return Number.isFinite(ms) ? Math.max(Math.round(ms / 60_000), 0) : 0;
}
