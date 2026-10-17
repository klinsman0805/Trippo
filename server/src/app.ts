import cors from '@fastify/cors';
import fastifyStatic from '@fastify/static';
import Fastify, { type FastifyInstance } from 'fastify';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { ZodError } from 'zod';
import { env, features } from './config/env.js';
import { AppError } from './lib/errors.js';
import { flightRoutes } from './modules/flights/routes.js';
import { ingestRoutes } from './modules/ingest/routes.js';
import { placeRoutes } from './modules/places/routes.js';
import { plannerRoutes } from './modules/planner/routes.js';
import { transitRoutes } from './modules/transit/routes.js';
import { travelRoutes } from './modules/travel/routes.js';
import { tripRoutes } from './modules/trips/routes.js';

export async function buildApp(): Promise<FastifyInstance> {
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

  if (env.WEB_DIR) {
    const root = resolve(env.WEB_DIR);
    // Loud rather than silent: a deploy whose app build failed would
    // otherwise answer `/` with a JSON 404 and look like a dead server.
    if (!existsSync(resolve(root, 'index.html'))) {
      throw new Error(`WEB_DIR is set to ${root}, but there is no index.html in it.`);
    }
    // The app routes with the URL hash, so `/` is the only page there is —
    // no fallback to index.html needed, and an unknown path still gets the
    // API's own JSON 404.
    await app.register(fastifyStatic, { root, prefix: '/' });
  }

  return app;
}
