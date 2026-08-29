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
  PLANNER_MODEL: z.string().default('gemini-3.5-flash-lite'),
  /**
   * How long to wait on one model call before giving up, in milliseconds.
   *
   * Deliberately shorter than the client's own patience, so a slow run comes
   * back as a recorded failure with a retry rather than as a request the app
   * eventually abandons while the server is still working on it.
   */
  PLANNER_TIMEOUT_MS: z.coerce.number().int().positive().default(300_000),
  /**
   * Note that not every model accepts every level — the 3.5 family rejects
   * 'minimal' with a 400 — so this is validated by the provider, not here.
   */
  PLANNER_EFFORT: z.enum(['minimal', 'low', 'medium', 'high']).default('low'),
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

  // Fares. 'amadeus' needs the two client credentials; 'mock' needs nothing.
  FLIGHT_PROVIDER: z.enum(['amadeus', 'mock']).default('mock'),
  AMADEUS_CLIENT_ID: z.string().optional(),
  AMADEUS_CLIENT_SECRET: z.string().optional(),
  AMADEUS_BASE_URL: z.string().url().default('https://test.api.amadeus.com'),

  /**
   * Schedules — "what does AK892 do on the 26th" — which is a different
   * question from "what would a seat cost", and in practice a different
   * vendor. Flight-status APIs sell no fares, and fare APIs answer schedule
   * questions poorly, so the two are configured separately.
   */
  SCHEDULE_PROVIDER: z.enum(['aerodatabox', 'amadeus', 'mock']).default('mock'),
  AERODATABOX_API_KEY: z.string().optional(),
  /** RapidAPI gateway by default; set to the direct host if you buy direct. */
  AERODATABOX_HOST: z.string().default('aerodatabox.p.rapidapi.com'),

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
  /** Looking a booked flight up by number — separate from fares. */
  schedules:
    env.SCHEDULE_PROVIDER === 'mock' ||
    (env.SCHEDULE_PROVIDER === 'aerodatabox'
      ? Boolean(env.AERODATABOX_API_KEY)
      : Boolean(env.AMADEUS_CLIENT_ID && env.AMADEUS_CLIENT_SECRET)),
} as const;
