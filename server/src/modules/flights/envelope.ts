import type { FlightOffer } from './types.js';

/**
 * What the selected flights do to the shape of the trip.
 *
 * The design's rule: a short day must *reduce* what gets planned, not carry a
 * warning on top of a full day. So this works out which time-of-day slots
 * actually survive at each end, and the planner is told to plan only those.
 */

export type Slot = 'morning' | 'afternoon' | 'evening';
export const ALL_SLOTS: Slot[] = ['morning', 'afternoon', 'evening'];

export interface ShortDay {
  /** 1-based day number within the trip. */
  day: number;
  date: string;
  /** Which slots can actually be used. */
  usable_slots: Slot[];
  lost_slots: Slot[];
  reason: 'late_arrival' | 'early_departure';
  /** Local time that caused it, e.g. "13:15". */
  at: string;
  /** Plain-language explanation, rendered on the amber band. */
  note: string;
}

export interface TripEnvelope {
  start_date: string;
  end_date: string;
  arrival_local_time: string | null;
  departure_local_time: string | null;
  /** Calendar days between arrival and departure, inclusive. */
  total_days: number;
  /**
   * Days worth planning — [total_days] minus any day with no usable slot.
   *
   * A departure morning that leaves at 10:00 is not a day the planner should
   * fill; dropping it is what stops the itinerary ending on an empty page.
   */
  planning_days: number;
  short_days: ShortDay[];
}

/**
 * Cut-offs, in local time at the destination.
 *
 * These are deliberately conservative and account for getting out of an
 * airport: landing at 13:15 does not mean you are in the city at 13:15. The
 * design's worked example — land 13:15, "nothing before 15:00" — is roughly a
 * 90-minute allowance, which is what these thresholds encode.
 */
const ARRIVAL_KILLS_MORNING_AFTER = 9 * 60 + 30; // in the city by ~11:00
const ARRIVAL_KILLS_AFTERNOON_AFTER = 15 * 60 + 30; // in the city by ~17:00
const ARRIVAL_KILLS_EVENING_AFTER = 20 * 60; // nothing left but sleep

/**
 * A red-eye landing in the small hours costs the morning too — not because
 * there is no time, but because nobody is doing anything at 06:00 after a
 * 02:00 arrival. Anything landing before this is treated as sleep-first.
 */
const RED_EYE_BEFORE = 5 * 60;

const DEPARTURE_KILLS_MORNING_BEFORE = 12 * 60;
const DEPARTURE_KILLS_AFTERNOON_BEFORE = 17 * 60;
const DEPARTURE_KILLS_EVENING_BEFORE = 21 * 60;

export function deriveTripEnvelope(offers: FlightOffer[]): TripEnvelope | null {
  const itineraries = offers.flatMap((o) => o.itineraries);
  const outbound = itineraries.find((i) => i.direction === 'outbound');
  const inbound = itineraries.find((i) => i.direction === 'return');

  const arrival = outbound?.segments.at(-1)?.arrives_at;
  if (!arrival) return null;

  const departure = inbound?.segments[0]?.departs_at ?? null;

  const startDate = arrival.slice(0, 10);
  const endDate = departure?.slice(0, 10) ?? startDate;
  const totalDays = daysBetweenInclusive(startDate, endDate);

  const shortDays: ShortDay[] = [];

  if (departure && endDate === startDate) {
    // A day trip: both ends squeeze the same day, so they merge into one
    // entry rather than contradicting each other.
    const sameDay = sameDayShort(arrival, departure, startDate);
    if (sameDay) shortDays.push(sameDay);
  } else {
    const arrivalShort = arrivalShortDay(arrival, startDate);
    if (arrivalShort) shortDays.push(arrivalShort);

    if (departure) {
      const departureShort = departureShortDay(departure, endDate, totalDays);
      if (departureShort) shortDays.push(departureShort);
    }
  }

  const emptyDays = shortDays.filter((d) => d.usable_slots.length === 0).length;

  return {
    start_date: startDate,
    end_date: endDate,
    arrival_local_time: arrival.slice(11, 16),
    departure_local_time: departure?.slice(11, 16) ?? null,
    total_days: totalDays,
    planning_days: Math.max(totalDays - emptyDays, 1),
    short_days: shortDays,
  };
}

/** Which slots survive a given arrival time. */
function slotsAfterArrival(arrival: string): Slot[] {
  const minutes = minutesOfDay(arrival);
  const lost: Slot[] = [];

  // A red-eye is early by the clock but late by the body.
  if (minutes < RED_EYE_BEFORE) {
    lost.push('morning');
  } else {
    if (minutes > ARRIVAL_KILLS_MORNING_AFTER) lost.push('morning');
    if (minutes > ARRIVAL_KILLS_AFTERNOON_AFTER) lost.push('afternoon');
    if (minutes > ARRIVAL_KILLS_EVENING_AFTER) lost.push('evening');
  }

  return ALL_SLOTS.filter((s) => !lost.includes(s));
}

/** Which slots survive a given departure time. */
function slotsBeforeDeparture(departure: string): Slot[] {
  const minutes = minutesOfDay(departure);
  const lost: Slot[] = [];
  if (minutes < DEPARTURE_KILLS_MORNING_BEFORE) lost.push('morning');
  if (minutes < DEPARTURE_KILLS_AFTERNOON_BEFORE) lost.push('afternoon');
  if (minutes < DEPARTURE_KILLS_EVENING_BEFORE) lost.push('evening');
  return ALL_SLOTS.filter((s) => !lost.includes(s));
}

function arrivalShortDay(arrival: string, date: string): ShortDay | null {
  const usable = slotsAfterArrival(arrival);
  if (usable.length === ALL_SLOTS.length) return null;

  const at = arrival.slice(11, 16);
  const isRedEye = minutesOfDay(arrival) < RED_EYE_BEFORE;

  return {
    day: 1,
    date,
    usable_slots: usable,
    lost_slots: ALL_SLOTS.filter((s) => !usable.includes(s)),
    reason: 'late_arrival',
    at,
    note: usable.length === 0
      ? `The flight lands at ${at}. Day 1 is the transfer and sleep, nothing else.`
      : isRedEye
        ? `The flight lands at ${at}, so the morning goes to sleeping it off. ` +
          `Only the ${formatList(usable)} are usable.`
        : `The flight lands at ${at} and the transfer into town takes about an hour. ` +
          `Only the ${formatList(usable)} are usable.`,
  };
}

/** A trip that arrives and leaves on the same day, squeezed from both ends. */
function sameDayShort(
  arrival: string,
  departure: string,
  date: string,
): ShortDay | null {
  const afterArrival = slotsAfterArrival(arrival);
  const beforeDeparture = slotsBeforeDeparture(departure);
  const usable = ALL_SLOTS.filter(
    (s) => afterArrival.includes(s) && beforeDeparture.includes(s),
  );
  if (usable.length === ALL_SLOTS.length) return null;

  const from = arrival.slice(11, 16);
  const to = departure.slice(11, 16);

  return {
    day: 1,
    date,
    usable_slots: usable,
    lost_slots: ALL_SLOTS.filter((s) => !usable.includes(s)),
    reason: 'late_arrival',
    at: from,
    note: usable.length === 0
      ? `Landing ${from} and leaving ${to} leaves no usable time on the ground.`
      : `You land at ${from} and leave at ${to}, so only the ` +
        `${formatList(usable)} are usable.`,
  };
}

function departureShortDay(
  departure: string,
  date: string,
  dayNumber: number,
): ShortDay | null {
  const usable = slotsBeforeDeparture(departure);
  if (usable.length === ALL_SLOTS.length) return null;

  const at = departure.slice(11, 16);

  return {
    day: dayNumber,
    date,
    usable_slots: usable,
    lost_slots: ALL_SLOTS.filter((s) => !usable.includes(s)),
    reason: 'early_departure',
    at,
    note:
      usable.length === 0
        ? `A ${at} departure means leaving for the airport before the day starts. ` +
          `This day is packing and the transfer, nothing else.`
        : `A ${at} departure ends the day early. Only the ${formatList(usable)} are usable.`,
  };
}

const minutesOfDay = (iso: string): number =>
  Number(iso.slice(11, 13)) * 60 + Number(iso.slice(14, 16));

function daysBetweenInclusive(start: string, end: string): number {
  const ms = Date.parse(`${end}T00:00:00Z`) - Date.parse(`${start}T00:00:00Z`);
  return Math.max(Math.round(ms / 86_400_000), 0) + 1;
}

function formatList(slots: Slot[]): string {
  if (slots.length === 1) return slots[0]!;
  return `${slots.slice(0, -1).join(', ')} and ${slots.at(-1)}`;
}

/**
 * The envelope as planner instructions.
 *
 * Phrased as a hard constraint on which slots exist, because the failure mode
 * is a model that plans a full day and appends "note: you land at 13:15" —
 * which is exactly the padding the design forbids.
 */
export function envelopeInstructions(envelope: TripEnvelope): string[] {
  if (envelope.short_days.length === 0) return [];

  const lines = [
    `Plan ${envelope.planning_days} day(s), numbered from 1.`,
    'The selected flights shorten the following days. Plan ONLY the slots listed as usable — ' +
      'do not schedule anything in a lost slot, and do not pad a short day to make it look full. ' +
      'A short day with two blocks is correct.',
  ];

  const dropped = envelope.short_days.filter((d) => d.usable_slots.length === 0);
  if (dropped.length) {
    lines.push(
      `Do not produce a day entry at all for: ${dropped
        .map((d) => d.date)
        .join(', ')} — there is no usable time on those dates.`,
    );
  }

  for (const short of envelope.short_days) {
    lines.push(
      `- Day ${short.day} (${short.date}): usable slots are ` +
        `${short.usable_slots.length ? short.usable_slots.join(', ') : 'NONE'}. ` +
        `${short.note}`,
    );
  }

  return lines;
}
