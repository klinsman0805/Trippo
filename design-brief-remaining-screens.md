# Design brief: Wayfare — remaining screens

Paste everything below into your design tool alongside the existing
`design_handoff_wayfare_mobile/` bundle.

---

I need designs for the screens missing from the Wayfare mobile handoff. Treat
the existing bundle as the source of truth for everything visual — I am not
asking you to redesign what exists, only to extend it consistently.

## Read first

From `design_handoff_wayfare_mobile/`:
- `README.md` — tokens, platform variants, IA, interaction rules
- `WayfarePhone.dc.html` — the primary reference (structure + values)
- `screenshots/01-ios.png` … `06-ios-android-side-by-side.png`

Match the existing work exactly: the `#f4efe6` / `#fffdf9` / `#241f1a` palette,
terracotta `#b8543a` accent, Instrument Serif for display and platform sans for
UI, the same radii per platform (iOS 14/20, Android 16/24, pills 14 vs 999),
44px iOS / 48px Android minimum tap targets, and the same one-component-two-
dresses approach driven by a `platform` prop.

## Hard constraint: do not add a fifth tab

The handoff cut to four tabs (Trip, Budget, Group, Refine) deliberately, for
one-thumb reach. That decision stands. Everything below has to live inside the
existing four tabs, in a sheet, or on a pushed screen reached from one of them.
If a screen genuinely cannot fit that, say so and explain why rather than
quietly adding a tab.

---

## 1. Flights — the highest priority

Flights are what pin a trip's dates. Right now the design has fixed `start` and
`end` in state with no way for a user to set them, and that is the biggest gap.

**Search and results.** Origin and destination airport pickers (type-ahead over
IATA codes and city names), departure and optional return dates, traveller
count, cabin class, and a non-stop toggle. Results are a list of offers, each
showing: total and per-person price, outbound and return legs with departure and
arrival times, duration, stop count, and the carrier. Design the empty, loading
and no-results states.

**One requirement that is not negotiable.** Every offer carries an
`is_estimate` flag. It is true for sandbox and mock inventory, which is not
bookable and whose prices are directional only. When it is true the UI must say
so plainly and near the price — not in a footnote, not in a tooltip. Presenting
an estimate as a real fare is the exact false confidence this product is
supposed to avoid. Design that treatment.

**Selection and its consequence.** Choosing an outbound and a return derives the
trip's date envelope, and that has visible knock-on effects the user should
understand:

- A late arrival (say landing 20:01) means day 1 is a transfer-and-rest evening
  with no substantial activities.
- An early departure (say 10:00) means the final morning is gone.

Design how that reads back to the user — both at the moment of selection, and
afterwards on the Trip tab where those days now look emptier than the others.
This is a "the app is being honest with you about your own trip" moment, so it
deserves real design attention rather than a toast.

**Where it lives.** Propose the entry point. Reasonable candidates: the Trip
tab's header action, a row in the day-1 position before dates exist, or an item
in a `⋯` sheet. Show your reasoning.

## 2. Getting around — public transport

Two related jobs:

**Between two activities.** From an activity card, "how do I get from here to
the next thing" — transit steps with line names, vehicle types, departure and
arrival stops, number of stops, walking segments, and total duration. Also
walking, driving and cycling as alternative modes.

**Between cities.** A multi-city trip needs the inter-city leg shown as part of
the plan (train, bus, flight), with duration and rough cost.

Design the not-available case too: some places have no transit route, and that
is a legitimate answer rather than an error.

## 3. Imported sources

Links imported through the Refine composer currently produce places invisibly.
Users should be able to see what came from where.

Design a list of imported sources — each with its origin (小红书, TripAdvisor,
a blog), title, and the places extracted from it — plus a way to remove a source
and the places it contributed. Include the state where a source was blocked and
is waiting on pasted text.

Also: a place that came from a saved link but did **not** make it into the plan
should be discoverable. Right now those quietly disappear.

## 4. Trip setup and the trip list

The handoff assumes one trip that already has a title, destinations, budget and
dates. Two gaps:

**Creating a trip.** Title, destinations, budget and currency, and rough dates
or a flexible window. Consider whether this is a sheet like add-traveller, or a
short first-run flow.

**Choosing between trips.** A list screen. I have an interim version built from
existing tokens, but it was not designed — please do it properly, including the
empty state.

## 5. States the handoff does not cover

Small but load-bearing:

- **Planner failure.** Generation takes minutes and can fail (quota, network,
  the model returning something invalid). The full-screen generating overlay has
  no failure counterpart.
- **Feature unavailable.** The server reports which integrations are configured.
  When flights or transit are switched off, those surfaces need a designed
  "unavailable" state rather than a broken-looking screen.
- **Editing a traveller.** The sheet only adds. People change their minds.
- **`needs_info` plans.** When the planner lacks something critical it returns
  questions instead of an itinerary. The Trip tab needs to render that.

---

## Deliverables

For each screen: the iOS and Android dress, every state (empty, loading, error,
populated), and a note on where it sits in the existing navigation. Same
fidelity as the current bundle — final-intent colours, type sizes, spacing and
copy.

Copy matters as much as layout here. The existing writing is plain, calm and
specific ("Two travellers minimum", "No dietary or access needs", "Nothing
starts before 10:00"). Match that voice: say the true thing plainly, never
brightly.
