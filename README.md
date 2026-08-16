# Wayfare (Trippo)

Group trip planner for 2–8 travellers. Each person records their own pace and
needs; the planner produces a day-by-day itinerary, tracks a shared budget, and
surfaces preference conflicts with the compromise it made.

The UI implements the **Wayfare mobile handoff** — four tabs, two platform
dresses, tokens transcribed from the spec.

```
Trippo/
├── server/   TypeScript + Fastify backend
└── app/      Flutter client (iOS + Android dresses)
```

## The four tabs

| Tab | What it shows |
|---|---|
| **Trip** | One day at a time behind a day-chip scroller. Activity cards, optional ones dashed with a badge, overlapping member avatars, per-day cost. |
| **Budget** | Over/under hero with a capped progress bar, then per-category planned-vs-estimated bars. |
| **Group** | Travellers with pace and needs, Generate CTA, and the conflicts the planner surfaced with "Looks good" / "Discuss". |
| **Refine** | Chat that mutates the itinerary — and takes pasted links (see below). |

Setup lives in the add-traveller bottom sheet, not a separate flow. Generating is
a full-screen overlay.

## Where link import lives

The handoff has no import screen, so imports go through the **Refine composer**.
Paste a 小红书 share blob or any URL and the server detects it, runs the ingest
pipeline, and replies with what it found:

```
You:  12 复制本条信息，打开【小红书】App… http://xhslink.com/a/…
Bot:  Found 6 places in that — 3 in Alfama, 2 in Bairro Alto.
      Time Out Market, A Cevicheria, … Want me to work them into the plan?
```

Importing does **not** immediately regenerate the plan. Pasting three links in a
row would otherwise fire three full planning runs, each superseded by the next.
The import reports what it found and offers to work it in.

When 小红书 blocks the fetch, the same box becomes the paste target — the reply
asks for the note text, and the next message is routed to that source. The
blocked-import path is a normal conversational turn, not an error modal.

## Why this split

Every hard part is server-side and has to be:

- The Gemini API key can never ship inside the app binary.
- 小红书 and TripAdvisor need a server-side fetcher with a browser-like UA;
  the app cannot do it from the device.
- Provider keys (Amadeus, Google Maps) stay on the server, where they can be
  rotated and rate-limited without an app release.

That leaves the client as forms, lists, maps and a share-intent handler — which
is why Flutter is enough, and native Swift + Kotlin would be double the work for
no gain.

## Running it

```bash
cd server && npm install && cp .env.example .env && npm run dev
```

The server boots with **no keys configured** and reports what's disabled:

```bash
curl localhost:8080/health
# {"status":"ok","features":{"planner":false,"maps":false,"flights":true,"flight_provider":"mock"}}
```

Then the app:

```bash
cd app && flutter run
```

`AppConfig` points at `10.0.2.2:8080` on the Android emulator and
`localhost:8080` elsewhere. Override with
`--dart-define=TRIPPO_API_BASE=https://your-host`.

## The modules

### Link ingestion (`server/src/modules/ingest`)

Extractors are tried in registration order, first match wins:

| Extractor | Strategy |
|---|---|
| `xiaohongshu` | `__INITIAL_STATE__` blob → OpenGraph meta → `needs_manual` |
| `tripadvisor` | schema.org LD+JSON (name, address, geo, rating) → Readability |
| `generic` | Readability article body → OpenGraph description |

Scraped text goes to Gemini with an extraction prompt that is explicit about
**not** inventing places — an empty result is the correct answer for a page with
no concrete venues in it. Results land in the trip's candidate `places` pool,
deduped by (name, city).

**On 小红书 specifically:** XHS blocks unauthenticated server-side reads. Note
pages are client-rendered behind a signed-request check, so a plain fetch
usually returns a login wall. What survives is the OpenGraph metadata served for
link unfurling, which is often enough to identify the places a note covers.
When even that fails, the import is stored with `status: needs_manual` and the
client shows a paste box against that same source row.

**Treat `needs_manual` as a normal branch of the import flow, not an error** —
it will be hit regularly, and the UI already handles it. The share-text parser
means users can paste the whole clipboard blob
(`12 复制本条信息，打开【小红书】App查看… http://xhslink.com/…`) untouched.

### Flights (`server/src/modules/flights`)

`FlightProvider` interface with two adapters. `mock` needs no credentials and
returns deterministic synthetic offers so the whole flow is testable offline;
`amadeus` wraps Flight Offers Search v2.

Every offer carries `is_estimate`. It is true for all mock offers **and** for
anything from `test.api.amadeus.com`, whose inventory is cached and not
bookable. The client must label these — showing a sandbox fare as a real price
is exactly the false confidence the planner spec forbids.

Selecting an offer derives a **date envelope** and writes the dates back onto
the trip. This is what makes flight selection load-bearing rather than
decorative: a 20:01 arrival sets `arrival_day_usable: false`, and the planner
context then tells the model not to schedule activities on day 1.

### Places and transit (`server/src/modules/geo`)

Two provider stacks behind one interface, selected by `MAPS_PROVIDER`:

| | `osm` (default) | `google` |
|---|---|---|
| Geocoding | [Photon](https://photon.komoot.io/) | Places API (New) |
| Transit | [Transitous](https://transitous.org/) / [MOTIS](https://github.com/motis-project/motis) | Routes API |
| Cost | free, no key | needs a key, bills per call |

`osm` needs no credentials at all — `/health` reports `maps: true` on a clean
checkout. Both upstreams are open source, so `PHOTON_URL` and `MOTIS_URL` can
point at self-hosted instances when the public ones aren't good enough.

**Proximity is geometric and calls no API either way.** Grouping a day only
needs "near or not near" — the difference between a 19- and a 23-minute ride
never changes which places share a day — so it's a haversine calculation with
no quota, no element cap and no failure mode. That's what removed the hardest
dependency, not a provider swap.

Turn-by-turn directions deliberately stop at a **deep link to the traveller's
own maps app**. Live departures, disruptions and their actual location belong
there, not to a route computed at planning time. `RouteResult` carries a
`directions_url` for that, and `is_estimate` marks any duration that came from
the straight-line fallback rather than a real router — the UI must not show an
estimate as a timetable.

Two things the free tier demands, both handled: an identifying `User-Agent`
(Transitous answers a generic one with a 403), and visible **© OpenStreetMap
contributors** attribution, which the API returns alongside results so the
client can render it.

### Planner (`server/src/modules/planner`)

Runs on **Google Gemini** via `@google/genai`. All model access goes through
`src/lib/llm.ts`, a deliberately narrow seam — every caller asks for "JSON
matching this schema" and nothing else — so switching providers is one file.
Planning runs on `gemini-3.7-flash` at high thinking effort; link extraction is
mechanical so it drops to `gemini-3.5-flash-lite` at low effort.

> **Free-tier caveat.** Google uses free-tier content to improve their products.
> That covers trip details and anything a user pastes in. The paid tier does not.


The Voyager system prompt from the spec, with trip context, member profiles,
selected flights and saved places assembled into the user turn as prose (the
model reasons better over a briefing than a serialized record, and prose carries
each place's provenance).

**One deliberate deviation from the planner spec.** It has the model emit Part A
as prose and Part B inside a fenced ```json block, then has the app parse the
block out and retry on failure. Instead, the whole response is constrained with
`output_config.format`, and Part A lives in a `conversational_summary` field.
The two-part contract is preserved; what changes is that a malformed response
becomes near-impossible rather than a retry path. The spec's retry still exists,
but now it catches what a JSON schema *can't* express — chiefly member ids that
don't exist, which would break per-member filtering in the client.

Refinements ("make day 3 more relaxed") get the previous plan in context and
return a complete new revision, never a diff — so the client replaces its state
wholesale, exactly as the spec's integration notes call for.

## API

All routes are under `/v1`. `GET /health` is unversioned.

| Method | Path | Notes |
|---|---|---|
| `GET POST` | `/trips` | |
| `GET PATCH DELETE` | `/trips/:id` | |
| `POST` | `/trips/:id/members` | `PATCH DELETE .../members/:memberId`; PATCH returns `conflicts_may_be_stale` |
| `GET` | `/trips/:id/sources` | |
| `POST` | `/trips/:id/sources/url` | 202 when it needs a manual paste |
| `POST` | `/trips/:id/sources/text` | pass `source_id` to complete a blocked import |
| `GET POST` | `/trips/:id/places` | |
| `POST` | `/trips/:id/places/resolve` | geocode saved places |
| `GET` | `/trips/:id/places/travel-matrix` | pairwise transit times |
| `GET` | `/flights/airports?q=` | |
| `POST` | `/flights/search` | |
| `GET POST` | `/trips/:id/flights` | selecting pins the trip dates |
| `POST` | `/transit/route`, `/transit/route-by-name`, `/transit/matrix` | |
| `POST` | `/trips/:id/plan` | generate or regenerate; minutes-long |
| `GET` | `/trips/:id/plan` | latest plan + `updated_day` + accepted conflicts |
| `GET DELETE` | `/trips/:id/plan/failure` | the last attempt that produced nothing; DELETE dismisses it |
| `POST` | `/trips/:id/plan/answers` | answer clarifying questions and re-plan |
| `POST` | `/trips/:id/refine` | one Refine turn: link, pasted text, or instruction |
| `GET` | `/trips/:id/chat` | conversation, derived from plan revisions |
| `POST` | `/trips/:id/conflicts/accept` | toggle "Looks good", keyed by tag |

Errors are always `{ error: { code, message, details? } }`. A `503` means the
server has no key for that capability — the client should show the feature as
unavailable rather than as a failure.

## Flights and the date envelope

Flights are a **pushed screen off the Trip tab**, not a fifth tab — entered from
a day-1 row while the trip has no dates, and from the header sheet once it does.

Choosing an offer derives a **date envelope**: which time-of-day slots actually
survive at each end of the trip. That is a constraint on the planner, not a
label on a full day — a short day gets *fewer blocks*, and a day with no usable
slot is dropped from the itinerary entirely rather than rendered empty.

The thresholds are generic across the clock, not tuned to any sample:

| Arrival | Day 1 becomes |
|---|---|
| before 05:00 (red-eye) | afternoon + evening — the morning goes to sleep |
| 05:00–09:30 | full day |
| after 09:30 | afternoon + evening |
| after 15:30 | evening only |
| after 20:00 | nothing — day dropped |

Departures mirror it (before 12:00 kills the morning, before 17:00 the
afternoon, before 21:00 the evening). Same-day trips intersect both ends into a
single short day; one-ways apply the arrival rules alone.

`is_estimate` offers carry four redundant signals, all adjacent to the price:
a `~` prefix, muted price ink, an amber card border, and a band saying in words
that the fare is sandbox inventory and cannot be booked. The CTA changes with
it — **Use these times anyway** rather than **Use these flights**.

Nothing is written until the consequence sheet is confirmed: selection derives
the envelope through a preview endpoint, shows what each affected day loses, and
only then commits.

## Three ways into a dated trip

The Trip tab leads with three options while a trip has no dates, ordered by how
much work each asks rather than by what the app would prefer you did:

1. **"I have my flight booked"** — a flight number and a date. The schedule
   fills in the rest, including the short first and last days. Someone holding
   a booking has the answer already and should not be sent shopping.
2. **"Haven't booked yet?"** — the search flow, with the consequence sheet.
3. **"Not flying?"** — a date range, no flight. No envelope is derived, so no
   day is marked short: a 09:00 train does not cost you a morning the way a
   13:15 landing does, and guessing would put a warning on a day that is fine.

A booked flight is stored with `booked: true` and no price. There is a fare, but
they already paid it and we were not there — inventing one would put a number in
the budget that nobody is going to pay.

**On Skyscanner:** its Flights Live Prices API is partner-gated — a dedicated
account manager and a revenue/commissions portal, not a self-serve key — and it
searches by route and date, so it cannot answer "what does MH123 do on the 12th"
at all. Flight-number lookup therefore runs on Amadeus's On-Demand Flight
Status, and search stays on Amadeus. Both sit behind `FlightProvider`, so
Skyscanner can be added as a third adapter if a partnership ever lands.

**Travellers are optional.** They are what make a plan *tailored* — pace, access
needs, and the conflicts between them — not what makes it possible. The planner
needs a destination; everything else is an improvement.

## The three load-bearing states

**`failed` — the planner stopped and produced nothing.** A page, not an overlay,
so the group can leave with whatever survived. A planning run is atomic: it
writes one complete revision or none. So the state is worded against
**revisions**, not partial days — `Revision 2, all 5 days of it, is still on the
trip`. The reason comes from the real error in the same plain register
(`This project's model quota is used up for now`), and a failure that came back
in 300ms is called a rejection rather than a timeout, because it is one.

**`needs_info` — the planner asked instead of guessing.** The questions replace
the itinerary rather than sitting beside it. The client sends ids and answers;
the server pairs them with the question text it stored, so an answer can never
attach to a question that was never asked. Skipped questions are named in the
follow-up prompt with an explicit licence to assume — without that the planner
asks the same question again and the group cannot leave the state.

**`edit_traveller` — the same sheet as adding, prefilled.** One component, not
two, because a separate edit form drifts from the add form the first time either
changes. Editing adds an identity header, a panel naming the concrete thing at
stake (`Day 4's surf lesson is the only thing currently marked optional for
Ruth`), and a named `Remove Ruth from the trip` — outline, never a destructive
fill, and confirmed. Fields the sheet does not show are carried through rather
than cleared. Afterwards the conflicts are marked stale, because they were
reconciled against preferences that have since changed.

## Deviations from the handoff

Three, all deliberate:

1. **Header action is an icon, not a glyph.** The spec writes `+` / `↻` / `⋯`;
   those fall back to tofu on some platforms. The handoff also says to use the
   codebase's icon set, so icons win.
2. **Trip picker before the shell.** The design holds one trip and says nothing
   about choosing one. The picker fills that gap, styled with the same tokens.
3. **Link import in the Refine composer** — see above. Adds no screens.

Public transport has **no UI**. The backend module works and is tested, but the
design has no surface for it, so nothing was invented. Same for imported
sources, trip creation and the shared trip list — the handoff lists these under
its own "Not covered yet".

## What's verified

Run `flutter test` (44 tests) and `npm run typecheck`.

- `tsc --noEmit` clean, `flutter analyze` clean.
- **Trip tab screenshotted** against `01-ios.png` at 402×874 — day chips,
  activity cards, avatars, costs, dots all match.
- **All four tabs covered by widget tests**: day-chip selection, optional
  filtering and its effect on the day total, split-group vs "Everyone",
  the updated-day notice, over/under budget headlines, per-category deltas,
  the empty state, disabled Generate under two travellers, conflict tags and
  acceptance, chat bubbles, and the iOS/Android radius differences.
- Trip CRUD, flight search, flight selection → date envelope → trip dates.
- 小红书 login-wall detection with the URL pulled out of Chinese share text.
- Every 503 degradation path with keys absent.

**Verified against the live model** (Gemini, `gemini-3.7-flash`):

- Plan generation, ~40s per call. The short-day constraint holds: a 13:15
  arrival produced a day 1 with only afternoon and evening blocks, and the
  10:00 departure day was dropped entirely rather than emitted empty.
- `planned` and `estimated` differ per budget category and each side sums to
  its total; conflict tags come back inside the enum.
- `needs_info` returns structured question cards — the question, the decision it
  unblocks, and either choices or a text placeholder. A deliberately vague trip
  ("Somewhere in Japan", no dates, no budget) produced three: budget as choices,
  travel window as text, and the exact limit behind Ruth's stairs need.
- Link import through the Refine composer: fetch → Readability → extraction →
  deduped places → conversational reply.
- **The failure path, driven for real** on a throwaway database. A refinement
  with a broken key left revision 1 untouched and recorded
  `last_good_revision: 1, last_good_days: 4`; retrying with a working key
  produced revision 2 and cleared the failure. A genuine free-tier `429` was
  recorded as *"This project's model quota is used up for now"*, and the
  `needs_info` plan with its three questions survived that failure intact, so
  the answers can still be sent.

- **The answers flow, both branches.** Answering two of three questions and
  skipping the third produced revision 2, `status: complete`, no questions left,
  and honoured the chosen budget bracket. `plan_anyway` with all three skipped
  did the same and recorded one entry in `trip.assumptions` per skipped
  question — *"Five days, since no trip length was given."* Unknown question ids
  are rejected before any model call.
- **`needs_info` on an iPhone 17 simulator**, against a live server: header
  reads `No dates yet · waiting on two answers`, the info panel and numbered
  cards render with their why-lines and placeholders, and `Send answers` is
  disabled until something is filled in.

Free-tier quota is 20 requests/day per model. `PLANNER_MODEL=gemini-3.5-flash`
is a working fallback once `gemini-3.7-flash` is exhausted.

**Still unverified:** anything needing `GOOGLE_MAPS_API_KEY` (geocoding and
transit routing).

### Prompt tuning that came out of those runs

Two problems only showed up by actually running it:

- The summary came back as brochure copy — *"Welcome to your personalized
  Singapore trip plan! We have crafted…"*. The prompt now carries a VOICE
  section using the handoff's own register as the standard, and the field
  description no longer says "warm". It now opens *"I built this itinerary to
  balance Ruth's need for flat, step-free routes…"*.
- Extraction pulled "Zhangde Primary School" out of a Wikipedia article. The
  test is now "would a visitor plan their day around this?" rather than "is this
  a location?", which drops schools, clinics and housing blocks.

The demo trip is seeded, not generated:

```bash
npx tsx scripts/seed-demo.ts
```

## Next

- Share-intent handling (`receive_sharing_intent`) so 小红书 shares straight into
  the app — the biggest remaining UX win, and why Flutter beat separate native
  clients.
- Design surfaces for transit, imported sources, trip creation and the shared
  trip list — the four the handoff has not covered.
- Feed the travel-time matrix into the planner context; it currently gets
  coordinates and reasons about proximity itself.
- Swap the in-process `TtlCache` for Redis before running more than one instance.
- Auth. There is none — every trip is readable by anyone who can reach the
  server. Fine locally, not for a deploy.

## Running it on a phone

The server binds `0.0.0.0:8080`, so anything on the same network can reach it.

**Simulator or emulator** — nothing to configure:

```bash
cd server && npm run dev
```

```bash
cd app && flutter run
```

`AppConfig` already sends the Android emulator to `10.0.2.2` and everything else
to `localhost`.

**A real phone** needs the Mac's address instead of localhost. Use the `.local`
name rather than the LAN IP — iOS App Transport Security permits plain HTTP to
`.local` names but not to a raw private IP, and the IP changes with the network:

```bash
scutil --get LocalHostName
```

```bash
cd app && flutter run --dart-define=TRIPPO_API_BASE=http://YOUR-MAC-NAME.local:8080
```

Both sides of that are already wired: `NSAllowsLocalNetworking` in
`ios/Runner/Info.plist` (the narrow exception — not `NSAllowsArbitraryLoads`),
and `usesCleartextTraffic` in the **debug-only** Android manifest, so release
builds keep the secure default. iOS will ask once for local-network permission.

Useful while iterating:

- `--dart-define=TRIPPO_TRIP_ID=trip_abc123` boots straight into one trip
- `--dart-define=TRIPPO_SCREEN=flights` opens the Flights screen directly
