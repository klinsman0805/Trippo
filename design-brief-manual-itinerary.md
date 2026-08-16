# Design brief: Wayfare — building an itinerary by hand

Paste everything below into your design tool alongside the existing
`design_handoff_wayfare_mobile/` and `design_handoff_wayfare_mobile 2/` bundles.

---

I need designs for editing an itinerary by hand. The existing bundles cover
*reading* a generated plan thoroughly — activity cards, day chips, optional
badges, short-day bands — but there is no way to write one. Right now a user
who sets their dates and doesn't want to use the planner reaches a dead end.

Treat both existing bundles as the source of truth for everything visual. I am
not asking you to redesign what exists, only to extend it consistently.

## Read first

- `design_handoff_wayfare_mobile/README.md` — tokens, platform variants, IA
- `design_handoff_wayfare_mobile 2/README-flights-and-states.md` — the newer
  tokens (amber family, destructive ink) and the load-bearing states
- `WayfarePhone.dc.html` and `WayfareFlights.dc.html` — primary references

Match the existing work exactly: the `#f4efe6` / `#fffdf9` / `#241f1a` palette,
terracotta `#b8543a` accent, Instrument Serif for display and platform sans for
UI, the same radii per platform (iOS 14/20, Android 16/24), 44px iOS / 48px
Android minimum tap targets, and the one-component-two-dresses approach driven
by a `platform` prop.

## Hard constraints

1. **Still four tabs.** Trip, Budget, Group, Refine. This must live inside them,
   in a sheet, or on a pushed screen. If something genuinely cannot fit, say so
   and explain why rather than adding a tab.
2. **The activity card is not up for redesign.** A hand-written activity and a
   generated one must render *identically* in the day view. Whatever the editor
   produces has to fill the card that already exists.
3. **Individual use for now.** Assume one person planning. The group features
   exist but are optional and being deferred, so nothing here should depend on
   there being travellers.

---

## The question I most need answered

**What happens to a hand-written day when the planner regenerates?**

This is the crux, and it is a product decision before it is a visual one.
Today a plan is a whole revision produced in one shot; refining produces a new
revision that replaces the last. If a user hand-writes day 3 and then asks the
planner for a change, the obvious implementations either silently destroy their
work or quietly refuse to touch that day.

Please pick a position and design for it. Some directions, not exhaustive:

- **Hand-written blocks are pinned.** They survive regeneration and the planner
  is told to work around them. Needs a visual mark for "you wrote this" and
  somewhere to unpin.
- **Regenerating warns first.** A confirmation naming exactly what would be
  overwritten — "Day 3 has 4 activities you added. Replace them?"
- **Two modes.** A plan is either planner-owned or yours, and taking it over is
  an explicit, one-way act with its own screen.

Whatever you choose, the user must never lose typed work without being told
first. That is the same principle as the `failed` state in bundle 2, which is
emphatic that nothing entered is lost.

---

## 1. Empty itinerary, no plan yet

The Trip tab once dates exist but nothing is planned. Currently a placeholder
tile, a title, and a Generate button.

It needs a second, equal path: **build it myself**. Not a link buried under the
primary action — a genuine alternative for someone who has their own plan and
wants somewhere to put it.

Note the trip already has dates and a day count by this point, so the empty
state can legitimately show the day chips with empty days behind them.

## 2. Adding an activity

The fields the app stores per activity, all of which the planner fills and a
person should be able to:

| Field | Notes |
|---|---|
| Time of day | morning / afternoon / evening. Not a clock time — the whole plan is slot-based, which is what makes short days work. Do not introduce exact times. |
| Activity title | Sentence case, short. The card truncates around 260px. |
| Description | A sentence or two. |
| Location | Free text place name. |
| Duration | Minutes. Shown on the card as `1h 30m`. |
| Cost per person | Optional. Blank renders as `free`, not `0`. |
| Optional | The dashed-border treatment that already exists. |
| Weather backup | Optional, a sentence. Rarely used — consider progressive disclosure. |

Questions I have no answer to yet:

- Sheet or pushed screen? The add-traveller sheet is the closest precedent and
  it is quite long already; this has more fields.
- How much should be behind a "more" disclosure? Title, slot and location are
  the ones people will always fill. Duration, cost, weather backup are not.
- Is there a fast path — type a title, tap done, fill the rest later? A
  half-filled activity is more useful than an abandoned form.

## 3. Editing and removing an activity

Follow the `edit_traveller` pattern from bundle 2: the same form, prefilled,
with an identity header and a **named** destructive action in outline, never a
red fill. Removal should say what goes.

Also needed: how does a user get *into* edit? The activity card currently has
no affordance. Tapping the whole card is the obvious answer, but the card is
also just something you read — consider whether that makes reading feel risky.

## 4. Empty and partly-filled days

A day with nothing in it, in a plan where other days are full. Distinct from
the short-day empty row in bundle 2 §5 — that one means "the flight leaves no
time", this one means "you have not filled this in yet". They must not look
the same. One is a deliberate absence; the other is a to-do.

Also: a day with a morning and an evening but no afternoon. Does the gap show
as an empty slot inviting a tap, or does it close up?

## 5. Reordering and moving

- Reordering activities within a day.
- Moving an activity to a different day.

Both are common when planning by hand and neither exists. Drag is the obvious
answer for the first and a poor one for the second. Note the plan is grouped by
slot, so "reorder" within a slot may not even be meaningful — worth deciding
whether ordering within a slot is a thing at all.

## 6. Adding and removing days

The day count comes from the flight dates, so adding a day means changing the
trip's dates. Does that flow back into the flights screen, or can a day exist
outside the flight envelope? I lean towards the former — the envelope is
load-bearing and I do not want two sources of truth for how long a trip is —
but if that makes the flow painful, say so.

---

## Voice

Same register as the existing copy: plain, first person where the planner is
speaking, no promotional adjectives, no exclamation marks. Sentence case for
activity titles. Where an action costs the user something, name the cost —
that principle drives the whole flights consequence sheet and should hold here.

## Deliverable

Same format as the previous bundles: a `.dc.html` reference with `platform`
(`ios` | `android`) and `view` props covering each state above, plus a README
documenting anything new. If you add tokens, list them explicitly — I transcribe
them literally rather than rounding to Material defaults.
