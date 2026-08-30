# User Sentiment, Reviews and Community Discussion — Paths & doro (BLANK CRAFT PTE. LTD.)

*Research conducted 17 October 2026. Data pulled live from Apple's iTunes Lookup API, per-storefront App Store pages, and Google Play's review endpoint on that date.*

**Scope warning up front:** both apps are tiny. Across the five storefronts checked, Paths has ~21 iOS ratings total and doro has ~10. There is effectively **no** third-party community discussion of either app — no Reddit threads, no Threads/X mentions, no Xiaohongshu posts, and no independent press beyond one affiliate-flavoured blog post. Reddit (r/Dorotravel) and the doro Discord were **not readable** from this environment (see Gaps). Most of the usable signal is store reviews plus one Chinese-market article about the same product category.

---

## Q1. What do App Store and Google Play reviews say for Paths and doro? (text, stars, dates, countries)

### Takeaway
Paths' US App Store rating (4.7, n=6) badly misrepresents sentiment: in Southeast Asia and Greater China the same app sits at **2.7 in Singapore (n=3), 3.0 in Hong Kong (n=2), 3.7 in Malaysia (n=7) and 3.7 in Taiwan (n=3)**, and the substantive negative reviews cluster on three themes — itinerary quality losing to ChatGPT, geographic/map errors, and account/login/sync friction (especially the absence of WeChat login and cross-device sync). doro is uniformly 5-star but on only 9 US ratings of near-content-free praise, so it carries almost no information.

### Cited Findings

**Paths — per-storefront iOS ratings (iTunes Lookup API, 17 Oct 2026; app id 6786985803, v1.7.3, first released 20 Jul 2026, last updated 16 Oct 2026; languages EN, zh-Hans, zh-Hant):**
- US: **4.67 / 5, n=6** — [iTunes Lookup](https://itunes.apple.com/lookup?id=6786985803&country=us)
- Singapore: **2.67 / 5, n=3** — [iTunes Lookup](https://itunes.apple.com/lookup?id=6786985803&country=sg)
- Malaysia: **3.71 / 5, n=7** — [iTunes Lookup](https://itunes.apple.com/lookup?id=6786985803&country=my)
- Hong Kong (listed as "Paths: AI 行程規劃助手"): **3.0 / 5, n=2** — [iTunes Lookup](https://itunes.apple.com/lookup?id=6786985803&country=hk)
- Taiwan (listed as "Paths: AI 行程規劃助手"): **3.67 / 5, n=3** — [iTunes Lookup](https://itunes.apple.com/lookup?id=6786985803&country=tw)
- All ratings are against the current version (`userRatingCountForCurrentVersion` equals `userRatingCount` in every storefront), i.e. the rating base is young and resets with each release.

**Paths — iOS review text, verbatim:**
- **US, "Makes planning trips so much easier", wanderingem_41, 5★, 31 Aug 2026:** "Love how easy this makes trip planning. I just put in where I'm going and how long I'll be there, and the AI basically plans the trip for me. It even organizes the stops so I'm not going back and forth across the city all day. Super easy to tweak the itinerary and share it with friends too." — [App Store US](https://apps.apple.com/us/app/id6786985803?see-all=reviews)
- **US, "Way more helpful than I expected", Okiedokie_9, 5★, 31 Aug 2026:** "Paths surprised me in so many ways. It helped with things like budget, weather, visa requirements, and other details I wouldn't have thought of. It felt more like having a personal travel assistant than just an itinerary generator. I also love the map view. Nice touch!" — [App Store US](https://apps.apple.com/us/app/id6786985803?see-all=reviews)
- **US, "App down了！！", Jane2333, ~14 Oct 2026 ("3d ago"):** "正着急用呢！！结果app down了！！啥时候能好啊！！求救！！" ("I urgently needed to use it!! And then the app went down!! When will it be fixed?! Help!!") — [App Store US](https://apps.apple.com/us/app/id6786985803?see-all=reviews)
- **Singapore, "Needs improvement", ~D10, 20 Sep 2026:** "Idea is good but still a lot to be improved. Compared to ChatGPT, the output is not as detailed and good, when I prompted for more activities and less history/museums on the itinerary, it doesn't reflect it. It doesn't take into consideration my preferences for example what food I like to have, age appropriate activities considering my 4 year old etc. The segregation into the daily plan as a new tab was a good idea." — [App Store SG](https://apps.apple.com/sg/app/id6786985803)
- **Malaysia, "Awesome FREE Planner", BoycottNetgamble, 5★, 12 Aug 2026:** "I just saw this app on Threads and I thought 'it looks nice and convenient, but I bet there's a subscription'. To my surprise, THERE ISN'T ONE AT ALL. And it's so easy to use, especially how you can instantly see how long and how far it takes to get from one place or another! One small suggestion, there is a checklist for the trip, but it would be so much better if you could set a reminder for it too, like when to book stuff." — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- **Malaysia, "Integrated with Train", Zerinism, 29 Sep 2026:** "If it built in with map/location trace by train would be A+. Instead of showing walking or by cars on the map, it would be good improvement to have train options." — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- **Malaysia, "No option to hide my email", ss_2580, 1★, 2 Sep 2026:** "The reason I give one star because previous it was recommend by influencer from Chinese platform but due to Chinese version I didn't install until I see English version however unlike other apps no option for me to hide my email. Hence I rather use other AI platform." Developer replied 7 Sep 2026: "Paths uses Sign in with Apple without requesting the email address linked to your Apple ID. You can sign in without sharing your email address with us. We do not send any advertising or promotional emails." — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- **Taiwan, "超好用的AI工具！", 繞地球走一圈, 7 Sep 2026:** "能自動生成旅行規劃，還能用AI調整行程、回答問題，超級推薦。" ("Can auto-generate travel plans, and you can use AI to adjust the itinerary and answer questions. Highly recommended.") — [App Store TW](https://apps.apple.com/tw/app/id6786985803)
- **Hong Kong, "不可以微信登录吗" ("Can't I log in with WeChat?"), Olleo-biu-biu, 21 Sep 2026:** user had switched Apple accounts and asks how to recover their previous data, and asks whether WeChat login is supported. — [App Store HK](https://apps.apple.com/hk/app/id6786985803)
- **Hong Kong, "不能與iphone共用帳號" ("Can't share an account with iPhone"), willall5, 27 Aug 2026:** the iPad version lacks WeChat login; after choosing Apple Account login instead, content does not sync across devices. The user notes planning needs a large screen while checking the itinerary while travelling happens on a phone. Developer replied 31 Aug 2026 confirming **neither** the iPhone nor iPad version supports WeChat login, and asked the user to email device details and login timing to team@gopaths.ai. — [App Store HK](https://apps.apple.com/hk/app/id6786985803)

**Paths — Google Play (`ai.gopaths.pitravel`), 17 Oct 2026: 4.3 stars, 10K+ downloads, Travel & Local.** All 7 visible reviews, verbatim — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel):
- **CalvinYP, 2★, 4 Oct 2026, v1.7.0:** "it needs to be more aware of the map and geography. basked for places to stay near Narita airport, it told me Fuji." Developer reply: "We're sorry about your experience. This isn't what we want for our users. We haven't been able to reproduce the issue yet… Could you email team@gopaths.ai with more details?"
- **Pumbinking, 5★, 29 Sep 2026, v1.7.0:** "Excellent"
- **Alvin Zheng, 5★, 16 Sep 2026, v1.5.1:** "amazing app, so helpful"
- **Mario Caeser, 5★, 14 Sep 2026, v1.5.1:** "socool"
- **Mhadz Aradani, 5★, 3 Sep 2026, v1.4.1:** "nice"
- **apollyon abbadon, 5★, 2 Sep 2026:** "amazing 😍🤩"
- **Shiba Jimmy, 5★, 27 Aug 2026, v1.4.0:** "awesome"
- The identical review set is returned for the US, SG and MY Play storefronts, i.e. Play reviews are not storefront-segmented here and the 7 reviews above are the entire public Play corpus.

**doro — iOS (app id 6755711343; first released 4 Dec 2025; current v1.1, 7 Jul 2026; English only):**
- US: **5.0 / 5, n=9**; Taiwan: **5.0 / 5, n=1**; **Singapore, Malaysia and Hong Kong: n=0 ratings** — [iTunes Lookup](https://itunes.apple.com/lookup?id=6755711343&country=us)
- Listing title differs by storefront: "doro: auto-pin places & events" (US/HK/TW) vs "Doro - AI Trip Planner" (SG/MY) — [App Store US](https://apps.apple.com/us/app/doro-ai-trip-planner/id6755711343)
- Pricing: free with doro Pro Monthly $14.99 / doro Pro Yearly $39.99 — [App Store US](https://apps.apple.com/us/app/doro-ai-trip-planner/id6755711343)
- **"super cute and helpful!", pegs3233, 5★, 18 Apr:** "Will be using this for my future trips :)"
- **"Love this app", Lucy Lu06, 5★, 27 May:** "I really like this idea!! It's helped me plan my trips so well"
- **"wow", lidonpo, 5★, 26 Jan:** "Good idea to make it easy to plan a trip"
- **"so underrated", mishfan, 5★, 20 Feb:** "this app was super helpful for planning my family trip and way more accurate than chatgpt for building itineraries!!!"
- doro v1.1 release notes frame the product around "screenshot fatigue": "Share it to doro. We'll parse the link, put it on your map, and summarize the only things you care about." v0.5.3 (16 Jan) added journey sharing, AI voice input and a liquid-glass redesign. — [App Store US](https://apps.apple.com/us/app/doro-ai-trip-planner/id6755711343)
- **doro has no Google Play listing.** Candidate packages (`ai.gopaths.doro`, `ai.godoro.app`, `com.blankcraft.doro`) all return HTTP 404; the only BLANK CRAFT app on Play is `ai.gopaths.pitravel` (Paths). An editorial review of doro from Feb 2026 also states iOS exclusivity was then "the biggest limitation" — [ReviewNexa](https://reviewnexa.com/doro-app-review/)

### Inferences
- The US 4.7 for Paths is almost certainly seeded by early/friendly reviews: the two 5★ US reviews are both dated 31 Aug 2026, read like onboarding-prompt reviews (feature checklists, "Nice touch!"), and the only organic-looking US review is an outage complaint. The SG/HK/TW/MY numbers (2.7–3.7) are the more honest read.
- Paths' entire rating base resets to the current version each release, so the headline score is extremely volatile — one 1★ moves SG from 3.5 to 2.7. This is why the US and SEA scores diverge so far on tiny n.
- doro's 5.0/9 is not a quality signal. Four of the nine ratings have text, all short, and two are essentially "good idea" rather than "it worked". The most specific one (mishfan) praises *accuracy relative to ChatGPT*, which is the same axis on which Paths loses in the SG review — the two apps are being judged against ChatGPT, not against each other.
- doro appears to be the earlier/parked product (last iOS update 7 Jul 2026, no Play build, English-only) and Paths the active one (v1.7.3 shipped 16 Oct 2026, three languages, Play build at 10K+ downloads). Effort spent waiting for doro sentiment is likely wasted.

### Gaps
- Apple's `rss/customerreviews` JSON feed returns an **empty entry list** for both app ids in all eight storefronts tested (us, sg, my, hk, tw, cn, gb, au) despite HTTP 200 — so the complete review corpus could not be enumerated programmatically. The reviews above are only those rendered on the public web storefront pages, which show a subset. Several storefronts show fewer review bodies than they have ratings (e.g. MY: 7 ratings, 3 bodies; SG: 3 ratings, 1 body), so there are unread negative reviews.
- Star ratings for individual reviews on the HK, TW and SG pages are not exposed in the page text, only the per-store average. I have not attributed stars where they were not visible.
- No mainland-China (cn) storefront listing was confirmed for either app.
- Exact Play rating *count* for Paths could not be extracted (the page exposes "10K+ Downloads" and 4.3 stars but not the ratings count).

---

## Q2. What is discussed in r/Dorotravel, the doro Discord, and other publisher-run communities?

### Takeaway
**I could not read either community, and I found no evidence that either has meaningful activity.** r/Dorotravel exists and is linked from doro's own marketing, but Reddit was unreachable from this environment and the subreddit has left no searchable footprint whatsoever — zero indexed posts, zero inbound links, no mention in any travel-subreddit roundup. The honest finding is: these communities are referenced by the publisher but produce no discoverable user discussion.

### Cited Findings
- r/Dorotravel exists and is the publisher's official community, pitched as a place to "share your adventures and discover your next destination," alongside a Discord — both linked from doro's marketing surface — [search summary of doro.app / App Store listing](https://apps.apple.com/us/app/doro-ai-trip-planner/id6755711343)
- A Discord invite `https://discord.gg/r92MMN5d` surfaced in a web-search summary as doro's official community server. **Unverified** — the Discord invite API returned an empty response from this environment, so I could not confirm the invite is live, nor read member counts or any channel content.
- `doro.app` renders no community/social links, no testimonials and no named source platforms in its served HTML — only the generic claim "Drop in any link, text or screenshot you love." — [doro.app](https://doro.app/)
- `gopaths.ai` / `www.gopaths.ai` serves a 13KB JavaScript shell with **no** Discord, Reddit, Threads, Instagram or Xiaohongshu links in the HTML. — fetched 17 Oct 2026
- Reddit was inaccessible: `reddit.com` and `old.reddit.com` are blocked for fetching from this environment, `reddit.com/r/Dorotravel/about.json` returns HTTP 403, and the public mirrors tried (redlib.catsarch.com → 429, safereddit.com → Anubis anti-scraping challenge, libreddit.privacydev.net → 502) all failed.
- Web search for `site:reddit.com r/Dorotravel doro app` returned **zero results referencing the subreddit** — only unrelated pages (Doro the Swedish phone company, r/Dororo the anime sub, Dopplr, Globetrooper).
- r/Dorotravel does not appear in any of the three travel-subreddit roundups returned by search — [reevesroam](https://reevesroam.com/best-travel-subreddits/), [travelingmitch](https://www.travelingmitch.com/mostrecent/travel-subreddits-tour-the-world), [Skyscanner](https://www.skyscanner.com/tips-and-inspiration/reddit-travel)
- One secondary source claims to cite "real Reddit users from December 2025" discussing doro — one with "345 notes of things to do" across platforms, another saying the app "saved me probably 4+ hours of planning" for a Japan trip. **Treat as low confidence:** the piece is an affiliate-flavoured SEO review (multiple "Try Doro Free" / "Download Now" CTAs, comparison tables favouring the subject) and does not link the Reddit threads. — [ReviewNexa, updated 27 Feb 2026](https://reviewnexa.com/doro-app-review/)

### Inferences
- A subreddit with zero search-indexed posts after ~10 months and no inbound links from any community roundup is almost certainly near-dead or very low volume. "The publisher runs r/Dorotravel and a Discord; these are likely the richest sources" does not hold on the available evidence — the richest source is actually the non-US App Store review pages.
- The absence of community footprint plus 10K+ Play downloads suggests acquisition is happening through influencer/social seeding, not community — consistent with two reviewers independently saying they found the app via Threads and via a "Chinese platform" influencer (see Q6).

### Gaps
- Subscriber count, post volume, moderator identity, top-requested features and bug reports in r/Dorotravel: **unknown and unobtainable from this environment.** Someone with direct Reddit/Discord access should check manually; this is the single largest hole in this research.
- Whether the Discord is publicly joinable, and what its channels contain.

---

## Q3. How well does link/screenshot extraction work in users' hands, and which sources does it handle?

### Takeaway
There is **no verbatim user testimony on extraction accuracy for Paths or doro** — not one store review mentions pasting a link or a screenshot. The only quantified accuracy claim comes from a single affiliate-flavoured blog, and the only well-evidenced category data point comes from the Chinese app whose name is embedded in Paths' Android package (`pitravel`), where >80% of users cite extraction as their reason for choosing the product.

### Cited Findings
- Paths' own positioning: "drop links, screenshots, or text into Paths, and its AI extracts the places and builds a complete itinerary in just a few taps," plus route optimisation, interactive maps, live weather and transit info, and real-time collaboration. — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- doro's positioning: "automatically pulls all mentioned spots from travel posts," extracting "places, events, local tips (like 'avoid the long lines' or 'best time to visit')" from "Instagram posts, TikTok videos, blog links, or screenshots," producing a map with travel times between locations. — [App Store US](https://apps.apple.com/us/app/doro-ai-trip-planner/id6755711343)
- **Single quantified accuracy claim, low confidence:** one reviewer reports 87% overall extraction accuracy across three trips, and that "Screenshot accuracy varies (75–85% vs. 95–100% for direct links)." Other listed limitations: no booking integrations, English-only, limited export options, limited collaboration features. This is one person's self-reported testing in an affiliate-flavoured post with no methodology published. — [ReviewNexa, updated 27 Feb 2026](https://reviewnexa.com/doro-app-review/)
- **Category evidence (Chinese market):** 圆周旅迹 — whose domain is `pitravel.cn`, matching Paths' Android package `ai.gopaths.pitravel` — built its growth on one-click extraction of Xiaohongshu travel notes, a feature users jokingly call 抄作业 ("copying someone's homework"). It claims ~10 million registered users concentrated in tier-1 and new-tier-1 cities, reached **#5 in Apple's China travel category** over the October holiday, and **over 80% of its users cite the extraction feature as their primary reason for choosing the app.** Named weakness: it lacks "hotel reservations, flight purchases, and other one-stop services," forcing users to switch apps to book. — [环球旅讯 / TravelDaily, 黎展铺, 23 Dec 2025](https://m.traveldaily.cn/article/188945)
- No user review of Paths or doro, in any storefront, mentions TikTok, Instagram, Xiaohongshu/RED, YouTube or a blog link as an input source. The closest to a sourcing complaint is a *geographic reasoning* failure: Paths recommended Mt. Fuji when asked for accommodation near Narita Airport (see Q4).

### Inferences
- Extraction is the marketed wedge for both apps but is invisible in the review corpus. Users who leave reviews are describing the *generative* path ("I just put in where I'm going and how long I'll be there") rather than the extraction path. Either extraction is under-discovered, or reviewers do not find it remarkable enough to mention.
- If Paths is the international build of 圆周旅迹 (strongly suggested by the `pitravel` package id and by the MY reviewer who says the app was "recommend[ed] by influencer from Chinese platform" and that they waited for an English version), then Xiaohongshu/RED extraction is a core, battle-tested capability — but **this identity is an inference, not a confirmed fact**; the Play publisher is BLANK CRAFT PTE. LTD. (Singapore).
- The booking gap named for 圆周旅迹 is the same gap the ReviewNexa piece names for doro ("no booking integrations"), and it is the only limitation independently identified by two sources. It is likely the strongest category-level product gap.

### Gaps
- No verbatim user description of a successful or failed extraction from a specific platform (TikTok vs Reel vs Xiaohongshu vs blog) for either app. Nothing on paywalled/login-gated sources, video-only posts, non-English OCR, or carousel screenshots.
- No independent accuracy benchmark for either app.
- Whether Paths and 圆周旅迹 are the same product/company is unconfirmed.

---

## Q4. Complaints about accuracy, hallucinated places, wrong hours, bad routing, made-up prices?

### Takeaway
For Paths specifically, there are exactly two substantive accuracy complaints, and they are the two most damaging kinds: **a geographic/map reasoning failure** (Narita → Fuji) and **a failure to honour stated preferences** (user asked for fewer museums and got museums anyway). Category-wide, the documented failure modes are hallucinated venues, venues closed on the suggested day, geographically incoherent day-splitting, and missing local/contextual knowledge. I found **no** complaint — for either app or the category — specifically about made-up prices.

### Cited Findings
- **Geography / routing failure, Paths, 2★, 4 Oct 2026:** "it needs to be more aware of the map and geography. basked for places to stay near Narita airport, it told me Fuji." The developer replied that they could not reproduce it. — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- **Preference-adherence failure, Paths, Singapore, 20 Sep 2026:** "when I prompted for more activities and less history/museums on the itinerary, it doesn't reflect it. It doesn't take into consideration my preferences for example what food I like to have, age appropriate activities considering my 4 year old." Same review benchmarks Paths against ChatGPT: "Compared to ChatGPT, the output is not as detailed and good." — [App Store SG](https://apps.apple.com/sg/app/id6786985803)
- **Transit-mode gap, Paths, Malaysia, 29 Sep 2026:** "Instead of showing walking or by cars on the map, it would be good improvement to have train options." — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- **Reliability/outage, Paths, US, ~14 Oct 2026:** "正着急用呢！！结果app down了！！" ("I urgently needed to use it!! And then the app went down!!") — [App Store US](https://apps.apple.com/us/app/id6786985803?see-all=reviews)
- **Category — hallucinated venues:** GuideGeek, asked about "Crete Freeze," "crafted a detailed story about a non-existent ice cream parlor in Pittsburgh." AI travel tools have suggested "routes that don't exist or accommodations that are the stuff of fiction." — [Fox News, Kurt Knutsson, 16 May 2024](https://www.foxnews.com/tech/even-with-glitches-planning-your-next-trip-with-ai-is-making-me-rethink-travel)
- **Category — missing local knowledge:** on a Hawaiian hike the AI named the trail but "didn't know to tell me what happens if a common rain shower interrupts the hike, turning the elevated trail into a treacherous trench of mud." — [Fox News, 16 May 2024](https://www.foxnews.com/tech/even-with-glitches-planning-your-next-trip-with-ai-is-making-me-rethink-travel)
- **Category — hallucination rate is tractable:** GuideGeek reports cutting hallucinations from **14% to 2%** via better training plus real-time data from Skyscanner and Expedia. — [Fox News, 16 May 2024](https://www.foxnews.com/tech/even-with-glitches-planning-your-next-trip-with-ai-is-making-me-rethink-travel)
- **Category — wrong location, closures, incoherent routing:** testers found AI tools sent users "to activities in the wrong locations instead of their intended destination," recommended non-historic hotels as historic, suggested "shows that didn't actually exist," sent users to "venues that were closed on the specified days," and spread nearby attractions "across different days despite them being only a 15-minute walk apart." — [Afar, "We Tested AI Travel Planning Apps"](https://www.afar.com/magazine/we-tested-ai-travel-planning-apps-here-are-the-3-that-actually-worked) *(obtained via search-result summary; direct fetch of the article returned empty content, so treat the wording as close paraphrase rather than exact quotation, and re-verify before quoting in a published report)*

### Inferences
- The two Paths accuracy complaints map onto the two hardest parts of the problem: spatial grounding (Narita/Fuji is a ~190 km error) and instruction-following/personalisation. Neither is an extraction bug; both are reasoning/grounding bugs. That suggests Paths' weak point in users' hands is the *generative planner*, not the parser.
- The SG reviewer's framing — "Compared to ChatGPT, the output is not as detailed and good" — is the key competitive threat in this corpus. The one specific doro compliment runs the same way ("way more accurate than chatgpt for building itineraries"). Users in this category benchmark against a free general chatbot, so the app's defensible value must be the things ChatGPT cannot do (map, routing, live transit, collaboration), not the prose quality of the plan.
- The developer's "we haven't been able to reproduce the issue" reply to a geographic hallucination is a weak public response pattern: non-determinism makes reproduction hard, so the complaint stands unrebutted on a 2★ review on a small base.

### Gaps
- **No complaints found about wrong opening hours or made-up prices** for Paths or doro. Given that neither app has enough reviews to surface such issues, this is absence of evidence rather than evidence of absence.
- The Afar article could not be fetched directly; its findings are reported here from a search-result summary and should be re-verified.
- The Fox News category piece is from **May 2024** — the most recent, well-sourced category critique I could retrieve. I found no 2026-dated independent audit of AI itinerary accuracy.

---

## Q5. What do users say about the collaborative editing feature?

### Takeaway
Almost nothing, and what little exists is lukewarm. One Paths user praises sharing in passing; one secondary source lists "limited collaboration features" as a doro weakness; and the loudest adjacent complaints are not about *collaborating with other people* but about **the app failing to sync with the same user's own second device**.

### Cited Findings
- Paths markets "create a trip and invite friends to collaborate in real time." — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- The only positive user mention, and it is a clause not a review: "Super easy to tweak the itinerary and share it with friends too." (wanderingem_41, 5★, US, 31 Aug 2026) — [App Store US](https://apps.apple.com/us/app/id6786985803?see-all=reviews)
- doro added "journey sharing" in v0.5.3 (16 Jan) — [App Store US](https://apps.apple.com/us/app/doro-ai-trip-planner/id6755711343)
- "Limited collaboration features" is listed as a doro limitation — [ReviewNexa, updated 27 Feb 2026](https://reviewnexa.com/doro-app-review/) *(affiliate-flavoured; low confidence)*
- **Cross-device sync failure, Paths, HK, willall5, 27 Aug 2026:** the iPad version lacks WeChat login; after signing in with an Apple Account instead, content does not sync across devices — and the user explains why that matters: planning needs a large screen, but checking the itinerary while travelling happens on a phone. Developer promised to investigate and "improve cross-device experience." — [App Store HK](https://apps.apple.com/hk/app/id6786985803)
- **Account/data portability failure, Paths, HK, Olleo-biu-biu, 21 Sep 2026:** after switching Apple accounts the user asks how to recover their previous trip data, and asks for WeChat login. — [App Store HK](https://apps.apple.com/hk/app/id6786985803)

### Inferences
- If single-user, two-device sync is broken, multi-user real-time collaboration is unlikely to be reliable. The HK reviews are the best available proxy evidence on the state of the collaboration/sync layer, and they are negative.
- Collaboration is marketed prominently but is not what users praise or request. In this corpus, demand concentrates instead on transit modes, reminders, login options and sync.

### Gaps
- No user account of a real multi-person collaborative trip: no reports on edit conflicts, permissions, notifications, invite friction, or whether invitees must install the app. Nothing on whether collaboration works across the iOS/Android boundary.

---

## Q6. Mentions on Reddit (r/travel, r/solotravel, r/digitalnomad, r/Singapore, r/malaysia), Xiaohongshu/RED, Threads and X

### Takeaway
**Zero discoverable mentions of Paths or doro in any of these communities.** The only evidence that social discussion exists at all is indirect: two Paths reviewers say they discovered the app through Threads and through a Chinese-platform influencer respectively — so seeding is happening, but it leaves no indexed, readable trace.

### Cited Findings
- **Threads is a real acquisition channel, by a user's own account (MY, 12 Aug 2026):** "I just saw this app on Threads and I thought 'it looks nice and convenient, but I bet there's a subscription'." — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- **Chinese-platform influencer seeding, by a user's own account (MY, 2 Sep 2026):** "previous it was recommend by influencer from Chinese platform but due to Chinese version I didn't install until I see English version" — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- Searches for Paths/doro discussion on Reddit, Threads and X returned **no** matching threads or posts; results were store listings for unrelated competitors (Pathwise, PathPlan, Pathsight, Pathly, JRNEY) and marketing pages.
- A Chinese-language search for `小红书 Paths AI 行程规划 App 推荐 doro` surfaced **no** Xiaohongshu posts about Paths or doro. It surfaced the competitive set instead: 圆周旅迹 ([pitravel.cn](https://www.pitravel.cn/)), Travelmapify ([80aj.com, 6 Apr 2026](https://www.80aj.com/2026/04/06/ai-travel-planner-tool/)), and 小红旅计 ([yjpoo.com](https://www.yjpoo.com/site/3983.html)) — all built on the same "turn a Xiaohongshu note into an itinerary" premise.
- The 80aj.com piece on Travelmapify "reads as a product announcement rather than a critical review," documents no accuracy problems or failures, and sources from a V2EX community share rather than independent testing — a useful caution about Chinese-language "review" content in this category. — [80aj.com, 6 Apr 2026](https://www.80aj.com/2026/04/06/ai-travel-planner-tool/)

### Inferences
- The "extract places from a social post into an itinerary" category is **crowded in Chinese and nearly invisible in English community discussion.** At least four products occupy it in Chinese (圆周旅迹, 小红旅计, Travelmapify, plus Paths/doro), with one at ~10M registered users; meanwhile English-language travel subreddits show no organic discussion of any of them.
- Paths' discovery path is influencer-seeded social (Threads, Chinese platforms) → App Store, not community word-of-mouth. That makes store-page conversion and first-run quality disproportionately important, and it means negative store reviews on a 3–7 rating base do real damage.
- The second MY review identifies a concrete, fixable funnel leak: a Chinese-first listing suppressed installs from an English-preferring user who had already been reached by an influencer. Paths now ships EN/zh-Hans/zh-Hant, which addresses this.

### Gaps
- Xiaohongshu and Threads are not searchable from this environment; both require authenticated, in-app search. Chinese-language sentiment — which matters given the app ships both Chinese scripts and is seeded by Chinese-platform influencers — is therefore **substantially unmeasured** here. The three Chinese-language store reviews found (TW ×1, HK ×2) are the only direct Chinese user voices in this research, and two of the three are complaints about WeChat login and cross-device sync.
- X/Twitter could not be searched directly.

---

## Q7. Most common repeated complaints about AI travel-planning apps as a category

### Takeaway
Six recurring complaints, in rough order of how often and how concretely they appear: (1) hallucinated or closed venues, (2) geographically incoherent routing, (3) generic output that ignores stated preferences, (4) missing local/contextual knowledge a human guide would volunteer, (5) no booking path, so the plan dead-ends, and (6) weak local transit modelling. Across both app-specific and category evidence, the implicit benchmark users apply is **ChatGPT**, not other travel apps.

### Cited Findings
- **Hallucinated venues and routes:** AI travel tools produce "hilarious, hallucinatory responses"; GuideGeek invented "a non-existent ice cream parlor in Pittsburgh"; tools have suggested "routes that don't exist or accommodations that are the stuff of fiction." — [Fox News, 16 May 2024](https://www.foxnews.com/tech/even-with-glitches-planning-your-next-trip-with-ai-is-making-me-rethink-travel)
- **Wrong location, non-existent shows, closed-on-the-day venues, incoherent day-splitting:** testers found tools sent users to activities in the wrong city, recommended non-historic hotels as historic, suggested shows that did not exist, sent users to venues closed on the specified day, and split attractions a 15-minute walk apart across different days. — [Afar](https://www.afar.com/magazine/we-tested-ai-travel-planning-apps-here-are-the-3-that-actually-worked) *(via search-result summary; re-verify wording before quoting)*
- **Missing local context:** the Hawaiian trail example — the AI named the trail but could not warn that a routine rain shower turns it into "a treacherous trench of mud." — [Fox News, 16 May 2024](https://www.foxnews.com/tech/even-with-glitches-planning-your-next-trip-with-ai-is-making-me-rethink-travel)
- **Generic output / ignores preferences, verbatim user quote (Paths, SG, 20 Sep 2026):** "Compared to ChatGPT, the output is not as detailed and good… it doesn't take into consideration my preferences for example what food I like to have, age appropriate activities considering my 4 year old etc." — [App Store SG](https://apps.apple.com/sg/app/id6786985803)
- **No booking path:** 圆周旅迹, at ~10M registered users, is faulted for lacking "hotel reservations, flight purchases, and other one-stop services," requiring an app switch to book — [环球旅讯, 23 Dec 2025](https://m.traveldaily.cn/article/188945); "No booking integrations" is likewise listed as a doro limitation — [ReviewNexa](https://reviewnexa.com/doro-app-review/)
- **Weak transit modelling, verbatim user quote (Paths, MY, 29 Sep 2026):** "Instead of showing walking or by cars on the map, it would be good improvement to have train options." — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- **Privacy/sign-in friction drives outright rejection, verbatim user quote (Paths, MY, 2 Sep 2026):** "unlike other apps no option for me to hide my email. Hence I rather use other AI platform" — 1★ — [App Store MY](https://apps.apple.com/my/app/id6786985803)
- **Hallucination is reducible with grounding:** GuideGeek went from 14% to 2% by adding real-time Skyscanner and Expedia data. — [Fox News, 16 May 2024](https://www.foxnews.com/tech/even-with-glitches-planning-your-next-trip-with-ai-is-making-me-rethink-travel)
- **Also in this corpus: pricing resistance and reliability.** A user's default assumption is that such an app will be paywalled — "I bet there's a subscription" — and was pleasantly surprised Paths was free ([App Store MY](https://apps.apple.com/my/app/id6786985803)), which is notable against doro Pro at $14.99/month or $39.99/year ([App Store US](https://apps.apple.com/us/app/doro-ai-trip-planner/id6755711343)). Separately, a mid-October 2026 Paths outage produced an immediate public complaint ([App Store US](https://apps.apple.com/us/app/id6786985803?see-all=reviews)).

### Inferences
- The category's credibility problem is **grounding, not generation.** Every well-documented failure (fake parlour, closed venue, Narita→Fuji) is a failure to check a generated claim against a real place database, calendar or map. The one documented remedy is real-time data integration.
- The free-ChatGPT baseline sets a hard floor: an AI itinerary app that merely produces prose plans is competing with a free tool users already have, and losing (per the SG review). The defensible surface is the parts ChatGPT cannot do — verified place data, map/route optimisation, live transit, offline access, collaboration — which is also where Paths' reviewers both praise it (route ordering, distance/time between stops, map view) and fault it (no train mode, poor geographic awareness).
- Booking is the most consistently named gap across independent sources and across market sizes (10M-user incumbent and 9-rating newcomer alike). It is a category-level opportunity, not a Paths-specific one.
- Sign-in design is an underrated churn cause in this corpus: of the four substantive Paths complaints outside accuracy, **three** are account-related (email privacy → 1★ and explicit switch to a competitor; no WeChat login; no cross-device sync). For a Chinese-seeded audience, the absence of WeChat login appears twice independently.

### Gaps
- No large-N sentiment dataset (e.g. aggregated review-mining across the category) was found. The category findings rest on two journalistic hands-on tests, one of which (Afar) could not be fetched directly, and the most substantial one (Fox News) is from May 2024.
- No 2025–2026 independent accuracy benchmark of AI itinerary apps was found.
- Churn reasons are inferred from one-off review complaints; there is no retention or cancellation data for either app.

---

## Cross-cutting note for the report writer: confidence summary

| Finding | Confidence | Basis |
|---|---|---|
| Paths' non-US ratings are materially worse than its US rating | **High** | Live iTunes Lookup API, 5 storefronts, 17 Oct 2026 |
| Paths' substantive complaints are geography/grounding, preference-adherence, and account/sync | **High** | 6 verbatim reviews across US/SG/MY/HK/Play |
| doro sentiment is uninformative (5.0 on 9 ratings, no Play build, last updated Jul 2026) | **High** | iTunes Lookup + 404s on candidate Play packages |
| r/Dorotravel and the doro Discord have no discoverable activity | **Medium** | Could not be read; zero search footprint. Needs manual check. |
| Extraction accuracy figures (87% overall; 75–85% screenshots vs 95–100% links) | **Low** | Single affiliate-flavoured blog, no methodology |
| Paths is the international build of 圆周旅迹 / pitravel | **Medium (inference)** | Android package `ai.gopaths.pitravel` + pitravel.cn + "Chinese platform influencer" review. Not confirmed. |
| Category failure modes (hallucinated/closed venues, incoherent routing, no booking) | **Medium-High** | Two journalistic tests + one Chinese trade-press piece; Afar wording unverified, Fox News dated May 2024 |
| Complaints about made-up prices or wrong opening hours for these two apps | **None found** | Absence of evidence on a tiny review base |
