import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { citeSavedPlace } from './cite.js';

const place = {
  id: 'plc_alor',
  trip_id: 'trip_kl',
  name: 'Jalan Alor',
  address: 'Jalan Alor, Bukit Bintang',
  why: 'Street food after dark',
};

describe('citeSavedPlace', () => {
  it('cites the place and its source, filling in what was left blank', () => {
    const input = citeSavedPlace({ time_of_day: 'evening' }, place, '吉隆坡3天2夜旅游攻略', 'trip_kl');

    assert.equal(input.activity, 'Jalan Alor');
    assert.equal(input.location, 'Jalan Alor, Bukit Bintang');
    assert.equal(input.description, 'Street food after dark');
    assert.equal(input.from_place_id, 'plc_alor');
    assert.equal(input.from_source_title, '吉隆坡3天2夜旅游攻略');
    assert.equal(input.time_of_day, 'evening');
  });

  it('keeps whatever the person typed over the place\'s own fields', () => {
    const input = citeSavedPlace({ activity: 'Supper at Jalan Alor', description: '' }, place, null, 'trip_kl');

    assert.equal(input.activity, 'Supper at Jalan Alor');
    // Blank is not an answer: the place's own line fills it.
    assert.equal(input.description, 'Street food after dark');
  });

  it('a place added by hand has no source to name', () => {
    assert.equal(citeSavedPlace({}, place, null, 'trip_kl').from_source_title, null);
  });

  it('refuses a place from another trip, rather than citing it here', () => {
    assert.throws(() => citeSavedPlace({}, place, null, 'trip_other'), /No saved place/);
  });
});
