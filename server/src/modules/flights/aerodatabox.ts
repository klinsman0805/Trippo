import { env } from '../../config/env.js';
import { fetchWithRetry, jsonOrThrow } from '../../lib/http.js';
import { UpstreamError } from '../../lib/errors.js';
import type { FlightItinerary, FlightLookup, ScheduleProvider } from './types.js';

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
      body = await jsonOrThrow<AeroDataBoxFlight[]>(res, 'aerodatabox');
    } catch (err) {
      // No such flight that day is an ordinary answer — a mistyped digit,
      // usually — and must stay distinguishable from the service being down.
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
