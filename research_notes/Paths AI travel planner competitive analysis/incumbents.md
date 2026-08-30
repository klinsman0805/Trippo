# Incumbents and Big-Tech Platforms in AI Trip Planning (as of October 2026)

Scope note on source quality: primary sources (Google blog, Booking Holdings press releases, Expedia IR, Tripadvisor newsroom, Skift, PhocusWire, TechCrunch) are used wherever possible. Several "AI itinerary error rate" studies circulating online come from SEO-driven blogs with no published methodology; these are flagged explicitly as low-confidence.

## Google: trip-planning capability across Gemini, Search AI Mode, Maps, and Google Travel/Flights

### Takeaway
Google has reassembled the old Google Trips functionality across Gemini, Search AI Mode (Canvas), Maps and Google Travel, and as of 2026 Gemini can genuinely produce a routed, day-by-day itinerary grounded in Maps/Flights/Hotels data and personalised from Gmail/Photos/YouTube — all free. The weak spot is that the output lives in surfaces built for answers and bookings, not in a durable, editable, collaborative trip object.

### Cited Findings
- Google's own product blog post "How Gemini plans custom trips with detailed itineraries" (August 6, 2026) states Gemini pulls real-time data from "Google Maps, Hotels, and Flights to build highly personalized itineraries based on real-world data," incorporates YouTube creator content, and integrates the Viator app for booking tours and activities — [Google Blog](https://blog.google/products-and-platforms/products/gemini/how-gemini-plans-trips/)
- Same post: via "Personal Intelligence," Gemini references stored preferences, Gmail confirmations and past bookings to "build your itinerary around your existing plans and preferences — cross-referencing times and locations before weaving things into your schedule"; it also does packing lists, rental car comparison, and (via Gemini Spark) navigating to an airline site and pre-filling booking forms — [Google Blog](https://blog.google/products-and-platforms/products/gemini/how-gemini-plans-trips/)
- Same post describes routing and neighbourhood grouping as part of producing "a cohesive plan that accounts for all your constraints" — [Google Blog](https://blog.google/products-and-platforms/products/gemini/how-gemini-plans-trips/)
- Google announced a major expansion of AI travel tooling in Search on November 17, 2025: Flight Deals (an AI/natural-language version of Google Flights, launched in US/Canada/India around August 2025) went to 200+ countries and territories in 60+ languages; "Canvas" in AI Mode generates travel itineraries in a side panel combining flight and hotel data, Google Maps information and web content; agentic booking began rolling out starting with restaurant reservations — [TechCrunch](https://techcrunch.com/2025/11/17/google-rolls-out-its-ai-flight-deals-tool-globally-adds-new-travel-features-in-search/); [Search Engine Journal](https://www.searchenginejournal.com/google-extends-ai-travel-planning-and-agentic-booking-in-search/561251/)
- Canvas travel planning was at launch limited to desktop in the US for users opted into the AI Mode experiment in Google Labs — [Search Engine Journal](https://www.searchenginejournal.com/google-extends-ai-travel-planning-and-agentic-booking-in-search/561251/)
- Google Maps shipped a Gemini-powered "Screenshots" list (announced March 27, 2025): Gemini reads places out of the text in your screenshots, plots them on the map, and lets you save them to a shareable list; it rolled out first to English-language iOS users in the US, with Android "coming soon" — [9to5Google](https://9to5google.com/2025/03/27/google-maps-gemini-screenshots/); [Android Police](https://www.androidpolice.com/google-maps-now-has-pixel-screenshots-built-in/)
- Google has a dedicated travel-planning tips post covering AI Overviews, Maps updates and hotel price tracking — [Google Blog](https://blog.google/products-and-platforms/products/search/summer-travel-tips-ai-overviews-hotel-price-tracking/)
- Secondary/review coverage describes an "Ask Maps" conversational experience where a user can type or speak e.g. "a relaxed three days in Lisbon with good seafood and not too much walking" and get an answer drawn from Maps' own places, reviews, photos and opening hours — available only "in supported regions and languages." Caveat: this description comes from SEO/review sites, not a Google primary source — [AI Learning Guides](https://ailearningguides.com/gemini-google-maps-vacation-itinerary-planning/); [TechBuzz](https://www.techbuzz.ai/articles/google-maps-gemini-ai-plans-your-day-surprisingly-well)
- The same secondary coverage states the tools "should not be the sole source for live fares, availability, visa rules, opening hours or cancellation terms" — [AI Learning Guides](https://ailearningguides.com/gemini-google-maps-vacation-itinerary-planning/)

### Google Trips (shut down)
- Google Trips lost support on August 5, 2019 and the mobile app was shut down that day — [9to5Google](https://9to5google.com/2019/06/03/google-trips-stop-support/); [AlternativeTo](https://alternativeto.net/news/2019/8/google-s-mobile-trips-app-is-being-shut-down)
- Functionality was split rather than killed: notes moved to the Google Travel website (google.com/travel); reservations moved into Google Maps under "Your places > Upcoming reservations"; Google pointed users to the Travel site and the Google Search app, and said offline capability and maps would be added to Google Maps — [Thrifty Traveler](https://thriftytraveler.com/guides/google-trips-where-to-find-info/); [9to5Google](https://9to5google.com/2019/06/03/google-trips-stop-support/)

### Inferences
- Google's 2026 position is effectively "Google Trips, rebuilt as a layer across Gemini + AI Mode + Maps." The planning *generation* problem is commoditised and free: an indie app should not compete on "describe your trip, get a day-by-day plan."
- What Google has not rebuilt is the *artifact*: a single persistent trip document that multiple people edit, reorder, annotate and carry offline. Canvas is a desktop AI Mode side panel; Maps lists are flat place collections without day structure or timing; Gemini chats are ephemeral. The gap is the container, not the generator.
- Fragmentation across surfaces (Gemini chat, AI Mode Canvas, Maps lists, Google Travel reservations, Flights) is itself a durable weakness — there is no one place a traveller's trip lives.

### Gaps
- No primary Google source found confirming the exact name, launch date, or market/language availability of a conversational "Ask Maps" trip-planning mode; the descriptions found are from secondary SEO sites. Needs verification against a Google blog post or Maps release note.
- Could not confirm whether Google Maps can *import* an external list of places (e.g. from a web page or another app) into a saved list or trip, beyond the Gemini screenshot-scraping path. No source found either way.
- No usage/adoption numbers published by Google for Gemini trip planning, AI Mode Canvas itineraries, or the Maps Screenshots list.
- Could not confirm whether Gemini-generated itineraries persist as editable, shareable objects or only as chat output.

## TripIt: feature set, pricing, user base, email parsing, AI, ownership

### Takeaway
TripIt remains the canonical email-forwarding itinerary organiser, owned by SAP Concur, monetised via a $49/year Pro tier, and it has added narrow AI features (on-device document parsing, risk alerts) rather than generative itinerary building — it is an organiser, not a planner.

### Cited Findings
- TripIt is part of the SAP Concur portfolio; companies using Concur TripLink give employees a complimentary TripIt Pro subscription — [SAP Concur Community](https://community.concur.com/t5/Support-and-FAQs/What-is-TripIt-and-How-Does-TripIt-Work/ba-p/16867); [SAP Concur App Center](https://www.concur.com/app-center/listings/550353cc99066b13221bcdf5)
- TripIt Pro is $49 USD/year with a 30-day free trial; it covers flight status, reminders and travel perks — [TripIt Pro](https://www.tripit.com/web/pro); [SAP Concur Community](https://community.concur.com/t5/Getting-Started/Getting-Started-with-TripIt-Pro/ba-p/49657)
- At SAP Concur Fusion 2026 SAP announced AI additions for TripIt Pro: "Image to Plan with Apple Intelligence," which turns photos or PDFs (tickets, reservations, event flyers, receipts) into TripIt plans using Apple Intelligence's on-device foundation models to extract dates, times, locations, confirmation numbers and costs; and expanded Risk Alerts that monitor breaking news against the addresses in a trip plan and proactively alert on incidents affecting lodging, car rental, rail and activities — [SAP Concur blog](https://www.concur.com/blog/article/sap-showcases-new-ai-integrated-travel-and-expense-enhancements-and-global)
- SAP's Joule copilot is now embedded across Concur solutions to automate routine tasks — [SAP Concur blog](https://www.concur.com/blog/article/sap-showcases-new-ai-integrated-travel-and-expense-enhancements-and-global)

### Inferences
- TripIt's AI strategy is extraction and risk monitoring, not itinerary generation. It validates "the trip container as a product" (people pay $49/yr for a well-organised trip object) while leaving the planning/discovery side wide open.
- Its centre of gravity has shifted to corporate travel via Concur/TripLink, which means the consumer leisure-planning experience is not where SAP's incentives point.
- The email-forwarding parse model (forward confirmations to plans@tripit.com) remains the de facto standard mechanism, and the new Image-to-Plan feature is an extension of it rather than a replacement.

### Gaps
- No reliable current user-base number found. TripIt has historically cited ~20M+ users but I found no 2025–2026 primary source stating active users, so this is deliberately omitted rather than guessed.
- No source found confirming the current free-vs-Pro feature split in detail (which specific features are gated) beyond flight status/alerts/perks being Pro.
- No evidence found that TripIt has shipped any generative day-by-day itinerary builder.

## Booking.com / Booking Holdings

### Takeaway
Booking.com was first to market with a generative AI trip planner (June 2023) and has since layered natural-language search (Smart Filter), Property Q&A and review summaries on top, but its disclosed AI-originated demand is under 1% of room nights — planning is a funnel into booking, and it is not yet converting.

### Cited Findings
- Booking.com's AI Trip Planner launched as a US-only beta in June 2023; by October 2024 it had reached the UK, Australia, New Zealand and Singapore — [Air Traveler Club](https://www.airtraveler.club/news/ai-trip-planners-booking-expedia/) (secondary); corroborated for the Oct 2024 expansion by the Booking Holdings press release below
- Booking Holdings press release dated October 30, 2024 announced: **Smart Filter** (describe your ideal property in natural language, GenAI applies filters across the whole inventory) and **Property Q&A** (GenAI answers property questions from listings, reviews and photos), both live in the US, UK, Australia, New Zealand and Singapore on mobile; **Review Summaries** in testing; and the **AI Trip Planner** expanded to the UK, Australia, New Zealand and Singapore, with Spain, Italy, Germany, France, Poland and the Netherlands "launching soon" with local-language support and a desktop version coming — [Booking Holdings](https://www.bookingholdings.com/press-releases/booking-com-enhances-travel-planning-with-new-ai-powered-features-for-easier-smarter-decisions/)
- Booking.com has also shipped AI Review Summaries, AI Voice Support, and partner-side agentic tools (Smart Messenger, Auto-Reply) — [Booking.com news](https://news.booking.com/bookingcom-enhances-travel-planning-with-new-ai-powered-features--for-easier-smarter-decisions/)
- Less than 1% of Booking Holdings room nights originate from AI channels (reported alongside a Bernstein estimate of ~1.6% for Marriott) — [Skift, Oct 11 2026](https://skift.com/2026/10/11/travel-ais-prove-it-phase-visibility-and-the-booking-gap/)
- Q2 2026: revenue up 8% to ~$7.35B, gross bookings up 9% to ~$51B, room nights up 5%; CEO Glenn Fogel has called agentic AI a "transformative force," and ~$170M of efficiency savings is being reinvested into AI capabilities and Connected Trip — [PYMNTS](https://www.pymnts.com/earnings/2026/ai-can-plan-the-trip-but-booking-holdings-wants-the-transaction/)
- Booking Holdings plans a $100 million investment in Vayo, a new company focused on a personal AI-driven travel agent — [MarketScreener](https://www.marketscreener.com/news/booking-holdings-plans-100-million-investment-in-ai-travel-agent-company-ce785dd2de8cf521); [PYMNTS](https://www.pymnts.com/earnings/2026/ai-can-plan-the-trip-but-booking-holdings-wants-the-transaction/)
- Booking.com's CTO publicly discussed the AI Trip Planner and the path to autonomous agents in March 2025 — [Skift](https://skift.com/2025/03/25/booking-com-and-ai-now-vs-2023-tech-chief-explains-whats-changed-whats-next/)

### Inferences
- The PYMNTS headline framing ("AI can plan the trip but Booking Holdings wants the transaction") captures the strategic pattern precisely: planning is loss-leader top-of-funnel, and Booking's planner is constrained to what it can sell. Attractions, restaurants, neighbourhood walks, free/independent places are only included insofar as they support an accommodation booking.
- Spinning Vayo out as a separate $100M-funded company suggests Booking does not believe the planner-inside-the-OTA-app model wins on its own.
- Sub-1% AI-originated room nights after three years of shipping means an indie app is not competing against a proven conversion machine; it is competing against a marketing surface.

### Gaps
- No disclosed usage numbers for AI Trip Planner specifically (sessions, MAU, share of users).
- Could not confirm whether the "launching soon" European-language expansion from the Oct 2024 release actually shipped, or current market/language coverage as of Oct 2026.
- No primary Booking source found for the June 2023 launch date; it rests on secondary coverage (widely reported, but not verified here against a 2023 press release).

## Expedia Group (including Layla)

### Takeaway
Expedia's flagship AI concierge Romie has been **deprioritised** — the company concluded an all-in-one concierge was impractical — and on July 31, 2026 it acquired Berlin startup Layla to pivot to a "multi-agentic" architecture of specialised agents. This is the single clearest public admission by an incumbent that the monolithic AI trip planner did not work.

### Cited Findings
- Expedia Group acquired Layla on July 31, 2026: an AI-native trip planning and booking platform for destination discovery, personalised itineraries and complete trip planning via a conversational travel agent — [Expedia Group IR](https://ir.expediagroup.com/news-and-events/news/news-details/2026/Expedia-Group-acquires-Layla-accelerating-its-AI-powered-trip-planning-and-booking-strategy/default.aspx); [PhocusWire](https://www.phocuswire.com/news/technology/expedia-group-acquires-ai-travel-planning-app-layla)
- Layla: Berlin-based, founded 2023, ~25 employees, ~€5M raised, undisclosed deal terms; Expedia gained technology and talent as it builds out Silicon Valley presence — [Skift](https://skift.com/2026/07/31/expedia-acquired-ai-trip-planner-layla-exclusive/); [Skift on X](https://x.com/skift/status/2083260024252416436)
- "The deal advances Expedia's pivot from an all-in-one AI concierge (the deprioritized Romie) toward a 'multi-agentic' architecture of specialized agents." Expedia "found that its original end-to-end concierge concept (Romie) wasn't practical" and now bets on specialised agents that communicate with each other — [Skift](https://skift.com/2026/07/31/expedia-acquired-ai-trip-planner-layla-exclusive/); [Skift on X](https://x.com/skift/status/2083260024252416436)
- Expedia positions differentiation around trust, first-party traveller insights, global bookable inventory, marketplace scale, and a rigorous "evals" system to guard against AI hallucinations — [Skift on X](https://x.com/skift/status/2083260024252416436)
- Expedia launched an app inside ChatGPT on October 6, 2025, letting users ask for hotel rooms and get dynamic prices and availability in-chat — [Air Traveler Club](https://www.airtraveler.club/news/ai-trip-planners-booking-expedia/) (secondary)
- Romie was described as an "intelligent sidekick" living in messaging threads to help groups agree on villas and track flight prices — [Travel and Tour World](https://www.travelandtourworld.com/news/article/expedia-and-booking-holdings-elevate-travel-experience-with-ai-tools/)

### Inferences
- Romie's deprioritisation is the strongest available evidence that "one chatbot that does the whole trip" is not the winning shape — including for a company with inventory, data and distribution.
- Expedia explicitly naming hallucination-guarding "evals" as a differentiator implies accuracy was a live failure mode in its earlier planning products.
- The Layla acquisition also shows incumbents will buy, not build, indie AI planners — relevant to an indie app's exit optionality, and a reason not to position purely as a thin wrapper that a giant can acquire or clone cheaply.

### Gaps
- Could not establish Romie's original launch date (announced at Expedia's EXPLORE conference; no primary source retrieved in this research).
- No source found on whether Layla's consumer app continues to operate independently post-acquisition, or on Layla's user numbers.
- No Expedia-disclosed adoption numbers for Romie or any planning feature.
- Could not confirm the existence/status of an Expedia "Trip Matching" product (the social/Instagram-reel-based matching feature) as of Oct 2026.

## Airbnb

### Takeaway
Airbnb shipped AI-powered search in its fall 2026 release (September 30, 2026) but has explicitly **not** shipped trip planning — Chesky has said the real AI agent, a visual interface rather than a chatbot, comes in 2027. Airbnb is the slowest mover of the big platforms on planning.

### Cited Findings
- Airbnb added AI search and more social features on September 30, 2026; users toggle on text or voice prompt search and the interface generates dynamic filters from preferences — [TechCrunch](https://techcrunch.com/2026/09/30/airbnb-adds-ai-search-more-social-features/); [NewsBytes](https://www.newsbytesapp.com/news/science/airbnb-unveils-fall-2026-ai-search-tool-for-group-travel/tldr)
- Chesky announced on the Q4 earnings call (reported February 13, 2026) a plan to integrate LLM-powered AI across search, trip planning and host support — still in development — [TechCrunch](https://techcrunch.com/2026/02/13/airbnb-plans-to-bake-in-ai-features-for-search-discovery-and-support/); [Cybernews](https://cybernews.com/ai-news/airbnb-plans-ai-powered-search-and-trip-planning-ceo-says/)
- At Skift Global Forum, Chesky said Airbnb will ship its own AI agent in **2027**, described as "much richer than a chatbot" — a visual interface built for how people shop for a stay, handling travellers arriving "with a broad request" such as a family trip to Europe — [The AI Insider](https://theaiinsider.tech/2026/10/01/airbnb-introduces-ai-search-as-brian-chesky-bets-on-cautious-conversion-focused-rollout/); [TechCrunch interview](https://techcrunch.com/2026/10/01/brian-chesky-interview-ai-agents-need-their-own-operating-system/)
- Airbnb has automated ~45% of customer support contacts with AI; its "Project Y" uses LLMs for discovery and host property management — [PYMNTS](https://www.pymnts.com/news/artificial-intelligence/2026/airbnb-is-weaving-ai-into-every-step-of-a-trip/); [AI Magazine](https://aimagazine.com/news/tripadvisor-airbnb-can-ai-agents-beat-travel-agents)

### Inferences
- Chesky's "cautious, conversion-focused" framing and the 2027 date mean there is a real window — roughly the next 12–18 months — before the most design-led large platform enters planning properly.
- Chesky's stated conclusion that the right form is a rich visual interface rather than a chat window converges with Expedia's abandonment of the monolithic concierge. Two independent incumbents have concluded chat is the wrong container.

### Gaps
- No detail found on whether Airbnb's fall 2026 AI search produces any multi-day or itinerary-shaped output (appears to be stay search only).

## Tripadvisor

### Takeaway
Tripadvisor has a free AI Trip Builder / AI Assistant grounded in its ~1 billion reviews, and in 2026 has pushed distribution outward — into Anthropic's Claude and Amazon's Alexa+ — rather than deepening the in-app planning product. It publishes no adoption numbers.

### Cited Findings
- Tripadvisor operates a free itinerary builder at tripadvisor.com/Trips and a free AI trip planner/assistant at tripadvisor.com/AIAssistant — [Tripadvisor Trips](https://www.tripadvisor.com/Trips); [Tripadvisor AI Assistant](https://www.tripadvisor.com/AIAssistant)
- Tripadvisor newsroom post dated April 23, 2026 states that Tripadvisor and Viator "are now available inside Anthropic's AI assistant Claude," giving experience and hotel recommendations inside a Claude conversation, and that Tripadvisor content is integrated with Amazon's Alexa+, where users can ask for destination ideas, points of interest or activities and receive "personalized itineraries tailored to what the traveler is looking for" — [Tripadvisor Newsroom](https://tripadvisor.mediaroom.com/2026-04-23-How-AI-Is-Changing-the-Way-We-Plan-Travel)
- That same newsroom post contains **no launch dates, no adoption metrics and no stated limitations** — it is positioning ("trusted information matters more than ever in an AI-driven world") — [Tripadvisor Newsroom](https://tripadvisor.mediaroom.com/2026-04-23-How-AI-Is-Changing-the-Way-We-Plan-Travel)
- Tripadvisor's approach is to ground GPT-4 in its proprietary first-party review corpus (over a billion reviews) to avoid generic results — [AI Magazine](https://aimagazine.com/news/tripadvisor-airbnb-can-ai-agents-beat-travel-agents); [PhocusWire](https://www.phocuswire.com/news/technology/tripadvisor-ai-travel-planning-tool)
- Tripadvisor has partnered with Nvidia, Nebius and Nexla to demo end-to-end AI travel planning — [AI Magazine](https://aimagazine.com/news/tripadvisor-airbnb-can-ai-agents-beat-travel-agents)

### Inferences
- Tripadvisor's bet is on being the *data layer* inside other people's assistants, which implicitly concedes that its own app is not where users will plan. That makes its first-party planning product a lower-investment surface and a weaker competitor than its data moat suggests.
- Its review corpus is the single asset an indie app cannot replicate — but Tripadvisor's reviews skew toward high-traffic, tourist-facing venues, which is precisely where an indie app differentiates on independent and local places.

### Gaps
- No launch date found for Tripadvisor's AI Trip Builder general availability (it was demoed per PhocusWire; GA date unconfirmed).
- No adoption or usage numbers published by Tripadvisor for any AI planning feature.

## Agoda and Klook

### Takeaway
Both have shipped AI planning, both in beta/limited form, and both are APAC-focused — Agoda's full booking-capable AI Assistant entered limited public beta around September 2026; Klook's K.AI chatbot/trip planner launched with support for eight languages, making Klook the most credible incumbent on non-English planning.

### Cited Findings
- Agoda launched an AI Vacation Planner for Indian travellers built on Google's Gemini and Imagen, delivered as a standalone campaign microsite (AgodaVacationPlanner.com) available until June 30, with an Ayushmann Khurrana marketing campaign — [PhocusWire](https://www.phocuswire.com/agoda-launches-ai-powered-vacation-planner-indian-travelers); [Branding in Asia](https://www.brandinginasia.com/agoda-launches-ai-vacation-planner-in-india-with-campaign-starring-ayushmann-khurrana/)
- Agoda began a limited public beta (reported September 16, 2026) of an AI Assistant that goes beyond destination suggestions to connect travellers to live hotel, flight and activity inventory, keeping planning, price comparison, availability checks and booking in one conversation; initially released to selected Agoda mobile app users — [Rus Tourism News](https://www.rustourismnews.com/2026/09/16/agoda-launches-ai-travel-assistant-that-can-plan-and-book-entire-trips/); [Yahoo Finance](https://finance.yahoo.com/technology/ai/articles/agoda-begins-limited-public-beta-030000344.html); [ANTARA News](https://en.antaranews.com/news/432649/agoda-begins-limited-public-beta-of-new-ai-assistant-that-turns-travel-ideas-into-bookable-trips)
- Klook announced K.AI, a generative AI chatbot and trip planner, at its 9th birthday press conference in Bangkok (COO/co-founder Eric Gnock Fah), after an in-app beta; K.AI is being integrated into the Things To Do activity pages across **eight languages** for Klook's APAC markets — [Web in Travel](https://www.webintravel.com/at-nine-klook-rolls-out-k-ai-trip-planner-and-klook-kreators-to-convert/)

### Inferences
- The Agoda India vacation planner being a time-boxed campaign microsite (not a product in the app) shows how much of incumbent "AI trip planning" is marketing rather than retained product.
- Klook's eight-language K.AI is the notable counterexample to the "incumbents are English-first" gap — but it is scoped to activities/things-to-do, not whole-trip planning.

### Gaps
- No K.AI launch date confirmed with a primary Klook source (the WiT report does not give a date I could verify; Klook's 9th anniversary implies 2023, which conflicts with treating K.AI as a 2026 feature — treat the date as unresolved).
- No adoption numbers for either K.AI or Agoda's AI Assistant.
- Could not determine whether Agoda's AI Assistant is still beta-limited or has gone GA as of Oct 2026.

## Apple

### Takeaway
Apple ships no AI trip planner. Apple Maps offers multi-stop routing (up to 15 stops, since iOS 16), Guides/Favorites lists, Mac-to-iPhone route sharing, and in iOS 26 added Visited Places, Recent Places, preferred routes and predicted destinations — logistics and memory features, not itinerary planning. Apple is not a competitor on planning today, and is in fact an enabler via on-device Apple Intelligence.

### Cited Findings
- New in iOS 26 Apple Maps: Recent Places, preferred routes, and predicted destinations — [AppleInsider](https://appleinsider.com/inside/apple-maps/tips/inside-apple-maps---how-to-get-the-most-out-of-your-iphones-navigation-app)
- iOS 26 adds Visited Places, which logs places you visit and how many times — framed in coverage as "Spotify Wrapped for your travels" — [TechRadar](https://www.techradar.com/phones/iphone/this-new-ios-26-apple-maps-feature-is-like-spotify-wrapped-for-your-travels-and-i-cant-wait-to-try-it); [AppleInsider](https://appleinsider.com/inside/apple-maps/tips/inside-apple-maps---how-to-get-the-most-out-of-your-iphones-navigation-app)
- Apple Maps supports multi-stop route planning with up to 15 stops, since iOS 16 — [NextBillion.ai](https://nextbillion.ai/blog/apple-maps-trip-planner); [iPhone Life](https://www.iphonelife.com/content/how-to-use-multi-stop-route-planning-apple-maps)
- On Mac, Maps lets you plan a car or transit trip in advance and share it to iPhone, iPad or Apple Watch — [Apple Support](https://support.apple.com/en-ie/guide/maps/mps2fd1a573a/mac)
- Apple Maps Guides and Favorites are the place-organising primitives — [Simology](https://simology.io/blog/build-shareable-maps-lists-googleapple-maps-itinerary-planning)
- Apple Intelligence's on-device foundation models are already being used by third-party travel apps — TripIt's "Image to Plan" runs on them — [SAP Concur blog](https://www.concur.com/blog/article/sap-showcases-new-ai-integrated-travel-and-expense-enhancements-and-global)

### Inferences
- Apple's on-device model availability is a cost and privacy advantage an indie iOS app can exploit (document parsing, local structuring) without paying per-token inference costs.
- Visited Places / Recent Places means Apple has the location-history signal for personalisation but has shown no intent to build planning on it — a vacated position.

### Gaps
- No information found about iOS 27 (not released / no reliable source as of Oct 2026); the question of iOS 27 trip-organising capability cannot be answered.
- No evidence found of any Apple AI itinerary or trip-object feature in Maps.

## The strategic pattern: is planning driving bookings, and does it retain users?

### Takeaway
No. Across the board, incumbents built planning to funnel into bookings, and the funnel is not converting: AI-originated demand is under 1% at Booking Holdings and ~1.6% at Marriott, AI usage collapses from ~30% at the inspiration stage to ~6% at booking/checkout, and only ~2% of leisure travellers will let AI book. Planning is a marketing surface for them, not a retained product — which is exactly the structural opening for an app whose product *is* the plan.

### Cited Findings
- Less than 1% of Booking Holdings room nights originate from AI channels; ~1.6% at Marriott per Bernstein — [Skift, Oct 11 2026](https://skift.com/2026/10/11/travel-ais-prove-it-phase-visibility-and-the-booking-gap/)
- AI usage drops to roughly 6% by the booking and checkout stage (Skift/McKinsey research) — [Skift](https://skift.com/2026/10/11/travel-ais-prove-it-phase-visibility-and-the-booking-gap/)
- 51% of travellers distrust AI's reliability and accuracy (Skyscanner survey) — [Skift](https://skift.com/2026/10/11/travel-ais-prove-it-phase-visibility-and-the-booking-gap/)
- Skift State of Travel 2026: 62% of global travellers are now familiar with AI trip-planning tools; 30% report "extensive" use of AI for trip planning, up 17 percentage points year-on-year (more than doubling in a year); yet only 2% of leisure travellers will let AI book for them — [Skift State of Travel 2026](https://skift.com/insights/state-of-travel/); [Skift newsletter](https://newsletters.skift.com/p/my-four-favorite-charts-from-state-of-travel-2026); [Open Jaw](https://openjaw.com/newsroom/retail/2026/08/13/2026-state-of-travel-lack-of-ai-adoption-becoming-revenue-risk/)
- For established travel brands, internal efficiency is the leading ROI from AI, while new booking demand from AI agents remains low; measurable ROI shows in operations, not trip-planning adoption — [Open Jaw](https://openjaw.com/newsroom/retail/2026/08/13/2026-state-of-travel-lack-of-ai-adoption-becoming-revenue-risk/); [Skift](https://skift.com/2026/10/11/travel-ais-prove-it-phase-visibility-and-the-booking-gap/)
- AI-enabled companies took 45% of travel startup funding by mid-2025, up from 10% in 2023 — [Open Jaw](https://openjaw.com/newsroom/retail/2026/08/13/2026-state-of-travel-lack-of-ai-adoption-becoming-revenue-risk/)
- Booking Holdings reinvesting ~$170M of efficiency savings into AI and Connected Trip, plus a planned $100M into Vayo — [PYMNTS](https://www.pymnts.com/earnings/2026/ai-can-plan-the-trip-but-booking-holdings-wants-the-transaction/); [MarketScreener](https://www.marketscreener.com/news/booking-holdings-plans-100-million-investment-in-ai-travel-agent-company-ce785dd2de8cf521)
- Over 60% of Gen Z and Millennial travellers already use AI tools for travel inspiration and itinerary planning (Simon-Kucher 2026 Travel Trends Study), with trust and accuracy gaps remaining — [Travel and Tour World](https://www.travelandtourworld.com/news/article/expedia-and-booking-holdings-elevate-travel-experience-with-ai-tools/) (secondary citation of the study)

### Inferences
- The incumbents' planning tools are commercially unjustified on their own numbers. That means (a) they are under-invested relative to the marketing noise, and (b) their roadmaps bend toward booking conversion, not toward planning quality — a persistent, structural quality gap rather than a temporary one.
- The 30%-plan / 6%-book / 2%-trust-to-book spread says the value is concentrated in the *planning* phase and in *handing a trusted plan to a human to execute*. An indie app that owns the plan and does not need the booking margin is aligned with where users actually are.
- Because planning does not pay for incumbents, their planning features are unlikely to get offline support, deep editing, or collaboration — features that cost engineering and generate no bookings.

### Gaps
- No incumbent has published retention data for its planning features, so "does planning retain users for them" can only be inferred from the booking-conversion numbers and from Expedia's deprioritisation of Romie.

## Where the incumbents visibly fall short

### Takeaway
The consistent, documented gaps are: discovery of independent and non-chain venues; factual accuracy on hours and closures; the lack of a durable editable trip artifact; English-first/market-limited rollouts; absent collaboration and offline; and planning scoped to what the platform can sell.

### Cited Findings
**Independent and non-chain places**
- Stiplo analysis of 27,360 AI travel answers across 659 Barcelona properties: independent hotels are **8x more likely to be unknown** to AI systems than chains; once known, recommendation rates are roughly equal — "the gap is discovery, not favoritism." Google review volume was the strongest factor associated with discoverability. Founder Carlo Del Mistro: "Google review volume was the strongest factor associated with discoverability." — [Skift](https://skift.com/2026/10/11/travel-ais-prove-it-phase-visibility-and-the-booking-gap/)
- Only 6% of hotels appear in AI-generated search results, leaving most brands invisible at the first traveller query — [Open Jaw](https://openjaw.com/newsroom/retail/2026/08/13/2026-state-of-travel-lack-of-ai-adoption-becoming-revenue-risk/)
- ~75% of European hotels are independently owned, making the visibility gap especially acute there — [Skift](https://skift.com/2026/10/11/travel-ais-prove-it-phase-visibility-and-the-booking-gap/)

**Factual accuracy (low-confidence sources — flagged)**
- Claimed study by SEO Travel: 90% of AI itineraries contained at least one error, nearly 1 in 4 recommended permanently closed restaurants or attractions, and over half suggested visiting places outside operating hours — [Food Drink Destinations](https://fooddrinkdestinations.com/ai-travel-planning/). **Low confidence: no primary methodology located; secondary blog citation only.**
- Claimed study across 356 AI-generated itineraries / 2,735 planned days: 43% of days carried at least one verifiable fault — venue shut at the scheduled hour, visit running past closing, day backtracking across the map, or the same place booked twice — [Monkey Eating Mango](https://monkeyeatingmango.com/research/ai-itinerary-errors-data-study/). **Low confidence: self-published blog research, methodology unverified.**
- Claimed 2025 analysis: general chatbots hallucinated venues ~15–20% of the time, while dedicated AI trip planners that cross-reference Google Places data brought that to ~3–5% — [Monkey Travel](https://monkeytravel.app/blog/can-you-trust-ai-travel-itinerary). **Low confidence: vendor blog, no primary source.**
- Test of five AI models on a Tokyo itinerary: Grok scored 63% accuracy with five hallucinated or critically outdated recommendations — [Talkory](https://www.talkory.ai/blog/best-ai-for-travel-planning-5-models-tested). **Low confidence: vendor blog.**
- Corroborating but non-quantified: typical failures are wrong restaurant hours, closed places, and generic recommendations; the biggest mistake is treating AI output as a finished plan rather than a first draft, since tools hallucinate hotel closures, fabricate visa requirements and suggest long-closed restaurants — [Travel Anywhere](https://www.travelanywhere.blog/blog/worst-ai-travel-planning-mistakes-prompts); [Elliott Report](https://www.elliott.org/on-travel/can-i-trust-ai-to-give-me-good-travel-advice/)
- Expedia names a rigorous "evals" system to guard against hallucinations as a differentiator — an incumbent implicitly confirming hallucination is the core risk — [Skift on X](https://x.com/skift/status/2083260024252416436)
- Google's own guidance is that its AI tools should not be the sole source for live fares, availability, visa rules, opening hours or cancellation terms — [AI Learning Guides](https://ailearningguides.com/gemini-google-maps-vacation-itinerary-planning/) (secondary)

**Editing and the missing trip artifact**
- Expedia concluded the all-in-one conversational concierge "wasn't practical" and deprioritised Romie — [Skift](https://skift.com/2026/07/31/expedia-acquired-ai-trip-planner-layla-exclusive/)
- Chesky's 2027 Airbnb agent is explicitly "much richer than a chatbot," a visual interface rather than a chat window — [The AI Insider](https://theaiinsider.tech/2026/10/01/airbnb-introduces-ai-search-as-brian-chesky-bets-on-cautious-conversion-focused-rollout/)
- Industry framing credits AI with replacing rigid filters with natural-language conversation — i.e. the innovation is at the *input*, not at the plan object — [AI Magazine](https://aimagazine.com/news/tripadvisor-airbnb-can-ai-agents-beat-travel-agents)

**Language and market limitations**
- Booking.com's Smart Filter and Property Q&A launched mobile-only in five English-speaking markets; AI Trip Planner reached UK/AU/NZ/SG with European languages only "launching soon" as of Oct 2024 — [Booking Holdings](https://www.bookingholdings.com/press-releases/booking-com-enhances-travel-planning-with-new-ai-powered-features-for-easier-smarter-decisions/)
- Google Maps' Gemini Screenshots list rolled out to English-language iOS users in the US first — [9to5Google](https://9to5google.com/2025/03/27/google-maps-gemini-screenshots/)
- Google's AI Mode Canvas travel planning launched desktop-only, US-only, behind a Google Labs opt-in — [Search Engine Journal](https://www.searchenginejournal.com/google-extends-ai-travel-planning-and-agentic-booking-in-search/561251/)
- Counterexample: Google Flight Deals reached 200+ countries and 60+ languages; Klook's K.AI covers eight languages — [TechCrunch](https://techcrunch.com/2025/11/17/google-rolls-out-its-ai-flight-deals-tool-globally-adds-new-travel-features-in-search/); [Web in Travel](https://www.webintravel.com/at-nine-klook-rolls-out-k-ai-trip-planner-and-klook-kreators-to-convert/)

**Collaboration**
- Romie's one documented group feature was helping groups agree on villas in messaging threads — and Romie was deprioritised — [Travel and Tour World](https://www.travelandtourworld.com/news/article/expedia-and-booking-holdings-elevate-travel-experience-with-ai-tools/); [Skift](https://skift.com/2026/07/31/expedia-acquired-ai-trip-planner-layla-exclusive/)
- Google Maps' Screenshots feature saves to a "shareable list" — sharing, not co-editing — [Android Police](https://www.androidpolice.com/google-maps-now-has-pixel-screenshots-built-in/)
- Airbnb's fall 2026 release paired AI search with "more social features," and coverage framed the AI search tool around group travel — [TechCrunch](https://techcrunch.com/2026/09/30/airbnb-adds-ai-search-more-social-features/); [NewsBytes](https://www.newsbytesapp.com/news/science/airbnb-unveils-fall-2026-ai-search-tool-for-group-travel/tldr)

**Scope bounded by inventory**
- "AI can plan the trip but Booking Holdings wants the transaction" — [PYMNTS](https://www.pymnts.com/earnings/2026/ai-can-plan-the-trip-but-booking-holdings-wants-the-transaction/)
- Expedia's stated differentiation rests on "global bookable inventory" and "marketplace scale" — [Skift on X](https://x.com/skift/status/2083260024252416436)
- Klook's K.AI is integrated into Things To Do activity pages — i.e. scoped to sellable activities — [Web in Travel](https://www.webintravel.com/at-nine-klook-rolls-out-k-ai-trip-planner-and-klook-kreators-to-convert/)

### Inferences
- The strongest, best-sourced gap is **independent-venue discovery**. The Stiplo finding (8x invisibility for independents, driven by Google review volume) is a quantified, mechanistic explanation of why giant-built planners produce chain-heavy, tourist-trail itineraries. An indie app that solves independent-place coverage is attacking a gap rooted in the incumbents' data pipeline, not in their effort level.
- The second strongest is the **missing editable trip artifact**. Two incumbents (Expedia, Airbnb) have publicly concluded chat is the wrong container, and neither has shipped the replacement. The incumbent surfaces are a chat log (Gemini), a desktop side panel (Canvas), a flat place list (Maps), or a booking funnel (Booking/Agoda). None is a day-structured, reorderable, annotatable, offline-capable, multi-person trip document.
- **Offline** is a credible gap by absence: no source in this research describes offline capability in any incumbent AI planning feature, and Google's only documented offline commitment dates to the 2019 Trips migration (offline maps in Google Maps, not offline itineraries). Treat as an inference, not a cited finding.
- **Accuracy on hours and closures** is probably the highest-salience user-facing gap (51% of travellers distrust AI accuracy, per Skyscanner/Skift), but the quantified error-rate studies available are all low-quality blog sources. The defensible version of this claim rests on the Skyscanner trust figure and Expedia's own "evals" positioning, not on the 90%/43% error statistics.
- **Non-English content** is a partially open gap: incumbents' *interfaces* are English-first in rollout, but Google Flight Deals (60+ languages) and Klook (8 languages) show the giants can and do localise when it serves bookings. The sharper, more durable gap is non-English *source content* — reviews, local blogs, local-language place information — which is downstream of the same review-volume discovery bias Stiplo identified.

### Gaps
- Could not find any credible, methodologically transparent study quantifying error rates in AI-generated itineraries. All located studies are self-published blog or vendor research. The report writer should not cite the 90%, 43%, or 15–20% figures as established fact.
- No head-to-head hands-on comparison from a reputable travel-tech outlet (Skift, PhocusWire, Travel Weekly, Wirecutter, Condé Nast Traveler) testing Gemini vs Booking vs Tripadvisor vs Expedia planners against each other. This would be the single most valuable missing source.
- No source found documenting offline behaviour of any incumbent AI planning feature, in either direction.
- No source found on collaborative/multi-user editing capability in Booking's AI Trip Planner, Tripadvisor Trips, or Gemini itineraries.
- Accessibility of Google's itineraries as persistent, re-editable objects is unconfirmed.
