# Paths: AI Travel Planner — Product, Feature Set and UI/UX Profile

> All data gathered 17 October 2026 from live primary sources (Apple App Store US storefront, iTunes Lookup API, Google Play US storefront, gopaths.ai). Figures are point-in-time and will drift — the app shipped three releases in the seven days before this research.

## Disambiguation: which "Paths"?

### Takeaway
The target app is **"Paths: Trip & Itinerary Agent"** (Google Play title: **"Paths"**, with Play short-description "Paths: AI Travel Planner"), Apple ID `6786985803`, bundle/package `ai.gopaths.pitravel`, published by **BLANK CRAFT PTE. LTD.** (Singapore), website **gopaths.ai**. At least three other unrelated iOS apps use the name "Paths", and several near-name AI trip planners (Pathly, Pathsight, Pathwise, Pathsie) pollute search results — the domains `paths.app` and `getpaths.com` belong to other products, not this one.

### Cited Findings
- Target app, Apple listing: "Paths: Trip & Itinerary Agent", seller BLANK CRAFT PTE. LTD., category Travel, seller URL `https://www.gopaths.ai`, bundle id `ai.gopaths.pitravel` — [Apple App Store](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803) (via iTunes Lookup API, 17 Oct 2026)
- Google Play title is just "Paths", developer name shown as "gopaths", with the short description "Paths: AI Travel Planner" — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- Unrelated same-name iOS apps: "Paths: Friends Memories Life" (Seize LLC, Lifestyle, id 1480890359); "Paths: Movement Memory" (Paths Labs Limited, Lifestyle, id 6778448141); "Paths™ - Choices You Make" (Paths Game Ltd, Games, id 1467842360) — [iTunes Search API results, 17 Oct 2026](https://itunes.apple.com/search?term=paths&entity=software&country=us)
- `getpaths.com` resolves to an unrelated product whose landing copy reads "Never miss a memory, Never struggle to find it"; `paths.app` returns an empty/JS-only page — direct HTTP fetch, 17 Oct 2026
- Near-name AI trip planners that are NOT this app: Pathly (id 6753792428), Pathsight: AI Trip Planner (id 6740884888), Pathwise (id 6757256653), Pathsie (id 6755628205) — [Apple App Store search results](https://apps.apple.com/us/app/id6740884888)

### Inferences
- The "getpaths" spelling in the research brief appears to be a mis-recollection of the real handle **gopaths** (`gopaths.ai`, `ai.gopaths.*`).

### Gaps
- No trademark/brand filing found tying BLANK CRAFT to the "Paths" wordmark.

---

## Publisher, launch date, platforms, version and update cadence

### Takeaway
Paths is a very new app: first public build (0.1) landed **14 July 2026**, 1.0 on **18 July 2026**, and it is on **version 1.7.3 as of 16 October 2026** — 18 shipped versions in roughly 13 weeks. It is live on iOS (iPhone/iPad, plus Apple-silicon Mac and visionOS compatibility) and Android; **there is no evidence of a web app** — gopaths.ai is only a download landing page.

### Cited Findings
- Publisher: BLANK CRAFT PTE. LTD., registered at 9 Raffles Place, #26-01 Republic Plaza, Singapore 048619; support email `team@gopaths.ai`; contact phone listed as `+86 186 5190 0596` — [Google Play developer block](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- Apple `releaseDate` 2026-07-20, `currentVersionReleaseDate` 2026-10-16T13:05:55Z, `version` 1.7.3 — [iTunes Lookup API, id 6786985803](https://itunes.apple.com/lookup?id=6786985803&country=us)
- Full visible iOS version history with dates: 0.1 (Jul 14), 1.0 (Jul 18), 1.0.1 (Jul 21), 1.0.2 (Jul 24), 1.1 (Jul 28), 1.2.x (Aug 1), 1.3 (Aug 20), 1.3.1 (Aug 23), 1.4 (Aug 28), 1.4.1 (Sep 2), 1.5 (Sep 6), 1.5.1 (Sep 14), 1.6 (Sep 21), 1.7 (Sep 24), 1.7.1 (Oct 10), 1.7.2 (~Oct 15), 1.7.3 (~Oct 16) — [App Store version history](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Copyright line: "© Copyright 2026 BLANK CRAFT PTE. LTD." — same App Store page
- iOS requirements: iOS 16.0+; iPadOS 16.0+; macOS 13.0+ on Apple M1 or later; visionOS 1.0+. App size 163 MB. Age rating 9+ ("Infrequent/Mild Profanity or Crude Humor"). Languages: English, Simplified Chinese, Traditional Chinese — [App Store information panel](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Android: package `ai.gopaths.pitravel`, **10K+ downloads**, content rating "Everyone", category "Travel & Local", last updated **Oct 10, 2026** (i.e. the Android build trails iOS by ~1 week / 2 point releases) — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- gopaths.ai renders only a hero page with buttons "Start Planning", "Download Paths on App Store", "Download Paths on Google Play", "Privacy Policy", plus Chinese variants "請至應用商店下載Paths App" / "现在下载 Paths APP" and a "Click to open App" deep-link handler — strings extracted from the site's own JS bundle `index.8ac3ec87.js`, 17 Oct 2026
- The app is **not listed on the China mainland App Store** (iTunes Lookup with `country=cn` returns zero results), despite shipping zh-Hans/zh-Hant localisation
- Ratings on the US App Store: **4.7 average from only 6 ratings** (17 Oct 2026) — [App Store](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Sibling app from the same publisher: **"doro: auto-pin places & events"** (id 6755711343, v1.1, released 4 Dec 2025), tagline "Turn travel posts into plans" — it shares links from TikTok/Instagram/YouTube to a map via AI extraction, and runs a community at `reddit.com/r/Dorotravel` and a Discord — [iTunes Search API / App Store](https://apps.apple.com/us/app/doro-auto-pin-places-events/id6755711343)

### Inferences
- The Singapore holding company plus a mainland-China phone number, zh-Hans/zh-Hant localisation, and a Tencent Cloud Shanghai COS bucket (`sns-poki-1251524319.cos.ap-shanghai.myqcloud.com`) serving the website image strongly suggest a China-based team shipping internationally through a Singapore entity. (Inference, not stated anywhere.)
- doro looks like the team's earlier, narrower product (social-link → map pins); Paths is the broader itinerary product built on the same extraction capability.
- Cadence is effectively weekly-to-fortnightly point releases with Android lagging iOS — consistent with a small, fast-iterating startup, not a mature product.

### Gaps
- No founder names, funding, headcount, or launch press. No Product Hunt launch, no TechCrunch/tech-press coverage, and no Sensor Tower / Appfigures / data.ai figures surfaced for this app — the only install metric available anywhere is Google Play's "10K+ Downloads" bucket. iOS install/revenue estimates: **not found**.
- No web app confirmed; absence of evidence, and gopaths.ai has a "Start Planning" button whose destination I could not resolve (client-side routed Vue app).

---

## Complete feature list

### Takeaway
Paths is an **AI itinerary agent with a chat-first front door**: its three headline capabilities are (1) ingesting external travel content (links, screenshots, raw text) and extracting places — branded **"Smart Parse"**; (2) AI route optimisation across a day with a map view, live weather and transit info; (3) real-time multi-player collaboration on a trip. Around that sit per-trip checklists, notes, a photo collection, a weather strip, and a new **"Fact Check"** tool. There is **no evidence of in-app flight/hotel booking, no offline mode, and no budget ledger** as shipped features.

### Cited Findings (from the App Store / Play description, verbatim claims)
- "Found a travel post you love? Drop the **link, screenshot, or text** straight into Paths. Our AI extracts the places and builds a complete itinerary in just a few taps." — [App Store description](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- "Pick your must-visit spots, **set your start and end points**, and Paths creates the smartest route for your trip. **Interactive maps, live weather, and transit info**, all in one clean view."
- "Create a trip and **invite friends to collaborate in real time**. Add stops, leave notes, and adjust routes together."
- Release notes for 1.7.1–1.7.3 announce a **"Fact Check" tool**: "He rage-coded the 'Fact Check' tool overnight out of pure spite. Come vibe-check your itinerary and help him win the argument!" — [App Store What's New, 16 Oct 2026](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Same release notes: "Gave the welcome page a glow-up so you don't ghost us immediately" — i.e. the onboarding/welcome screen was redesigned in Oct 2026.

### Cited Findings (from App Store screenshot UI, 17 Oct 2026 — six iPhone screenshots)
- Screenshot 3 shows a social post card ("The ULTIMATE Singapore travel guide") with a blue pill button labelled **"Smart Parse"**, feeding a "Day 1" list — caption **"From Feed to Plan in Seconds"**.
- Screenshot 4 (caption **"Your Entire Trip, Organised"**) shows four discrete per-trip modules: a **Checklist** card (items "Book Flights" ✓, "Book Hotels", "Visa"), a yellow **Notes** sticky ("Make reservations 3 days in advance"), a **"Photos · 16"** horizontal film-strip card, and a **"Weather · Singapore"** card with per-day rows ("Thu, Oct 4 — Cloudy 25°–31°", "Fri, Oct 5 — Sunny 25°–…", with "Thu, Oct 4 · Today" highlighted).
- Screenshot 5 (caption **"Clean Itineraries, Smart Details"**) shows each stop carrying a **category tag** ("Attractions", "Shopping") and an optional **time-window chip** rendered as ⏰ "10:00–12:00", plus an AI tip bubble: "Remember to buy tickets in advance".
- Screenshot 2 (caption **"Your AI Travel Assistant"**) shows suggested-prompt chips: **"Help me plan a 3-day trip to Singapore"**, **"📍 Extract places from this post"**, **"🗂 Optimize the route for Day 2"**.
- Screenshot 6 (caption **"Plan Together, Stay in Sync"**) shows an invite sheet: avatar, "Paths", "Invite friends to collaborate on the itinerary", "**5 people**", named collaborators (Tom, Rika, David) on coloured chips, a trip card reading "3-day trip to Singapore / 10.3 – 10.5 · 3 Days 2 Nights / **13 Stops**", and a black pill CTA "🔗 **Invite friends**".
- App Store user review (Okiedokie_9, 31 Aug 2026, 5★ section): "It helped with things like **budget, weather, visa requirements**, and other details I wouldn't have thought of. It felt more like having a personal travel assistant than just an itinerary generator. I also love the map view." — [App Store Ratings & Reviews](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- App Store user review (wanderingem_41, 31 Aug 2026, 5★): "I just put in **where I'm going and how long I'll be there**, and the AI basically plans the trip for me. It even **organizes the stops so I'm not going back and forth across the city** all day. Super easy to tweak the itinerary and share it with friends too."
- Apple privacy disclosure lists collection of **Precise Location, Photos or Videos, Audio Data, Search History, Email Address, User Content** — the Photos/Audio entries sit under "Data Not Linked to You / App Functionality" — [App Store App Privacy panel](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)

### Inferences
- The declared **Audio Data** collection implies a voice-input path into the AI agent (dictation or voice chat), though no screenshot or marketing copy confirms a voice feature. Flagged as unconfirmed.
- **Photos or Videos** collection + the "Photos · 16" card implies a journaling/trip-album feature where users attach their own photos to a trip; it is presented as storage/organisation, not as a social feed.
- "Budget" and "visa requirements" appear only in one user review, not in any first-party copy — most plausibly these are things the **chat agent answers conversationally**, not dedicated budget/visa screens. Treat as unverified.
- "Fact Check" most likely validates AI-generated itinerary claims (opening hours, closures, feasibility of the day's route) — the release note does not actually say what it checks.

### Gaps
- **Not found / no evidence for:** in-app flight or hotel booking, affiliate booking links, OTA integrations, flight tracking, email-confirmation parsing (TripIt-style inbox forwarding), offline map or offline itinerary access, currency conversion, packing-list templates, a structured budget tracker, export to PDF/calendar, or an Apple Watch/widget surface. None of these appear in either store description, in release notes, or in the six screenshots.
- No explicit confirmation that TikTok / Instagram / 小红书 (RED) specifically are supported — the Paths copy says only "link, screenshot, or text". (The sibling app doro names TikTok, Instagram and YouTube explicitly.)
- No public changelog beyond App Store "What's New" strings, most of which are the same marketing boilerplate repeated per version.

---

## Onboarding flow

### Takeaway
I could **not verify the step-by-step onboarding flow** — no walkthrough video, hands-on review or documentation exists for this app. What the first screenshot does show is that the post-install home state is a **conversational empty state**, not a structured questionnaire wizard: the agent asks an open question and the user types a destination.

### Cited Findings
- Screenshot 1 (caption "Made for Chill Travellers") shows the home/empty state: a circular user avatar top-left, a **"+" button top-right**, the Paths logo mark centred, the heading **"So, where are we heading?"** with subhead **"Paths is ready to plan your next trip 😉"**, two sample trip cards floating ("Tokyo 2-Day Trip — 12 places", "Classic 7-Day NYC Tour — 24 places"), a blue user bubble "Let me handle the planning!", and a bottom composer bar with a **paperclip/attachment icon** and placeholder **"Tell me your next destination"**, next to a large circular blue send/agent FAB. — [App Store screenshot 1](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- The welcome page was explicitly reworked in v1.7.1–1.7.3 (Oct 2026): "Gave the welcome page a glow-up so you don't ghost us immediately." — App Store What's New
- A user describes the required inputs as minimal: "I just put in where I'm going and how long I'll be there" — App Store review, wanderingem_41, 31 Aug 2026
- Apple privacy panel declares **Email Address** collected under "App Functionality", implying an account step — [App Store App Privacy panel](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Collaboration screenshot shows the trip owner's own avatar/profile, implying authenticated accounts rather than anonymous local trips.

### Inferences
- Minimum viable input is plausibly just **destination + duration** (or a pasted link), with everything else — interests, pace, budget, travel style — elicited conversationally in chat rather than via preference sliders. This matches the chat-first empty state and the single user account of the flow, but **no screenshot of an interest/pace/budget picker exists**, so a hidden wizard cannot be ruled out.
- A sign-in step (likely Apple/Google SSO given the email-address declaration and real-time collaboration) almost certainly precedes the chat screen. Unconfirmed.

### Gaps
- **The exact onboarding sequence, number of steps, permission prompts (location/notifications/photos), paywall placement, and whether a preference questionnaire exists are all unverified.** No YouTube/TikTok walkthrough, no hands-on review, and no third-party teardown of this app was found. Obtaining this reliably requires installing the app.

---

## Core screen structure and navigation

### Takeaway
Based on screenshots, Paths appears to be structured as a **chat/agent surface as home**, with trips opening into a **map-on-top / day-list-below** detail screen, and per-trip side modules (checklist, notes, photos, weather). **The tab-bar structure is not visible in any marketing screenshot** — all six are stylised composites, not raw captures.

### Cited Findings
- Trip detail layout (screenshot 5): map occupies the upper ~half with numbered circular pins (1, 2, 3) joined by a thick blue polyline; a title pill overlays it ("3-Day Singapore Trip"); below, a white sheet lists stops as rows of **square thumbnail + bold place name + grey category label**, with a time-window chip on the right of the active row.
- Route visualisation (screenshot 2): the same numbered-pin + blue-line treatment, with each pin's place name shown on a floating card with a photo thumbnail ("Changi Airport", "Marina Bay Sands", "Chinatown", "Singapore Flyer").
- Day grouping (screenshot 3): an explicit **"Day 1"** header above a vertical list of stops, each showing a thumbnail, place name, and **street address** underneath ("Changi Airport / 80 Changi Airport Boulevard"; "Marina Bay Sands / 10 Bayfront Avenue"; "ArtScience Museum / 6 Bayfront Avenue"; "Chinatown / Smith Street"; "Singapore Flyer / 30 Raffles Avenue").
- Trip card format (screenshot 6): title, date range in `10.3 – 10.5` shorthand, "3 Days 2 Nights", "13 Stops", and a cover photo.
- Home list cards (screenshot 1) summarise a trip as **title + "N places"**.
- Visual design: near-white/very light blue background, heavy rounded corners, soft drop shadows, a single accent colour (bright cyan-blue ~#3FC3F5), black pill CTAs, Inter/SF-like geometric sans, emoji accents in copy. The logo is a three-element dot-slash-dot mark.

### Inferences
- The two list treatments differ: the **address-under-name** rendering (screenshot 3) looks like the *import/parse review* state, while **category + time chip** (screenshot 5) looks like the *finalised itinerary* state. Inference from visual difference only.
- Dates render in `M.D` shorthand, and stops are counted at trip level ("13 Stops") rather than per day — suggesting the data model is a flat ordered list of places assigned to days.

### Gaps
- **Main navigation tabs are unconfirmed.** No bottom tab bar is visible in any screenshot; screenshot 1 shows only an avatar and a "+" in the top bar, which would be consistent with a tab-less, chat-rooted app, but this cannot be asserted.
- Whether the map is Apple Maps, Google Maps or Mapbox is unknown (the marketing screenshots use an abstract illustrated map, not a real tile render).

---

## Editing: manual vs conversational

### Takeaway
Evidence points to **both**: conversational editing through the agent (suggested prompt "Optimize the route for Day 2") and direct manipulation of the itinerary list. Specific gestures (drag-to-reorder, swipe-to-delete, long-press) are **not confirmed by any source**.

### Cited Findings
- Suggested agent prompt chip reads **"🗂 Optimize the route for Day 2"** — [App Store screenshot 2](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- App Store description: "Pick your must-visit spots, set your start and end points, and Paths creates the smartest route" — i.e. route optimisation is parameterised by user-chosen anchors, not fully automatic.
- App Store description (collaboration): "**Add stops, leave notes, and adjust routes** together" — explicit edit verbs.
- User review: "Super easy to **tweak the itinerary** and share it with friends too" (wanderingem_41, 31 Aug 2026) and "It even **organizes the stops so I'm not going back and forth across the city** all day" (same review).
- The home composer has a paperclip attachment affordance and free-text field, i.e. edits can originate from pasted content as well as typed instructions.

### Inferences
- "Set your start and end points" implies a per-day route configuration control (likely a sheet where you pin the first/last stop) distinct from chat. Unverified UI.
- Given the chat-first architecture and collaborative real-time sync, manual edits most likely write to the same trip document the agent edits, so both modes converge — but this is architectural inference, not observed.

### Gaps
- **Drag-to-reorder, swipe-to-delete, add-stop entry points, undo, and whether the agent edits in place or regenerates the day are all unverified.** Requires hands-on use.

---

## External content ingestion

### Takeaway
Ingestion is the app's lead marketing claim and is branded **"Smart Parse"**: paste a **link**, a **screenshot**, or **raw text**, and the AI extracts places and assembles days. Named platform support (TikTok / Instagram / 小红书) is **claimed explicitly only for the publisher's sibling app doro**, not for Paths.

### Cited Findings
- Paths description: "Drop the **link, screenshot, or text** straight into Paths. Our AI extracts the places and builds a complete itinerary in just a few taps. No more copying and pasting between apps." — [App Store](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Branded UI element **"Smart Parse"** appears as a blue pill on the screenshot showing a social-post card converting into a Day 1 list — App Store screenshot 3, caption "From Feed to Plan in Seconds"
- Agent prompt chip: "📍 Extract places from this post" — App Store screenshot 2
- Sibling app doro (same publisher, BLANK CRAFT PTE. LTD.) names platforms outright: "Tired of manually pinning locations or copying tips from **TikTok, Instagram, and Youtube**? Just share the link to doro. Our AI tool instantly extracts the places, event details and crucial tips (like 'avoid the long lines' or 'best time to visit')" — [doro App Store listing](https://apps.apple.com/us/app/doro-auto-pin-places-events/id6755711343)
- Apple privacy disclosure confirms **Photos or Videos** and **Other User Content** are collected for App Functionality, consistent with screenshot upload — [App Store App Privacy panel](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)

### Inferences
- The screenshot path implies OCR/vision extraction, not just URL scraping — i.e. the same pipeline handles a RED/小红书 or WeChat screenshot even where the link itself is not fetchable. Strongly implied by "screenshot" + zh-Hans/zh-Hant localisation, but not stated.
- The paperclip icon in the home composer is almost certainly the attach-screenshot/link entry point; an iOS Share Sheet extension is likely (it is how doro works) but is **not confirmed** for Paths.

### Gaps
- **Email ingestion / booking-confirmation forwarding: no evidence at all.** Nothing in either store listing or privacy disclosure suggests mailbox parsing.
- Which specific platforms' links are reliably parsed by Paths, and whether a Share Sheet extension exists, are unverified.

---

## Monetization

### Takeaway
As of 17 October 2026, Paths appears to be **entirely free with no in-app purchases and no ads on either store**. Neither the Apple listing nor the Play listing carries the standard IAP/ads badges, and no subscription terms appear anywhere in the app descriptions. This is almost certainly a pre-monetization growth phase rather than a permanent model.

### Cited Findings
- Apple: `price: 0.0`, `formattedPrice: "Free"`; the App Store product page shows "Free · Designed for iPad" and contains **no "In-App Purchases" section** — [iTunes Lookup API + App Store page, 17 Oct 2026](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Google Play: the listing shows "Install" with **neither an "In-app purchases" nor a "Contains ads" label** (both strings absent from the fetched page) — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- For contrast, the publisher's competitors in the same search neighbourhood do disclose subscriptions (e.g. Pathsight lists a 3-day free trial from $3.99/month) — [Pathsight App Store listing](https://apps.apple.com/us/app/id6740884888)
- Apple privacy disclosure confirms **"Data Used to Track You: Identifiers"**, i.e. an attribution/ad-tracking SDK is present — [App Store App Privacy panel](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)

### Inferences
- Free-with-no-IAP + tracking identifiers + ~weekly releases + 10K+ downloads reads as a **land-grab / user-acquisition stage**, with monetization (likely a subscription on generation volume or collaboration seats, possibly booking affiliate revenue later) deferred. This is inference, not a stated roadmap.
- There is **no evidence of affiliate or booking commission** today: the app does not surface bookable inventory in any screenshot or description.

### Gaps
- **Free-tier generation limits (if any) are unknown** — nothing in public materials mentions a cap on itineraries, trips, collaborators or AI messages. There may be a server-side quota invisible to store listings.
- No revenue estimates exist for this app on any analytics source I could reach.

---

## Marketing claims and positioning

### Takeaway
Paths positions itself as a **low-effort "chill traveller" AI agent** that converts social-media inspiration into a routed, shareable itinerary — the pitch is anti-spreadsheet and anti-screenshot, not comprehensive trip management. The tone of voice is deliberately casual and meme-y, including in release notes.

### Cited Findings (verbatim)
- Opening lines of the store description: "Every trip begins with excitement and a little uncertainty. Paths helps you **plan smarter and travel lighter, turning scattered inspiration into seamless itineraries while leaving room for the unexpected**." — [App Store](https://apps.apple.com/us/app/paths-trip-itinerary-agent/id6786985803)
- Section headers used as taglines: "**Turn Any Inspiration into a Trip**", "**Smarter Routes, Everything in One Place**", "**Plan Together, Stay in Sync**" — same source
- Screenshot captions (the app's visual taglines): "**Made for Chill Travellers**", "**Your AI Travel Assistant**", "**From Feed to Plan in Seconds**", "**Your Entire Trip, Organised**", "**Clean Itineraries, Smart Details**", "**Plan Together, Stay in Sync**"
- Google Play short description: "**Paths: AI Travel Planner**" — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- Apple subtitle / track name: "**Paths: Trip & Itinerary Agent**" — note the deliberate word "**Agent**"
- Pain points named in copy: "No more copying and pasting between apps", "No more endless screenshots or buried messages", "Everyone stays on the same page"
- Website gopaths.ai carries almost no marketing copy — its only CTAs are "Start Planning", "Download Paths on App Store", "Download Paths on Google Play" — extracted from the site's JS bundle, 17 Oct 2026
- Brand voice in release notes is informal to the point of slang: "Gave the welcome page a glow-up so you don't ghost us immediately", "Our B-type dev got absolutely cooked by the A-types… He rage-coded the 'Fact Check' tool overnight out of pure spite." (The "A-type / B-type" framing is a Chinese/Korean internet meme about planner-types vs go-with-the-flow types.)

### Inferences
- The "A-type vs B-type traveller" joke plus "Made for Chill Travellers" shows the explicit target persona: the traveller who **wants a plan without doing planning work** — positioning against both rigid spreadsheet planners and generic chatbot output.
- Apple's "Agent" in the title and the chat-first home suggest the team is leaning into the agent framing rather than the "itinerary generator" framing that most competitors in this category use.

### Gaps
- No press release, launch blog, founder interview, Product Hunt launch, or any tech-press coverage of Paths was found. The entire public footprint is the two store listings plus a one-screen website.

---

## Confidence summary for the report writer

| Area | Confidence | Basis |
|---|---|---|
| Publisher, IDs, platforms, versions, dates | **High** | Apple + Google primary listings, fetched 17 Oct 2026 |
| Store-stated feature claims (Smart Parse, routing, collaboration, weather, transit) | **High** | Verbatim first-party copy |
| Screen content (day lists, map+list layout, checklist/notes/photos/weather cards, invite sheet, chat empty state) | **Medium-High** | Apple marketing screenshots — stylised composites, so real layouts may differ |
| Monetization = free, no IAP | **Medium-High** | Absence of IAP/ads badges on both stores; absence of evidence is not proof of absence of a server-side paywall |
| Onboarding step sequence | **Low / unverified** | No walkthrough or hands-on source exists |
| Navigation tabs, edit gestures | **Low / unverified** | No raw UI capture available |
| Install/revenue scale | **Low** | Only signal is Play's "10K+" bucket; 6 iOS ratings |
| Voice input, booking, offline, budget tracker, email ingestion | **No evidence** | Should be reported as unknown/absent, not inferred |
