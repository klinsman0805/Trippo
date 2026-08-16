import type {
  AirportMatch,
  FlightItinerary,
  FlightOffer,
  FlightProvider,
  FlightSearch,
} from './types.js';

/**
 * Deterministic offline flight provider.
 *
 * The point is to let the whole planning flow — date envelope, budget, day 1
 * pacing — be exercised without Amadeus credentials. Every offer it returns
 * carries `is_estimate: true`, and prices are a crude distance-free heuristic.
 * Nothing here should ever reach a user as a real fare.
 */
export class MockFlightProvider implements FlightProvider {
  readonly name = 'mock';
  readonly configured = true;

  async search(query: FlightSearch): Promise<FlightOffer[]> {
    const seed = hash(`${query.origin}${query.destination}${query.departure_date}`);
    const count = Math.min(query.max_results, 5);

    return Array.from({ length: count }, (_, i) => {
      const stops = i === 0 ? 0 : i % 2;
      const basePrice = 180 + (seed % 400) + i * 55 + stops * -30;
      const cabinMultiplier = CABIN_MULTIPLIER[query.cabin] ?? 1;
      const perTraveler = Math.round(basePrice * cabinMultiplier);
      const departHour = 7 + ((seed + i * 3) % 12);

      const itineraries: FlightItinerary[] = [
        this.buildItinerary('outbound', query.origin, query.destination, query.departure_date, departHour, stops, seed + i),
      ];

      if (query.return_date) {
        itineraries.push(
          this.buildItinerary('return', query.destination, query.origin, query.return_date, 9 + ((seed + i) % 10), stops, seed + i + 7),
        );
      }

      return {
        id: `mock-${seed}-${i}`,
        provider: this.name,
        is_estimate: true,
        price_total: perTraveler * query.adults * (query.return_date ? 2 : 1),
        price_per_traveler: perTraveler * (query.return_date ? 2 : 1),
        currency: query.currency,
        cabin: query.cabin,
        seats_available: 3 + (seed % 6),
        itineraries,
        last_ticketing_date: null,
      };
    });
  }

  async searchAirports(keyword: string): Promise<AirportMatch[]> {
    const needle = keyword.trim().toLowerCase();
    return SAMPLE_AIRPORTS.filter(
      (a) =>
        a.iata.toLowerCase().includes(needle) ||
        a.name.toLowerCase().includes(needle) ||
        (a.city ?? '').toLowerCase().includes(needle),
    ).slice(0, 10);
  }

  private buildItinerary(
    direction: 'outbound' | 'return',
    origin: string,
    destination: string,
    date: string,
    departHour: number,
    stops: number,
    seed: number,
  ): FlightItinerary {
    const legMinutes = 150 + (seed % 240);
    const totalMinutes = legMinutes * (stops + 1) + stops * 90;

    const segments = Array.from({ length: stops + 1 }, (_, s) => {
      const start = departHour * 60 + s * (legMinutes + 90);
      const via = stops > 0 && s === 0 ? 'HUB' : null;
      return {
        origin: s === 0 ? origin : (via ?? 'HUB'),
        destination: s === stops ? destination : 'HUB',
        departs_at: addMinutes(date, start),
        arrives_at: addMinutes(date, start + legMinutes),
        carrier_code: 'XX',
        flight_number: `XX${100 + ((seed + s) % 800)}`,
        duration_minutes: legMinutes,
        aircraft: null,
      };
    });

    return { direction, duration_minutes: totalMinutes, stops, segments };
  }
}

const CABIN_MULTIPLIER: Record<string, number> = {
  ECONOMY: 1,
  PREMIUM_ECONOMY: 1.8,
  BUSINESS: 3.4,
  FIRST: 5.5,
};

/** `2026-03-04` + 615 minutes → `2026-03-04T10:15:00`. */
function addMinutes(date: string, minutes: number): string {
  const base = new Date(`${date}T00:00:00Z`);
  base.setUTCMinutes(base.getUTCMinutes() + minutes);
  return base.toISOString().slice(0, 19);
}

function hash(input: string): number {
  let h = 2166136261;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return Math.abs(h);
}

const SAMPLE_AIRPORTS: AirportMatch[] = [
  { iata: 'KUL', name: 'Kuala Lumpur International', city: 'Kuala Lumpur', country: 'Malaysia', lat: 2.7456, lng: 101.7099 },
  { iata: 'SIN', name: 'Singapore Changi', city: 'Singapore', country: 'Singapore', lat: 1.3644, lng: 103.9915 },
  { iata: 'HND', name: 'Tokyo Haneda', city: 'Tokyo', country: 'Japan', lat: 35.5494, lng: 139.7798 },
  { iata: 'NRT', name: 'Tokyo Narita', city: 'Tokyo', country: 'Japan', lat: 35.772, lng: 140.3929 },
  { iata: 'ICN', name: 'Seoul Incheon', city: 'Seoul', country: 'South Korea', lat: 37.4602, lng: 126.4407 },
  { iata: 'BKK', name: 'Bangkok Suvarnabhumi', city: 'Bangkok', country: 'Thailand', lat: 13.69, lng: 100.7501 },
  { iata: 'HKG', name: 'Hong Kong International', city: 'Hong Kong', country: 'Hong Kong', lat: 22.308, lng: 113.9185 },
  { iata: 'TPE', name: 'Taiwan Taoyuan', city: 'Taipei', country: 'Taiwan', lat: 25.0777, lng: 121.2328 },
  { iata: 'LHR', name: 'London Heathrow', city: 'London', country: 'United Kingdom', lat: 51.47, lng: -0.4543 },
  { iata: 'JFK', name: 'New York John F. Kennedy', city: 'New York', country: 'United States', lat: 40.6413, lng: -73.7781 },
  { iata: 'LIS', name: 'Lisbon Humberto Delgado', city: 'Lisbon', country: 'Portugal', lat: 38.7756, lng: -9.1354 },
  { iata: 'CDG', name: 'Paris Charles de Gaulle', city: 'Paris', country: 'France', lat: 49.0097, lng: 2.5479 },
];
