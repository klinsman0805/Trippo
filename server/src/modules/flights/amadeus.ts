import { env } from '../../config/env.js';
import { fetchWithRetry, jsonOrThrow } from '../../lib/http.js';
import { UpstreamError } from '../../lib/errors.js';
import type {
  AirportMatch,
  FlightItinerary,
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

interface AmadeusLocation {
  iataCode: string;
  name: string;
  address?: { cityName?: string; countryName?: string };
  geoCode?: { latitude?: number; longitude?: number };
}
