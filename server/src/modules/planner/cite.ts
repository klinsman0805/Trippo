import { notFound } from '../../lib/errors.js';
import type { Place } from '../../schemas/trip.js';
import type { BlockInput } from './blocks.js';

/**
 * A saved place, as the activity that adds it to a day.
 *
 * The citation is built here from the place record — the same rule hydration
 * follows for the planner — so "From <source>" on the card is a statement
 * about Trippo's own data. Whatever the person typed wins over the place's
 * own fields; the place fills in what they left blank.
 */
export function citeSavedPlace(
  input: BlockInput,
  place: Pick<Place, 'id' | 'trip_id' | 'name' | 'address' | 'why'>,
  sourceTitle: string | null,
  tripId: string,
): BlockInput {
  if (place.trip_id !== tripId) {
    throw notFound('place_not_found', `No saved place ${place.id} on this trip.`);
  }
  return {
    ...input,
    activity: input.activity?.trim() || place.name,
    location: input.location?.trim() || place.address || place.name,
    description: input.description?.trim() || place.why || '',
    from_place_id: place.id,
    from_source_title: sourceTitle,
  };
}
