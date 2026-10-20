import type { Plan } from '../../schemas/plan.js';
import type { HoursSource, Place } from '../../schemas/trip.js';

/**
 * Whether the plan sends anyone somewhere shut.
 *
 * The planner is told the hours and asked to respect them, and the prompt has
 * said so since the beginning — but a prompt is a request. A real 小红书 KL
 * import proved it: the note gave ICC Pudu's hours as 6am–2pm, the extractor
 * captured them, and the model still put the stop at 18:00, with an empty
 * conflicts list and nothing to verify. A confident, fully-cited plan sending
 * someone to a market that shut four hours earlier.
 *
 * So this checks it against the hours we hold, the way the flight envelope
 * checks the shape of a day rather than asking the model to be careful. Only
 * what resolves is judged: a block with no clock time, or a place whose hours
 * nobody recorded, is not a finding — saying nothing is honest, and inventing
 * a closure would be the same failure in the other direction.
 *
 * Derived, never stored. Hours get corrected and blocks get moved, so a saved
 * list would be wrong by the next edit.
 */

export type Weekday = 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun';

/** Sunday-first, to match `Date.prototype.getUTCDay`. */
const WEEKDAYS: Weekday[] = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

const DAY_NAMES: Record<Weekday, string> = {
  mon: 'Mondays',
  tue: 'Tuesdays',
  wed: 'Wednesdays',
  thu: 'Thursdays',
  fri: 'Fridays',
  sat: 'Saturdays',
  sun: 'Sundays',
};

/**
 * One stretch a place is open.
 *
 * A day missing from every window is a day it is shut — which is how "closed
 * Mondays" is expressed, rather than with a separate field that could disagree
 * with this one. A `closes` at or before `opens` runs past midnight.
 */
export interface HoursWindow {
  days: Weekday[];
  /** "HH:MM", 24-hour. */
  opens: string;
  closes: string;
}

export type OpeningHours = HoursWindow[];

export interface Closure {
  day: number;
  date: string | null;
  block_id: string;
  activity: string;
  place_id: string;
  /** When the block is scheduled, "HH:MM". */
  at: string;
  kind: 'closed_that_day' | 'outside_hours';
  /** Who said so — the note is worded to match. */
  hours_from: HoursSource;
  /** Rendered on the band, e.g. "ICC Pudu closes at 14:00". */
  note: string;
}

/** Minutes since midnight, or null for anything that is not "HH:MM". */
export function clockToMinutes(clock: string): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(clock.trim());
  if (!m) return null;
  const hours = Number(m[1]);
  const minutes = Number(m[2]);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

export function weekdayOf(date: string): Weekday | null {
  const ms = Date.parse(`${date}T00:00:00Z`);
  if (Number.isNaN(ms)) return null;
  return WEEKDAYS[new Date(ms).getUTCDay()] ?? null;
}

/** The windows that apply on one weekday. */
function windowsOn(hours: OpeningHours, day: Weekday): HoursWindow[] {
  return hours.filter((w) => w.days.includes(day));
}

function covers(window: HoursWindow, minutes: number): boolean {
  const opens = clockToMinutes(window.opens);
  const closes = clockToMinutes(window.closes);
  if (opens == null || closes == null) return true; // unreadable: do not accuse
  // A window closing at or before it opens runs past midnight — 22:00–02:00
  // covers the late evening and the small hours, not the twenty hours between.
  return closes <= opens
    ? minutes >= opens || minutes < closes
    : minutes >= opens && minutes < closes;
}

/**
 * Parse the stored JSON, keeping only windows that make sense.
 *
 * Hours come from a model reading someone's post, so this is a boundary, not a
 * formality. Anything malformed is dropped rather than repaired: a half-read
 * window would produce confident nonsense about when a place is shut.
 */
export function parseHours(stored: string | null | undefined): OpeningHours | null {
  if (!stored) return null;
  let raw: unknown;
  try {
    raw = JSON.parse(stored);
  } catch {
    return null;
  }
  if (!Array.isArray(raw)) return null;

  const windows: OpeningHours = [];
  for (const entry of raw) {
    if (typeof entry !== 'object' || entry === null) continue;
    const { days, opens, closes } = entry as Record<string, unknown>;
    if (typeof opens !== 'string' || typeof closes !== 'string') continue;
    if (clockToMinutes(opens) == null || clockToMinutes(closes) == null) continue;
    if (!Array.isArray(days)) continue;
    const valid = days.filter((d): d is Weekday => WEEKDAYS.includes(d as Weekday));
    if (!valid.length) continue;
    windows.push({ days: valid, opens, closes });
  }
  return windows.length ? windows : null;
}

/** One point in a Google `regularOpeningHours` period. */
interface GoogleHourPoint {
  day?: number;
  hour?: number;
  minute?: number;
}

export interface GooglePeriod {
  open?: GoogleHourPoint;
  close?: GoogleHourPoint;
}

const clock = (hour: number, minute: number) =>
  `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;

/**
 * Google's opening hours, in the shape the rest of this file speaks.
 *
 * Google gives one period per day, so a place open 09:00-17:00 all week
 * arrives as seven of them. They are merged back by time, which keeps the
 * briefing short — "Mon,Tue,Wed 09:00-17:00" rather than three lines — and
 * leaves a day the place never opens absent, which is how closed is said here.
 *
 * A period with an `open` and no `close` is a day it never shuts. That becomes
 * 00:00-00:00, which reads as crossing midnight and so covers every minute —
 * the same answer by the same rule, rather than a special case.
 */
export function fromGooglePeriods(periods: GooglePeriod[] | undefined | null): OpeningHours | null {
  if (!periods?.length) return null;

  const windows: OpeningHours = [];
  for (const period of periods) {
    const open = period.open;
    if (!open || open.day == null) continue;
    const day = WEEKDAYS[open.day];
    if (!day) continue;
    windows.push({
      days: [day],
      opens: clock(open.hour ?? 0, open.minute ?? 0),
      // `close.day` is ignored on purpose: a close on the following day is
      // exactly what a past-midnight window already means here.
      closes: period.close ? clock(period.close.hour ?? 0, period.close.minute ?? 0) : '00:00',
    });
  }
  return windows.length ? mergeByTimes(windows) : null;
}

const WEEK_ORDER: Weekday[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/** Windows that run at the same times become one, listed in week order. */
function mergeByTimes(windows: OpeningHours): OpeningHours {
  const byTimes = new Map<string, HoursWindow>();
  for (const w of windows) {
    const key = `${w.opens}-${w.closes}`;
    const found = byTimes.get(key);
    if (found) {
      for (const day of w.days) if (!found.days.includes(day)) found.days.push(day);
    } else {
      byTimes.set(key, { days: [...w.days], opens: w.opens, closes: w.closes });
    }
  }
  return [...byTimes.values()].map((w) => ({
    ...w,
    days: WEEK_ORDER.filter((d) => w.days.includes(d)),
  }));
}

/** How a place's hours read on one day, for the band's second line. */
export function describeHours(hours: OpeningHours, day: Weekday): string {
  const windows = windowsOn(hours, day);
  if (!windows.length) return `closed on ${DAY_NAMES[day]}`;
  return windows.map((w) => `${w.opens}–${w.closes}`).join(', ');
}

export interface DayClosures {
  date: string;
  weekday: Weekday;
  /** Indexes into the places array as given, so the caller can name them. */
  closed: number[];
}

/**
 * Which saved places are shut on each day of the trip.
 *
 * Worked out here and handed to the planner, rather than left for it to
 * derive. It would have to turn a date into a weekday and check that against
 * seven windows per place, for every place, before writing anything — and a
 * model that gets one of those steps wrong produces a plan that looks right.
 *
 * This is the flight envelope's rule applied to hours: a day a place cannot
 * be visited should reduce what gets planned, not collect a warning on top of
 * it. The check after the fact stays, for the edits that come later.
 *
 * Only whole days. "Open, but not at that hour" is already answered by the
 * hours shown beside each place.
 */
export function closedByDay(places: Place[], dates: string[]): DayClosures[] {
  const found: DayClosures[] = [];

  for (const date of dates) {
    const weekday = weekdayOf(date);
    if (!weekday) continue;

    const closed: number[] = [];
    places.forEach((place, index) => {
      const hours = parseHours(place.hours);
      if (!hours) return;
      if (!hours.some((w) => w.days.includes(weekday))) closed.push(index);
    });

    if (closed.length) found.push({ date, weekday, closed });
  }

  return found;
}

/**
 * Every block scheduled when the place it cites is shut.
 *
 * Judged only on blocks that resolved to a saved place — the same rule
 * attribution follows, because a closure is a claim about our own records.
 */
export function findClosures(plan: Plan, places: Place[]): Closure[] {
  const byId = new Map(places.map((p) => [p.id, p]));
  const closures: Closure[] = [];

  for (const day of plan.itinerary) {
    if (!day.date) continue;
    const weekday = weekdayOf(day.date);
    if (!weekday) continue;

    for (const block of day.blocks) {
      if (!block.from_place_id || !block.start_time) continue;
      const place = byId.get(block.from_place_id);
      const hours = place ? parseHours(place.hours) : null;
      if (!place || !hours) continue;

      const at = clockToMinutes(block.start_time);
      if (at == null) continue;

      const windows = windowsOn(hours, weekday);
      if (windows.length && windows.some((w) => covers(w, at))) continue;

      // Hours read off a post are the poster's claim, and a real import proved
      // those can be wrong — a KL note had REXKL closed Mondays when it is the
      // bookshop inside that closes. So a finding built on one says who said
      // it, and only a finding built on the Places API states it flatly.
      const from: HoursSource = place.hours_source ?? 'source';
      const said = from === 'source' ? 'The post says ' : '';

      closures.push({
        day: day.day,
        date: day.date,
        block_id: block.id,
        activity: block.activity,
        place_id: place.id,
        at: block.start_time,
        kind: windows.length ? 'outside_hours' : 'closed_that_day',
        hours_from: from,
        note: windows.length
          ? `${said}${place.name} is open ${describeHours(hours, weekday)}, but this is at ${block.start_time}.`
          : `${said}${place.name} is closed on ${DAY_NAMES[weekday]}.`,
      });
    }
  }

  return closures;
}
