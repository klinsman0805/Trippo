import { mkdirSync } from 'node:fs';
import { env } from '../config/env.js';

/**
 * Postgres, from one of two places.
 *
 * With `DATABASE_URL` set — a deploy — it is Supabase, through `postgres.js`.
 * Without it — a laptop, a test run — it is PGlite: real Postgres compiled to
 * WebAssembly, running inside this process against a folder on disk (or
 * memory). Local development needs no database server and no account, and
 * runs the same SQL as production rather than a lookalike.
 *
 * Every call site goes through [Queryable], so neither engine leaks past this
 * file. SQL keeps the `?` and `@name` placeholders it was written with; they
 * are rewritten to Postgres's `$1` here, once.
 */

export type Row = Record<string, unknown>;
type Params = readonly unknown[] | Record<string, unknown>;

export interface Queryable {
  /** Every row. */
  query<T = Row>(sql: string, params?: Params): Promise<T[]>;
  /** The first row, or undefined. */
  one<T = Row>(sql: string, params?: Params): Promise<T | undefined>;
  /** How many rows a write touched. */
  run(sql: string, params?: Params): Promise<number>;
}

export interface Db extends Queryable {
  /** Runs [fn] in one transaction; its queries must go through the argument. */
  tx<T>(fn: (q: Queryable) => Promise<T>): Promise<T>;
  close(): Promise<void>;
}

/**
 * `?` and `@name` to `$n`.
 *
 * Positional `?` takes the array in order. Named `@name` takes an object, and
 * a name used twice reuses one parameter. Neither form appears inside a string
 * literal in this codebase's SQL, which is what makes a rewrite this plain
 * safe; keep it that way.
 */
export function toPostgres(sql: string, params: Params = []): { text: string; values: unknown[] } {
  if (Array.isArray(params)) {
    let i = 0;
    const text = sql.replace(/\?/g, () => `$${++i}`);
    if (i !== params.length) {
      throw new Error(`SQL has ${i} placeholders but got ${params.length} values: ${sql.trim().slice(0, 80)}`);
    }
    return { text, values: [...params] };
  }

  const named = params as Record<string, unknown>;
  const index = new Map<string, number>();
  const values: unknown[] = [];
  const text = sql.replace(/@([a-z_][a-z0-9_]*)/gi, (_, name: string) => {
    if (!(name in named)) throw new Error(`SQL names @${name} but no value was given`);
    let at = index.get(name);
    if (at === undefined) {
      values.push(named[name]);
      at = values.length;
      index.set(name, at);
    }
    return `$${at}`;
  });
  return { text, values };
}

// --- shared helpers ---
//
// Above the connection on purpose: opening it runs the migrations, which use
// these, while this module is still being evaluated.

/** Columns stored as JSON text. */
export const toJson = (v: unknown): string => JSON.stringify(v ?? null);
export const fromJson = <T>(v: unknown, fallback: T): T => {
  if (typeof v !== 'string') return fallback;
  try {
    const parsed = JSON.parse(v);
    return parsed === null ? fallback : (parsed as T);
  } catch {
    return fallback;
  }
};

export const nowIso = (): string => new Date().toISOString();
export const newId = (prefix: string): string =>
  `${prefix}_${crypto.randomUUID().replace(/-/g, '').slice(0, 20)}`;

// --- engines ---

type Exec = (text: string, values: unknown[]) => Promise<{ rows: Row[]; count: number }>;

function queryable(exec: Exec): Queryable {
  return {
    async query<T>(sql: string, params?: Params) {
      const { text, values } = toPostgres(sql, params);
      return (await exec(text, values)).rows as T[];
    },
    async one<T>(sql: string, params?: Params) {
      const { text, values } = toPostgres(sql, params);
      return (await exec(text, values)).rows[0] as T | undefined;
    },
    async run(sql: string, params?: Params) {
      const { text, values } = toPostgres(sql, params);
      return (await exec(text, values)).count;
    },
  };
}

async function openRemote(url: string): Promise<Db> {
  const { default: postgres } = await import('postgres');
  const sql = postgres(url, {
    // Supabase's pooler runs in transaction mode, which cannot hold a
    // prepared statement between transactions.
    prepare: false,
    max: env.DATABASE_POOL_MAX,
    idle_timeout: 20,
    // Postgres notices (`relation already exists, skipping`) are not news.
    onnotice: () => {},
  });

  const exec =
    (runner: { unsafe: (t: string, v: never[]) => Promise<Row[] & { count: number }> }): Exec =>
    async (text, values) => {
      const rows = await runner.unsafe(text, values as never[]);
      return { rows: [...rows], count: rows.count ?? 0 };
    };

  return {
    ...queryable(exec(sql as never)),
    tx: (fn) => sql.begin((tx) => fn(queryable(exec(tx as never)))) as never,
    close: () => sql.end({ timeout: 5 }),
  };
}

async function openLocal(dir: string): Promise<Db> {
  const { PGlite } = await import('@electric-sql/pglite');
  if (!dir.startsWith('memory://')) mkdirSync(dir, { recursive: true });
  const pg = new PGlite(dir);

  const exec =
    (runner: { query: (t: string, v: unknown[]) => Promise<{ rows: unknown[]; affectedRows?: number }> }): Exec =>
    async (text, values) => {
      const res = await runner.query(text, values);
      return { rows: res.rows as Row[], count: res.affectedRows ?? 0 };
    };

  return {
    ...queryable(exec(pg)),
    tx: (fn) => pg.transaction((tx) => fn(queryable(exec(tx)))),
    close: () => pg.close(),
  };
}

// --- schema ---

/**
 * Append-only: each entry runs once, recorded in `schema_migrations`. Never
 * edit a shipped entry — add a new one.
 *
 * Every table has row-level security switched on and no policies. Supabase
 * publishes the `public` schema through its REST API to anyone holding the
 * app's anon key; with RLS on and nothing allowed, those roles see nothing.
 * The server connects as the tables' owner, which RLS does not apply to.
 *
 * Text where JSON is stored, and integers for booleans, as the SQLite schema
 * had them — the repositories parse both, and keeping the shapes made this a
 * port rather than a rewrite.
 */
const MIGRATIONS: string[] = [
  // 1 — trips, travellers, imports, places, flights, plans, conflicts,
  // failures and the travel lookups: the SQLite schema, in one step.
  `
  CREATE TABLE trips (
    id               TEXT PRIMARY KEY,
    owner_id         TEXT NOT NULL,              -- the Supabase user who made it
    title            TEXT NOT NULL,
    destinations     TEXT NOT NULL DEFAULT '[]',
    start_date       TEXT,
    end_date         TEXT,
    date_flexible    INTEGER NOT NULL DEFAULT 1,
    currency         TEXT NOT NULL DEFAULT 'USD',
    total_budget     DOUBLE PRECISION,
    budget_basis     TEXT NOT NULL DEFAULT 'total',
    purpose          TEXT,
    hard_constraints TEXT NOT NULL DEFAULT '[]',
    notes            TEXT,
    created_at       TEXT NOT NULL,
    updated_at       TEXT NOT NULL
  );
  CREATE INDEX idx_trips_owner ON trips(owner_id, updated_at DESC);

  CREATE TABLE members (
    id                   TEXT PRIMARY KEY,
    trip_id              TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    name                 TEXT NOT NULL,
    departure_city       TEXT,
    interests            TEXT NOT NULL DEFAULT '[]',
    pace                 TEXT NOT NULL DEFAULT 'moderate',
    budget_sensitivity   TEXT,
    dietary_restrictions TEXT NOT NULL DEFAULT '[]',
    accessibility_needs  TEXT NOT NULL DEFAULT '[]',
    deal_breakers        TEXT NOT NULL DEFAULT '[]',
    wants                TEXT NOT NULL DEFAULT '[]',
    avoids               TEXT NOT NULL DEFAULT '[]',
    created_at           TEXT NOT NULL
  );
  CREATE INDEX idx_members_trip ON members(trip_id);

  CREATE TABLE sources (
    id         TEXT PRIMARY KEY,
    trip_id    TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    url        TEXT,
    kind       TEXT NOT NULL,
    status     TEXT NOT NULL,
    title      TEXT,
    author     TEXT,
    raw_text   TEXT,
    error      TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  CREATE INDEX idx_sources_trip ON sources(trip_id);

  CREATE TABLE places (
    id              TEXT PRIMARY KEY,
    trip_id         TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    source_id       TEXT REFERENCES sources(id) ON DELETE SET NULL,
    name            TEXT NOT NULL,
    category        TEXT,
    city            TEXT,
    country         TEXT,
    address         TEXT,
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION,
    google_place_id TEXT,
    why             TEXT,
    tags            TEXT NOT NULL DEFAULT '[]',
    resolved        INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL
  );
  CREATE INDEX idx_places_trip ON places(trip_id);

  CREATE TABLE flight_selections (
    id         TEXT PRIMARY KEY,
    trip_id    TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    member_id  TEXT REFERENCES members(id) ON DELETE CASCADE,
    direction  TEXT NOT NULL,
    offer      TEXT NOT NULL,
    created_at TEXT NOT NULL
  );
  CREATE INDEX idx_flights_trip ON flight_selections(trip_id);

  CREATE TABLE plans (
    id           TEXT PRIMARY KEY,
    trip_id      TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    revision     INTEGER NOT NULL,
    status       TEXT NOT NULL,
    summary      TEXT NOT NULL,
    plan         TEXT NOT NULL,
    model        TEXT NOT NULL,
    user_request TEXT,
    created_at   TEXT NOT NULL
  );
  CREATE UNIQUE INDEX idx_plans_trip_rev ON plans(trip_id, revision);

  CREATE TABLE conflict_acknowledgements (
    trip_id    TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    tag        TEXT NOT NULL,
    accepted   INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (trip_id, tag)
  );

  CREATE TABLE plan_failures (
    trip_id            TEXT PRIMARY KEY REFERENCES trips(id) ON DELETE CASCADE,
    reason_code        TEXT NOT NULL,
    detail             TEXT,
    elapsed_ms         INTEGER NOT NULL,
    last_good_revision INTEGER,
    user_request       TEXT,
    created_at         TEXT NOT NULL
  );

  CREATE TABLE geo_lookups (
    query      TEXT PRIMARY KEY,
    found      INTEGER NOT NULL,
    lat        DOUBLE PRECISION,
    lng        DOUBLE PRECISION,
    created_at TEXT NOT NULL
  );

  CREATE TABLE travel_legs (
    key        TEXT PRIMARY KEY,
    result     TEXT,
    created_at TEXT NOT NULL
  );

  ALTER TABLE trips                     ENABLE ROW LEVEL SECURITY;
  ALTER TABLE members                   ENABLE ROW LEVEL SECURITY;
  ALTER TABLE sources                   ENABLE ROW LEVEL SECURITY;
  ALTER TABLE places                    ENABLE ROW LEVEL SECURITY;
  ALTER TABLE flight_selections         ENABLE ROW LEVEL SECURITY;
  ALTER TABLE plans                     ENABLE ROW LEVEL SECURITY;
  ALTER TABLE conflict_acknowledgements ENABLE ROW LEVEL SECURITY;
  ALTER TABLE plan_failures             ENABLE ROW LEVEL SECURITY;
  ALTER TABLE geo_lookups               ENABLE ROW LEVEL SECURITY;
  ALTER TABLE travel_legs               ENABLE ROW LEVEL SECURITY;
  `,
];

/**
 * Applies whatever has not run yet, under an advisory lock: on Cloud Run two
 * instances can start at once, and only one of them should migrate.
 */
async function migrate(db: Db): Promise<void> {
  await db.run(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version    INTEGER PRIMARY KEY,
      applied_at TEXT NOT NULL
    )`);
  await db.run('ALTER TABLE schema_migrations ENABLE ROW LEVEL SECURITY');

  await db.tx(async (q) => {
    // Any constant will do, as long as it is this app's.
    await q.query('SELECT pg_advisory_xact_lock(7274770)');
    const done = new Set(
      (await q.query<{ version: number }>('SELECT version FROM schema_migrations')).map(
        (r) => r.version,
      ),
    );
    for (let i = 0; i < MIGRATIONS.length; i++) {
      if (done.has(i + 1)) continue;
      try {
        for (const statement of statements(MIGRATIONS[i]!)) await q.run(statement);
      } catch (err) {
        throw new Error(`Migration ${i + 1} failed: ${(err as Error).message}`);
      }
      await q.run('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)', [
        i + 1,
        nowIso(),
      ]);
    }
  });
}

/** One migration's statements. Parameterised queries take one at a time. */
function statements(sql: string): string[] {
  return sql
    .split(';')
    .map((s) => s.replace(/--.*$/gm, '').trim())
    .filter(Boolean);
}

export async function openDb(): Promise<Db> {
  const db = env.DATABASE_URL
    ? await openRemote(env.DATABASE_URL)
    : await openLocal(env.DATABASE_PATH);
  await migrate(db);
  return db;
}

export const db: Db = await openDb();
