import { env } from '../../config/env.js';
import { TtlCache } from '../../lib/cache.js';
import { fetchWithRetry, jsonOrThrow } from '../../lib/http.js';
import { UpstreamError } from '../../lib/errors.js';
import type { FlightItinerary, FlightLookup, ScheduleProvider } from './types.js';

/**
 * Cached lookups, because the quota is small and the answer barely moves.
 *
 * The free plan allows 600 requests a month, and this endpoint gets hit
 * repeatedly for the same thing: a user mistypes a date and corrects it, backs
 * out of the sheet and returns, or picks the wrong departure and taps Change.
 * A published schedule for a future date does not change hour to hour, so
 * serving those from memory costs nothing and is the difference between a
 * usable free tier and one exhausted in an afternoon.
 *
 * Six hours: long enough to cover a planning session and any number of
 * false starts, short enough that a genuine schedule change is picked up the
 * same day.
 */
const SCHEDULE_TTL_MS = 6 * 60 * 60 * 1000;
const scheduleCache = new TtlCache<FlightItinerary[]>(SCHEDULE_TTL_MS, 500);

/**
 * AeroDataBox — schedules only, no fares.
 *
 * Chosen for the already-booked flow because it answers the one question that
 * flow asks: what does this flight number do on this date. It publishes future
 * schedules months ahead, which fare-shopping APIs and live-tracking APIs both
 * handle badly.
 *
 * The decisive detail is `scheduledTime.local`: a wall-clock time at each
 * airport, which is exactly how this codebase stores flight times. A flight
 * leaving KUL at 16:55 (GMT+8) and returning at 18:45 (GMT+7) reads as the
 * boarding pass does, with no conversion and no chance of moving the trip a
 * day either side of midnight.
 */
export class AeroDataBoxProvider implements ScheduleProvider {
  readonly name = 'aerodatabox';

  get configured(): boolean {
    return Boolean(env.AERODATABOX_API_KEY);
  }

  async lookupFlights(query: FlightLookup): Promise<FlightItinerary[]> {
    if (!this.configured) {
      throw new UpstreamError('aerodatabox', 'AERODATABOX_API_KEY is not configured.');
    }

    // Keyed without `direction`, which only labels the leg and does not change
    // what the API is asked — otherwise the same flight would be fetched twice
    // for a return trip.
    return scheduleCache.wrap(
      `${query.flight_number}:${query.scheduled_date}`,
      () => this.fetchSchedules(query),
    ).then((itineraries) =>
      itineraries.map((it) => ({ ...it, direction: query.direction })),
    );
  }

  private async fetchSchedules(query: FlightLookup): Promise<FlightItinerary[]> {
    const url =
      `https://${env.AERODATABOX_HOST}/flights/number/` +
      `${encodeURIComponent(query.flight_number)}/${query.scheduled_date}` +
      // `Both` matches a flight that departs *or* arrives on the date, which is
      // what someone reading a boarding pass means by "my flight on the 26th"
      // even when it lands after midnight.
      '?dateLocalRole=Both&withAircraftImage=false&withLocation=false';

    let body: AeroDataBoxFlight[];
    try {
      const res = await fetchWithRetry(url, {
        provider: 'aerodatabox',
        headers: {
          'X-RapidAPI-Key': env.AERODATABOX_API_KEY!,
          'X-RapidAPI-Host': env.AERODATABOX_HOST,
        },
      });
      // 204 for a date the flight does not operate — AK892 flies KUL–DMK
      // most days but not every day, and that is an ordinary answer rather
      // than an error.
      body = (await jsonOrThrow<AeroDataBoxFlight[] | null>(res, 'aerodatabox')) ?? [];
    } catch (err) {
      // Nor is a 404 an outage: a mistyped digit is the common case here, and
      // both have to stay distinguishable from the service being down.
      if (err instanceof UpstreamError && err.upstreamStatus === 404) return [];
      throw err;
    }

    // A single number can operate more than once a day, which is why the
    // client asks which departure you were on rather than assuming.
    return (Array.isArray(body) ? body : []).flatMap((flight) => {
      const departs = localTime(flight.departure?.scheduledTime);
      const arrives = localTime(flight.arrival?.scheduledTime);
      const origin = flight.departure?.airport?.iata;
      const destination = flight.arrival?.airport?.iata;
      if (!departs || !arrives || !origin || !destination) return [];

      const minutes = minutesBetween(
        flight.departure?.scheduledTime?.utc,
        flight.arrival?.scheduledTime?.utc,
        departs,
        arrives,
      );

      return [
        {
          direction: query.direction,
          duration_minutes: minutes,
          stops: 0,
          segments: [
            {
              origin,
              destination,
              departs_at: departs,
              arrives_at: arrives,
              carrier_code: query.flight_number.slice(0, 2),
              flight_number: flight.number?.replace(/\s+/g, '') ?? query.flight_number,
              duration_minutes: minutes,
              aircraft: flight.aircraft?.model ?? null,
            },
          ],
        },
      ];
    });
  }
}

/**
 * `2026-09-26 16:55+08:00` → `2026-09-26T16:55:00`.
 *
 * The offset is dropped rather than applied: the rest of the codebase reads
 * flight times off the string as local to their own airport.
 */
function localTime(time: AeroDataBoxTime | undefined): string | null {
  const local = time?.local;
  if (!local) return null;
  const match = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})/.exec(local);
  return match ? `${match[1]}T${match[2]}:00` : null;
}

/**
 * Duration from the UTC pair when both are given, since local times across
 * two zones cannot be subtracted. Falls back to the local pair, which is right
 * whenever the flight does not cross a zone.
 */
function minutesBetween(
  utcFrom: string | undefined,
  utcTo: string | undefined,
  localFrom: string,
  localTo: string,
): number {
  const pair = utcFrom && utcTo
    ? [Date.parse(utcFrom.replace(' ', 'T')), Date.parse(utcTo.replace(' ', 'T'))]
    : [Date.parse(`${localFrom}Z`), Date.parse(`${localTo}Z`)];

  const ms = pair[1]! - pair[0]!;
  return Number.isFinite(ms) ? Math.max(Math.round(ms / 60_000), 0) : 0;
}

// --- the subset of the payload this adapter reads ---

interface AeroDataBoxTime {
  utc?: string;
  local?: string;
}

interface AeroDataBoxMovement {
  airport?: { iata?: string; name?: string; timeZone?: string };
  scheduledTime?: AeroDataBoxTime;
}

interface AeroDataBoxFlight {
  number?: string;
  status?: string;
  departure?: AeroDataBoxMovement;
  arrival?: AeroDataBoxMovement;
  aircraft?: { model?: string };
}
