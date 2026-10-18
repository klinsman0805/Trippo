import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { Plan, PlanBlock } from '../../schemas/plan.js';
import type { Place } from '../../schemas/trip.js';
import { clockToMinutes, findClosures, parseHours, weekdayOf, type OpeningHours } from './hours.js';

// --- fixtures: the KL city walk that found the bug ---

/** 2026-11-07 is a Saturday; 2026-11-09 a Monday. */
const SATURDAY = '2026-11-07';
const MONDAY = '2026-11-09';

const place = (id: string, name: string, hours: OpeningHours | null): Place =>
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
