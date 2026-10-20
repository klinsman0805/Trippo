import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { Plan, PlanBlock } from '../../schemas/plan.js';
import type { HoursSource, Place } from '../../schemas/trip.js';
import {
  clockToMinutes,
  closedByDay,
  findClosures,
  fromGooglePeriods,
  parseHours,
  weekdayOf,
  type OpeningHours,
} from './hours.js';

// --- fixtures: the KL city walk that found the bug ---

/** 2026-11-07 is a Saturday; 2026-11-09 a Monday. */
const SATURDAY = '2026-11-07';
const MONDAY = '2026-11-09';

const place = (
  id: string,
  name: string,
  hours: OpeningHours | null,
  hours_source: HoursSource = 'places',
): Place =>
  ({
    id,
    trip_id: 'trip_1',
    source_id: 'src_1',
    name,
    category: 'food',
    city: 'Kuala Lumpur',
    country: 'Malaysia',
    address: null,
    lat: null,
    lng: null,
    google_place_id: null,
    why: null,
    tags: [],
    hours: hours === null ? null : JSON.stringify(hours),
    hours_source: hours === null ? null : hours_source,
    resolved: false,
    created_at: '2026-10-19T00:00:00.000Z',
  }) satisfies Place;

const block = (opts: { at: string | null; place: string | null; activity?: string }): PlanBlock =>
  ({
    id: `blk_${opts.activity ?? opts.place ?? 'x'}`,
    time_of_day: 'morning',
    activity: opts.activity ?? 'A stop',
    description: '',
    location: '',
    start_time: opts.at,
    estimated_duration_minutes: null,
    estimated_cost_per_person: null,
    suited_for_members: [],
    optional: false,
    weather_backup: null,
    source: 'planner',
    pinned: false,
    from_place_id: opts.place,
    from_source_title: null,
    from_place: null,
  }) as unknown as PlanBlock;

const planWith = (date: string | null, blocks: PlanBlock[]): Plan =>
  ({ itinerary: [{ day: 1, date, blocks }] }) as unknown as Plan;

describe('reading stored hours', () => {
  it('keeps windows that make sense and drops the rest', () => {
    const parsed = parseHours(
      JSON.stringify([
        { days: ['sat'], opens: '06:00', closes: '14:00' },
        { days: ['sun'], opens: 'morning', closes: '14:00' }, // not a clock
        { days: [], opens: '09:00', closes: '17:00' }, // no days
        { days: ['nonsense'], opens: '09:00', closes: '17:00' }, // no valid day
        { days: ['mon'], opens: '25:00', closes: '26:00' }, // out of range
      ]),
    );
    assert.deepEqual(parsed, [{ days: ['sat'], opens: '06:00', closes: '14:00' }]);
  });

  it('treats nothing, nonsense and the wrong shape alike — as no hours', () => {
    for (const stored of [null, undefined, '', 'not json', '{"days":["sat"]}', '[]', '[1,2]']) {
      assert.equal(parseHours(stored), null, `for ${JSON.stringify(stored)}`);
    }
  });

  it('reads the clock, and refuses what is not one', () => {
    assert.equal(clockToMinutes('06:00'), 360);
    assert.equal(clockToMinutes('9:05'), 545);
    assert.equal(clockToMinutes('23:59'), 1439);
    for (const bad of ['', '6pm', '24:00', '12:60', '0600']) {
      assert.equal(clockToMinutes(bad), null, `for "${bad}"`);
    }
  });

  it('knows which day a date falls on', () => {
    assert.equal(weekdayOf(SATURDAY), 'sat');
    assert.equal(weekdayOf(MONDAY), 'mon');
    assert.equal(weekdayOf('not-a-date'), null);
  });
});

describe("reading Google's opening hours", () => {
  /** Google gives one period per day, Sunday = 0. */
  const period = (day: number, oh: number, om: number, ch: number, cm: number) => ({
    open: { day, hour: oh, minute: om },
    close: { day, hour: ch, minute: cm },
  });

  it('merges the seven periods of an all-week place into one window', () => {
    const hours = fromGooglePeriods([0, 1, 2, 3, 4, 5, 6].map((d) => period(d, 9, 0, 17, 0)));

    // Seven lines in the briefing for one fact would crowd out the rest of it.
    assert.deepEqual(hours, [
      { days: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], opens: '09:00', closes: '17:00' },
    ]);
  });

  it('keeps different times apart, and lists each in week order', () => {
    const hours = fromGooglePeriods([
      period(6, 9, 0, 18, 30), // Saturday
      period(1, 10, 0, 18, 30), // Monday
      period(0, 9, 0, 18, 30), // Sunday
      period(2, 10, 0, 18, 30), // Tuesday
    ]);

    assert.deepEqual(hours, [
      { days: ['sat', 'sun'], opens: '09:00', closes: '18:30' },
      { days: ['mon', 'tue'], opens: '10:00', closes: '18:30' },
    ]);
  });

  it('leaves a day the place never opens out entirely', () => {
    // Which is how "closed Mondays" is said here — no separate field to
    // disagree with the times.
    const hours = fromGooglePeriods([1, 2, 3].map((d) => period(d, 10, 0, 22, 0)));
    assert.deepEqual(hours?.[0]?.days, ['mon', 'tue', 'wed']);
  });

  it('treats a period with no closing time as never shutting that day', () => {
    const hours = fromGooglePeriods([{ open: { day: 1, hour: 0, minute: 0 } }]);
    assert.deepEqual(hours, [{ days: ['mon'], opens: '00:00', closes: '00:00' }]);

    // 2026-11-09 is a Monday; a 24-hour place is open at every hour of it.
    const open24 = place('plc_24', 'All night mamak', hours);
    for (const at of ['03:00', '12:00', '23:30']) {
      assert.deepEqual(findClosures(planWith(MONDAY, [block({ at, place: 'plc_24' })]), [open24]), []);
    }
  });

  it('says nothing for a provider that knows no hours', () => {
    assert.equal(fromGooglePeriods(undefined), null);
    assert.equal(fromGooglePeriods([]), null);
    assert.equal(fromGooglePeriods([{ close: { day: 1, hour: 9, minute: 0 } }]), null);
  });
});

describe('who said the place was shut', () => {
  const windows: OpeningHours = [{ days: ['sat'], opens: '06:00', closes: '14:00' }];

  it('states Places hours flatly', () => {
    const closures = findClosures(
      planWith(SATURDAY, [block({ at: '18:00', place: 'plc_p' })]),
      [place('plc_p', 'ICC Pudu', windows, 'places')],
    );
    assert.equal(closures[0]?.hours_from, 'places');
    assert.equal(closures[0]?.note, 'ICC Pudu is open 06:00–14:00, but this is at 18:00.');
  });

  it("attributes a post's hours to the post", () => {
    // A KL note had REXKL closed Mondays when it is the bookshop inside that
    // closes. Hours off a post are a claim, and the wording has to say so.
    const closures = findClosures(
      planWith(SATURDAY, [block({ at: '18:00', place: 'plc_s' })]),
      [place('plc_s', 'ICC Pudu', windows, 'source')],
    );
    assert.equal(closures[0]?.hours_from, 'source');
    assert.equal(closures[0]?.note, 'The post says ICC Pudu is open 06:00–14:00, but this is at 18:00.');
  });
});

describe('catching a stop timed when the place is shut', () => {
  const iccPudu = place('plc_icc', 'ICC Pudu', [
    { days: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], opens: '06:00', closes: '14:00' },
  ]);

  it('reports the morning market the planner put at 18:00', () => {
    // The bug, exactly as it happened: hours captured from the 小红书 note,
    // and the plan scheduled four hours after closing anyway.
    const closures = findClosures(
      planWith(SATURDAY, [block({ at: '18:00', place: 'plc_icc', activity: 'ICC Pudu' })]),
      [iccPudu],
    );

    const [closure] = closures;
    assert.equal(closures.length, 1);
    assert.ok(closure);
    assert.equal(closure.kind, 'outside_hours');
    assert.equal(closure.at, '18:00');
    assert.equal(closure.place_id, 'plc_icc');
    assert.equal(closure.day, 1);
    assert.match(closure.note, /ICC Pudu is open 06:00–14:00, but this is at 18:00/);
  });

  it('says nothing about the same stop timed inside the hours', () => {
    assert.deepEqual(
      findClosures(planWith(SATURDAY, [block({ at: '09:00', place: 'plc_icc' })]), [iccPudu]),
      [],
    );
  });

  it('counts opening time as open and closing time as shut', () => {
    const open = findClosures(planWith(SATURDAY, [block({ at: '06:00', place: 'plc_icc' })]), [iccPudu]);
    const shut = findClosures(planWith(SATURDAY, [block({ at: '14:00', place: 'plc_icc' })]), [iccPudu]);
    assert.equal(open.length, 0);
    assert.equal(shut.length, 1, 'arriving as it closes is arriving too late');
  });

  it('reports a day the place does not open at all', () => {
    const rex = place('plc_rex', 'REX KL', [
      { days: ['tue', 'wed', 'thu', 'fri', 'sat', 'sun'], opens: '10:00', closes: '23:00' },
    ]);
    const closures = findClosures(planWith(MONDAY, [block({ at: '11:00', place: 'plc_rex' })]), [rex]);

    const [closure] = closures;
    assert.ok(closure);
    assert.equal(closure.kind, 'closed_that_day');
    assert.match(closure.note, /REX KL is closed on Mondays/);
  });

  it('handles a bar that closes after midnight', () => {
    const bar = place('plc_bar', 'A late bar', [
      { days: ['sat'], opens: '22:00', closes: '02:00' },
    ]);
    const inside = (at: string) =>
      findClosures(planWith(SATURDAY, [block({ at, place: 'plc_bar' })]), [bar]).length === 0;

    assert.ok(inside('23:30'), 'late evening is open');
    assert.ok(inside('01:00'), 'the small hours are open');
    assert.ok(!inside('12:00'), 'the middle of the day is not');
  });

  it('finds every offending stop, and only those', () => {
    const closures = findClosures(
      planWith(SATURDAY, [
        block({ at: '09:00', place: 'plc_icc', activity: 'fine' }),
        block({ at: '15:00', place: 'plc_icc', activity: 'late one' }),
        block({ at: '20:00', place: 'plc_icc', activity: 'later one' }),
      ]),
      [iccPudu],
    );
    assert.deepEqual(closures.map((c) => c.activity), ['late one', 'later one']);
  });
});

describe('telling the planner which days a place cannot be visited', () => {
  // The real Balik Pulau guide: three places, three different closed days.
  const ahHuat = place('plc_ah', 'Ah Huat Uncle Fried Hor Fun', [
    { days: ['mon', 'tue', 'thu', 'fri', 'sat', 'sun'], opens: '08:00', closes: '15:00' },
  ]);
  const nada = place('plc_nada', 'Nada Natural Farming', [
    { days: ['thu', 'fri'], opens: '16:30', closes: '20:30' },
    { days: ['sat', 'sun'], opens: '15:00', closes: '21:00' },
  ]);
  const anytime = place('plc_any', 'Lian Cheng Water Powder Factory', [
    { days: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], opens: '09:00', closes: '18:00' },
  ]);
  const places = [ahHuat, nada, anytime];

  /** 2026-11-04 is a Wednesday, 11-05 a Thursday, 11-07 a Saturday. */
  it('names the places shut on each day, by their position in the list', () => {
    const byDay = closedByDay(places, ['2026-11-04', '2026-11-05']);

    assert.equal(byDay.length, 1, 'only Wednesday has closures');
    assert.equal(byDay[0]?.date, '2026-11-04');
    assert.equal(byDay[0]?.weekday, 'wed');
    // Ah Huat closes Wednesdays; Nada opens Thursday to Sunday only.
    assert.deepEqual(byDay[0]?.closed, [0, 1]);
  });

  it('says nothing about a day everything is open', () => {
    assert.deepEqual(closedByDay(places, ['2026-11-07']), []);
  });

  it('ignores places whose hours nobody recorded', () => {
    const unknown = place('plc_u', 'Pantai Malindo', null);
    assert.deepEqual(closedByDay([unknown], ['2026-11-04']), []);
  });

  it('skips a date it cannot read rather than guessing at it', () => {
    assert.deepEqual(closedByDay(places, ['not-a-date']), []);
  });
});

describe('staying quiet when it cannot know', () => {
  const kafeiDian = place('plc_kafei', 'Kafei Dian', [
    { days: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], opens: '07:30', closes: '22:30' },
  ]);

  it('judges nothing without a clock time on the block', () => {
    assert.deepEqual(
      findClosures(planWith(SATURDAY, [block({ at: null, place: 'plc_kafei' })]), [kafeiDian]),
      [],
    );
  });

  it('judges nothing without a date on the day', () => {
    assert.deepEqual(
      findClosures(planWith(null, [block({ at: '03:00', place: 'plc_kafei' })]), [kafeiDian]),
      [],
    );
  });

  it('judges nothing for a place whose hours nobody recorded', () => {
    assert.deepEqual(
      findClosures(planWith(SATURDAY, [block({ at: '03:00', place: 'plc_none' })]), [
        place('plc_none', 'Somewhere', null),
      ]),
      [],
    );
  });

  it('judges nothing for a block the planner chose itself', () => {
    // Uncited blocks resolved to no saved place, so there are no hours to
    // check — the same rule attribution follows.
    assert.deepEqual(
      findClosures(planWith(SATURDAY, [block({ at: '03:00', place: null })]), [kafeiDian]),
      [],
    );
  });

  it('judges nothing when the stored hours are unreadable', () => {
    const broken = { ...place('plc_broken', 'Mystery', null), hours: '{oh dear' };
    assert.deepEqual(
      findClosures(planWith(SATURDAY, [block({ at: '03:00', place: 'plc_broken' })]), [broken]),
      [],
    );
  });
});
