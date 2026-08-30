# China & SEA market for AI trip planning built on social-content extraction (圆周旅迹 / 小红书 "抄作业")

*Research conducted 17 October 2026. All claims carry inline sources. Where a source is an aggregator, SEO-farm or undated, that is flagged.*

---

## 1. What is 圆周旅迹 (pitravel.cn)? Feature set, scale, platform, monetization, launch, parent company — and is there any link to BLANK CRAFT PTE. LTD. / gopaths.ai?

### Takeaway
圆周旅迹 is a Shanghai-built, free, map-first AI itinerary app whose signature feature is pasting a Xiaohongshu/WeChat link and getting a ready-made itinerary; it is operated by 超超世世科技（上海）有限公司, reached ~#21 (and historically #5) in the Apple China Travel chart, and has been reported at roughly 10 million registered users. On the Paths link: I could **not** find any evidence tying 圆周旅迹 or 超超世世 to BLANK CRAFT PTE. LTD. — but unredacted WHOIS for `gopaths.ai` shows a registrant email **@xiaohongshu.com**, which points at a *different* and more surprising possible parent. See the dedicated sub-section below.

### Cited Findings — product and company
- Official site positions the product as "旅游出行智能规划, 复制行程攻略助手, 路线行程记录地图" — i.e. planning + guide-copying + route recording on a map — with a 开始规划 CTA and an app download — [pitravel.cn](https://www.pitravel.cn/)
- Core features: one-click import of itineraries from **Xiaohongshu links, text, or images, and WeChat Official Account articles**; 一键规划 auto-sequencing of POIs by location and traffic; map visualisation; multi-person real-time collaborative editing; poster/password sharing out to Xiaohongshu and Douyin; POI detail pages with reviews; 找搭子 (find-a-travel-buddy) community; 3D maps, draggable routes, live traffic, offline map caching — [ai-bot.cn profile of 圆周旅迹](https://ai-bot.cn/pitravel/)
- A reviewer round-up adds that imports also work from **大众点评 (Dianping)** notes, and describes the flow as: batch-save the POIs out of a post, then hit a "magic wand" button to auto-plan all saved POIs across dates — [知乎 / 虎嗅 round-up of 3 AI tools for Xiaohongshu users](https://www.huxiu.com/brief/224532.html)
- Also reported: **screenshot OCR ingestion** — importing flight details from a boarding pass screenshot and hotel details from a booking screenshot — [mwm.ai listing (aggregator)](https://mwm.ai/apps/yuan-zhou-lu-ji-lu-you-chu-xing-zhi-neng-gui-hua-fu-zhi-xing-cheng-gong-lue-zhu-shou/6473148424)
- Developer / operator: **超超世世科技（上海）有限公司** (Chaoshi/Chaochaoshishi Technology (Shanghai) Co., Ltd.); unified social credit code 91310110MA1G9DAW3M; ICP filing 沪ICP备2023038043号-5A — [Tencent 应用宝 listing](https://sj.qq.com/appdetail/com.chaochaoshishi.slytherin); [Xiaomi app store listing](https://app.mi.com/details?id=com.chaochaoshishi.slytherin)
- WHOIS for `pitravel.cn` confirms registrant **超超世世科技（上海）有限公司**, contact `pi@pitravel.cn`, registrar 广州云讯信息科技有限公司, nameservers ns3/ns4.dnsv4.com (Tencent DNSPod) — WHOIS lookup run locally 2026-10-17 (primary record; no public URL)
- **Android package id: `com.chaochaoshishi.slytherin`** — note the internal codename "slytherin" — [应用宝](https://sj.qq.com/appdetail/com.chaochaoshishi.slytherin)
- Apple China listing: Apple ID 6473148424, seller "Chaoshi Technology (Shanghai) Co., Ltd.", version 5.13 (24 September), **#21 in Travel (Free)**, 4.6/5 from 2,922 ratings, free, 267.5 MB, languages **Simplified Chinese, Traditional Chinese, English**, iOS/iPadOS 14+ and macOS 11+ (Apple silicon) — [App Store CN id6473148424](https://apps.apple.com/cn/app/id6473148424)
- Apple privacy label: collects user ID, device identifiers and **precise location**, and does cross-app tracking via identifiers — [App Store CN id6473148424](https://apps.apple.com/cn/app/id6473148424)
- Distribution is broad across Chinese Android channels: Tencent 应用宝, Xiaomi 应用商店, plus a long tail of download sites listing versions from v2.0.1 up to v5.5.0 — [Xiaomi](https://app.mi.com/details?id=com.chaochaoshishi.slytherin); [32r.com v5.5.0](https://www.32r.com/app/143385.html)
- Aggregator reports ~**2.5M+ downloads** and 4.6/5 for the Chinese app — [mwm.ai (aggregator, methodology unclear)](https://mwm.ai/apps/yuan-zhou-lu-ji-lu-you-chu-xing-zhi-neng-gui-hua-fu-zhi-xing-cheng-gong-lue-zhu-shou/6473148424)

### Cited Findings — scale and monetization (TravelDaily trade feature)
环球旅讯 (TravelDaily), a credible Chinese travel-trade outlet, ran a feature on the category titled 旅游AI"邪修"火爆出道：旅游笔记，一键抄作业 ("Travel AI's heretical build goes viral: travel notes, copy the homework in one click"), centred on 圆周旅迹:
- "Nearly **10 million registered users** accumulated since launch over a year ago" — [环球旅讯 article 188945](https://m.traveldaily.cn/article/188945)
- Core user base: **young white-collar users in tier-1/tier-2 cities** with strong purchasing power, averaging **2–3 trips a year** — [环球旅讯](https://m.traveldaily.cn/article/188945)
- Reached **#5 in the App Store Travel category** during an October holiday period (the article references the Oct 2024 Golden Week) — [环球旅讯](https://m.traveldaily.cn/article/188945)
- Reported satisfaction split: **>80% of users cite the copy/extraction function as crucial**, ~75% value the AI planning, ~60% found travel companions via sharing — [环球旅讯](https://m.traveldaily.cn/article/188945)
- **Monetization: currently entirely free, no IAP.** The team said it is interested in brand partnerships and bespoke/custom group tours rather than subscriptions or paywalls — [环球旅讯](https://m.traveldaily.cn/article/188945)
- Explicit positioning: it differentiates by letting users *interact with itinerary content*, rather than pushing hotel/flight booking conversion — [环球旅讯](https://m.traveldaily.cn/article/188945)
- Chinese AI-directory profiles likewise state the product is **完全免费** with 攻略解析, AI 行程规划 and 多人协作 all free — [ai-bot.cn](https://ai-bot.cn/pitravel/); [uied.cn write-up](https://www.uied.cn/83025.html)

### The Paths / gopaths.ai / BLANK CRAFT question
- Paths is published by **BLANK CRAFT PTE. LTD.**, address given as 9 Raffles Place #26-01 Republic Plaza, Singapore 048619; Apple ID **6786985803**; **released 20 July 2026**; version 1.5.1; 4.3/5 from 12 ratings; free; 3 locales — [mwm.ai Paths listing](https://mwm.ai/apps/paths-ai-travel-planner/6786985803); [App Store US](https://apps.apple.com/us/app/paths-ai-travel-planner-id6786985803); Singapore address surfaced in [search result summary of the Play listing](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- Paths' Play listing is **`ai.gopaths.pitravel`**, reported at **10k+ downloads** — [Google Play](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel); download figure via [mwm.ai](https://mwm.ai/apps/paths-ai-travel-planner/6786985803)
- Paths' described feature set is a near-exact match for 圆周旅迹's: "drop travel links, screenshots, or text into Paths" → AI extracts places and builds an itinerary; optimised route with interactive maps, live weather and transit; invite friends to collaborate in real time, add stops, leave notes, adjust routes — [Google Play listing summary](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel); [gopaths.ai/trip](https://www.gopaths.ai/trip)
- **Unredacted WHOIS for `gopaths.ai`** (looked up locally 2026-10-17): Creation Date **2026-06-26**; Registrar **Dominet (HK) Limited** (Alibaba Cloud / registrar abuse contact `@list.alibaba-inc.com`); Registrant Name "pan yu shun"; Registrant Organization **YOUTONG TRADING HONG KONG LIMITED**, Room 1903 19F Lee Garden One, 33 Hysan Avenue, Causeway Bay, Hong Kong; **Registrant / Admin email `hcmp-admin@xiaohongshu.com`**. Admin and Tech org are the same HK entity. (Primary record from a local `whois gopaths.ai`; no citable URL. Reproducible by anyone running the same query.)
- Corroborating pattern, weakly: Xiaohongshu's own `rednote.net` is also registered through **Dominet (HK) Limited** with Registrant Country **HK** — same registrar/jurisdiction pattern — though its registrant fields are redacted, so this is suggestive only (local WHOIS, 2026-10-17).
- The gopaths.ai front end is served from `cdn.gopaths.ai` with a fallback host `fe-platform-s11.gopaths.ai`, and an error-retry layer tagging assets `data-formulaAssetRetry` — i.e. a mature internal front-end platform ("fe-platform", "formula"), not a typical seed-stage indie stack (observed by fetching https://www.gopaths.ai/ raw HTML, 2026-10-17)
- I found **no** Chinese-media, 36氪, 虎嗅, 晚点, TechNode or KrASIA reporting of an acquisition, investment or corporate relationship between Xiaohongshu (or 行吟信息科技/Xingyin) and 超超世世科技, nor any between 超超世世 and BLANK CRAFT — searches on 小红书 收购 圆周旅迹 / 超超世世 and on "BLANK CRAFT PTE" returned nothing on point — [36氪 search results returned only unrelated Shanghai-unicorn stories](https://36kr.com/p/3329399915079945)

### Inferences
- The shared token "pitravel" in `ai.gopaths.pitravel` plus a feature set that is a line-for-line match for 圆周旅迹's (link/screenshot/text extraction + auto-route + real-time co-editing) makes it very likely Paths is **the same codebase or the same team's product, shipped internationally**. Chinese apps routinely front overseas releases through a Singapore Pte. Ltd. shell, so "BLANK CRAFT PTE. LTD." being Singapore-registered is not evidence against a China origin — it is the expected pattern.
- The `hcmp-admin@xiaohongshu.com` registrant email on `gopaths.ai` is the single strongest piece of hard evidence in this file, and it points to **Xiaohongshu itself** administering the Paths domain. The most economical explanation is that Xiaohongshu acquired or absorbed the 圆周旅迹 team/product and is using it as the basis of an **overseas travel-planning product**, retaining the legacy "pitravel" bundle namespace. A competing explanation — that Paths is an independent team and the WHOIS record is stale, mis-keyed or proxied — cannot be ruled out from WHOIS alone.
- If that reading is right, the strategic picture changes materially: the most direct competitor to a link-extraction trip planner in SEA would not be a small Chinese indie app, but the platform that *owns the source content*, with first-party access to RED notes and no scraping risk.
- 圆周旅迹's refusal to monetize via booking conversion (and zero IAP after a year+ and ~10M users) implies the category has strong top-of-funnel pull but **no proven direct monetization** in China; value is expected to be captured later via brands/custom tours, or by whoever owns the content graph.

### Gaps
- **Not verifiable from my environment:** whether BLANK CRAFT PTE. LTD. is beneficially owned by 超超世世科技, by Xiaohongshu/行吟, or by neither. ACRA (Singapore) and 国家企业信用信息公示系统 (China) both require interactive/paid lookups that WebFetch cannot complete. **Do not assert a corporate link in the final report beyond the WHOIS fact and the package-id coincidence.**
- No funding round, revenue, MAU (as opposed to registered users) or headcount figure for 超超世世科技 could be found. The ~10M registered-user figure is reported by one outlet, sourced to the team, and the article appears to date from late 2024/2025 — it may understate current scale and should be dated cautiously.
- Google Play's own page for `ai.gopaths.pitravel` would not render for me (truncated/blocked); developer email, exact release date and Data Safety declarations for Paths are unverified. A manual browser visit is worth doing.
- Apple China listing did not expose an original release date for 圆周旅迹; "launched over a year ago" as of the TravelDaily piece plus the 2023 ICP filing (沪ICP备2023038043) implies a **2023 launch**, but I could not confirm the month.
- `gopaths.ai` and `pitravel.cn` are JS-rendered SPAs; WebFetch returned only shell HTML, so I could not read Paths' own pricing page, privacy policy or its stated list of supported source platforms (does it accept Xiaohongshu links outside China? Instagram? TikTok?). This is the single highest-value open question for competitive positioning.

---

## 2. How does the Xiaohongshu note extraction work from the user's point of view, and what do users say about it?

### Takeaway
The user flow is deliberately zero-effort — copy a RED note's share link (or screenshot it), paste into the app, and the app returns a parsed, map-plotted, date-bucketed itinerary with POIs you tick to keep. Users describe it in the language of relief from attention-tax rather than of AI novelty; the extraction feature, not the AI generation, is what they value most.

### Cited Findings
- Flow as described by reviewers: see a guide you like on RED → copy the link or screenshot the image → drop it into the app → it intelligently parses and extracts the itinerary's locations → tick the ones you want → it auto-generates the optimal route — [知乎/虎嗅 round-up](https://www.huxiu.com/brief/224532.html); [ai-bot.cn](https://ai-bot.cn/pitravel/)
- Multi-source: RED notes, Dianping, WeChat Official Account articles, plain text, and images — "无需手动整理" (no manual tidying required) — [知乎/虎嗅 round-up](https://www.huxiu.com/brief/224532.html)
- Second entry point: batch-bookmark POIs mentioned inside a post, then press the "magic wand" to have the app plan all saved POIs, displayed by date and on a map — [知乎/虎嗅](https://www.huxiu.com/brief/224532.html)
- The category nickname in Chinese trade press is **"邪修"** — a gaming/wuxia term for an unorthodox-but-brutally-effective build — applied specifically to one-click note-copying, which the article says "resonates most strongly with users" — [环球旅讯](https://m.traveldaily.cn/article/188945)
- Quantified user preference: **>80% of users said the copy function was crucial**, vs ~75% for the AI planning — i.e. extraction out-polls generation — [环球旅讯](https://m.traveldaily.cn/article/188945)
- Organic RED word-of-mouth exists and uses pain-relief framing, e.g. notes titled 旅游攻略不需要来回切换软件 ("travel planning without switching back and forth between apps") and 天呐！所有不想做旅行攻略的姐妹都给我去用 ("OMG, every girl who doesn't want to make a travel plan needs to use this") — [xiaohongshu.com note](https://www.xiaohongshu.com/explore/6a476b98000000001101e1b9); [xiaohongshu.com note](https://www.xiaohongshu.com/explore/698ff00a000000001d0108bd)
- 圆周旅迹 also ships *outbound* sharing back into RED and Douyin (poster generation, share-codes), closing the loop — [ai-bot.cn](https://ai-bot.cn/pitravel/)

### Inferences
- The product's wedge is **not** "AI writes you a trip" but "AI finishes the job RED started". The 80/75 split suggests a pure LLM itinerary generator is a commodity, while the parse-a-specific-creator's-note path is the defensible, habit-forming surface.
- Sharing posters back to RED is a growth loop *and* a dependency: the app's acquisition channel is the same platform whose content it extracts, which is a strategic single point of failure (see §5).
- Screenshot/OCR ingestion is the obvious technical hedge against link-level anti-scraping, and 圆周旅迹 has already built it.

### Gaps
- I could not read first-party user reviews at any depth. Apple China review text is not exposed via WebFetch and I only have the aggregate (4.6/5, 2,922 ratings). **I therefore have no well-sourced account of negative reviews** — e.g. parse-failure rates, wrong-POI mapping, overseas-POI coverage, or data-quality complaints. This is a real gap: every user-sentiment finding above is positive, and that is a sampling artefact of the sources I could reach (vendor-adjacent write-ups and promotional RED notes), not a verified picture. Recommend a manual pass over App Store CN reviews and 小红书 搜索「圆周旅迹 不好用 / bug」before the report asserts anything about satisfaction.

---

## 3. What is the "抄作业" trip-planning behaviour on Xiaohongshu?

### Takeaway
RED is the de-facto trip-planning layer for young Chinese travellers: they search it for a specific person's day-by-day guide and literally re-execute it ("copy the homework") rather than plan from scratch. The pain is that this content is unstructured, scattered across dozens of notes and screenshots, and has no map, no sequencing and no shared editing — which is precisely the gap extraction tools fill.

### Cited Findings
- Scale of travel content on RED: searches for 旅游 return over 5 million notes, of which 旅游攻略 (travel guides) are about a quarter; users explicitly treat RED as a travel-guide platform where they look for "抄作业"-style 避坑 (pitfall-avoidance) advice — [知乎 analysis of 旅游类商家如何玩转小红书](https://zhuanlan.zhihu.com/p/649024998)
- Travel is RED's **second-largest category after beauty**, and the fastest-growing by note volume and engagement — [知乎, 3000字讲透旅游类商家如何玩转小红书](https://zhuanlan.zhihu.com/p/493454194)
- Current first-party platform figures: **39,000+ professional travel accounts and 21 million+ new travel notes submitted monthly** — [中国日报网 coverage of the 2026 小红书文旅峰会](https://cn.chinadaily.com.cn/a/202604/27/WS69ef1038a310942cc49a98ab.html); [环球旅讯 189197](https://m.traveldaily.cn/article/189197)
- RED's own marketing leans into the behaviour, e.g. its Labour Day campaign positioned as 旅游攻略我包了 ("I've got your travel guide covered") — [数英 campaign write-up](https://www.digitaling.com/projects/263682.html)
- The user benefit is stated as "少走弯路，避雷避坑" (fewer wrong turns, dodge the landmines) because notes are grounded in a real person's actual trip — [知乎](https://zhuanlan.zhihu.com/p/649024998)
- The articulated pain point: planning used to mean **staying up late trawling guides and still stepping into traps** — [知乎](https://zhuanlan.zhihu.com/p/649024998)
- "抄作业" is an explicit, native content format — notes are titled e.g. 全国通用旅行攻略，新手直接抄作业 ("universal China travel guide, beginners just copy the homework") — [xiaohongshu.com note](https://www.xiaohongshu.com/explore/6a40771f0000000017028622)
- Guides are expected to cover a standard bundle: transport, accommodation, food, sights, and day-by-day itinerary — [opp2.com guide](https://www.opp2.com/279259.html)
- Behaviour has shifted from **destination-led to interest-led**: trips are built around food, parent-child learning, exhibitions, markets, outdoor activity, live events, workation/digital-nomad lifestyles — and these interests extend into outbound travel across Asia — [i-Click, Interest-Led Journeys (2026)](https://www.i-click.com/resources/cultural-travel-trends-chinas-outbound-travel-xiaohongshu-2026/); [China Trading Desk, Xiaohongshu 2026 Tourism Guide](https://www.chinatradingdesk.com/post/travel-by-interest-xiaohongshu-2026-tourism-guide)

### Inferences
- "抄作业" is a *trust* mechanism as much as a convenience one: the itinerary's authority comes from an identifiable peer who actually went, which is why users want to copy a specific note rather than accept a generated plan. An extraction product inherits that trust; a pure generator does not. This is the strongest argument for link-extraction as a category rather than a feature.
- The pain is structural and will not be fixed by better LLMs: RED content is optimised for feed consumption, not execution. The missing primitives are the same four every time — geocoding, sequencing, time/transit budgeting, and shared editing.
- Interest-led planning raises the value of extraction, because interest-specific itineraries (a specific coffee crawl, a specific market route) are exactly what generic AI planners generate badly and what creators document well.

### Gaps
- Several §3 sources are marketing/agency blogs (知乎 marketing posts, digitaling, opp2, i-Click, China Trading Desk) rather than neutral research. The 5-million-note and "second-largest category" figures are agency claims and should be attributed as such, not stated as platform-verified. The 39,000 accounts / 21M monthly notes figures come from RED's own summit and are first-party-but-promotional.
- No independent survey data (e.g. iResearch, QuestMobile, Fastdata) on what share of Chinese travellers plan on RED vs OTAs. I did not find one.

---

## 4. What other Chinese apps do this? (马蜂窝, 携程/Trip.com, Qunar, 飞猪, 穷游, RED's own, and AI itinerary apps)

### Takeaway
By late 2025 essentially every Chinese OTA had bolted an AI planner on — 携程 问道, 马蜂窝 AI小蚂 + AI路书, 飞猪 问一问, 穷游 AI drafts — but these are booking-funnel entry points, not extraction tools. I found **no named direct competitor to 圆周旅迹 on the "paste a RED link" primitive**; the closest structural threat is RED's own 点点 assistant.

### Cited Findings
- "In H2 2025, essentially all mainstream OTA platforms completed AI integration — Ctrip launched 问道, Mafengwo shipped AI路书, Fliggy built in 问一问, and even Qyer started generating itinerary drafts with AI" — [人民日报海外版, 在线旅游平台纷纷推出AI助手 (14 May 2025)](https://paper.people.com.cn/rmrbhwb/pc/content/202505/14/content_30073102.html)
- **马蜂窝 (Mafengwo)**: AI travel assistant 「AI小蚂」 with real-time Q&A, route planning, online guiding and personalised recommendation, plus a guide-planning-focused 「AI路书」 feature; Mafengwo also presented an "AI full-chain service" / 旅游超级智能体 at 服贸会 — [执惠 coverage](https://www.tripvivid.com/46144.html); [知乎 AI Agent 展: 马蜂窝AI行程规划](https://zhuanlan.zhihu.com/p/1943443579151315300)
- **携程 (Ctrip/Trip.com)**: released 问道, a travel-vertical LLM, with products spanning the 问道 assistant, overseas **TripGenie**, ranked lists/榜单, and AI customer service — [人民日报海外版](https://paper.people.com.cn/rmrbhwb/pc/content/202505/14/content_30073102.html)
- **去哪儿 (Qunar)**: offers smart itinerary planning and personalised recommendation, but detail in Chinese-language sources is thin — [人民日报海外版](https://paper.people.com.cn/rmrbhwb/pc/content/202505/14/content_30073102.html)
- Critical read on the OTA AI products: Mafengwo/Fliggy/Qyer's itinerary features are "essentially traffic entrances to the booking system — AI is the wrapper, commercial recommendation is the core" — [知乎 deep review of four travel-planning apps' AI](https://zhuanlan.zhihu.com/p/2047322767398384530) (quoted via search snippet; the page itself returned HTTP 403 to me)
- A 36氪 piece as late as the May holiday argued **AI still can't be your trip planner** (这个五一，AI还不能成为你的旅行规划师) — i.e. the generative-planner category was publicly judged immature, which is consistent with extraction out-polling generation — [36氪](https://36kr.com/p/3280418956484997); [syndicated at 新浪财经](https://finance.sina.com.cn/roll/2025-05-07/doc-inevtimx3649430.shtml)
- The category is crowded at the long tail: a Baidu developer round-up catalogues **31 AI travel itinerary-planning tools** — [百度开发者中心, AI旅行工具大盘点](https://developer.baidu.com/article/details/3169633)
- A 少数派 (sspai) 派评 column covered 圆周旅迹 alongside other picks, i.e. it has credible Chinese prosumer-media recognition — [sspai 派评](https://sspai.com/post/91173)
- In the 虎嗅/知乎 "3 AI tools every RED user needs" framing, the travel slot is occupied by **圆周旅迹**, with RED's own 点点 in the search slot — no rival extractor is named — [虎嗅](https://www.huxiu.com/brief/224532.html)

### Inferences
- The competitive structure is a barbell: OTAs own transactions and are using AI defensively to protect booking funnels; RED owns inspiration content; 圆周旅迹-type apps occupy the uncontested middle — the *execution layer* — which is valuable in attention but has no native revenue, which is exactly why 圆周旅迹 is still free.
- The absence of a named second extractor in China after 1–2 years suggests either (a) a genuine technical/anti-scraping moat around reliable RED parsing, or (b) a category too hard to monetize to attract fast followers. Either way, a SEA entrant would not be entering a crowded extraction market — it would be creating one, against RED-adjacent incumbency.

### Gaps
- I could not open the most useful source (the 知乎 four-app AI teardown, HTTP 403), so the "AI is the wrapper, commercial recommendation is the core" characterisation rests on a search snippet and should be treated as a cited opinion, not verified analysis.
- The brief asked me to check 探途 and 游记 specifically; targeted Chinese searches for 探途 / 游迹 / 妙计 as 圆周旅迹 competitors returned **nothing on point** — the search engine explicitly reported no comparative information for those names. I cannot confirm those products exist in this category under those names.
- No Huawei AppGallery listing retrieved (searches surfaced Tencent 应用宝 and Xiaomi instead); no download-ranking data from QuestMobile / 七麦 / 点点数据, which is where real China app scale would be verified.

---

## 5. Has Xiaohongshu shipped trip-planning features? Has it restricted extraction? Legal/ToS friction?

### Takeaway
Yes on both counts, and this is the most material risk in the whole analysis: RED has shipped an AI assistant (点点) with a dedicated **Itinerary Mode** in 2026, and it has an aggressive, *successful* litigation and anti-crawler record — including criminal convictions and a RMB 4.9M final-judgment damages award against scrapers, plus 15.96 billion crawler attacks blocked in a single quarter.

### Cited Findings — RED's own trip planning
- RED launched its AI search assistant **点点 (Diandian)** on 26 December 2024, built on its in-house 「筹记」/Zhuji large model — [百度百科: 点点](https://baike.baidu.com/item/%E7%82%B9%E7%82%B9/65296356)
- In **2026, 点点 launched an "Itinerary Mode" (行程模式)** combining real-time information with map capability to generate detailed, executable travel and lifestyle itineraries — [百度百科: 点点](https://baike.baidu.com/item/%E7%82%B9%E7%82%B9/65296356)
- On **29 May 2026** RED shipped 点点 on PC, answering questions with summarised answers plus the underlying original notes, likes, saves and comments; it supports multi-turn dialogue and **can import the user's own liked/saved notes as context** for personalised answers — [今日头条 report](https://www.toutiao.com/article/7647115561138160171/); [品玩 (PingWest) analysis](https://www.pingwest.com/a/301644)
- 品玩's framing: RED's AI search has a capability "Perplexity and co. envy" — i.e. a proprietary UGC corpus — [品玩](https://www.pingwest.com/a/301644)
- RED is investing heavily in travel commercially: 2026 文旅峰会, a 文旅兴趣出游种草指南 report, and 39k+ pro travel accounts / 21M+ monthly travel notes — [中国日报网](https://cn.chinadaily.com.cn/a/202604/27/WS69ef1038a310942cc49a98ab.html); [环球旅讯 189197](https://m.traveldaily.cn/article/189197); [中国网海丝频道](http://hs.china.com.cn/2026-01/27/content_43343467.html)

### Cited Findings — scraping, ToS and litigation
- RED publicly stated it **blocked 15.96 billion crawler attacks in three months** and is actively fighting data-scraping of the platform — [央广网 (CNR), July 2022](http://tech.cnr.cn/techph/20220708/t20220708_525904562.shtml)
- July 2022: RED filed civil suits against companies including 艺恩星数 and 常州积奇, alleging improper technical means to crawl platform content and data and then store, process and commercialise it — [央广网](http://tech.cnr.cn/techph/20220708/t20220708_525904562.shtml)
- **Criminal case**: a Changzhou network company and its employees were prosecuted for illegally obtaining 小红书 app system data — they cracked the app's encryption algorithm and forged data requests to intrude on servers, scraping nicknames, IDs and notes, netting **RMB 6.53M+ between June 2019 and December 2021**. The company was fined RMB 200,000; **three employees received prison terms ranging from 3 years (suspended 5) to 4 years**, with fines of RMB 100,000–200,000 — [安全内参](https://www.secrss.com/articles/72097); [知产财经网](https://www.ipeconomy.cn/dongtai/9167.html); [知乎 summary](https://zhuanlan.zhihu.com/p/30164702875)
- **Civil, final judgment**: a company that illegally crawled 小红书 data for profit lost on final appeal and was ordered to pay **RMB 4.9 million** — [网易 report](https://m.163.com/dy/article/JU5N3CRA05129QAF.html)
- Courts held that RED had put technical protective measures in place, and that the defendants' **frequent rotation of user IDs and accelerated IP rotation to bypass those measures constituted infringement** (unfair competition) — [天同律师事务所 case note (counsel for 小红书)](https://www.tiantonglaw.com/Content/2024/06-27/1022448210.html); [央广网](http://tech.cnr.cn/techph/20220708/t20220708_525904562.shtml)
- Legal commentary consensus: crawling technology is not itself illegal, but **unauthorised crawling of RED data, cracking or circumventing RED's technical measures, and commercial use of crawled RED data can each be unlawful** — [淘发客 legal explainer](https://www.taofake.com.cn/article/xiaohongshu/101932.html)

### Inferences
- The legal record targets **bulk, server-side, encryption-cracking scrapers operating at commercial scale** — not obviously a consumer app parsing a single public share link the user themselves pasted. But the distinction is one of degree (volume, circumvention, commercialisation), and all three aggravating factors the courts named are present in any successful extraction product at scale: it is commercial, it is systematic, and link-level parsing of a modern RED note generally requires working around anti-bot measures. **This is a live, material legal risk, not a theoretical one, in the PRC.** Screenshot/OCR ingestion and on-device parsing materially reduce exposure versus server-side fetching.
- 点点's Itinerary Mode is the structural endgame: RED can do extraction losslessly and legally because it owns the corpus, and it already imports the user's own saves as context — which is the single best version of "copy that note's trip".
- Put together with the `gopaths.ai` WHOIS finding in §1, there is a coherent (unproven) story: RED concluded extraction is strategic, and is executing it both in-app (点点 行程模式, domestic) and as a standalone overseas app (Paths, via a Singapore entity). If true, a third-party SEA link-extraction planner would be competing with the rights-holder.
- Outside the PRC the legal calculus differs (RED's China judgments do not bind SG/MY/TH courts, and ToS-breach + copyright are the likelier theories), but RED's demonstrated willingness to litigate is the relevant signal.

### Gaps
- I did not retrieve 小红书's current user agreement / 用户协议 or robots.txt text verbatim, so I cannot quote the specific clause prohibiting third-party extraction. Recommend pulling https://www.xiaohongshu.com/robots.txt and the 用户协议 directly before the report characterises ToS.
- No evidence found either way on whether RED has ever sent a takedown/cease-and-desist to 圆周旅迹 or any consumer itinerary-extraction app. Absence of evidence here is weak evidence of absence — such letters are rarely public.
- No information on whether RED offers any sanctioned API or content-partner programme that a third party could license into.

---

## 6. What does the Southeast Asian market look like, and is there a regional gap?

### Takeaway
SEA has strong incumbents on *transactions* (Traveloka, Klook, Grab) and a crowd of small AI itinerary startups, but no one owns the **social-content-to-itinerary** layer; meanwhile RED is already the planning tool for the Chinese travellers coming *into* SEA. The plausible gap is a multilingual execution layer, not another booking app — though all the SEA-side sources I could reach are thin and promotional.

### Cited Findings
- **Xiaohongshu is already the planning layer for inbound Chinese travel to SEA**: it is reshaping Chinese tourists' SEA experience with in-depth UGC advice and itineraries that go beyond Instagram, and is "a beloved resource among young Chinese travelers", with **300M+ MAU** — [Rest of World (2024)](https://restofworld.org/2024/xiaohongshu-southeast-asia-tourism/)
- Chinese outbound trips in 2026 are being built interest-first (music, heritage, sport, nature, lifestyle) and extended "across Asia and beyond" — [i-Click](https://www.i-click.com/resources/cultural-travel-trends-chinas-outbound-travel-xiaohongshu-2026/)
- **Traveloka**: founded 2012 in Jakarta, **headquartered in Singapore** — [Wikipedia: Traveloka](https://en.wikipedia.org/wiki/Traveloka); has integrated AI letting customers **rebook entire itineraries via natural language in-app** — [Skift, Asia Forum 2026](https://skift.com/2026/04/30/high-touch-klook-traveloka-skift-asia-forum/)
- Traveloka publishes a quarterly **SEA Index**: Q3 2026 showed Indonesia→Mecca accommodation bookings up sharply YoY, Malaysian interest in Borobudur, and Vietnam→Luang Prabang bookings up — i.e. heavy intra-regional, faith/heritage-led demand — [PR Newswire APAC](https://www.prnewswire.com/apac/news-releases/traveloka-sea-index-q3-2026-faith-and-heritage-stand-out-across-southeast-asia-302906874.html)
- **Klook and Traveloka executives (Skift Asia Forum, Apr 2026)**: travellers "don't care if it's AI or human — they just want the answer now"; what matters is fast, accurate service — [Skift](https://skift.com/2026/04/30/high-touch-klook-traveloka-skift-asia-forum/); [Skift forum preview](https://skift.com/2026/04/29/klook-and-traveloka-at-skift-asia-forum-2026/)
- **Grab** is the region's dominant super-app across Indonesia, Singapore, Thailand, Vietnam, Malaysia and the Philippines, and is pushing AI-powered features for moving, eating, paying and exploring cities — [Travel And Tour World](https://www.travelandtourworld.com/news/article/indonesia-joins-singapore-thailand-vietnam-malaysia-and-philippines-in-accelerating-smart-tourism-with-ai-driven-travel-payments-and-mobility-ecosystems-a-complete-guide-for-modern-travele/); [Wikipedia: Grab Holdings](https://en.wikipedia.org/wiki/Grab_Holdings)
- Small AI-planner entrants explicitly targeting the region: **Trevia**, "built from the ground up as an AI trip planner", specialising in Thailand, Vietnam, Bali, the Philippines, Malaysia — [trevia.ai](https://trevia.ai/); **Visit77**, a travel app and social travel platform covering all 11 SEA countries — [Google Play: Visit 77](https://play.google.com/store/apps/details?id=com.visit77.mobile); **Stippl**, a free AI planner generating day-by-day itineraries with budget and stays — [stippl.io](https://www.stippl.io/)
- Mainstream framing of the AI planning benefit in SEA consumer media: it replaces "manually cross-referencing dozens of open browser tabs", suggests routes, flags scheduling conflicts and recommends by where you're staying, cutting planning hours "especially for multi-city trips" — [Traveloka Explore](https://www.traveloka.com/en-th/explore/tips/how-travel-technology-makes-trips-easier/92253)
- Governments across Singapore, Thailand, Vietnam, Malaysia, Indonesia and the Philippines are pushing "smart tourism" with AI-driven travel, payments and mobility — [Travel And Tour World](https://www.travelandtourworld.com/news/article/indonesia-joins-singapore-thailand-vietnam-malaysia-and-philippines-in-accelerating-smart-tourism-with-ai-driven-travel-payments-and-mobility-ecosystems-a-complete-guide-for-modern-travele/)

### Inferences
- The SEA gap is real but narrow. Incumbents are defending **transactions** (Traveloka, Klook) and **local mobility/daily life** (Grab); the AI-planner startups (Trevia, Stippl, Visit77) are generative/directory plays with no visible scale and, critically, **no extraction wedge**. Nobody reachable in these sources is doing "paste the post you actually saw, get the trip".
- SEA's demand pattern is heavily **intra-regional and multi-city** (Traveloka's Q3 2026 index; the "especially for multi-city trips" framing), which is where sequencing/route-optimisation — 圆周旅迹's actual core competence — pays off most. That is the strongest product-market argument for the category in SEA.
- Singapore is the natural HQ for a SEA travel product (Traveloka HQ'd there; BLANK CRAFT registered there), which means the Paths Singapore registration tells you about go-to-market intent, not about founder nationality.
- A regional entrant faces a harder content problem than in China: no single dominant source platform. Inspiration is split across Instagram, TikTok, Facebook groups, RED (for Chinese-speaking users), YouTube and local blogs — so the extraction surface must be multi-platform from day one, which is both a cost and a moat.

### Gaps
- **I found no Tech in Asia, e27 or Vulcan Post coverage** of SEA link-extraction / social-content itinerary startups. Searches returned only aggregators, SEO listicles and vendor pages. Either the coverage does not exist or my search tool (US-only) could not reach it. Flag to the report writer: **the SEA competitive picture in these notes is under-sourced and should be caveated.**
- No market sizing for SEA AI trip planning, no download/MAU figures for Trevia, Stippl or Visit77, and no funding data for any of them. Several of these may be pre-traction websites rather than real competitors.
- No app-store ranking data pulled from the SG, MY, TW or HK storefronts (the brief asked for this). Not retrievable via WebSearch/WebFetch; needs a 七麦/Sensor Tower/AppFigures-style tool or manual storefront visits.
- I could not verify whether Klook or Trip.com has shipped anything resembling social-post extraction.

---

## 7. What languages and content sources matter for a SEA-focused product?

### Takeaway
A SEA product needs at minimum English + Simplified/Traditional Chinese, with Bahasa Indonesia/Malaysia and Thai as the growth tier — and crucially it must ingest from *many* source platforms, since no SEA equivalent of RED's content monopoly exists. My direct evidence here is thin and largely inferential.

### Cited Findings
- 圆周旅迹 already ships **Simplified Chinese, Traditional Chinese and English** — so TW/HK/SG Chinese-speaking users are already in-scope for the incumbent — [App Store CN id6473148424](https://apps.apple.com/cn/app/id6473148424)
- Paths supports **3 locales** (specific languages not disclosed in the listing I could reach) — [mwm.ai](https://mwm.ai/apps/paths-ai-travel-planner/6786985803)
- Paths accepts "travel links, screenshots, or text" as input — a platform-agnostic framing, unlike 圆周旅迹's RED/WeChat/Dianping-specific one — [Google Play listing summary](https://play.google.com/store/apps/details?id=ai.gopaths.pitravel)
- Traveloka's regional demand data shows the highest-volume corridors run through **Indonesian, Malay, Vietnamese and Thai** markets (Indonesia→Mecca, Malaysia→Borobudur, Vietnam→Luang Prabang) — [PR Newswire APAC](https://www.prnewswire.com/apac/news-releases/traveloka-sea-index-q3-2026-faith-and-heritage-stand-out-across-southeast-asia-302906874.html)
- Traveloka localises consumer content per market (e.g. `/en-th/` for English-in-Thailand), indicating English remains a working lingua franca layered over local languages — [Traveloka Explore en-th](https://www.traveloka.com/en-th/explore/tips/how-travel-technology-makes-trips-easier/92253)
- RED's 300M+ MAU makes Chinese-language content the richest single structured-guide corpus for SEA destinations — [Rest of World](https://restofworld.org/2024/xiaohongshu-southeast-asia-tourism/)

### Inferences
- Language priority, inferred: **English (regional lingua franca, SG/MY/PH) → Chinese Simplified + Traditional (CN outbound, SG, MY Chinese, TW, HK) → Bahasa Indonesia/Melayu (largest population bloc) → Thai (largest inbound-tourism destination) → Vietnamese**. This ordering is my inference from the demand corridors and Traveloka's localisation, **not** a sourced finding.
- Source-platform priority is the harder problem and the real differentiator: Instagram Reels/Saved posts and TikTok dominate SEA inspiration, Facebook Groups remain heavily used in ID/PH/TH, RED serves Chinese-speaking users, and YouTube serves long-form. A SEA extractor that only does RED has a Chinese-speaking-only addressable market; one that does Instagram/TikTok has a regional one but loses the structured day-by-day richness that makes RED notes extractable in the first place.
- Screenshot/OCR ingestion is disproportionately valuable in SEA, because it is the only platform-agnostic, ToS-safe ingestion path and it matches how SEA users actually hoard inspiration (screenshots and saved Reels).

### Gaps
- **This section is the weakest in the file.** I have no sourced data on which social platforms SEA travellers actually use for trip planning, by country — no Instagram vs TikTok vs Facebook vs RED split, no survey, no platform MAU-by-country figures for SEA. Treat the source-platform ordering above as hypothesis only.
- I could not confirm which 3 locales Paths ships, nor whether Paths can parse Xiaohongshu links from outside China, nor whether it parses Instagram or TikTok. Needs a manual install/test — this is the highest-value single piece of primary research remaining.
- No data on willingness to pay for travel planning tools in SEA markets, which matters given 圆周旅迹's inability to monetize in China.

---

## Environment and method notes (for the report writer)

- **WebFetch could not render JS-heavy SPAs**: `pitravel.cn`, `gopaths.ai`, `gopaths.ai/trip` all returned only shell HTML/nav. Google Play's page for `ai.gopaths.pitravel` returned truncated content. 知乎 returned **HTTP 403** on both articles I tried (`p/2047322767398384530`, `p/17891744223`) — in one case I recovered the substance via the 虎嗅 version of the same piece.
- **Primary records obtained by local `whois`** (no citable URL; reproducible): `gopaths.ai` and `pitravel.cn`. The gopaths.ai record is unredacted and is the single most important new fact in this research. Xiaohongshu's own domains (`xiaohongshu.com`, `xhscdn.com`, `rednote.net`) are WHOIS-redacted, so I could not corroborate the YOUTONG TRADING entity against them beyond a matching registrar/jurisdiction on `rednote.net`.
- **Could not access**: Singapore ACRA (BLANK CRAFT PTE. LTD. ownership), 国家企业信用信息公示系统 (超超世世 shareholders), 七麦/点点数据/Sensor Tower (download and ranking data), Huawei AppGallery, App Store CN review text, SG/MY/TW/HK storefront charts, 小红书 用户协议 and robots.txt.
- **Searched for and did not find**: any Tech in Asia / e27 / Vulcan Post / TechNode / KrASIA / 36氪 / 虎嗅 / 晚点 coverage of 圆周旅迹's corporate situation, of Paths, or of SEA social-extraction travel startups; any acquisition or investment linking 小红书 to 超超世世; any named Chinese competitor on the link-extraction primitive (探途 / 游迹 / 妙计 all returned nothing on point).
- **Date caution**: the 环球旅讯 feature (the best source on 圆周旅迹's scale and monetization) references the Oct 2024 Golden Week and "launched over a year ago", so its ~10M registered users figure is likely 2024–2025 vintage and may be stale as of Oct 2026.
- **Sentiment caution**: every user-opinion finding I could source is positive, because the only reachable sources were vendor-adjacent write-ups and promotional RED notes. Do not present this as a balanced read on user satisfaction.
