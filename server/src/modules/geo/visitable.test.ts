import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { isVisitable } from './index.js';

/**
 * Types below are what the two providers actually returned for Balik Pulau,
 * read off a live lookup rather than invented.
 */

describe('whether a geocoding result is a place at all', () => {
  it('turns away the road Google offers for a beach it does not list', () => {
    // Asked for Pantai Malindo; answered "Jalan Kuala Sungai Burung". Stored,
    // that would have been the beach's name on a street's coordinates, with a
    // card still claiming it came from the traveller's own link.
    assert.equal(isVisitable(['route']), false);
  });

  it('accepts a venue Google knows', () => {
    assert.ok(
      isVisitable([
        'coffee_shop',
        'cafe',
        'food_store',
        'store',
        'point_of_interest',
        'food',
        'establishment',
      ]),
    );
    assert.ok(isVisitable(['restaurant', 'food', 'point_of_interest', 'establishment']));
  });

  it('accepts a venue Photon knows, and turns away its roads and settlements', () => {
    assert.ok(isVisitable(['amenity', 'cafe']));
    assert.ok(isVisitable(['tourism', 'attraction']));
    assert.ok(isVisitable(['shop', 'bakery']));
    assert.equal(isVisitable(['highway', 'residential']), false);
    assert.equal(isVisitable(['place', 'village']), false);
    assert.equal(isVisitable(['boundary', 'administrative']), false);
  });

  it('turns away an address or an area, which are not somewhere to go', () => {
    for (const types of [
      ['street_address'],
      ['postal_code'],
      ['locality', 'political'],
      ['administrative_area_level_1', 'political'],
    ]) {
      assert.equal(isVisitable(types), false, types.join(','));
    }
  });

  it('keeps a venue that also carries an area type', () => {
    // Malls and markets often come back tagged with their neighbourhood too.
    // The positive signal wins, or half the real places would be refused.
    assert.ok(isVisitable(['shopping_mall', 'point_of_interest', 'establishment', 'locality']));
  });

  it('takes a provider that reports nothing at its word', () => {
    // Refusing on no evidence loses real places, which is the worse error:
    // an unlisted type is not a claim that this is a road.
    assert.ok(isVisitable([]));
  });

  it('accepts a type neither provider vocabulary covers', () => {
    assert.ok(isVisitable(['some_future_category']));
  });
});
