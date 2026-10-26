# Purr Pot analytics plan

Owner: growth-analyst. Written 2026-10-25, aligned the same day with the designer's data-model.md section 16 (event names) and gdd.md (loop, economy, areas). Implementer: luau-engineer, server side only, feature F16 in features.md. Read with comps.md (why these numbers) and monetization.md (what the purchase events feed).

Naming follows data-model.md: ids and event names are lower snake_case and never change once shipped. Where this plan adds to section 16 it says so; the designer's names win on conflict.

## 1. What we want to know, and where it comes from

| Question | Metric | Source | Code needed |
|---|---|---|---|
| Do players come back? | D1, D7, D30 retention, split by acquisition source and compared to the Simulation genre benchmark set | Creator Hub, Experience Overview and Retention pages | None. Roblox tracks it once the game is published. |
| Do sessions hold attention? | Average session length, sessions per daily active user | Creator Hub, Engagement | None |
| Where do new players quit in the first 10 minutes? | Onboarding funnel conversion per step | AnalyticsService onboarding funnel | Yes, section 3 |
| Does the catch loop convert, grab and lure separately? | Recurring funnel: spotted to placed | AnalyticsService recurring funnel | Yes, section 4 |
| Is the coin economy balanced? | Sources vs sinks, average wallet, top sinks | AnalyticsService economy events | Yes, section 5 |
| Which cats, foods and upgrades do players actually chase? | Custom events by cat, area, method and item | AnalyticsService custom events | Yes, section 6 |
| Do players progress? | Cafe level start and complete rates | AnalyticsService progression events | Yes, section 7 |
| Does the thumbnail work? | Qualified play-through rate on Home recommendations | Creator Hub, Acquisition | None |
| Does anyone pay, and for what? | Conversion, revenue per pass and product | Creator Hub, Monetization; plus the IAP economy events below | Partly (soft launch only) |

Targets by phase are in section 9.

## 2. Platform limits the plan is built around

Source: Roblox event types docs, AnalyticsService reference, economy and funnel event docs, read 2026-10-25.

- Events send only from the server and only in a published experience. Studio and the client send nothing. Test in a privately published dev experience, then confirm with the View Events tool in Creator Hub. Dashboards take about 24 hours to fill. Data is kept 90 days from the last event.
- Rate limit: 120 plus 20 times concurrent users events per minute per server. At 8 players per server that is 280 events a minute. Anything that can fire more than once a minute per player is batched (section 5).
- Custom fields: up to 3 per event. This is why section 16's `cat_caught` list of five fields is split below. Values are unlimited, but after 8,000 distinct values across all fields the rest become "Other". Keep values to short enum-like strings, never player names, chat text or free text.
- Economy: 5 currencies (the overview page says 10, the economy page says 5; plan for 5), transaction types group into "Other" after 20, item SKUs after 100. Purr Pot has one currency, coins.
- Funnels: 10 funnels with dashboard tabs, 100 steps each. Skipping steps marks earlier steps complete. Repeated steps count once. A player's saved onboarding step expires after 180 days away.
- Custom events: 100 event names.
- Funnel session ids: only the 10 most recent per player per funnel are tracked. Use one GUID per attempt.
- Log after success, never on attempt (the purchase completed, the cat was placed).
- Client-reported steps (shop opened, item viewed) go through one validated, rate-limited remote; everything else is fired by the server system that already knows the truth.

## 3. Onboarding funnel (one-time, LogOnboardingFunnelStepEvent)

Section 16 names kept, four steps added (marked +). The funnel follows "The first ten minutes" in gdd.md, then the first week.

| Step | stepName | Fired when | Owner (data-model) |
|---|---|---|---|
| 1 | joined | PlayerAdded, after the profile loads | DataService |
| 2 | saw_alley | Character first enters the Alley area volume | Areas |
| 3 | first_catch | First successful GrabEnd or lured catch (the cat is in the player's arms) | Catching |
| 4 | + first_checkin | First CheckIn at the cafe door; the cat is in the cat room | Catching |
| 5 | first_place | First PlaceCat succeeds | Spots |
| 6 | first_table | BuyUpgrade tables level 1 | Shop |
| 7 | cafe_level_2 | BuyUpgrade cafe_level to 2 | Shop |
| 8 | + first_lure | First UseLure (the lure bowl has been bought and food used) | Lures |
| 9 | park_unlocked | Park unlocked | Areas |
| 10 | + returned_next_day | PlayerAdded when the previous session ended on an earlier UTC calendar day | DataService |
| 11 | + first_offline_claim | First ClaimOffline | Income |
| 12 | cafe_level_5 | BuyUpgrade cafe_level to 5 | Shop |

Custom field on step 1 only: `device` with values `phone`, `tablet`, `pc`, `console`, derived on the server from one validated client report at join. Filters apply to step 1, so this gives phone vs PC drop-off per step.

Reading it: the first big drop is the onboarding ticket of the week. The slice exit test (gdd: minute 10 target is 3 cats placed, 2 tables, cafe level 2 or 3) maps to steps 1 through 7 in under 10 minutes.

## 4. Recurring funnels (LogFunnelStepEvent)

Addition to section 16. Each attempt gets a GUID from HttpService:GenerateGUID(false) created on the server when step 1 fires. Three funnels in v1, seven spare.

### 4.1 catch_attempt

| Step | stepName | Fired when |
|---|---|---|
| 1 | engaged | GrabBegin accepted (lock set), or a lured stray spawned for this player |
| 2 | caught | GrabEnd success, or the lured stray caught |
| 3 | checked_in | CheckIn adds the cat instance |
| 4 | placed | PlaceCat for that cat uid |

Custom fields: `rarity` (common, rare, epic, legendary), `method` (grab, lure_kibble, lure_tuna, lure_salmon), `area` (alley, park). Drop from 1 to 2 is catch difficulty by rarity and gloves (compare with gdd base chances 90 / 65 / 45 / 25). Drop from 2 to 3 is the carry phase (did the player get home). Drop from 3 to 4 is spot pressure: cats parked in the cat room because every spot is full, which is the signal that spots or cafe levels are priced too high.

### 4.2 shop_checkout (coins)

| Step | stepName | Fired when |
|---|---|---|
| 1 | opened | Shop screen opened (client report, validated) |
| 2 | viewed | Item detail opened (client report, item id validated against the catalog) |
| 3 | bought | BuyUpgrade, BuyDecor or BuyLure succeeds |

Custom fields on step 2 and 3: `category` (upgrade, decor, lure, area), `item` (catalog id), `affordable` (yes, no). High view-to-buy drop with `affordable=no` means prices outrun income; with `affordable=yes` the item is not wanted.

### 4.3 robux_purchase (soft launch only)

| Step | stepName | Fired when |
|---|---|---|
| 1 | prompted | Server records that PromptGamePassPurchase or PromptProductPurchase was requested for this player |
| 2 | completed | PromptGamePassPurchaseFinished with wasPurchased true, or ProcessReceipt granted |

Custom fields: `sku` (pass or product id from monetization.md), `source` (shop, hud, offer_card), `restricted` (yes, no, from the cached PolicyService result). Prompt-to-complete under 10% on an item means the price or pitch is wrong; under 3% means remove the surface that prompts it.

## 5. Economy events (LogEconomyEvent)

One currency: `coins`. Section 16's source and sink names are kept as item SKUs; the transactionType column uses the Roblox enum names so the dashboard categories work. Amount is always positive, flowType says Source or Sink, endingBalance is the wallet after the transaction.

Income is accounted lazily (coins plus lastTick, data-model section 11), so tips are not an event per second. The accumulator in section 8 logs the tips accrued since the last log whenever the wallet is read for a spend, and at least once every 60 seconds while the player is online, and on PlayerRemoving.

| What happens | flowType | transactionType | itemSku | Aggregation |
|---|---|---|---|---|
| Tips accrued from placed cats | Source | Gameplay | tips | Batched: once per minute per player, plus before each spend and on leave |
| Duplicate cat sold (SellCat) | Source | Gameplay | sell_cat | One per sale; custom field `rarity` |
| Offline earnings claimed (ClaimOffline) | Source | TimedReward | offline | One per claim |
| First catch reward (collection reward when a cat is new) | Source | Onboarding for the very first cat, Gameplay for later new-cat rewards | first_catch_reward, collection_reward | One per grant |
| Starter coins (50 on first join) | Source | Onboarding | start_coins | Once |
| Coins granted by a Robux cash product (soft launch, only if monetization.md option B is chosen) | Source | IAP | the product sku, for example cash_small | One per receipt, after ProcessReceipt grants |
| Upgrade bought (BuyUpgrade, incl. cafe_level, tables, espresso, gloves, lure_bowl) | Sink | Shop | upgrade id, for example tables, cafe_level | One per purchase; custom field `level` |
| Decor bought (BuyDecor) | Sink | Shop | decor id | One per purchase |
| Food bought (BuyLure) | Sink | Shop | lure id: kibble, tuna, salmon | One per purchase |
| Park unlocked | Sink | Shop | area_park | One |

Custom fields on every economy event: `cafe_level` (1, 2, 3, 4, 5) and `cats_placed` (bucketed 1, 2 to 3, 4 to 5, 6 to 7). Section 16 uses `upgrade`, `decor` and `lure` as sink names; they are the `category` custom field value here and the specific id is the SKU, so the dashboard can show both "lure" as a category and "salmon" as an item.

Dashboard health rule: net sources minus sinks per day should sit near zero once players have things to buy. A wallet that climbs for a week means a desirable sink is missing at that level. A wallet pinned near zero with a high `affordable=no` rate in shop_checkout means income is too slow. Watch `sell_cat`: if it is a top source, duplicates are too common or prices too high.

## 6. Custom events (LogCustomEvent)

Section 16's three events, adjusted to the 3-field limit, plus nine additions (+). Values are counts unless noted. 100 names available; v1 uses 12.

| eventName | value | customFields (max 3) | Fired when | Why |
|---|---|---|---|---|
| cat_caught | 1 | cat_id, area, method (grab_perfect, grab_good, grab_miss, lure_kibble, lure_tuna, lure_salmon) | CheckIn adds the cat | Which cats players get and how. Rarity is derived from cat_id in the catalog, so it does not need a field. Section 16's ringResult is folded into method. |
| grab_failed | 1 | rarity, reason (ring_miss, chance_roll, lock_expired, out_of_range), area | GrabEnd fails | Catch difficulty tuning and the cheating check (a client that never misses the ring) |
| session_end | seconds played | cats_caught bucket (0, 1 to 2, 3 to 5, 6+), coins_earned bucket (under 500, 500 to 2k, 2k to 8k, 8k+), device | PlayerRemoving | Section 16's session_end with its two numbers bucketed into fields |
| + lure_used | 1 | lure_id, area, result_rarity | Lured stray spawns and its rarity is rolled | Audit the shown food odds against real results. Required if coins are ever sold (monetization.md section 7). |
| + cat_sold | 1 | cat_id, rarity | SellCat | Which duplicates get dumped |
| + cat_room_full | 1 | cafe_level | CheckIn succeeds while every open spot is taken | Spot pressure |
| + spot_favorite | 1 | cat_id, spot_type, favorite (yes, no) | PlaceCat | Do players use the favorite-spot bonus |
| + offline_claim | coins claimed | hours_away bucket (under 1, 1 to 4, 4 to 12, 12+) | ClaimOffline | Tune the one-hour cap and the 2-hour pass |
| + ui_opened | 1 | screen (shop, collection, settings, catbook) | Client report, allowlisted | Which screens are found at all |
| + tutorial_step | 1 | step | TutorialAdvance | Compare with funnel steps to see which beats land |
| + announcement_seen | 1 | rarity | Server fires a catch announcement | Social loop volume |
| + error_recovered | 1 | system (datastore, catalog, remote) | Server recovers from a known failure | Engineering health without reading logs |

`cat_caught` and `cat_sold` carry cat_id (12 values in the slice, 40 at launch) which is fine against the 8,000-value limit.

## 7. Progression events (LogProgressionEvent)

Addition to section 16.

| progressionPathName | level | levelName | Start fires when | Complete fires when |
|---|---|---|---|---|
| cafe_level | 1 to 5 | cafe_1 to cafe_5 | Player reaches level N | Player reaches level N+1 |
| collection | 1 to 4 | common_set, rare_set, epic_set, legendary_set | First cat of the rarity found | Every cat of the rarity found |

Use LogProgressionStartEvent and LogProgressionCompleteEvent. No Fail events; nothing in Purr Pot fails. Custom field: `cats_placed` bucket.

## 8. Implementation notes for luau-engineer

- One server module, `src/server/Services/Telemetry.luau` (not AnalyticsService; that is Roblox's class). Typed functions: `OnboardingStep(player, stepName)`, `FunnelStep(player, funnel, sessionId, stepName)`, `Economy(player, flow, amount, balance, txType, sku, fields)`, `Custom(player, name, value, fields)`, `ProgressStart` and `ProgressComplete`. Step numbers are looked up from an ordered list so the call sites use names. All names live in `src/shared/TelemetryNames.luau` as string constants so typos fail under --!strict.
- The accumulator: per-player `{tipsSinceLog, lastLogAt}` flushed by a 60-second loop, before every Sink event (so endingBalance is right) and on PlayerRemoving. The engineer may fold this into the lazy income tick.
- Custom field dictionaries use Roblox's fixed key enum, pattern `{[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "value"}`. Confirm the enum name against the AnalyticsService reference when implementing.
- Wrap every Log call in pcall. Telemetry must never throw into gameplay code.
- Client-reported events (shop opened, item viewed, ui_opened, device) go through one RemoteEvent `TelemetryReport` with a server allowlist of names and values and a rate limit of 10 per minute per player. Add it to data-model section 15 as a Proposed row.
- Do not log PII, chat text, usernames or free text.
- Verify in the dev experience with Creator Hub > Analytics > View Events before the friends alpha. QA's loop script (features.md section 8) should assert that onboarding steps 1 to 7 fire in order during one scripted run.

## 9. Targets and review cadence

Benchmarks from the GameAnalytics 2026 Roblox report (titles over 1 million MAU, updated 2026-09-01): median D1 10.3%, D7 1.6%, session 9.8 minutes, 1.56 sessions per player per day; 90th percentile D1 about 15.9%, session 14.7 minutes.

| Phase | What to look at | Target | If missed |
|---|---|---|---|
| 2 Slice | Onboarding steps 1 to 7 fire in order in the QA loop script | All fire, loop under 10 minutes | Engineering ticket |
| 3 Friends alpha | No onboarding step under 70% of the previous one among friends; session_end median over 10 minutes; catch_attempt 1 to 2 near the gdd base chances | Everything fires; the loop completes in under 10 minutes | Fix the step with the biggest drop before adding anything |
| 4 Soft launch, first 2 weeks (needs about 100 new players a day to read) | D1, session length, catch_attempt conversion, economy net flow | D1 at or above 12%, session at or above 10 minutes, catch 1 to 2 conversion 60 to 80% | Decision rules in comps.md section 8 |
| 5 Iterate | D7, offline_claim hours_away mix, robux_purchase prompt-to-complete, wallet trend, lure_used odds audit | D7 at or above 3%, prompt-to-complete over 10% on every live SKU, lure results within 2 points of the shown odds | Cut or re-price the SKU; add a sink at the wallet plateau level; fix the roll if odds drift |

Weekly ritual (Sunday, after the Saturday update): growth-analyst reads the five dashboards, writes ten lines to docs/growth/weekly/<date>.md (D1, D7, session, funnel worst step, top sink, top source, catch conversion, Robux conversion, one surprise, one action), and files the action as a ticket for the designer or QA.

## 10. Out of scope for v1

- Third-party analytics (GameAnalytics SDK or similar). Roblox's built-in dashboards cover retention, engagement and monetization; add a third party only if we need cohort exports.
- Our own DataStore-based metrics beyond lifetimeCoins for leaderboards. Do not build what Creator Hub already shows.
- A/B tests. Roblox's price optimization needs about 60,000 transactions in 30 days. Manual before-and-after comparisons with the funnel date filter are enough.

Proposed for docs/decisions.md: 2026-10-25, Purr Pot ships the section 16 onboarding funnel (extended to 12 steps), three recurring funnels, one-currency economy events and 12 custom events through a single server Telemetry module as feature F16, because retention and session length cannot be improved without seeing where new players stop.

## Addendum 2026-10-25 (evening): events for the launch-phase features in common-features.md

| eventName | value | customFields (max 3) | Fired when | Why |
|---|---|---|---|---|
| code_redeemed | 1 | code_id, reward_type (coins, food, catnip), days_since_release bucket (0, 1 to 7, 8 to 30, 31+) | Chalkboard redemption succeeds on the server | Which codes and which guide-site waves bring players (launch-ops.md section 1) |
| code_failed | 1 | reason (unknown, expired, already_used, rate_limited) | Chalkboard redemption fails | Spot brute-force attempts and typo-prone codes |
| regulars_claimed | 1 | member (yes, no) | Group check completes on join | Share of players in the group |
| daily_treat_claimed | 1 | day (1 to 7), streak_outcome (continued, restarted) | Daily Treat claim | How many players reach day 7 and how often the streak breaks |
| request_completed | 1 | request_id, day_slot (1, 2, 3, bonus) | Customer Request completes | Which daily tasks players finish |
| lure_used (changed) | 1 | lure_id, buff (none, catnip), result_rarity | Lured stray spawns | The odds audit must separate Catnip-boosted rolls from base rolls; `area` dropped because lure odds are per food, not per area |

Adoption Van purchases log as a Shop sink with SKU `van_<cat_id>`; Renovate logs as a Gameplay sink with SKU `renovate_N`; Nap Pod merges log as `cat_merged` with fields cat_id, from_variant, to_variant. Custom event names in use after this addendum: 20 of 100.
