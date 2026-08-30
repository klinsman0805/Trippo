# Traveller Planning Behaviour & Itinerary UI/UX Interaction Patterns

*Research completed 17 October 2026. Statistics are dated inline. Vendor-marketing and vendor-blog statistics are explicitly flagged — several of the most quotable numbers in this space come from companies selling trip-planning products and should not be treated as peer-reviewed.*

---

## Q1. What does published research say about how leisure travellers plan? (duration, number of sources, where ideas are saved, when dates are committed)

### Takeaway
There is solid vendor-survey evidence on *time spent* and *booking-window compression* — travellers spend roughly five hours with travel content in the 45 days before booking, and the short-window (7–13 day) search segment is growing fast — but I found **no reliable published statistic on how many distinct sources a traveller consults, or on the share who save ideas into screenshots / notes apps / group chats / spreadsheets**. That specific gap is the biggest hole in the public literature and is flagged below.

### Cited Findings
- Expedia Group's "Path to Purchase" research found travellers spend **303 minutes (over 5 hours) on average with travel content in the 45 days prior to booking** — *vendor research, Expedia Group; figure surfaced via search summary of [Expedia Newsroom](https://www.expedia.com/newsroom/eg-path-to-purchase-research) (the page returned HTTP 429 on direct fetch, so this is a secondhand read of Expedia's own claim)*.
- Expedia Group, February 2026: surveyed **more than 2,500 travellers across 10 markets** (US, UK, France, Japan, Mexico, Australia, Germany, China, Brazil, India). **77%** said they were at least somewhat likely to book more than one part of their next trip on the same platform (35% "very likely"); **90%** plan to book activities or experiences in the next year, **88%** flights, **75%** a rental car — *vendor research* — [Expedia Group IR, June 2026](https://ir.expediagroup.com/news-and-events/news/news-details/2026/EXPEDIA-GROUP-UNVEILS-NEW-GLOBAL-RESEARCH-SHOWING-TRAVELER-DEMAND-FOR-FULL-TRIP-PLANNING/default.aspx); [Businesswire release](https://www.businesswire.com/news/home/20260602270896/en/EXPEDIA-GROUP-UNVEILS-NEW-GLOBAL-RESEARCH-SHOWING-TRAVELER-DEMAND-FOR-FULL-TRIP-PLANNING)
- Booking windows are compressing: searches in the **7–13 day before departure window grew 25% year over year globally** in 2026 — *vendor data, Expedia Group* — [TravelPress summary](https://www.travelpress.com/expedia-group-data-reveals-travellers-booking-closer-to-departure-in-2026/); [Expedia Group partner blog, Q2 2026](https://partner.expediagroup.com/en-us/resources/blog/q2-2026-travel-trends-insights)
- Tripadvisor's traveller behaviour study surveyed **more than 6,700 travellers across Australia, Germany, Japan, the UK and the US** who intended to travel in the next 12 months, segmenting decision-making by life stage — *vendor research* — [Tripadvisor Insights](https://www.tripadvisor.com/business/insights/traveler-behavior-survey-life-stages)
- Academic work on information-seeking: roughly **70% of online tourism consumers begin trip planning with a search engine** before deciding where and how to travel — [Explorative Study of Tourist Behavior in Seeking Information to Travel Planning, IJSDP](https://www.iieta.org/journals/ijsdp/paper/10.18280/ijsdp.160819)
- Cross-national academic work exists specifically on *combining* information sources in travel planning (i.e. travellers are known to layer multiple source types rather than use one) — [Combination of Information Sources in Travel Planning: A Cross-national Study (ResearchGate)](https://www.researchgate.net/publication/221357526_Combination_of_Information_Sources_in_Travel_Planning_A_Cross-national_Study)
- Qualitative (forum, not survey) evidence of where ideas actually get saved: travellers describe **screenshots filed into photo albums, screenshots pasted into the Notes app, URLs collected in Google Docs, itineraries and hyperlinks in Apple Numbers / Excel spreadsheets shared via cloud, WhatsApp group chats, and link-folder tools** — [Rick Steves Travel Forum: "How do you organize your Trip Research?"](https://community.ricksteves.com/travel-forum/general-europe/how-do-you-organize-your-trip-research); [Rick Steves Forum: spreadsheet/app recommendations](https://community.ricksteves.com/travel-forum/general-europe/recommendations-travel-planning-apps-spreadsheet-templates-for-apple-i-phone-products); [Slow Europe: "How do you keep track of your travel ideas?"](https://www.sloweurope.com/community/threads/how-do-you-keep-track-of-your-travel-ideas.7156/)

### Inferences
- The 303-minute / 45-day figure plus the growth in 7–13-day searches implies a **two-phase shape**: a long, low-intensity, dateless "ambient collecting" phase, followed by a short, high-intensity "commit" phase close to departure. A product that only serves the second phase (booking-adjacent itinerary building) misses where most of the elapsed time actually goes.
- Because dates arrive *late* and inspiration is collected *early*, an itinerary data model should allow places to exist **without a date** for a long time, and should make "assign to a day" a later, cheap action rather than a precondition for saving. (See Q4, unscheduled/"maybe" bucket.)
- The forum evidence suggests the real competitor is not Wanderlog — it is **Notes app + camera roll + one WhatsApp thread + one spreadsheet**. Any migration story has to beat that four-tool stack, which is free, zero-learning-curve, and already contains the user's data.

### Gaps
- **No credible published number for "how many sources does a traveller consult"** or "how many apps/tabs are involved". Multiple SEO/AI-generated blog pages assert numbers like "38 sites" or "141 touchpoints" (these trace back to older Expedia/Google clickstream studies), but I could not reach a primary source that states them, so I am not reporting them. Treat any such figure as unverified unless the original Expedia/Google PDF is located.
- **No survey quantifying where ideas are saved** (% using screenshots vs notes app vs saved reels vs group chat vs spreadsheet). Only qualitative forum evidence found.
- **No reliable data on when dates get committed** relative to first inspiration. The 7–13-day search-window growth is about *booking*, not about when the traveller decided on dates.
- Phocuswright and Skift Research reports are paywalled; I could not access primary data from either. Arival (experiences) likewise not reachable in free form.

---

## Q2. The "saved content graveyard": saving travel inspiration and never using it

### Takeaway
The behaviour is real and well attested in commentary, and there is now one concrete dataset on *what* is in those saved collections and how unusable it is — the key structural finding being that **over half of the places shown in travel TikToks are never named in the caption**, so a saved video is not a retrievable place record. But I found **no rigorous study measuring the conversion rate from "saved" to "visited"**; the quotable "most saved videos never become trips" claims all come from companies selling the fix.

### Cited Findings
- Analysis of **231 TikToks and 71 Instagram Reels imported 1 July – 14 Sept 2026**, yielding **881 extracted places** and **2,626 video-to-place links** — *vendor blog (Dreamfare, a product in this exact category); methodology is disclosed but the sample is self-selected from their own users* — [Dreamfare: What People Actually Save From Travel TikToks](https://dreamfare.app/guides/what-people-save-from-travel-tiktoks):
  - Only **47.2%** of TikTok videos name at least one location in the caption; only **42.7%** of extracted places appear in captions — **57.3% had to be recovered from on-screen text, audio, or comments**. Instagram was slightly better (52.1% of Reels named places; 59.1% of places in captions).
  - Median **2 places per TikTok**; mean 3.8 (skewed by roundup videos). **41.6%** were single-venue; **7.8%** contained 11+ places.
  - Category mix: activities/sights **78.3%** (TikTok) vs 64.9% (IG); food/drink **15.0%** vs 31.2%; accommodation **6.7%** vs 3.9%.
  - **92.4%** of TikTok places and 91.6% of Instagram places resolved to a specific venue with an address once extracted.
  - Only **7.9%** of TikTok places carried an actionable tip (booking, timing, how-to), vs **31.2%** on Instagram and **85.2%** in Reddit threads.
  - Most-saved destinations in the sample: Iceland (125 places), Lisbon (88), London (60), Interlaken (59), Cape Town (53).
- **48% of Gen Z travellers** use TikTok for travel inspiration — [Travel Tomorrow summary of study](https://traveltomorrow.com/nearly-half-of-gen-z-travellers-turn-to-tiktok-for-travel-inspiration-study-finds/); [usagevpn write-up](https://usagevpn.com/travel/i-saw-it-on-tiktok/)
- The inspiration-to-action gap is asymmetric: **58% of consumers say they would not book a trip through TikTok or Instagram**, while **21%** say they would use social media to research a trip and then book elsewhere — *consumer survey reported via syndicated wire coverage* — [Epoch Times](https://www.theepochtimes.com/bright/new-survey-highlights-consumer-hesitance-with-booking-travel-via-social-media-6090138); [Union Democrat](https://www.uniondemocrat.com/lifestyle/article_df611173-b823-4f8b-91a8-9f807af3a073.html)
- **51% said they have planned a trip inspired by a viral travel trend, but only 21% said those trips always lived up to expectations** — [Yahoo/Creators: What's Actually Inspiring Trips in 2026](https://creators.yahoo.com/lifestyle/story/forget-tiktok-travel-trends--heres-whats-actually-inspiring-trips-in-2026-211543367.html)
- Commentary framing the graveyard explicitly (the "47 saved videos" framing) exists as marketing content, not research — [Wingman blog](https://blog.wman.com/you-have-47-saved-travel-videos-heres-what-to-do-with-them/); [Plotline blog](https://getplotline.app/blog/best-app-to-save-travel-inspiration) — *both are vendor content marketing; treat the premise as a credible shared observation but the numbers as unsourced.*

### Inferences
- The 57.3% unnamed-place figure is the **single most actionable finding** for a product in this space: the bottleneck is not storage, it is **resolution** — turning a video into a named, addressed, mappable place. A save button is table stakes; extraction is the value.
- The 7.9%-actionable-tips number implies that even after resolution, TikTok-sourced places arrive **context-poor** (no hours, no booking, no "go early"). Reddit's 85.2% suggests a hybrid pipeline (video for discovery, text sources for practical detail) is what a planner actually needs to assemble.
- Median 2 places per video, but 7.8% with 11+, means the import UI must gracefully handle both **"one place, confirm it"** and **"eleven places, triage them"** — likely a reviewable checklist rather than silent auto-add.
- The 58%-won't-book figure suggests the right product boundary is **plan-and-organise, not book**; social inspiration converts to research, not transactions.

### Gaps
- **No measured save-to-visit conversion rate** from any independent source. The "graveyard" is well-described but unquantified.
- No data on collection *size distribution* (how many saves a typical user accumulates) from a neutral source.
- Nothing found on RED / Xiaohongshu collections specifically, despite its importance for Asian travellers — this is a real blind spot in English-language sources.

---

## Q3. Who plans in a group, and what breaks?

### Takeaway
There is a strong, consistent *qualitative* account of group-planning failure — an organiser-bears-all-the-load pattern, decisions lost in chat threads, and unreadable enthusiasm from participants — but essentially **no credible quantitative data**. The most-cited numbers (e.g. "10 hours down to 2.5 hours") appear only in vendor case studies and should not be repeated as findings.

### Cited Findings
- Design-research case study interviewing **both group trip leaders and participants** identified that planning derails from **lack of timely communication and unclear enthusiasm levels from group members** — i.e. the organiser cannot tell who actually wants to do what — [Simplifying the trip planning experience for group trip leaders (Medium / Design Bootcamp case study)](https://medium.com/design-bootcamp/simplifying-the-trip-planning-experience-for-group-trip-leaders-a-product-design-case-study-ffc3e10eb547)
- The documented fragmentation pattern: group workflows are spread **across chat apps, calendars, email confirmations and photo services**, producing miscommunication, duplicate work, lost confirmations, and friction in expense settlement — [IdeaUsher: developing a collaborative trip planner like Wanderlog](https://ideausher.com/blog/develop-collaborative-trip-planner-wanderlog/) — *vendor/agency content*
- A vendor case study claims pre-trip coordination time fell from **10 hours to 2.5 hours (−75%)**, group message volume from **200+/day to 35/day (−82%)**, and expense disputes to zero — *flagged as vendor-marketing; single unreplicated case, no methodology* — [IdeaUsher](https://ideausher.com/blog/develop-collaborative-trip-planner-wanderlog/)
- Real-time sync (websocket-backed live collaboration so edits appear instantly on every device) is the standard technical answer vendors converge on — [IdeaUsher](https://ideausher.com/blog/develop-collaborative-trip-planner-wanderlog/) — *vendor*
- Group trip planning is an active academic problem in its own right (optimising a shared itinerary across group members with multimodal travel), confirming the combinatorial difficulty is genuine and not just a UX issue — [Group Trip Planning Query Problem with Multimodal Journey, arXiv 2502.03144 (2025)](https://arxiv.org/pdf/2502.03144)
- Money is repeatedly named as the relationship-level friction point, separate from scheduling — [Tineo: How to Plan a Group Trip Without Losing Your Mind](https://tineo.ai/blog/plan-group-trip-with-friends/) — *vendor blog*

### Inferences
- The "unclear enthusiasm levels" finding points at a specific, cheap mechanic: **lightweight per-item signalling (a vote / 👍 / "I'd skip this") attached to the item rather than expressed in prose in a chat thread.** The organiser's real job-to-be-done is reading the group's preference distribution, not editing a document.
- Group planning is **asymmetric by default** — one organiser, N passive participants. Designing for "everyone co-edits" probably mismatches reality; designing for "one editor, N reactors, with a path to promote a reactor" matches the interview evidence better.
- Because the group's canonical record already lives in a chat thread, the highest-leverage integration is probably **export/share into the chat** (a readable, link-previewing summary) rather than asking the group to migrate into the app.

### Gaps
- **No population-level data on what share of leisure trips are planned in a group**, group sizes, or who in a group plans. This is a major gap; Phocuswright/Skift may hold it behind paywalls.
- No independent measurement of coordination time, message volume, or decision latency in group planning.

---

## Q4. Concrete interaction patterns for building and editing a day-by-day itinerary on mobile

### Takeaway
The dominant pattern set is well converged: a **day-sectioned list as the primary surface, a map as a linked secondary surface, drag-to-reorder within a day, an explicitly unscheduled bucket, and auto-computed travel time injected *between* list items**. Wanderlog is the clearest reference implementation of nearly all of them and the only one for which I could source feature-level confirmation; several patterns below I can describe but could only partially source, and those are marked.

### Cited Findings — Wanderlog (the most complete reference implementation)
- **Reorder within a day, move between days, and leave items unscheduled** are all first-class: places can be rearranged by drag-and-drop, moved across days, or "left unscheduled" — [Wanderlog review (stardrift)](https://stardrift.ai/resources/wanderlog); [Wanderlog iOS App Store listing](https://apps.apple.com/us/app/wanderlog-travel-planner/id1476732439)
- **Travel time between stops is auto-computed and shown inline**, including estimated time and distance between consecutive places, plus a **per-day total time and distance** ("to make sure you're not driving too long") — [Wanderlog App Store listing](https://apps.apple.com/us/app/wanderlog-travel-planner/id1476732439); [Google Play listing](https://play.google.com/store/apps/details?id=com.wanderlog.android)
- **Route optimisation** automatically re-sequences a day's stops for the most efficient path; it is **gated behind Wanderlog Pro (~$39.99/yr)** — [stardrift review](https://stardrift.ai/resources/wanderlog); [mapyourvoyage comparison](https://mapyourvoyage.com/blog/best-apps-to-plot-locations-on-a-map-and-optimize-routes)
- **Map + list duality** is Wanderlog's signature: interactive maps alongside the itinerary layout so the whole trip is visible at a glance; it is described as the better canvas when a trip "starts as a wishlist of restaurants, museums and neighbourhoods" — [Wanderlog vs TripIt (Tineo)](https://tineo.ai/blog/best-travel-planning-apps-2025-comparison/); [Ghost Town Hotel comparison](https://www.ghosttownhotel.com/blog/wanderlog-vs-tripit-2024)
- Independent hands-on comparisons rate Wanderlog best for **visual, map-based, collaborative** planning — [explore.com: We tried the most popular travel itinerary apps](https://www.explore.com/1440646/we-tried-popular-travel-itinerary-apps-here-is-our-favorite/); [Rick Steves forum: trial of Wanderlog and TripIt](https://community.ricksteves.com/travel-forum/general-europe/trial-of-wanderlog-and-tripit-inspired-by-trip-research-post)

### Cited Findings — TripIt
- TripIt's model is **inbox-to-itinerary**: forwarded confirmation emails are parsed into a **clean chronological timeline**, optimised for speed of retrieval rather than for composition. Its UX is described as clean, straightforward and non-laggy, and it reads as a business-travel tool — [A Purple Life: TripIt review (Mar 2025)](https://apurplelife.com/2025/03/18/best-travel-organization-app-2025/); [Tineo comparison](https://tineo.ai/blog/best-travel-planning-apps-2025-comparison/); [comparewise](https://comparewise.tech/wanderlog-vs-tripit-2026/)
- The split is explicitly an **input-modality split**: wishlist-first trips → Wanderlog's canvas; confirmation-email-first trips → TripIt's inbox pipeline — [Tineo comparison](https://tineo.ai/blog/best-travel-planning-apps-2025-comparison/)

### Cited Findings — Google Maps lists
- The native pattern is **one shareable list per destination**, created via *You → Saved → New list*, shareable with travel companions; the stated discipline is "one list per destination" to stop saves blurring into one giant pile — [Triply: How to save & organize visited places in Google Maps (2026)](https://triplyplanner.com/blog/how-to-save-visited-places-google-maps)

### Cited Findings — Polarsteps
- Polarsteps is **step-based and retrospective-leaning**: it records the route automatically in the background, and each "step" takes a cover image, notes, start/end times, photos and videos; finished trips become a shareable timeline or a printed book — [TechRadar on Polarsteps](https://techradar.com/phones/polarsteps-is-the-free-app-that-tracks-your-travels-and-it-just-made-my-new-years-resolutions-list); [stampie comparison](https://stampie.app/blog/best-travel-tracker-apps)
- Its primary surface is a **map-route timeline**, not an editable day grid — the itinerary is a byproduct of movement, which is the opposite architecture to Wanderlog's.

### Cited Findings — timeline/day-list rendering
- Dense chronological UIs (Google Maps Timeline, history logs) need users to scan large volumes and still find a specific moment; the stated best practice is to use size, colour, weight and spacing to build **no more than two or three levels of hierarchy** — more levels make a timeline measurably harder to scan — [Eleken: Timeline UI design patterns](https://www.eleken.co/blog-posts/timeline-ui-design)

### Pattern catalogue (synthesis — see Gaps for which of these I could not source per-app)

| Job | Dominant pattern | Where seen (sourced unless marked) |
|---|---|---|
| **Add an item** | Persistent search/add affordance scoped to the current day; result becomes a card appended to that day. Secondary paths: add from map pin; add from a saved list; parse from pasted link/email. | Wanderlog (search + map add, wishlist→day); TripIt (email forwarding as the *only* add path) |
| **Add without committing** | Explicit **unscheduled / wishlist bucket** that lives beside the dated days, so saving never requires a date | Wanderlog "leave stuff unscheduled"; Google Maps lists as a de facto bucket |
| **Reorder within a day** | **Long-press then drag** on a list row, with a dedicated drag handle; day auto-renumbers and travel times recompute | Wanderlog drag-and-drop |
| **Move between days** | Two patterns coexist: (a) drag across a day boundary / onto a day chip; (b) a **"Move to day…" menu** on the item — the menu path is the accessible and one-handed-friendly fallback | Wanderlog ("move things between days") |
| **Set times** | Times are **optional metadata on an ordered list**, not the organising axis. Ordering is primary; a time is added per item when it matters (reservation, tour, train) | Wanderlog (ordered list with optional times); Polarsteps (start/end times per step) |
| **"Maybe" items** | Keep in the unscheduled bucket rather than inventing a tri-state; graduation to a day is the commitment signal | Wanderlog |
| **Travel time between stops** | Rendered as a **connector row between two item cards** (mode icon + duration + distance), plus a **day-level total** to catch over-packed days | Wanderlog inline travel time + per-day total time/distance |
| **Auto-sequencing** | One-tap **route optimiser** that re-sequences the day; treated as a premium feature | Wanderlog Pro |
| **Map alongside list** | Mobile convention is **one surface at a time with a fast toggle plus a draggable sheet** — map behind, list in a bottom sheet that expands to full height; selecting a list row highlights its pin and vice versa | Wanderlog map+itinerary duality; Google Maps' own sheet behaviour |

### Inferences
- **Order is the real data structure; time is decoration.** Every app that succeeds at composition (Wanderlog) treats a day as an ordered list with optional times, while apps that treat the clock as the primary axis (calendar-grid planners, Structured-style day timelines) are good at *executing* a known day but bad at *composing* an unknown one. A planner should probably be list-first with a calendar-ish read-only view, not the reverse.
- **The travel-time connector row is the highest-value single component.** It is the only element that converts a list into a feasibility check, and it is what makes drag-reordering feel consequential rather than cosmetic. It also does double duty as the in-trip "what's next and how far" affordance (Q6).
- **Map/list should be one coordinated view, not two tabs.** A hard tab switch loses selection state and forces re-orientation; a bottom sheet over a map preserves both. This is the pattern Google Maps itself established and that users arrive already fluent in.
- Gating route optimisation behind Pro (Wanderlog) tells you where perceived value sits — users will pay for *sequencing judgement*, not for storage.

### Gaps
- **Tripsy**: I found no substantive interaction-design review. Comparisons name it but do not describe its patterns. Needs hands-on teardown.
- **Structured** and **Arc**: no sources found tying either to itinerary/trip use; both are general day-planner/browser products. Any claims about their patterns would be my own impression, so I have not asserted them. Structured's relevance is as a *time-blocked day timeline* reference, not a travel app — worth a hands-on pass.
- **Notion travel templates**: no credible UX analysis found; the relevant observation (database-with-views, so the same trip renders as board/calendar/table) is a property of Notion generally rather than a sourced travel finding.
- **Mobbin and similar pattern libraries**: not reachable without an account, so I could not pull screen-level evidence. A Mobbin pass on "itinerary", "day", "trip" flows would materially strengthen the catalogue.
- No source found that evaluates *drag-and-drop vs menu-based* day reassignment on mobile head to head. The accessibility argument for offering both (Q8) is reasoned, not measured.

---

## Q5. Known UX failure modes of AI-generated itineraries

### Takeaway
This is the best-evidenced section. **More than half of travellers who used AI for a trip hit at least one bad recommendation, and 1 in 6 were recommended a place that does not exist**; peer-reviewed work confirms hallucinations damage perceived accuracy → usefulness → trustworthiness → intention to follow the itinerary. Separately, NN/g's generative-AI research explains *why chat is a bad editing surface for a long list*, which is exactly what an itinerary is.

### Cited Findings — error rates and trust
- Survey (Greetwell, reported Sept 2026): **1 in 6 (16%) AI-using travellers were recommended a place, tour or activity that wasn't real.** More than half who used AI for trips hit **at least one** bad recommendation: incorrect prices or hours **27%**, fully booked/unavailable **21%**, simply wrong for what was asked **17%**, non-existent places/tours **16%**, permanently closed businesses **10%** — *single-vendor survey, syndicated via Stacker; methodology not independently verified* — [KVIA/Stacker](https://kvia.com/entertainment/stacker-travel/2026/09/16/survey-ai-hallucinated-travel-destinations-for-1-in-6-users/); [Lee Enterprises](https://news.lee.net/life-entertainment/nation-world/travel/survey-ai-hallucinated-travel-destinations-for-1-in-6-users/article_13e7a312-a58c-59b6-b97b-8597f725744f.html)
- Trust damage is measurable and asymmetric: among travellers who hit at least one problem, **21% said their trust in AI declined, versus 5%** of those who hit none — [KVIA/Stacker, Sept 2026](https://kvia.com/entertainment/stacker-travel/2026/09/16/survey-ai-hallucinated-travel-destinations-for-1-in-6-users/)
- Peer-reviewed: hallucinations **significantly reduced perceived accuracy**; accuracy drove usefulness, usefulness drove trustworthiness, and trustworthiness **strongly predicted intention to follow the itinerary** — hallucinations had a significant negative *indirect* effect on following the plan — Rejón-Guardia et al., *Journal of Consumer Behaviour*, 2026, "AI Hallucinations in Tourism: How Errors Impact Consumer Trust and Recommendation Acceptance" — [Wiley](https://onlinelibrary.wiley.com/doi/10.1002/cb.70105?af=R) *(abstract reachable via search; direct fetch returned HTTP 403, so sample size and method could not be verified — treat the causal chain as the paper's claim, unverified in detail)*
- Reported hallucination rates by system type: **general chatbots ~15–20% of venues**, versus **~3–5% for dedicated AI trip planners that cross-reference Google Places data** — *vendor blog; no methodology given, treat as indicative only* — [monkeytravel: Can you trust an AI travel itinerary?](https://monkeytravel.app/blog/can-you-trust-ai-travel-itinerary)
- Confident, structured, authoritative-sounding output is itself identified as the trust hazard — the format invites over-trust independent of correctness — [monkeytravel](https://monkeytravel.app/blog/can-you-trust-ai-travel-itinerary); [Generali: Risks of AI trip planning](https://www.generalitravelinsurance.com/travel-resources/ai-dangers.html)
- Real-world consequence cases (non-existent bars, visa failures) are documented in journalism — [Squamish Chief: Bad travel advice from AI](https://www.squamishchief.com/highlights/bad-travel-advice-from-ai-from-bogus-bars-to-visa-fails-12868919)
- Field-experimental HCI work exists on whether generative AI in travel planning should be persuasive or neutral — relevant to tone choices in generated plans — [Persuasive or Neutral? A Field Experiment on Generative AI in Online Travel Planning, arXiv 2509.14259 (2025)](https://arxiv.org/pdf/2509.14259)

### Cited Findings — why chat is the wrong surface for editing a long list (NN/g)
- NN/g identified two early generative-AI user behaviours in a qualitative study (**n=8**, 90-minute sessions, marketing/UX/PM/PhD participants, ChatGPT-3.5, published **24 Sept 2023**) — [NN/g: Accordion Editing and Apple Picking](https://www.nngroup.com/articles/accordion-editing-apple-picking/):
  - **Accordion editing** — users repeatedly prompt the model to shrink ("top 5") or expand the output to converge on one goal.
  - **Apple picking** — users manually type or copy specific elements out of a previous response to reference them in the next prompt.
  - NN/g's prescribed fixes are directly applicable to generated itineraries: **compartmentalisation** (edit one portion without regenerating the whole), **direct editing** (change text in place, no new prompt), and **point-to-select** (indicate the item by pointing, via GUI elements or interim numbering, instead of describing it in prose).
- The **articulation barrier**: a text-only interface limits both input and output quality, and some users cannot add specificity even when they want to because they lack the vocabulary; **GUI prompt controls** are NN/g's recommended remedy, producing hybrid interfaces that cut cognitive load and typing effort — [NN/g: Prompt Controls in GenAI Chatbots](https://www.nngroup.com/articles/prompt-controls-genai/); [NN/g: The 6 Types of Conversations with Generative AI](https://www.nngroup.com/articles/AI-conversation-types/)
- **Response outlining** (users pre-listing the structure they want in the prompt) carries high cognitive load and interaction cost — [NN/g: Response Outlining with Generative-AI Chatbots](https://www.nngroup.com/articles/response-outlining/)
- NN/g also warns against **step-by-step reasoning displays**, which are typically post-hoc rationalisations unfaithful to the actual computation, and recommends prioritising source citations and limitation transparency instead — [NN/g: Explainable AI in Chat Interfaces (12 Dec 2025)](https://www.nngroup.com/articles/explainable-ai/)

### Inferences
- "Apple picking" is *precisely* what happens when a user wants to change one stop in a generated 5-day itinerary and has only a chat box. The fix is already named and specific: **every generated item must be a directly manipulable object** (tap to swap, delete, move, pin), not a line of prose. Chat can create and amend in bulk; it must not be the only editing surface.
- The 16%-non-existent-places finding plus the 3–5% figure for Places-grounded systems argues for an architectural commitment: **no itinerary item should exist in the UI unless it resolves to a real, addressed, currently-open venue.** Resolution should be a precondition for rendering, not a post-hoc check — and items that fail to resolve should be visibly held back rather than silently shown.
- The trust-decline asymmetry (21% vs 5%) means **one hallucinated stop is disproportionately expensive.** Conservative behaviour — fewer, verified items with visible gaps — beats a full, confident, partly-fictional plan.
- A long generated list has a second failure mode beyond accuracy: it **arrives un-owned.** The user did not choose any of it, so there is nothing to defend or refine. Generating *fewer* items and leaving deliberate holes for the user to fill may produce more commitment than a complete plan.

### Gaps
- Could not verify the *Journal of Consumer Behaviour* paper's sample size, country, or method (403 on fetch). Flag before citing precisely.
- The Greetwell survey's sample size and sampling frame are not stated in the syndicated coverage.
- I found **no design critique specifically of chat-based travel planning UIs** (as opposed to AI chat UIs generally). The NN/g findings are transferred by analogy — strong analogy, but transferred.

---

## Q6. What makes a travel app get opened *during* a trip?

### Takeaway
This is the weakest-evidenced question. I found the standard engagement-metric vocabulary (DAU/MAU stickiness, screen flow, session duration) and the general claim that in-destination support depends on **real-time, location-aware** functionality, but **no study isolating which features drive in-trip opens**. Report this as a reasoned hypothesis, not a finding.

### Cited Findings
- In-destination usage is explicitly identified as its own opportunity, driven by **location data used to deliver better experiences in the moment** — [Alchemer: 2022 benchmarks for mobile customer engagement in travel apps](https://www.alchemer.com/resources/blog/travel-apps-2022-mobile-customer-engagement-benchmarks/) — *vendor benchmark report, 2022*
- Travel brands measure in-app engagement via **screen flow, feature usage and session duration**, with **DAU/MAU "stickiness"** as the headline frequency metric — [WebEngage: mobile app metrics for travel & hospitality](https://webengage.com/blog/mobile-app-metrics-for-travel-hospitality/); [Hospitality Tech: beyond web analytics](https://hospitalitytech.com/beyond-web-analytics-unleashing-power-app-specific-metrics-travel-brands)
- Travellers "increasingly rely on real-time mobile functionality for trip planning and in-destination support"; travel app downloads rose **17% in 2024 to ~1.5bn installs** — [Prioridata travel app statistics](https://prioridata.com/data/travel-app-statistics/) — *aggregator, derived from app-store estimates*
- Industry coverage of how travel brands prioritise app engagement — [PhocusWire](https://www.phocuswire.com/how-travel-brands-prioritizing-mobile-app-engagement)
- Academic instrument work on measuring tourists' perceived engagement with mobile travel apps exists (useful if you want a validated engagement scale rather than proxy metrics) — [Mobile Travel Apps Engagement: Measuring Tourists' Perception (ResearchGate, 2022)](https://www.researchgate.net/publication/362267572_Mobile_Travel_Apps_Engagement_Measuring_Tourists'_Perception)
- Relevant adjacent evidence from Q5: travellers' most common AI complaint in-destination was **incorrect prices or hours (27%)** and **fully booked / unavailable (21%)** — both are *in-trip* failures, discovered at the door — [KVIA/Stacker, Sept 2026](https://kvia.com/entertainment/stacker-travel/2026/09/16/survey-ai-hallucinated-travel-destinations-for-1-in-6-users/)
- Polarsteps' in-trip hook is passive: it **records the route in the background** and turns the trip into a timeline/book, so the app accrues value without requiring an open — [TechRadar](https://techradar.com/phones/polarsteps-is-the-free-app-that-tracks-your-travels-and-it-just-made-my-new-years-resolutions-list)

### Inferences (explicitly hypotheses — not sourced)
- The in-trip job-to-be-done is **not "review my plan", it is "answer the next 90 minutes"**: what's next, how do I get there, is it open, what's near me if this falls through. That argues for a *now-oriented* default screen during the trip dates, distinct from the composition view used beforehand.
- The 27%/21% hours-and-availability failure rate suggests the single most valuable in-trip feature is **freshness of operational data** (open/closed now, today's hours, closure alerts) — the thing a static exported PDF or Notes doc can never do, and therefore the clearest reason to open an app rather than a screenshot.
- Offline availability is likely a precondition rather than a driver: without it, the app fails exactly when it is needed (no roaming), but having it does not itself create opens.
- Polarsteps shows a second, orthogonal route to in-trip relevance: **capture** (passive logging, photos attached to steps) creates a reason to open that is emotional rather than logistical, and it produces the post-trip artefact that drives sharing.

### Gaps
- **No study found that ranks in-trip features by usage or retention impact.** Everything above is either generic metric guidance or inference.
- No data on pre-trip vs in-trip session split for any named itinerary app.
- No data on offline-use incidence.

---

## Q7. What does good provenance / source-attribution UI look like?

### Takeaway
NN/g's December 2025 guidance on explainable AI is the most directly usable source and is unusually prescriptive: attribution should be **visually distinct, adjacent to the specific claim, deep-linked to the relevant section, and labelled with a meaningful publication name** — while designers should assume users *will not* actually verify, and avoid anthropomorphic framing that inflates trust.

### Cited Findings
All from [NN/g: Explainable AI in Chat Interfaces, 12 Dec 2025](https://www.nngroup.com/articles/explainable-ai/):
- **What fails:** citations are frequently hallucinated (nonexistent URLs, unrelated sources); **users rarely verify sources even when they are visible**; visible-but-unverified citations create a *false appearance of reliability* that suppresses critical evaluation.
- **What works:** style citations **distinctly from the main response text**; place each source **directly adjacent to the specific claim it supports** (not pooled at the end); **deep-link to the relevant section** rather than the whole page; use **meaningful labels — the publication name — instead of a generic "Source"**; and **set realistic expectations** that verification is still needed.
- **Avoid step-by-step reasoning displays** that imply certainty; prioritise source citations and explicit limitation statements instead.
- **Disclaimers:** plain language, no AI jargon; pair each limitation with a concrete user action ("Double-check outputs"); place **near the input box, not in a footer**; also surface during onboarding.
- **Avoid anthropomorphic phrasing** — "based on the following source" rather than "I searched the internet" — because humanising the system inflates trust.

Travel-specific corroboration:
- The hallucination evidence in Q5 makes provenance load-bearing rather than decorative: dedicated planners that **cross-reference Google Places** reportedly cut fabricated venues from ~15–20% to ~3–5% — i.e. provenance UI should surface *which* authority resolved the place — [monkeytravel](https://monkeytravel.app/blog/can-you-trust-ai-travel-itinerary) *(vendor, no methodology)*
- The Dreamfare data gives a concrete provenance taxonomy for socially-sourced places — a place can be known from the **caption (42.7%)**, or from **on-screen text, audio, or comments (57.3%)** — meaning extraction confidence genuinely varies per item and is worth exposing — [Dreamfare](https://dreamfare.app/guides/what-people-save-from-travel-tiktoks) *(vendor)*

### Inferences
- Applied to a travel planner, NN/g's "adjacent to the claim" rule means provenance belongs **on the itinerary item card**, not on the trip or on a separate sources screen: a small creator/source chip on the card for the place that came from that reel.
- "Users rarely verify" has a design consequence most products get wrong: **do the verification for them and show the result**, rather than showing a link and considering the duty discharged. "Open now · hours confirmed today · from @creator's reel" is a stronger trust artefact than a citation link.
- The caption-vs-audio provenance split argues for an honest **confidence tier** on imported items — a place named in the caption is near-certain; one inferred from audio deserves a "check this" state and a tap-to-see-the-moment-in-the-video affordance.
- Deep-linking "to the relevant section" translates, for video sources, into **linking to the timestamp**, not the video — the single highest-value provenance interaction available in this category, and the one that makes a saved reel actually re-checkable.

### Gaps
- I found **no cross-category survey of provenance UI patterns** (e.g. how Spotify, Pinterest, Perplexity, Arc Max, Notes' linked-source UIs compare). The NN/g article is strong but single-source.
- No usability data on creator-attribution chips specifically, nor on timestamp-deep-link affordances in saved-video UIs.

---

## Q8. Accessibility and one-handed mobile use for list/day interfaces

### Takeaway
The foundational reachability data is Hoober's 2013 observational work (still the standard citation): roughly half of phone use is genuinely one-handed and ~75% of interactions are thumb-driven, which puts primary itinerary actions in the bottom-centre of the screen and makes **drag-and-drop reordering an accessibility liability unless a non-drag equivalent exists**. Note that the specific percentages are now 13 years old and predate large-format phones.

### Cited Findings
- **49% of people use one hand, 36% cradle the device and interact with the other hand, 15% use two hands**; about **75% of mobile interactions are thumb-driven** — originally Steven Hoober's observational study (2013), reported in — [Scott Hurff: How to design for thumbs in the era of huge screens (foundational, 2014)](https://www.scotthurff.com/posts/how-to-design-for-thumbs-in-the-era-of-huge-screens/); also summarised in [Parachute Design: thumb zone guide](https://parachutedesign.ca/blog/thumb-zone-ux/) and [Heyflow](https://heyflow.com/blog/mastering-the-thumb-zone/)
- Zone model: **green** (easy, bottom-centre, where the thumb rests without strain), **yellow** (mid-screen sides, reachable with a stretch), **red** (top corners, awkward or impossible, forcing a grip change or second hand) — [Parachute Design](https://parachutedesign.ca/blog/thumb-zone-ux/); [Global Bridge Labs](https://globalbridgelabs.co.uk/blogs/thumb-zone-design); [MockFlow glossary](https://mockflow.com/glossary/Thumb-reachability)
- Placing primary actions in the natural reach area **reduces effort and errors**; on larger screens, OS reachability affordances (one-handed mode, pull-down) exist to drag far elements into thumb range — [Parachute Design](https://parachutedesign.ca/blog/thumb-zone-ux/); [Timothy Graf: designing for the thumb zone](https://timgraf.com/ux-design/designing-for-the-thumb-zone-a-modern-guide-to-mobile-ux-that-respects-human-anatomy/)
- Timeline/dense-list scanning: hold hierarchy to **two or three levels** via size, colour, weight and spacing; more levels measurably degrade scanning — [Eleken: timeline UI design](https://www.eleken.co/blog-posts/timeline-ui-design)
- A mobile travel-planning app developed with a user-centric UX process scored **SUS 87.23** ("great usability") in usability testing, demonstrating that high measured usability is achievable in this specific category and giving a benchmark to beat — [An Interactive Mobile Application to Enhance Travel Planning: A UX Design Case Study (iJIM)](https://online-journals.org/index.php/i-jim/article/view/51279)
- Travel/hospitality research playbooks name **itinerary management** (how users access booking details, add activities, coordinate with companions) as a core research area in its own right — [CleverX: travel & hospitality UX research playbook](https://cleverx.com/blog/travel-and-hospitality-user-research-a-complete-guide-for-product-and-ux-teams/)

### Inferences (reasoned from the above; the drag-and-drop accessibility argument is not directly sourced)
- **Every drag-to-reorder must have a tap-only twin.** Drag-and-drop requires sustained precise pressure plus movement — the hardest gesture class for users with motor impairments, and awkward one-handed on a tall phone. The twin is a per-item menu: *Move up / Move down / Move to day… / Unschedule*. Wanderlog's existence of both drag and "move between days" suggests this is already partly convention.
- **Put composition actions at the bottom.** Add-place, day switcher, and map/list toggle belong in the green zone; destructive or rare actions (delete trip, settings) belong in the red zone where accidental activation is unlikely — the reachability model doubles as a safety model.
- **Day chips as a bottom-anchored horizontal scroller** is the thumb-friendly solution to day navigation, and it also provides the drop target for cross-day moves — one component serving navigation and reassignment.
- The two-to-three-hierarchy-level limit constrains the item card: realistically **place name (primary), one line of type/time (secondary), travel-time connector (tertiary)**. Provenance chips, prices, notes and ratings all compete for the same tertiary slot and cannot all be shown.
- Screen-reader correctness for a day list means each item announces **its position and its day** ("Stop 3 of 5, Tuesday"), since position *is* the data in an order-primary model — otherwise reordering is unverifiable non-visually.

### Gaps
- Hoober's percentages are **from 2013** and predate 6.7"+ phones; I found no modern replication. Use them as directional, and date them explicitly if quoted.
- **No WCAG-specific or empirical guidance found on accessible alternatives to drag-and-drop reordering** in the sources I reached. (WCAG 2.2's "Dragging Movements" success criterion 2.5.7 is the relevant normative requirement — a single-pointer alternative must exist — but I did not retrieve a W3C source in this pass and so have not cited it as verified.)
- No accessibility audit found of any named itinerary app (Wanderlog, TripIt, Tripsy).

---

## Overall source-quality warning for the report writer

1. **The travel-planning web is heavily polluted by AI-generated SEO content.** A large share of search results for "best trip planning app 2026", "Wanderlog vs TripIt" etc. are vendor blogs owned by competing products, and they routinely state statistics without sources. I have flagged every such citation as vendor, and I have deliberately *not* reported several attractive-sounding numbers (e.g. "travellers visit 38 sites before booking", "coordination time fell 75%") where no primary source was reachable.
2. **Paywalled primary research was not accessible**: Phocuswright, Skift Research, Arival, and Google/Think with Google travel studies all failed to yield primary data in this pass. Expedia's own Path-to-Purchase page returned HTTP 429 and the *Journal of Consumer Behaviour* paper returned HTTP 403, so two of the most load-bearing citations (the 303-minute figure and the hallucination→trust causal chain) are reported secondhand and should be re-verified before publication.
3. **Strongest evidence base:** AI itinerary failure modes (Q5) and provenance UI (Q7). **Weakest:** in-trip usage drivers (Q6) and group-planning quantification (Q3) — both are hypothesis-grade and should be presented as such.
