import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest, unauthorized } from '../../lib/errors.js';
import type { Verifier } from '../../lib/auth.js';
import { db } from '../../db/index.js';

/**
 * Moving trips off the anonymous user a device started with.
 *
 * Signing in on a second device does not join two halves of one account. That
 * device made an anonymous user of its own on first launch, and anything
 * planned there belongs to it — so the moment Apple hands back an identity
 * already linked elsewhere, the app switches to the permanent user and the
 * device's own trips are left behind, owned by someone nobody will ever
 * authenticate as again.
 *
 * The app still holds that session at the moment it switches. This is where
 * it spends it: present both tokens, and the trips move.
 */

const TransferBody = z.object({
  /** The access token of the anonymous user whose trips are being claimed. */
  from_access_token: z.string().min(16),
});

export function accountRoutes(verify: Verifier) {
  return async function routes(app: FastifyInstance): Promise<void> {
    app.post('/account/transfer', async (req, reply) => {
      const parsed = TransferBody.safeParse(req.body ?? {});
      if (!parsed.success) {
        throw badRequest('validation_error', 'Expected { from_access_token }', parsed.error.flatten());
      }

      // Holding a live token for the old user is the proof, and the only one
      // there is: an anonymous user has no password to re-enter and nothing
      // else to show. Checked by the same path every request takes, so a
      // forged or expired token is refused here exactly as it is there.
      const from = await verify(`Bearer ${parsed.data.from_access_token}`);
      const to = req.caller;

      if (from.userId === to.userId) {
        // Linking an identity keeps the user's id, so this is what the device
        // that did the linking sees. Nothing to move, and not an error.
        return { moved: 0 };
      }

      // Only from an anonymous user, and this restriction is what makes the
      // proof safe to accept. An anonymous token belongs to one device and
      // buys only what that device made. A token for a real account would
      // make this a way to empty one — and merging two real accounts is a
      // different feature, needing consent this request does not carry.
      if (!from.anonymous) {
        throw unauthorized(
          'not_anonymous',
          "Only a device's own anonymous trips can be moved. Sign in on the other device instead.",
        );
      }

      // Everything else hangs off a trip by `trip_id` and follows it. The row
      // recording who it belongs to is the only one that changes.
      const moved = await db.run('UPDATE trips SET owner_id = ? WHERE owner_id = ?', [
        to.userId,
        from.userId,
      ]);

      req.log.info({ moved }, 'moved trips from an anonymous user');
      reply.code(200);
      return { moved };
    });
  };
}
