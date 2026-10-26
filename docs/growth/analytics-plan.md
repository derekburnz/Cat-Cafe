# Purr Pot analytics plan

Owner: growth-analyst. v0.3, 2026-10-26: rebuilt on design v0.3 (data-model.md v0.3: tiers, roles, closing-circle net, rescue minigames, bait bowl, carry bumps, shinies, night dealer, rich customers). v0.1 was written 2026-10-25 on design v0.2. Implementer: luau-engineer, server side only, feature F16 in features.md. Read with comps.md (why these numbers), monetization.md (what the purchase events feed) and launch-ops.md (codes, group bonus, update board).

Naming follows data-model.md: ids and event names are lower snake_case and never change once shipped. The designer's data-model section 16 points here; where the two differ, raise it with the designer rather than silently diverging.

## 1. What we want to know, and where it comes from

| Question | Metric | Source | Code needed |
|---|---|---|---|
| Do players come back? | D1, D7, D30 retention, split by acquisition source and compared to the Simulation genre benchmark set | Creator Hub, Experience Overview and Retention pages | None. Roblox tracks it once the game is published. |
| Do sessions hold attention? | Average session length, sessions per daily active user | Creator Hub, Engagement | None |
| Where do new players quit in the first 10 minutes? | Onboarding funnel conversion per step | AnalyticsService onboarding funnel | Yes, section 3 |
| Does catching convert, net and rescue separately? Does bait bring players back? | Recurring funnels | AnalyticsService recurring funnels | Yes, section 4 |
| Is the coin economy balanced, day and night? | Sources vs sinks, average wallet, top sinks | AnalyticsService economy events | Yes, section 5 |
| Is the net fair on touch, and are bumps fun or griefing? | Circle scores by rarity and net level; bump outcomes and what the bumped player does next | AnalyticsService custom events | Yes, section 6 |
| Do players progress through tiers and areas? | Tier and area book start and complete | AnalyticsService progression events | Yes, section 7 |
| Is anyone auto-pressing the circles? | Per-player perfect rate and timing spread | Server-side check, not analytics | Yes, section 8 |
| Does the thumbnail work? | Qualified play-through rate on Home recommendations | Creator Hub, Acquisition | None |
| Does anyone pay, and for what? | Conversion, revenue per pass | Creator Hub, Monetization; plus the robux_purchase funnel | Soft launch only |

Targets by phase are in section 10.

## 2. Platform limits the plan is built around

Source: Roblox event types docs, AnalyticsService reference, economy and funnel event docs, read 2026-10-25.

- Events send only from the server and only in a published experience. Studio and the client send nothing. Test in a privately published dev experience, then confirm with the View Events tool in Creator Hub. Dashboards take about 24 hours to fill. Data is kept 90 days from the last event.
- Rate limit: 120 plus 20 times concurrent users events per minute per server. At 8 players that is 280 a minute. Budget in section 9.
- Custom fields: up to 3 per event. Values are unlimited, but after 8,000 distinct values across all fields the rest become "Other". Keep values to short enum-like strings, never player names, cat names, chat text or free text.
- Economy: plan for 5 currencies (Purr Pot uses one, coins), transaction types group into "Other" after 20, item SKUs after 100.
- Funnels: 10 funnels with dashboard tabs, 100 steps each. Logging a step marks every earlier step complete, and repeated steps count once. That makes step order matter: section 3.2 explains how the server keeps it honest. A player's saved onboarding step expires after 180 days away.
- Custom events: 100 names. This plan uses 28.
- Funnel session ids: only the 10 most recent per player per funnel are tracked. One GUID per attempt, or a persistent key where the attempt spans sessions (bait).
- Dashboards are aggregates. There is no per-player query or export, so anything that must act on one player (the auto-press check) lives on the server, not in analytics.
- Log after success, never on attempt.

## 3. Onboarding funnel (one-time, LogOnboardingFunnelStepEvent)

### 3.1 Steps

Follows "The first ten minutes" and tutorialStep 1 to 5 in data-model v0.3, then the first week.

| Step | stepName | Fired when | v0.3 change |
|---|---|---|---|
| 1 | joined | PlayerAdded, after the profile loads. Custom field `device` (phone, tablet, pc, console) from one validated client report | |
| 2 | saw_alley | Character first enters the Alleyway area volume (tutorialStep 1) | |
| 3 | first_catch | First CatchResult success (the cat is in the player's arms) | was GrabEnd |
| 4 | first_checkin | First CheckIn adds a cat | |
| 5 | first_role | First PlaceCat into a role slot (tutorialStep 3) | replaces first_place |
| 6 | first_table | BuyUpgrade tables to level 1 (tutorialStep 4) | |
| 7 | first_bait | First UseLure: bowl bought and food in (tutorialStep 5) | replaces first_lure |
| 8 | first_bait_resolved | First ResolveBait, tame or let go. Ten minutes after step 7 at the earliest, so this step measures whether players wait or come back | new |
| 9 | tier_2 | RankUp to Tier 2 (opens the Park) | replaces cafe_level_2 and park_unlocked |
| 10 | returned_next_day | PlayerAdded when the previous session ended on an earlier UTC calendar day | |
| 11 | first_offline_claim | First ClaimOffline | |
| 12 | tier_3 | RankUp to Tier 3 (12 different cats and one Epic) | replaces cafe_level_5 as the first-week goal |

The slice exit test (a new player completes one loop in under 10 minutes) maps to steps 1 to 7.

### 3.2 Keeping the order honest

Players will not always follow the tutorial order. A player can rank up before setting bait, or come back the next day before ranking up. If the server logged tier_2 (step 9) first, Roblox would mark steps 1 to 8 complete and the funnel would show conversions that never happened.

Rule for the engineer: keep `telemetry = { onboardingStep, achieved }` in the profile (needs a data-model row; proposed to the designer). When an action matches step `onboardingStep + 1`, log it, advance, then keep logging any already-achieved later steps in order. When an action matches a later step, add it to `achieved` and log nothing yet. Steps never log out of order, and nothing is lost.

## 4. Recurring funnels (LogFunnelStepEvent)

Four funnels, six spare.

### 4.1 catch_attempt (net and rescue)

| Step | stepName | Fired when |
|---|---|---|
| 1 | engaged | GrabBegin accepted (schedule sent), or RescueBegin accepted (challenge sent) |
| 2 | caught | CatchResult success, or RescueResult success |
| 3 | checked_in | CheckIn adds the cat |
| 4 | working | PlaceCat puts that cat uid in a role slot |

Session id: GUID created at step 1, held with the carry state. Custom fields: `rarity`, `method` (net, rescue, net_dropped for a stray that was knocked loose), `area`.

Reading it: 1 to 2 is catch difficulty by rarity (compare with the net feel targets in data-model section 10). 2 to 3 is the carry home, which now includes bumps: a drop here that grew after bumps shipped is the bump cost. 3 to 4 is slot pressure (role slots full at the player's tier).

### 4.2 bait_cycle

| Step | stepName | Fired when |
|---|---|---|
| 1 | set | UseLure rolls and saves `bait` |
| 2 | seen | The bait card is shown to the owner (BaitReady fired while online, or on the first join after it became ready) |
| 3 | tamed | ResolveBait tame |

Session id: `<userId>-<placedAt>`, a persistent key because the 10-minute timer runs offline. Custom fields: `lure_id`, `source` (shop, dealer), `rarity` of the rolled cat. Drop from 1 to 2 is players who never come back for their bait. Drop from 2 to 3 is the let-go rate, which should be low except for Commons and duplicates.

### 4.3 shop_checkout (coins: shop and dealer)

| Step | stepName | Fired when |
|---|---|---|
| 1 | opened | Shop screen or dealer screen opened (client report, validated) |
| 2 | viewed | Item card opened (client report, id validated against the catalog or tonight's dealer slots) |
| 3 | bought | BuyUpgrade, BuyDecor, BuyLure or BuyDealerFood succeeds |

Custom fields on steps 2 and 3: `category` (upgrade, decor, food, dealer), `item` (catalog id), `affordable` (yes, no). A high view-to-buy drop with `affordable=no` means prices outrun income; with `affordable=yes` the item is not wanted.

### 4.4 robux_purchase (soft launch only)

| Step | stepName | Fired when |
|---|---|---|
| 1 | prompted | Server records a PromptGamePassPurchase request |
| 2 | completed | PromptGamePassPurchaseFinished with wasPurchased true |

Custom fields: `sku` (pass id from monetization.md), `source` (shop, hud, offer_card), `restricted` (yes, no, from the cached PolicyService result). Prompt-to-complete under 10% on a pass means the price or pitch is wrong; under 3% means remove the surface that prompts it.

## 5. Economy events (LogEconomyEvent)

One currency: `coins`. Amount is always positive, flowType says Source or Sink, endingBalance is the wallet after the transaction. transactionType uses Roblox's enum names where they fit, plus one custom name (`Promo`) for codes.

Income is accounted lazily (coins plus lastTick) and now integrates the 60% night rate, so tips are never an event per second. The accumulator logs the tips settled since the last log at least once a minute while the player is online, before every Sink (so endingBalance is right) and on PlayerRemoving.

Custom fields on every economy event: `tier` (1 to 5), `phase` (day, night), `cats_working` bucket (1, 2 to 3, 4 to 6, 7 to 10).

| What happens | flowType | transactionType | itemSku |
|---|---|---|---|
| Tips settled from working cats | Source | Gameplay | tips |
| Rich customer tip, claimed or auto-added | Source | Gameplay | rich_tip |
| Cat sold | Source | Gameplay | sell_cat |
| Offline earnings claimed | Source | TimedReward | offline |
| First catch of the very first cat | Source | Onboarding | first_catch_reward |
| First catch of any later new cat | Source | Gameplay | collection_reward |
| Starter coins | Source | Onboarding | start_coins |
| Daily Treat coins (launch) | Source | TimedReward | daily_treat_<day> |
| Customer Request coins (launch) | Source | Gameplay | request_<id> |
| Code coins (launch) | Source | Promo | code_<id> |
| Upgrade bought: tables, espresso, net, lure_bowl | Sink | Shop | upgrade id |
| Decor bought | Sink | Shop | decor id |
| Shop food bought | Sink | Shop | kibble, tuna, salmon |
| Dealer food bought | Sink | Shop | dealer_<lure_id> |
| Rank up | Sink | Gameplay | rank_up_<tier> |
| Adoption Van cat bought (launch) | Sink | Shop | van_<rarity> |

Using food at the bowl spends no coins and is not an economy event; bait_rolled and the bait_cycle funnel cover it. The v2 to v3 save migration refunds are not logged; they only touch test saves.

Dashboard health: net sources minus sinks per day should sit near zero once players have things to buy. A wallet that climbs for a week means a desirable sink is missing at that tier (watch whether rank_up costs absorb it). A wallet pinned near zero with a high `affordable=no` rate means income is too slow. If `sell_cat` is a top source, duplicates are too common or worth too much. Filter by `phase` to see whether night play earns enough to feel worth it at 60%.

## 6. Custom events (LogCustomEvent)

Values are counts unless noted. Never log a cat's player-given name, a username or chat.

### 6.1 Catching, rescue and bait

| eventName | value | customFields (max 3) | Fired when | Why |
|---|---|---|---|---|
| cat_caught | 1 | cat_id, method (net, rescue, bait, net_dropped), variant (base, shiny) | A cat joins the player: CheckIn, or ResolveBait tame | Which cats players get and how. Area and rarity come from cat_id in the catalog. |
| catch_circles | catch chance as a whole percent | rarity, net_level (0 to 3), perfect_count (0 to 5) | After the last circle of every net attempt, success or fail | Net fairness: average chance by rarity and net level. Feel target: Common on a Basic Net mostly caught. |
| rescue_attempt | 1 | trap (trash_bin, garbage_bag, tree, trashcan, ...), rarity, result (freed, out_of_paws, cancelled, missed_catch) | RescueResult with done true, or RescueCancel | Which traps are too hard on touch |
| bait_rolled | 1 | lure_id, rarity, buff (none, catnip) | UseLure rolls the cat | Odds audit: results against the food card, base and boosted separately (monetization.md section 7) |
| bait_resolved | 1 | lure_id, rarity, choice (tame, letgo) | ResolveBait | Let-go rate by food and rarity |
| shiny_found | 1 | method (net, rescue, bait), rarity, first_of_cat (yes, no) | A shiny joins the player | Shiny rate against 2%, 2%, 10% |

### 6.2 Bumps

Bumps are the first player-versus-player contact in the game, and the GDD names griefing as a risk with a server switch. These three events decide whether they stay after the friends alpha.

| eventName | value | customFields (max 3) | Fired when | Why |
|---|---|---|---|---|
| bump | 1 | result (dropped, held), rarity of the carried cat, area | Bump passes every server check and rolls | How often bumps happen and land |
| drop_outcome | 1 | recaught_by (carrier, bumper, other, nobody), rarity, area | A dropped stray is caught, or despawns at the next night | Does the bumper usually end up with the cat? If yes, bumping is stealing in practice. |
| left_after_bump | 1 | rarity, seconds_after (under 30, 30 to 120) | A player whose cat was knocked loose leaves the server within 120 s | The griefing signal. Compare its rate with session_end for players never bumped. |

### 6.3 Cafe and progression

| eventName | value | customFields (max 3) | Fired when | Why |
|---|---|---|---|---|
| rank_up | lifetime minutes played | tier | RankUp succeeds | Time to each tier (designer's tier pacing) |
| dealer_buy | coins spent | lure_id, tier, slot (1 to 3) | BuyDealerFood | Which dealer foods sell at which tier |
| rich_tip | coins | outcome (claimed, auto), tier | Rich tip claimed or auto-added | Is the rich customer noticed at all |
| role_favorite | 1 | cat_id, role, favorite (yes, no) | PlaceCat | Do players use the 1.5x favorite role |
| slots_full | 1 | tier | A cat joins while every open role slot is taken | Slot pressure per tier |
| cat_sold | 1 | cat_id, variant | SellCat | Which cats get dumped |
| cat_renamed | 1 | rarity | RenameCat succeeds | Naming adoption. Never the name. |
| offline_claim | coins | minutes_away (under 15, 15 to 60, capped) | ClaimOffline | Is the one-hour cap reached often (tests the Long Nap pass) |

### 6.4 Session, UI and health

| eventName | value | customFields (max 3) | Fired when | Why |
|---|---|---|---|---|
| session_end | seconds played | cats_caught bucket (0, 1 to 2, 3 to 5, 6+), tier, device | PlayerRemoving | Session length by progress and device |
| ui_opened | 1 | screen (shop, collection, shiny_book, dealer, rank_up, settings) | Client report, allowlisted | Which screens are found at all |
| tutorial_step | 1 | step | TutorialAdvance | Which beats land |
| announce_sent | 1 | rarity, shiny (yes, no) | Server fires an Announce | Social moment volume |
| error_recovered | 1 | system (datastore, catalog, remote, policy, filter) | Server recovers from a known failure | Health without reading logs |
| catch_flagged | 1 | reason (perfect_rate, low_spread), net_level | Section 8 check trips, at most once per player per session | Volume of suspected auto-pressers |

### 6.5 Launch-phase features (common-features.md)

| eventName | value | customFields (max 3) | Fired when | Why |
|---|---|---|---|---|
| code_redeemed | 1 | code_id, reward_type (coins, food, catnip), days_since_release bucket (0, 1 to 7, 8 to 30, 31+) | Chalkboard redemption succeeds | Which codes and guide-site waves bring players (launch-ops.md) |
| code_failed | 1 | reason (unknown, expired, already_used, rate_limited) | Chalkboard redemption fails | Brute-force attempts and typo-prone codes |
| regulars_claimed | 1 | member (yes, no) | Group check completes on join | Share of players in the group |
| daily_treat_claimed | 1 | stamp (1 to 7), card (first, repeat) | Daily Treat stamp claimed | How many players fill a card. The card no longer resets, so there is no streak field. |
| request_completed | 1 | request_id, slot (1, 2, 3, bonus) | Customer Request completes | Which daily tasks players finish |

Removed from v0.1: grab_failed (the catch_attempt funnel and catch_circles cover it), lure_used (now bait_rolled), spot_favorite (now role_favorite), cat_room_full (now slots_full), cat_merged (Nap Pod dropped), and the coins-earned field on session_end (replaced by tier).

## 7. Progression events (LogProgressionEvent)

| progressionPathName | level | levelName | Start fires when | Complete fires when |
|---|---|---|---|---|
| tier | 1 to 5 | corner, cozy, busy, famous, grand | Player reaches tier N | Player reaches tier N+1 |
| area_book | 1 to 5 | alley, park, neighbourhood, woods, sewer | Area unlocked | All 10 of the area's cats in the collection |

LogProgressionStartEvent and LogProgressionCompleteEvent only; nothing in Purr Pot fails. Custom field: `cats_distinct` bucket (1 to 4, 5 to 11, 12 to 19, 20 to 29, 30+), matching the tier thresholds.

## 8. Auto-press check (server side, not analytics)

Data-model section 10 asks telemetry to carry per-circle error so auto-pressers can be flagged (Perfect rate over 95% across 50 circles with an error spread under 10 ms). AnalyticsService cannot do this: dashboards are aggregates with no per-player view, and an event per circle would cost up to five events per catch.

Do it in CatService instead:
- Keep a ring buffer of the last 50 judged circles per player in server memory: the latency-corrected error in milliseconds and the grade.
- After each judged circle with a full buffer, compute the Perfect rate and the standard deviation of the error. Human timing on a touch screen typically spreads by tens of milliseconds; a script with a fixed offset spreads by a few.
- On a trip: log `catch_flagged` once per session, set `profile.flags.autoPress = os.time()` (needs a data-model row; proposed to the designer) and keep playing normally. No automatic punishment in the slice; the lead reviews flags by hand.
- The profile already counts perfectCircles and circlesTotal, which give the lifetime Perfect rate for any flagged player.

## 9. Implementation notes for luau-engineer

- One server module, `src/server/Services/Telemetry.luau` (not AnalyticsService; that is Roblox's class), with typed functions: `OnboardingStep(player, stepName)` (applies section 3.2), `FunnelStep(player, funnel, sessionId, stepName, fields)`, `Economy(player, flow, amount, balance, txType, sku)` (adds the three standard fields itself), `Custom(player, name, value, fields)`, `ProgressStart` and `ProgressComplete`. All names live in `src/shared/TelemetryNames.luau` as string constants so typos fail under --!strict.
- The tips accumulator: per-player `{ tipsSinceLog, lastLogAt }` flushed by a 60-second loop, before every Sink and on PlayerRemoving. It can live inside `Economy.settle`.
- Custom field dictionaries use Roblox's fixed key enum, pattern `{[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "value"}`. Confirm the enum name against the AnalyticsService reference when implementing.
- Wrap every Log call in pcall. Telemetry must never throw into gameplay code.
- Client-reported events (shop or dealer opened, item viewed, ui_opened, device) go through the TelemetryReport remote already in data-model section 15: allowlist, 10 per minute per player.
- Budget at 8 players: a catch every 30 seconds per player costs about 6 events (funnel steps, catch_circles, cat_caught), plus one tips flush a minute and a few UI reports. About 100 events a minute per server against a limit of 280. A night wave rush can double that briefly and still fits.
- Verify in the dev experience with Creator Hub, Analytics, View Events before the friends alpha. QA's loop script should assert onboarding steps 1 to 7 fire in order in one scripted run, and that a scripted rank-up before bait does not log tier_2 early.

## 10. Targets and review cadence

Benchmarks from the GameAnalytics 2026 Roblox report (titles over 1 million MAU, updated 2026-09-01): median D1 10.3%, D7 1.6%, session 9.8 minutes, 1.56 sessions per player per day; 90th percentile D1 about 15.9%, session 14.7 minutes.

| Phase | What to look at | Target | If missed |
|---|---|---|---|
| 2 Slice | Onboarding steps 1 to 7 fire in order in the QA loop script; no event fires out of order | All fire, loop under 10 minutes | Engineering ticket |
| 3 Friends alpha | No onboarding step under 70% of the previous one; session_end median over 10 minutes; catch_circles average chance on Commons with a Basic Net above 70%; left_after_bump rare (a handful across the alpha) and drop_outcome not dominated by bumper | The loop completes in under 10 minutes and bumps read as play | Fix the worst step first; turn BumpEnabled off if bumps drive leaves |
| 4 Soft launch, first 2 weeks (needs about 100 new players a day to read) | D1, session length, catch_attempt conversion, bait_cycle return rate, economy net flow by phase | D1 at or above 12%, session at or above 10 minutes, bait_cycle set to seen above 60% | Decision rules in comps.md section 8 |
| 5 Iterate | D7, tier pacing from rank_up, offline_claim capped share, robux_purchase prompt-to-complete, wallet trend, bait_rolled odds audit | D7 at or above 3%, prompt-to-complete over 10% on every live pass, bait results within 2 points of the cards | Re-price or cut the pass; add a sink at the wallet plateau tier; fix the roll if odds drift |

Weekly ritual (Sunday, after the Saturday update): growth-analyst reads the dashboards, writes ten lines to docs/growth/weekly/<date>.md (D1, D7, session, worst funnel step, top sink, top source, catch conversion, bump leaves, one surprise, one action) and files the action as a ticket for the designer or QA.

## 11. Out of scope for v1

- Third-party analytics (GameAnalytics SDK or similar). Add one only if cohort exports become necessary.
- Our own DataStore metrics beyond the profile counters the design already keeps.
- A/B tests. Roblox's price optimization needs about 60,000 transactions in 30 days.

Proposed for docs/decisions.md: 2026-10-26, analytics follows design v0.3: a 12-step onboarding funnel logged strictly in order through a profile telemetry field, four recurring funnels (catch, bait, shop, Robux), one-currency economy events with tier, phase and cats-working fields, 28 custom events including three for bumps, tier and area-book progression, and the auto-press check on the server instead of in analytics, because AnalyticsService dashboards cannot flag a single player.
