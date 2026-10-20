import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyInstance, type RouteOptions } from 'fastify';
import { ZodError } from 'zod';
import { env, features } from './config/env.js';
import { localVerifier, supabaseVerifier, type Caller, type Verifier } from './lib/auth.js';
import { db } from './db/index.js';
import { AppError, notFound } from './lib/errors.js';
import { getPlan } from './modules/planner/service.js';
import { tripOwner } from './modules/trips/repo.js';
import { flightRoutes } from './modules/flights/routes.js';
import { ingestRoutes } from './modules/ingest/routes.js';
import { placeRoutes } from './modules/places/routes.js';
import { plannerRoutes } from './modules/planner/routes.js';
import { transitRoutes } from './modules/transit/routes.js';
import { travelRoutes } from './modules/travel/routes.js';
import { accountRoutes } from './modules/account/routes.js';
import { tripRoutes } from './modules/trips/routes.js';

declare module 'fastify' {
  interface FastifyRequest {
    /** Set for every /v1 request before any route runs. */
    caller: Caller;
  }
}

/**
 * How often one person may call each kind of route.
 *
 * Generous for ordinary use, and tight where a call costs something the user
 * does not see: a model call on a quota counted per day, a page fetch and a
 * model call per import, a free community router that asks to be used gently,
 * a paid flight lookup. First match wins; anything unmatched gets the default.
 */
const LIMITS: { path: RegExp; method?: string; max: number; timeWindow: string }[] = [
  { path: /\/trips\/:id\/(plan|plan\/answers|refine)$/, method: 'POST', max: 20, timeWindow: '1 hour' },
  { path: /\/trips\/:id\/sources\/(url|text)$/, method: 'POST', max: 30, timeWindow: '1 hour' },
  { path: /\/(plan\/travel|points)$/, max: 300, timeWindow: '1 hour' },
  { path: /\/(transit\/|places\/search|places\/resolve)/, max: 120, timeWindow: '1 hour' },
  { path: /\/flights\//, max: 60, timeWindow: '1 hour' },
  // Claiming a device's anonymous trips happens once on that device, ever.
  { path: /\/account\/transfer$/, method: 'POST', max: 10, timeWindow: '1 hour' },
];
const DEFAULT_LIMIT = { max: 300, timeWindow: '1 minute' };

/**
 * Who is asking, from configuration.
 *
 * Production without Supabase is refused rather than run single-user: every
 * request would be the same person, so every trip would be everyone's.
 */
function callerVerifier(): Verifier {
  if (env.SUPABASE_URL) {
    return supabaseVerifier({ supabaseUrl: env.SUPABASE_URL, jwtSecret: env.SUPABASE_JWT_SECRET });
  }
  if (env.NODE_ENV === 'production') {
    throw new Error('SUPABASE_URL is not set. Refusing to run in production without sign-in.');
  }
  return localVerifier;
}

export async function buildApp(verify: Verifier = callerVerifier()): Promise<FastifyInstance> {
  const app = Fastify({
    logger: { level: env.LOG_LEVEL },
    // Planner calls run for minutes; the default 0 (no timeout) is what we want,
    // but request bodies still need a sane cap for pasted source text.
    bodyLimit: 2 * 1024 * 1024,
  });

  await app.register(cors, { origin: true });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof AppError) {
      // 4xx are the client's problem to fix; only log 5xx as server errors.
      const log = error.statusCode >= 500 ? request.log.error : request.log.warn;
      log.call(request.log, { err: error, code: error.code }, error.message);
      return reply.code(error.statusCode).send({
        error: { code: error.code, message: error.message, details: error.details },
      });
    }

    if (error instanceof ZodError) {
      return reply.code(400).send({
        error: {
          code: 'validation_error',
          message: 'Request failed validation',
          details: error.flatten(),
        },
      });
    }

    // Fastify's own errors (bad JSON body, body too large) carry a statusCode.
    const fastifyError = error as { statusCode?: number; code?: string; message?: string };
    if (fastifyError.statusCode && fastifyError.statusCode < 500) {
      return reply.code(fastifyError.statusCode).send({
        error: {
          code: fastifyError.code ?? 'bad_request',
          message: fastifyError.message ?? 'Bad request',
        },
      });
    }

    request.log.error({ err: error }, 'Unhandled error');
    return reply.code(500).send({
      error: { code: 'internal_error', message: 'Something went wrong on our end.' },
    });
  });

  app.setNotFoundHandler((request, reply) =>
    reply.code(404).send({
      error: {
        code: 'route_not_found',
        message: `${request.method} ${request.url} is not a route on this server.`,
      },
    }),
  );

  /**
   * Health check that also reports which optional integrations are live.
   *
   * `checked_at` is surfaced because the client shows it on the "switched off"
   * screens — "Checked at 09:12" reads as a status the app knows, rather than
   * a guess.
   */
  app.get('/health', async () => ({
    status: 'ok',
    checked_at: new Date().toISOString(),
    // Asked, not assumed: after a deploy this is the line that says the
    // connection string works. It is also what a scheduled ping relies on to
    // keep a free Supabase project from pausing — a ping that never reached
    // the database would not count as activity.
    database: await db.one('SELECT 1 AS ok').then(
      () => 'ok',
      () => 'unreachable',
    ),
    sign_in: env.SUPABASE_URL ? 'supabase' : 'local',
    features: {
      planner: features.planner,
      // Named for the same reason the schedule provider is: a run that is slow,
      // or refused for quota, is the model's identity being relevant — and
      // there is otherwise no way to see which one is configured.
      planner_model: env.PLANNER_MODEL,
      planner_effort: env.PLANNER_EFFORT,
      maps: features.maps,
      flights: features.flights,
      transit: features.maps,
      flight_provider: env.FLIGHT_PROVIDER,
      // Surfaced separately because it is separately configured — and because
      // "why am I still seeing mock data" is otherwise invisible from outside.
      schedules: features.schedules,
      schedule_provider: env.SCHEDULE_PROVIDER,
      flights_are_estimates: env.FLIGHT_PROVIDER === 'mock' || env.AMADEUS_BASE_URL.includes('test.api'),
    },
  }));

  await app.register(
    async (api) => {
      // Every /v1 request says who it is from first; nothing below runs for
      // a request that cannot.
      api.decorateRequest('caller', null as unknown as Caller);
      api.addHook('onRequest', async (req) => {
        req.caller = await verify(req.headers.authorization);
      });

      // A trip in the path must be the caller's. 404 rather than 403: a
      // stranger learns nothing about whether the trip exists. Children of a
      // trip — members, places, sources, selections — are checked against
      // that trip by the routes themselves.
      api.addHook('preHandler', async (req) => {
        const route = req.routeOptions.url ?? '';
        const params = req.params as { id?: string; planId?: string };
        if (params.id && /\/trips\/:id(\/|$)/.test(route)) {
          if ((await tripOwner(params.id)) !== req.caller.userId) {
            throw notFound('trip_not_found', `No trip with id ${params.id}`);
          }
        }
        if (params.planId && /\/plans\/:planId$/.test(route)) {
          const plan = await getPlan(params.planId);
          if ((await tripOwner(plan.trip_id)) !== req.caller.userId) {
            throw notFound('plan_not_found', `No plan with id ${params.planId}`);
          }
        }
      });

      // Limits attach per route as each is registered — before the plugin's
      // own onRoute hook reads them — and count per person, not per address:
      // a whole office on one IP is many people.
      api.addHook('onRoute', (route: RouteOptions) => {
        const path = route.url ?? '';
        const methods = ([] as string[]).concat(route.method);
        const rule =
          LIMITS.find((l) => l.path.test(path) && (!l.method || methods.includes(l.method))) ??
          DEFAULT_LIMIT;
        route.config = { ...(route.config ?? {}), rateLimit: { max: rule.max, timeWindow: rule.timeWindow } };
      });
      await api.register(rateLimit, {
        hook: 'preHandler',
        keyGenerator: (req) => req.caller?.userId ?? req.ip,
        // An AppError, so a 429 reaches the client in the same shape as
        // every other error rather than as the plugin's own.
        errorResponseBuilder: (_req, ctx) =>
          new AppError(
            429,
            'rate_limited',
            `That's a lot of requests in a short time. Try again in ${ctx.after}.`,
          ),
      });

      // Takes the verifier, because it has to check a second token: the one
      // belonging to the anonymous user whose trips are being claimed.
      await api.register(accountRoutes(verify));
      await api.register(tripRoutes);
      await api.register(ingestRoutes);
      await api.register(placeRoutes);
      await api.register(flightRoutes);
      await api.register(transitRoutes);
      await api.register(travelRoutes);
      await api.register(plannerRoutes);
    },
    { prefix: '/v1' },
  );

  return app;
}
