import { buildApp } from './app.js';
import { env, features } from './config/env.js';

const app = await buildApp();

// Surface disabled integrations at boot — a missing key otherwise only shows up
// as a 503 the first time someone taps "plan my trip".
if (!features.planner) {
  app.log.warn('GEMINI_API_KEY not set — link extraction and trip planning are disabled.');
}
if (!features.maps) {
  app.log.warn('GOOGLE_MAPS_API_KEY not set — place lookup and transit routing are disabled.');
}
if (env.FLIGHT_PROVIDER === 'mock') {
  app.log.warn('FLIGHT_PROVIDER=mock — flight results are synthetic estimates, not real fares.');
}

try {
  await app.listen({ port: env.PORT, host: env.HOST });
} catch (err) {
  app.log.error(err, 'Failed to start server');
  process.exit(1);
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    app.log.info({ signal }, 'Shutting down');
    void app.close().then(() => process.exit(0));
  });
}
