import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest } from '../../lib/errors.js';
import { attribution, geoProvider } from '../geo/index.js';
import { listPlaces, markResolved } from '../trips/places.repo.js';
import { getTrip } from '../trips/repo.js';

export async function placeRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Querystring: { q?: string; lat?: string; lng?: string; lang?: string } }>(
    '/places/search',
    async (req) => {
      const q = req.query.q?.trim();
      if (!q) throw badRequest('missing_query', 'Provide ?q=');

      const lat = Number(req.query.lat);
      const lng = Number(req.query.lng);
      const bias =
        Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : undefined;

      const provider = geoProvider();
      return {
        provider: provider.name,
        attribution: attribution(),
        places: await provider.search(q, { bias, language: req.query.lang ?? 'en' }),
      };
    },
  );

  const ResolveBody = z.object({
    /** Restrict to these saved-place ids; omit to resolve everything unresolved. */
    place_ids: z.array(z.string()).optional(),
  });

  /**
   * Geocode the trip's saved places so the planner can group them by proximity.
   *
   * Runs sequentially rather than in parallel: both providers rate-limit bursts,
   * and this is a background-ish operation where latency matters far less than
   * not stampeding a free service.
   */
  app.post<{ Params: { id: string } }>('/trips/:id/places/resolve', async (req) => {
    const trip = getTrip(req.params.id);
    const parsed = ResolveBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid body', parsed.error.flatten());
    }

    const provider = geoProvider();
    const wanted = parsed.data.place_ids ? new Set(parsed.data.place_ids) : null;
    const targets = listPlaces(trip.id).filter(
      (p) => (wanted ? wanted.has(p.id) : !p.resolved),
    );

    // Bias toward the first destination so ambiguous names land in the right city.
    const primaryDestination = trip.destinations[0];
    const [anchor] = primaryDestination
      ? await provider.search(primaryDestination, { limit: 1 })
      : [];
    const bias = anchor ? { lat: anchor.lat, lng: anchor.lng } : undefined;

    const resolved: unknown[] = [];
    const failed: { id: string; name: string; reason: string }[] = [];

    for (const place of targets) {
      const query = [place.name, place.city ?? primaryDestination].filter(Boolean).join(', ');
      try {
        const [match] = await provider.search(query, { bias, limit: 1 });
        if (!match) {
          failed.push({ id: place.id, name: place.name, reason: 'no_match' });
          continue;
        }
        resolved.push(
          markResolved(place.id, {
            lat: match.lat,
            lng: match.lng,
            address: match.address,
            google_place_id: match.place_id,
            city: place.city ?? match.city,
          }),
        );
      } catch (err) {
        failed.push({
          id: place.id,
          name: place.name,
          reason: err instanceof Error ? err.message : 'lookup_failed',
        });
      }
    }

    return {
      provider: provider.name,
      attribution: attribution(),
      resolved,
      failed,
      attempted: targets.length,
    };
  });
}
