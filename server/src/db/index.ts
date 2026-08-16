import Database from 'better-sqlite3';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { env } from '../config/env.js';

/**
 * Migrations are an append-only array: each entry runs once, tracked by
 * `user_version`. Never edit a shipped entry — add a new one.
 */
const MIGRATIONS: string[] = [
  // 1 — core trip + member model
  `
  CREATE TABLE trips (
    id            TEXT PRIMARY KEY,
    title         TEXT NOT NULL,
    destinations  TEXT NOT NULL DEFAULT '[]',   -- JSON string[]
    start_date    TEXT,                          -- YYYY-MM-DD, null when flexible
    end_date      TEXT,
    date_flexible INTEGER NOT NULL DEFAULT 1,
    currency      TEXT NOT NULL DEFAULT 'USD',
    total_budget  REAL,
    budget_basis  TEXT NOT NULL DEFAULT 'total', -- 'total' | 'per_person'
    purpose       TEXT,
    hard_constraints TEXT NOT NULL DEFAULT '[]', -- JSON string[]
    notes         TEXT,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
  );

  CREATE TABLE members (
    id                  TEXT PRIMARY KEY,
    trip_id             TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    name                TEXT NOT NULL,
    departure_city      TEXT,
    interests           TEXT NOT NULL DEFAULT '[]',
    pace                TEXT NOT NULL DEFAULT 'moderate', -- packed|moderate|relaxed
    budget_sensitivity  TEXT,
    dietary_restrictions TEXT NOT NULL DEFAULT '[]',
    accessibility_needs TEXT NOT NULL DEFAULT '[]',
    deal_breakers       TEXT NOT NULL DEFAULT '[]',
    wants               TEXT NOT NULL DEFAULT '[]',
    avoids              TEXT NOT NULL DEFAULT '[]',
    created_at          TEXT NOT NULL
  );
  CREATE INDEX idx_members_trip ON members(trip_id);
  `,

  // 2 — imported links and the candidate places extracted from them
  `
  CREATE TABLE sources (
    id           TEXT PRIMARY KEY,
    trip_id      TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    url          TEXT,
    kind         TEXT NOT NULL,               -- xiaohongshu|tripadvisor|web|manual
    status       TEXT NOT NULL,               -- pending|fetched|extracted|failed|needs_manual
    title        TEXT,
    author       TEXT,
    raw_text     TEXT,
    error        TEXT,
    created_at   TEXT NOT NULL,
    updated_at   TEXT NOT NULL
  );
  CREATE INDEX idx_sources_trip ON sources(trip_id);

  CREATE TABLE places (
    id              TEXT PRIMARY KEY,
    trip_id         TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    source_id       TEXT REFERENCES sources(id) ON DELETE SET NULL,
    name            TEXT NOT NULL,
    category        TEXT,                     -- food|sight|activity|lodging|transport|shopping|nightlife|other
    city            TEXT,
    country         TEXT,
    address         TEXT,
    lat             REAL,
    lng             REAL,
    google_place_id TEXT,
    why             TEXT,                     -- why the source recommended it
    tags            TEXT NOT NULL DEFAULT '[]',
    resolved        INTEGER NOT NULL DEFAULT 0, -- 1 once geocoded against Places
    created_at      TEXT NOT NULL
  );
  CREATE INDEX idx_places_trip ON places(trip_id);
  `,

  // 3 — flight selections and generated plan revisions
  `
  CREATE TABLE flight_selections (
    id          TEXT PRIMARY KEY,
    trip_id     TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    member_id   TEXT REFERENCES members(id) ON DELETE CASCADE,
    direction   TEXT NOT NULL,                -- outbound|return
    offer       TEXT NOT NULL,                -- JSON FlightOffer
    created_at  TEXT NOT NULL
  );
  CREATE INDEX idx_flights_trip ON flight_selections(trip_id);

  CREATE TABLE plans (
    id           TEXT PRIMARY KEY,
    trip_id      TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    revision     INTEGER NOT NULL,
    status       TEXT NOT NULL,               -- complete|needs_info|infeasible
    summary      TEXT NOT NULL,               -- Part A prose
    plan         TEXT NOT NULL,               -- JSON, validated against PlanSchema
    model        TEXT NOT NULL,
    user_request TEXT,                        -- the refinement that produced it
    created_at   TEXT NOT NULL
  );
  CREATE UNIQUE INDEX idx_plans_trip_rev ON plans(trip_id, revision);
  `,

  // 4 — conflict acknowledgement ("Looks good" on a conflict card)
  //
  // Keyed by the conflict's tag rather than its array index: a regenerated plan
  // reorders conflicts, and an index-keyed record would silently reattach the
  // acknowledgement to a different conflict.
  `
  CREATE TABLE conflict_acknowledgements (
    trip_id     TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    tag         TEXT NOT NULL,
    accepted    INTEGER NOT NULL DEFAULT 1,
    updated_at  TEXT NOT NULL,
    PRIMARY KEY (trip_id, tag)
  );
  `,

  // 5 — the last planning attempt that did not produce a revision
  //
  // One row per trip, replaced on each failure and deleted on the next success.
  // History is deliberately not kept: the failed state answers "what happened
  // just now, and what is still here", and a log of old failures would only
  // make that harder to word.
  `
  CREATE TABLE plan_failures (
    trip_id            TEXT PRIMARY KEY REFERENCES trips(id) ON DELETE CASCADE,
    reason_code        TEXT NOT NULL,           -- the AppError code, or 'unknown'
    detail             TEXT,                    -- the raw message, for support
    elapsed_ms         INTEGER NOT NULL,
    last_good_revision INTEGER,                 -- null when nothing was ever planned
    user_request       TEXT,                    -- the refinement being attempted
    created_at         TEXT NOT NULL
  );
  `,
];

function migrate(db: Database.Database): void {
  const current = db.pragma('user_version', { simple: true }) as number;
  for (let i = current; i < MIGRATIONS.length; i++) {
    const sql = MIGRATIONS[i];
    if (!sql) continue;
    db.exec('BEGIN');
    try {
      db.exec(sql);
      db.pragma(`user_version = ${i + 1}`);
      db.exec('COMMIT');
    } catch (err) {
      db.exec('ROLLBACK');
      throw new Error(`Migration ${i + 1} failed: ${(err as Error).message}`);
    }
  }
}

function open(): Database.Database {
  mkdirSync(dirname(env.DATABASE_PATH), { recursive: true });
  const db = new Database(env.DATABASE_PATH);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  migrate(db);
  return db;
}

export const db = open();

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
