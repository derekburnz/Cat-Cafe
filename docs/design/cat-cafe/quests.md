# Quests and achievements (proposal, 2026-10-27)

Derek, 2026-10-27 21:59: "Add some gameplay for daily quests, weeklys quests, and achievements which keep progress forever for some rewards completing all dailys or completing all weekly quests should give good reward boosts towards progression". He added that the rewards for finishing all the dailies or all the weeklies should speed a player up (tips, coins, catch luck or similar), not just cosmetics or one-off drops.

Derek, 22:10, on the first draft: "lets do 5 a day. Give potions that can be used not straight boosts immediately. Same thing for weekly. No tips boost for achievements grant money based on money per min calculation for  rewards or spins or crates or potions. Achievements not needed in order and add more should be at least 30". This version follows it: five dailies, potions for the full sets, and 42 achievements that stand on their own and pay coins scaled to income, spins, crates and potions.

Status: approved by Derek on 2026-10-27 at 22:14 ("looks good"), and handed to the engineer and UI threads. Feature F73. Every number is a first guess for QA to tune. Owner: game-designer thread. This replaces the Customer Requests plan (common-features item 15).

## 1. What a player sees

A Quests button on the HUD opens the Quests window with three tabs: Daily, Weekly and Achievements.

- **Daily:** five quests a day, new at 00:00 UTC. Four normal ones and one Big Request that pays more. Finishing all five pays a Big Tip Potion and a Gold Rush Potion (section 4), which go into the potion bag to drink whenever the player likes.
- **Weekly:** three bigger quests a week, new on Monday at 00:00 UTC. Finishing all three pays three Big Tip Potions, three Gold Rush Potions, two Quick Bait Potions and a Golden Classic Crate.
- **Achievements:** 42 goals, each on its own. They are all open from the start, any of them can be finished first and each pays once. They count from what the player has already done, so a player who has caught 300 cats can claim Cat Catcher on day one.

The HUD tracker under the next goal card shows the closest unfinished daily ("Catch 5 cats 3/5"). The Quests button gets a dot when something can be claimed.

Fairness rules:
- Nothing is lost by missing a day or a week. A quest that is finished but not claimed when the reset comes is paid automatically, set prize included. There are no streaks.
- One free reroll a day for the dailies and one a week for the weeklies swaps an unfinished quest for another of the same kind. Rerolls, quests and potions are never sold for Robux, and nothing skips a quest.
- No quest or achievement asks a player to shove, chase or beat another player.
- The reset time shows as plain text ("New quests in 5 h"). It never flashes and sends no notifications.

## 2. Daily quests

Each day the server picks five quests: slots 1 and 2 from the Streets pool (never the same counter twice), slot 3 from Cafe, slot 4 from Extra and slot 5 from Big Request. It skips rows the player cannot do yet and, where it can, the ids it picked yesterday.

| pool | id | quest | counts | needs | requires |
|---|---|---|---|---|---|
| Streets | `d_catch5` | Catch 5 cats | `catsCaught` | 5 | |
| Streets | `d_perfect10` | Land 10 perfect circles | `perfectCircles` | 10 | |
| Streets | `d_rescue2` | Rescue 2 stuck cats | `rescues` | 2 | |
| Streets | `d_rare1` | Catch a Rare or better cat | `rareCatches` | 1 | |
| Cafe | `d_coins` | Earn coins | `lifetimeCoins` | 600 s of day rate, at least 500 | |
| Cafe | `d_tips6` | Collect 6 tip piles | `tipPilesCollected` | 6 | F61 |
| Cafe | `d_bait1` | Tame a cat at your bait bowl | `baitsTamed` | 1 | the bait bowl |
| Cafe | `d_food2` | Put 2 foods in your bait bowl | `luresUsed` | 2 | the bait bowl |
| Extra | `d_spin1` | Spin the wheel | `spins` | 1 | |
| Extra | `d_tipjar3` | Claim 3 Tip Jar gifts | `tipJarClaims` | 3 | |
| Extra | `d_fish5` | Earn 5 golden fish | `fishEarned` | 5 | |
| Extra | `d_crate1` | Open a Cafe Crate | `cratesOpened` | 1 | a banked crate or 60 golden fish when rolled |
| Big Request | `d_rare3` | Catch 3 Rare or better cats | `rareCatches` | 3 | |
| Big Request | `d_catch12` | Catch 12 cats | `catsCaught` | 12 | |
| Big Request | `d_rescue5` | Rescue 5 stuck cats | `rescues` | 5 | |
| Big Request | `d_perfect30` | Land 30 perfect circles | `perfectCircles` | 30 | |
| Big Request | `d_coinsbig` | Earn coins | `lifetimeCoins` | 1,500 s of day rate, at least 1,500 | |

Prizes:

| what | prize |
|---|---|
| a slot 1 to 4 quest | 180 s of day rate (at least 200 coins) and 2 golden fish |
| the Big Request | 300 s of day rate (at least 400 coins), 4 golden fish and 1 Tuna |
| all five claimed (the daily set) | 1 Big Tip Potion, 1 Gold Rush Potion, 10 golden fish and 1 spin |

A day of dailies pays about 17 minutes of day income, 22 golden fish, a Tuna, a spin and two potions.

## 3. Weekly quests

One quest from each of three pools, picked on Monday at 00:00 UTC.

| pool | id | quest | counts | needs | requires |
|---|---|---|---|---|---|
| A | `w_catch60` | Catch 60 cats | `catsCaught` | 60 | |
| A | `w_perfect150` | Land 150 perfect circles | `perfectCircles` | 150 | |
| A | `w_rescue15` | Rescue 15 stuck cats | `rescues` | 15 | |
| B | `w_coins` | Earn coins | `lifetimeCoins` | 10,800 s of day rate, at least 10,000 | |
| B | `w_bait10` | Tame 10 cats at your bait bowl | `baitsTamed` | 10 | the bait bowl |
| B | `w_tips60` | Collect 60 tip piles | `tipPilesCollected` | 60 | F61 |
| C | `w_new2` | Find 2 new cats | different cats in `collection` | 2 | at least 2 cats not yet found in the open areas |
| C | `w_gold2` | Catch 2 gold cats | `goldCatches` | 2 | |
| C | `w_daily15` | Finish 15 daily quests | `dailyQuestsDone` | 15 | |
| C | `w_sets3` | Finish all your dailies on 3 days | `dailySetsDone` | 3 | |

Prizes:

| what | prize |
|---|---|
| a weekly quest | 1,200 s of day rate (at least 2,000 coins), 15 golden fish, 1 spin and 1 Salmon |
| all three claimed (the weekly set) | 3 Big Tip Potions, 3 Gold Rush Potions, 2 Quick Bait Potions, 1 Golden Classic Crate, 40 golden fish and 3 spins |

With the dailies, a player who finishes everything gets about 240 golden fish a week, four bought crates. That roughly doubles a regular's fish, which is the point: quests are the steady fish source for players who come back.

## 4. Quest potions

Three new potions join F64's four in the potion bag, so they reuse `potions`, `UsePotion`, `buffs`, PotionMaxMinutes (60) and the `ActivePotions` glow. They sit in the bag until the player drinks one. Like every potion, its timer then counts down only while the player is in the game and pauses while they are away (Derek, 22:14: "Also make potion time left pause on exit", data-model 12b). Drinking another of the same kind adds its time up to 60 minutes, and the rest stay in the bag for later.

| id | name | lasts | effect |
|---|---|---|---|
| `big_tip_potion` | Big Tip Potion | 30 min | +50% tips |
| `gold_rush_potion` | Gold Rush Potion | 30 min | +25% gold luck on every gold roll (catches, rescues and bait) |
| `quick_bait_potion` | Quick Bait Potion | 30 min | bait set while it runs is ready 25% sooner |

- **Tips** work like the Tip Potion: a multiplier on `incomePerSecond`, the tip piles and rich visitors, with `Economy.settle` splitting the window where a potion ends. Every running tip potion adds into one multiplier, capped at TimedTipsMax (+100%), so a Tip Potion and a Big Tip Potion together give +75%.
- **Gold luck** adds 0.25 to the player's Index `goldLuck`, on top of GoldLuckMax. With every gold milestone and a Gold Rush Potion, a gold roll is 5% x (1 + 1.5 + 0.25) = 13.75%. It counts wherever goldLuck counts, including the shared stray and rescue rolls, so one player's potion lifts the gold odds for everyone in the server. The Lucky Potion stays as it is (bait set while it runs rolls gold at double).
- **Bait speed** adds 0.25 to the All Cats `baitSpeed` inside BaitSpeedMax (0.5), read when the food is set (`readyAt = placedAt + wait x (1 - baitSpeed)`).
- Potions are earn-only: selling one for Robux would change income or gold odds, so it would need the monetization review first.

## 5. Achievements

Each achievement is one goal with one prize. All 42 are open from the start and can be finished in any order; the ones that share a counter (Cat Catcher, Cat Wrangler, Cat Legend) are separate goals, not steps. Each reads a lifetime value, so progress is kept forever and old saves get credit for what they did before.

Prizes by size, coins scaled to the player's day rate when claimed:

| size | prize |
|---|---|
| S | 300 s of day rate (at least 300 coins) and 1 spin |
| M | 900 s of day rate (at least 1,000 coins), 2 spins and 1 Tip Potion |
| L | 1,800 s of day rate (at least 2,500 coins), 3 spins, 1 Classic Crate and 1 Big Tip Potion |
| XL | 3,600 s of day rate (at least 5,000 coins), 5 spins, 1 Golden Classic Crate, 1 Big Tip Potion and 1 Gold Rush Potion |

| id | name | goal | measure | needs | size |
|---|---|---|---|---|---|
| `a_first_catch` | First Catch | Catch your first cat | `catsCaught` | 1 | S |
| `a_catch100` | Cat Catcher | Catch 100 cats | `catsCaught` | 100 | M |
| `a_catch1k` | Cat Wrangler | Catch 1,000 cats | `catsCaught` | 1,000 | L |
| `a_catch10k` | Cat Legend | Catch 10,000 cats | `catsCaught` | 10,000 | XL |
| `a_rare1` | Rare Find | Catch a Rare or better cat | `rareCatches` | 1 | S |
| `a_rare100` | Rare Hunter | Catch 100 Rare or better cats | `rareCatches` | 100 | L |
| `a_gold1` | Golden Paws | Catch a gold cat | `goldCatches` | 1 | M |
| `a_gold50` | Gold Rush | Catch 50 gold cats | `goldCatches` | 50 | XL |
| `a_perfect1` | Perfect Circle | Land a perfect circle | `perfectCircles` | 1 | S |
| `a_perfect500` | Perfect Paws | Land 500 perfect circles | `perfectCircles` | 500 | L |
| `a_perfect5k` | Steady Hands | Land 5,000 perfect circles | `perfectCircles` | 5,000 | XL |
| `a_rescue1` | First Rescue | Rescue a stuck cat | `rescues` | 1 | S |
| `a_rescue250` | Rescue Hero | Rescue 250 stuck cats | `rescues` | 250 | L |
| `a_bait1` | Bait Beginner | Tame a cat at your bait bowl | `baitsTamed` | 1 | S |
| `a_bait200` | Bait Master | Tame 200 cats at your bait bowl | `baitsTamed` | 200 | L |
| `a_cats10` | Growing Family | Find 10 different cats | `distinctCats` | 10 | S |
| `a_cats25` | Big Family | Find 25 different cats | `distinctCats` | 25 | M |
| `a_cats50` | Every Cat | Find all 50 cats | `distinctCats` | 50 | XL |
| `a_goldcats10` | Gold Collector | Find 10 different gold cats | `goldCats` | 10 | L |
| `a_mythical` | Mythical Friend | Find a Mythical cat | `mythicalCats` | 1 | L |
| `a_tier2` | Open for Business | Reach Cozy Cafe (Tier 2) | `tier` | 2 | S |
| `a_tier3` | Busy Bee | Reach Busy Cafe (Tier 3) | `tier` | 3 | M |
| `a_tier4` | Famous | Reach Famous Cafe (Tier 4) | `tier` | 4 | L |
| `a_tier5` | Grand Opening | Reach Grand Cafe (Tier 5) | `tier` | 5 | XL |
| `a_coins10k` | Pocket Money | Earn 10,000 coins | `lifetimeCoins` | 10,000 | S |
| `a_coins1m` | Big Earner | Earn 1,000,000 coins | `lifetimeCoins` | 1,000,000 | L |
| `a_coins100m` | Coin Mountain | Earn 100,000,000 coins | `lifetimeCoins` | 100,000,000 | XL |
| `a_tips100` | Tip Collector | Collect 100 tip piles | `tipPilesCollected` | 100 | M |
| `a_tips2k` | Head Waiter | Collect 2,000 tip piles | `tipPilesCollected` | 2,000 | L |
| `a_net` | Master Net | Get the Master Net | `upgrade:net` | 3 | M |
| `a_tables` | Full House | Get every table | `upgrade:tables` | 6 | M |
| `a_spins50` | Lucky Spinner | Spin the wheel 50 times | `spins` | 50 | M |
| `a_crates25` | Crate Opener | Open 25 Cafe Crates | `cratesOpened` | 25 | M |
| `a_decor30` | Decorator | Own 30 decor pieces | `decorOwned` | 30 | L |
| `a_potions25` | Potion Brewer | Drink 25 potions | `potionsUsed` | 25 | M |
| `a_trades5` | Collector's Friend | Trade 5 cats with the Cat Collector | `collectorTrades` | 5 | M |
| `a_gifts10` | Mystery Fan | Open 10 Mystery Visitor gifts | `mysteryGifts` | 10 | M |
| `a_hours10` | Cafe Regular | Play for 10 hours | `playtimeSeconds` | 36,000 | M |
| `a_hours100` | Devoted | Play for 100 hours | `playtimeSeconds` | 360,000 | XL |
| `a_quests100` | Quest Keeper | Finish 100 daily quests | `dailyQuestsDone` | 100 | L |
| `a_week1` | Full Week | Finish every weekly quest in a week | `weeklySetsDone` | 1 | M |
| `a_week10` | Week Champion | Finish every weekly quest in 10 weeks | `weeklySetsDone` | 10 | XL |

That is 8 S, 14 M, 12 L and 8 XL. All 42 together pay about 18 hours of day income, 112 spins, 20 crates and 42 potions, spread over a long time. No achievement pays golden fish or a permanent bonus. Shoves and pickups are left out on purpose, so nothing rewards pushing other players around. Rows that need a feature not built yet (tip piles, potions, the Cat Collector, the Mystery Visitor) show once it ships.

## 6. Contract for the engineer

**Day and week.** The day is `floor(os.time() / 86400)` (UTC), as for the free spin and the Daily Treat. The week is `floor((os.time() - QuestWeekOffsetSeconds) / 604800)` with the offset 345,600 (four days, so weeks start on Monday 00:00 UTC). The server rolls on profile load and, for players in the game, when the day or week changes (a check every QuestRollCheckSeconds, 60, is enough). Before rolling it pays every finished, unclaimed quest of the old set and the set prize if all of them were finished, so nothing is lost.

**Quest progress.** Each picked quest saves `base`, the counter's value when it was picked, and `needs`. Progress is `min(needs, value - base)`. A coins quest fixes `needs = max(min, floor(dayRate x seconds))` when it is picked. `w_new2` counts distinct catIds in `collection`. Rows that need something the player lacks are skipped when picking; every pool has a row with no requirement.

**Achievement progress.** A `measure` is a key of `stats`, `lifetimeCoins`, `tier`, `distinctCats` (entries in `collection`), `goldCats` (entries in `goldCollection`), `mythicalCats` (distinct Mythical catIds in `collection`), `decorOwned` (pieces owned) or `upgrade:<id>` (that upgrade's level). An achievement is met when the measure reaches `needs`.

**Catalog.**
- `Catalog.quests.daily` keyed by pool (`streets`, `cafe`, `extra`, `big`) and `Catalog.quests.weekly` keyed by pool (`a`, `b`, `c`): lists of `{ id, text, stat, needs?, needsSeconds?, needsMin?, requires? = { upgrade?, feature?, fishOrCrate?, uncaught? } }`.
- `Catalog.questPrizes`: `daily`, `dailyBig`, `dailySet`, `weekly` and `weeklySet`, in the Index prize shape plus potions.
- `Catalog.achievements`: a list of `{ id, name, text, measure, needs, size }` in the table's order, and `Catalog.achievementPrizes` keyed by size (`S`, `M`, `L`, `XL`) in the same prize shape.
- Three rows in `Catalog.potions`: `{ id, name, minutes, tips?, goldLuck?, baitSpeed? }`.

**Profile** (the next free save version when F73 ships; migration sets the new fields empty or 0):

| field | type | default |
|---|---|---|
| quests | `{ day, daily = { { id, base, needs, claimed } } x 5, dailyReroll, dailySet, week, weekly = { ... } x 3, weeklyReroll, weeklySet }` | day and week 0, empty lists, false flags (rolled on load) |
| achievements | map achievementId to true (claimed) | empty |
| stats | adds `rareCatches`, `goldCatches`, `tipPilesCollected`, `dailyQuestsDone`, `dailySetsDone`, `weeklyQuestsDone`, `weeklySetsDone` | 0 |

Lists are dense arrays in slot order (the N116 lesson). On load an unknown quest id is replaced by a fresh pick for its slot, `needs` is clamped to at least 1 and unknown achievement ids are dropped. `rareCatches` and `goldCatches` count up wherever `catsCaught` does (net, rescue and bait). `tipPilesCollected` counts each pile CollectTips pays.

**Remotes.**

| name | kind | args | checks; rate | does |
|---|---|---|---|---|
| ClaimQuest | event | kind (`daily` or `weekly`), slot | profile loaded, slot 1 to 5 (daily) or 1 to 3 (weekly), finished, not claimed; 2 per second | pays through Payout, marks it claimed, counts `dailyQuestsDone` or `weeklyQuestsDone`; when that completes the set it also pays the set prize and counts `dailySetsDone` or `weeklySetsDone`; fires QuestResult and ProfileSync |
| RerollQuest | event | kind, slot | the reroll for that day or week unused, the quest unfinished and unclaimed; 1 per second | picks another eligible row from the same pool with a fresh `base` |
| ClaimAchievement | event | achievementId | known id, met, not claimed; 2 per second | pays its prize and marks it claimed |
| QuestResult | server to client | paid (list of strings) | | the toast, as for Index rewards |

ProfileSync adds `quests`, `achievements` and `stats`, which the client needs for achievement progress. Analytics: custom events `quest_claimed` (kind, id, slot), `quest_set` (kind) and `achievement_claimed` (id, size); economy sources `quest_daily`, `quest_weekly` and `achievement`.

**Constants.** QuestDailyCount 5, QuestWeeklyCount 3, QuestWeekOffsetSeconds 345600, QuestRollCheckSeconds 60, TimedTipsMax 1.0.

**Order.** F73 needs F52 (golden fish), F53 (crates) and F64 (the potion bag). The tip pile rows wait for F61, and the Cat Collector and Mystery Visitor achievements for F63 and F64.

## 7. For the UI thread

- A Quests button on the HUD with a dot while anything is claimable, opening a window with the tabs Daily, Weekly and Achievements.
- Daily and Weekly rows: the quest text, a progress bar, the prize chips (the PrizeChips component), Claim when done and a small Reroll button while the reroll is unused. Above the rows: "3 of 5 done" with the set prize card, and "New quests in 5 h".
- Achievements: a grid of cards, claimable ones first, then the closest to done. Each card shows the name, the goal, a progress bar, the prize chips and Claim when met. A count at the top reads "12 of 42".
- The HUD tracker: one line under the next goal card with the closest unfinished daily, shown after onboarding.
- The quest potions sit in the potion bag with F64's potions and a Use button, and their timers show in the HUD buff chips.
