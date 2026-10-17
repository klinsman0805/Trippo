import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { unauthorized } from './errors.js';

/** Who a request is from. */
export interface Caller {
  userId: string;
  /**
   * Signed in without an account yet. Same rights as anyone else — the first
   * trip needs no sign-up — but worth knowing when it comes to linking one.
   */
  anonymous: boolean;
}

export type Verifier = (authorization: string | undefined) => Promise<Caller>;

/** Everyone, when there is no Supabase: a laptop with one person at it. */
export const LOCAL_USER = 'local';

/**
 * Checks a Supabase access token and says whose it is.
 *
 * Signature, issuer, audience and expiry are all checked. The audience must be
 * `authenticated` — which is what anonymous sign-ins get too — and there must
 * be a user id, which together turn away the app's own anon key if it is ever
 * sent as a token: that key is a JWT, but it names no user.
 *
 * Keys come from the project's published key set, or from a shared secret for
 * a project that has not moved to asymmetric signing.
 */
export function supabaseVerifier(opts: {
  supabaseUrl: string;
  jwtSecret?: string;
  /** Tests pass a local key set; production fetches the project's. */
  keys?: JWTVerifyGetKey;
}): Verifier {
  const issuer = `${opts.supabaseUrl.replace(/\/+$/, '')}/auth/v1`;
  const key: JWTVerifyGetKey | Uint8Array =
    opts.keys ??
    (opts.jwtSecret
      ? new TextEncoder().encode(opts.jwtSecret)
      : createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`)));

  return async (authorization) => {
    const token = /^Bearer\s+(\S+)$/i.exec(authorization ?? '')?.[1];
    if (!token) {
      throw unauthorized('unauthenticated', 'Sign in to use Trippo.');
    }
    try {
      const { payload } = await jwtVerify(token, key as JWTVerifyGetKey, {
        issuer,
        audience: 'authenticated',
      });
      if (!payload.sub) throw new Error('no subject');
      return { userId: payload.sub, anonymous: payload.is_anonymous === true };
    } catch {
      // One answer for expired, forged and malformed alike: the client's
      // response to each is the same — refresh the session, or sign in again.
      throw unauthorized('invalid_token', 'Your session has expired. Sign in again.');
    }
  };
}

/** No Supabase configured: every request is the one local user. */
export const localVerifier: Verifier = async () => ({ userId: LOCAL_USER, anonymous: false });
