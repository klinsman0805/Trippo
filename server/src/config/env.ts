import { z } from 'zod';

/**
 * Load `.env` before anything reads `process.env`.
 *
 * Node 22 can do this natively, so there is no dotenv dependency. Real
 * environment variables still win — `loadEnvFile` does not overwrite them —
 * which is what you want in a deployed environment that has no file.
 */
try {
  process.loadEnvFile();
} catch {
  // No .env is normal in production; the schema below reports what's missing.
}

/**
 * All configuration lives here. Every provider key is optional so the server
 * boots with nothing configured — each module degrades to a clearly-labelled
 * "unavailable" or mock provider rather than crashing at startup.
 */
const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  HOST: z.string().default('0.0.0.0'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

  DATABASE_PATH: z.string().default('./data/trippo.db'),

  // Planner (Google Gemini). Without this the /plan endpoints return 503.
  // Free keys come from https://aistudio.google.com/apikey
  GEMINI_API_KEY: z.string().optional(),
  PLANNER_MODEL: z.string().default('gemini-3.7-flash'),
  PLANNER_EFFORT: z.enum(['minimal', 'low', 'medium', 'high']).default('high'),
  /** Cheaper model for mechanical work like pulling places out of a page. */
  EXTRACTION_MODEL: z.string().default('gemini-3.5-flash-lite'),

  // Geocoding and transit.
  //   osm    — Photon + Transitous/MOTIS. Free, no key, no quota.
  //   google — Places (New) + Routes API. Needs a key and bills per call.
  // Proximity clustering is geometric either way and uses neither.
  MAPS_PROVIDER: z.enum(['osm', 'google']).default('osm'),
  GOOGLE_MAPS_API_KEY: z.string().optional(),
  /** Override to point at a self-hosted Photon. */
  PHOTON_URL: z.string().url().default('https://photon.komoot.io'),
  /** Override to point at a self-hosted MOTIS. */
  MOTIS_URL: z.string().url().default('https://api.transitous.org'),

  // Flights. 'amadeus' needs the two client credentials; 'mock' needs nothing.
  FLIGHT_PROVIDER: z.enum(['amadeus', 'mock']).default('mock'),
  AMADEUS_CLIENT_ID: z.string().optional(),
  AMADEUS_CLIENT_SECRET: z.string().optional(),
  AMADEUS_BASE_URL: z.string().url().default('https://test.api.amadeus.com'),

  // Outbound fetch behaviour for link ingestion.
  INGEST_USER_AGENT: z
    .string()
    .default(
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36',
    ),
  INGEST_TIMEOUT_MS: z.coerce.number().int().positive().default(15_000),
  INGEST_MAX_BYTES: z.coerce.number().int().positive().default(3_000_000),
});

export type Env = z.infer<typeof EnvSchema>;

const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment configuration:');
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env: Env = parsed.data;

export const features = {
  planner: Boolean(env.GEMINI_API_KEY),
  // The OSM stack needs no credentials, so maps are on unless Google is
  // selected without a key.
  maps: env.MAPS_PROVIDER === 'osm' || Boolean(env.GOOGLE_MAPS_API_KEY),
  flights:
    env.FLIGHT_PROVIDER === 'mock' ||
    Boolean(env.AMADEUS_CLIENT_ID && env.AMADEUS_CLIENT_SECRET),
} as const;
