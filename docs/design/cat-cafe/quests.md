# Quests and achievements (proposal, 2026-10-27)

Derek, 2026-10-27 21:59: "Add some gameplay for daily quests, weeklys quests, and achievements which keep progress forever for some rewards completing all dailys or completing all weekly quests should give good reward boosts towards progression". He added that the rewards for finishing all the dailies or all the weeklies should be boosts that speed a player up (tips, coins, catch luck or similar), not just cosmetics or one-off drops.

Status: proposal. The numbers go to the engineer and UI threads once Derek okays them. Feature F73. Every number is a first guess for QA to tune. Owner: game-designer thread. This replaces the Customer Requests plan (common-features item 15).

## 1. What a player sees

A Quests button on the HUD opens the Quests window with three tabs: Daily, Weekly and Achievements.

- **Daily:** four quests a day, new at 00:00 UTC. Three normal ones and one Big Request that pays more. Finishing all four earns a **Daily Boost**: a bottle for the bag that gives +50% tips and +25% gold luck for 30 minutes, started whenever the player likes.
- **Weekly:** three bigger quests a week, new on Monday at 00:00 UTC. Finishing all three earns a **Weekly Boost** (+50% tips, +50% gold luck and 25% faster bait for 2 hours) and a Golden Classic Crate.
- **Achievements:** 13 lifetime goals with five steps each, counted forever from the player's stats, so a player who has already caught 300 cats can claim the first steps on day one. The last step of each pays +2% tips forever and a name tag.

The HUD tracker under the next goal card shows the closest unfinished daily ("Catch 5 cats 3/5"). The Quests button gets a dot when something can be claimed.

Fairness rules:
- Nothing is lost by missing a day or a week. A quest that is finished but not claimed when the reset comes is paid automatically, set prize included. There are no streaks.
- One free reroll a day for the dailies and one a week for the weeklies swaps an unfinished quest for another of the same kind. Rerolls, quests and boosts are never sold for Robux, and nothing skips a quest.
- No quest asks a player to shove, chase or beat another player.
- The reset time shows as plain text ("New quests in 5 h"). It never flashes and sends no notifications.

## 2. Daily quests

Each day the server picks one quest from each of four slot pools, skipping rows the player cannot do yet and, where it can, the ids it picked yesterday.

| slot | id | quest | counts | needs | requires |
|---|---|---|---|---|---|
| 1 Streets | `d_catch5` | Catch 5 cats | `catsCaught` | 5 | |
| 1 | `d_perfect10` | Land 10 perfect circles | `perfectCircles` | 10 | |
| 1 | `d_rescue2` | Rescue 2 stuck cats | `rescues` | 2 | |
| 1 | `d_rare1` | Catch a Rare or better cat | `rareCatches` | 1 | |
| 2 Cafe | `d_coins` | Earn coins | `lifetimeCoins` | 600 s of day rate, at least 500 | |
| 2 | `d_tips6` | Collect 6 tip piles | `tipPilesCollected` | 6 | F61 |
| 2 | `d_bait1` | Tame a cat at your bait bowl | `baitsTamed` | 1 | the bait bowl |
| 2 | `d_food2` | Put 2 foods in your bait bowl | `luresUsed` | 2 | the bait bowl |
| 3 Extra | `d_spin1` | Spin the wheel | `spins` | 1 | |
| 3 | `d_tipjar3` | Claim 3 Tip Jar gifts | `tipJarClaims` | 3 | |
| 3 | `d_fish5` | Earn 5 golden fish | `fishEarned` | 5 | |
| 3 | `d_crate1` | Open a Cafe Crate | `cratesOpened` | 1 | a banked crate or 60 golden fish when rolled |
| 4 Big Request | `d_rare3` | Catch 3 Rare or better cats | `rareCatches` | 3 | |
| 4 | `d_catch12` | Catch 12 cats | `catsCaught` | 12 | |
| 4 | `d_rescue5` | Rescue 5 stuck cats | `rescues` | 5 | |
| 4 | `d_perfect30` | Land 30 perfect circles | `perfectCircles` | 30 | |
| 4 | `d_coinsbig` | Earn coins | `lifetimeCoins` | 1,500 s of day rate, at least 1,500 | |

Prizes:

| what | prize |
|---|---|
| a slot 1 to 3 quest | 180 s of day rate (at least 200 coins) and 2 golden fish |
| the Big Request | 300 s of day rate (at least 400 coins), 4 golden fish and 1 Tuna |
| all four claimed (the daily set) | 1 Daily Boost, 10 golden fish and 1 spin |

A day of dailies pays about 14 minutes of day income, 20 golden fish, a Tuna, a spin and the boost.

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
| C | `w_daily12` | Finish 12 daily quests | `dailyQuestsDone` | 12 | |
| C | `w_sets3` | Finish all your dailies on 3 days | `dailySetsDone` | 3 | |

Prizes:

| what | prize |
|---|---|
| a weekly quest | 1,200 s of day rate (at least 2,000 coins), 15 golden fish, 1 spin and 1 Salmon |
| all three claimed (the weekly set) | 1 Weekly Boost, 1 Golden Classic Crate, 40 golden fish and 3 spins |

With the dailies, a player who finishes everything gets about 225 golden fish a week, almost four bought crates. That roughly doubles a regular's fish, which is the point: quests are the steady fish source for players who come back.

## 4. Boosts

Boosts are two more kinds in F64's potion bag, so they reuse `potions`, `UsePotion`, `buffs` and the `ActivePotions` glow. The player drinks one when they want, and its timer then runs in real time like a potion's.

| id | name | lasts | effect |
|---|---|---|---|
| `daily_boost` | Daily Boost | 30 min | +50% tips and +25% gold luck |
| `weekly_boost` | Weekly Boost | 2 h | +50% tips, +50% gold luck and bait waits 25% shorter |

- **Tips** work like the Tip Potion: a multiplier on `incomePerSecond`, the tip piles and rich visitors, with `Economy.settle` splitting the window where a boost ends. Every running tip effect adds into one multiplier, capped at TimedTipsMax (+100%), so a Tip Potion, a Daily Boost and a Weekly Boost at once give +100%, not +125%.
- **Gold luck** adds to the player's Index `goldLuck`, on top of GoldLuckMax, capped at BoostGoldLuckMax (0.5). With every gold milestone and a Weekly Boost, a gold roll is 5% x (1 + 1.5 + 0.5) = 15%. It counts wherever goldLuck counts, including the shared stray and rescue rolls, so one player's boost lifts the gold odds for everyone in the server.
- **Bait speed** adds to the All Cats `baitSpeed` inside BaitSpeedMax (0.5), read when the food is set (`readyAt = placedAt + wait x (1 - baitSpeed)`).
- Drinking another of the same boost adds its time, up to BoostMaxMinutes (240). Boosts and potions of different kinds run together.
- Boosts are earn-only: selling one for Robux would change income or gold odds, so it would need the monetization review first.

## 5. Achievements

Each achievement reads one lifetime counter. Every step uses the same prize, so the thresholds set the difficulty.

| id | name | counts | steps | step 5 tag |
|---|---|---|---|---|
| `a_catch` | Cat Catcher | `catsCaught` | 10, 50, 250, 1,000, 5,000 | Cat Catcher |
| `a_rare` | Rare Finder | `rareCatches` | 5, 25, 100, 400, 1,500 | Rare Finder |
| `a_gold` | Gold Hunter | `goldCatches` | 1, 5, 20, 75, 250 | Gold Hunter |
| `a_perfect` | Perfect Paws | `perfectCircles` | 25, 150, 750, 3,000, 12,000 | Perfect Paws |
| `a_rescue` | Rescue Hero | `rescues` | 5, 25, 100, 400, 1,500 | Rescue Hero |
| `a_bait` | Bait Master | `baitsTamed` | 3, 15, 60, 250, 1,000 | Bait Master |
| `a_coins` | Big Earner | `lifetimeCoins` | 10,000, 100,000, 1M, 10M, 100M | Tycoon |
| `a_tips` | Tip Collector | `tipPilesCollected` | 25, 150, 750, 3,000, 12,000 | Head Waiter |
| `a_crates` | Crate Opener | `cratesOpened` | 3, 15, 60, 200, 600 | Decorator |
| `a_spins` | Lucky Spinner | `spins` | 5, 30, 100, 365, 1,000 | Lucky Paw |
| `a_hours` | Cafe Regular | `playtimeSeconds` | 1, 5, 25, 100, 400 hours | Regular |
| `a_quests` | Quest Keeper | `dailyQuestsDone` | 10, 50, 200, 600, 1,500 | Quest Keeper |
| `a_weeks` | Full Week | `weeklySetsDone` | 1, 4, 12, 26, 52 | Week Champion |

| step | prize |
|---|---|
| 1 | 120 s of day rate (at least 200 coins) and 5 golden fish |
| 2 | 300 s of day rate (at least 500 coins), 15 golden fish and 1 spin |
| 3 | 30 golden fish, 2 spins and 1 Classic Crate |
| 4 | 50 golden fish, 3 spins and 1 Golden Classic Crate |
| 5 | 100 golden fish, 5 spins, 1 Golden Classic Crate, +2% tips forever and the name tag |

All thirteen finished add +26% tips forever, next to the Index's +35%. Shoves and pickups are left out on purpose, so no achievement rewards pushing other players around. Golden fish earned is left out too, because the quests' own fish would feed it.

## 6. Contract for the engineer

**Day and week.** The day is `floor(os.time() / 86400)` (UTC), as for the free spin and the Daily Treat. The week is `floor((os.time() - QuestWeekOffsetSeconds) / 604800)` with the offset 345,600 (four days, so weeks start on Monday 00:00 UTC). The server rolls on profile load and, for players in the game, when the day or week changes (a check every QuestRollCheckSeconds, 60, is enough). Before rolling it pays every finished, unclaimed quest of the old set and the set prize if all of them were finished, so nothing is lost.

**Progress.** Each picked quest saves `base`, the counter's value when it was picked, and `needs`. Progress is `min(needs, value - base)`. A coins quest fixes `needs = max(min, floor(dayRate x seconds))` when it is picked. `w_new2` counts distinct catIds in `collection`. Rows that need something the player lacks are skipped when picking; every pool has a row with no requirement.

**Catalog.**
- `Catalog.quests.daily[slot]` and `Catalog.quests.weekly[pool]`: lists of `{ id, text, stat, needs?, needsSeconds?, needsMin?, requires? = { upgrade?, feature?, fishOrCrate?, uncaught? } }`.
- `Catalog.questPrizes`: `daily`, `dailyBig`, `dailySet`, `weekly` and `weeklySet`, in the Index prize shape plus potions.
- `Catalog.achievements`: `{ id, name, stat, steps = { n1, n2, n3, n4, n5 }, tag }` and `Catalog.achievementPrizes[1..5]` in the same prize shape (step 5 with `bonus = 0.02`).
- Two rows in `Catalog.potions` for the boosts: `{ id, name, minutes, tips?, goldLuck?, baitSpeed? }`.

**Profile** (the next free save version when F73 ships; migration sets the new fields empty or 0):

| field | type | default |
|---|---|---|
| quests | `{ day, daily = { { id, base, needs, claimed } } x 4, dailyReroll, dailySet, week, weekly = { ... } x 3, weeklyReroll, weeklySet }` | day and week 0, empty lists, false flags (rolled on load) |
| achievements | map achievementId to steps claimed (0 to 5) | empty |
| stats | adds `rareCatches`, `goldCatches`, `tipPilesCollected`, `dailyQuestsDone`, `dailySetsDone`, `weeklyQuestsDone`, `weeklySetsDone` | 0 |

Lists are dense arrays in slot order (the N116 lesson). On load an unknown quest id is replaced by a fresh pick for its slot, `needs` is clamped to at least 1 and each achievement step count to 0 to 5. `rareCatches` and `goldCatches` count up wherever `catsCaught` does (net, rescue and bait). `tipPilesCollected` counts each pile CollectTips pays.

**Remotes.**

| name | kind | args | checks; rate | does |
|---|---|---|---|---|
| ClaimQuest | event | kind (`daily` or `weekly`), slot | profile loaded, slot 1 to 4 (daily) or 1 to 3 (weekly), finished, not claimed; 2 per second | pays through Payout, marks it claimed, counts `dailyQuestsDone` or `weeklyQuestsDone`; when that completes the set it also pays the set prize and counts `dailySetsDone` or `weeklySetsDone`; fires QuestResult and ProfileSync |
| RerollQuest | event | kind, slot | the reroll for that day or week unused, the quest unfinished and unclaimed; 1 per second | picks another eligible row from the same pool with a fresh `base` |
| ClaimAchievement | event | achievementId | known id, at least the next step met; 1 per second | pays every step met and not yet claimed, in order |
| QuestResult | server to client | paid (list of strings) | | the toast, as for Index rewards |

ProfileSync adds `quests`, `achievements` and `stats`, which the client needs for achievement progress. Analytics: custom events `quest_claimed` (kind, id, slot), `quest_set` (kind) and `achievement_claimed` (id, step); economy sources `quest_daily`, `quest_weekly` and `achievement`.

**Constants.** QuestDailyCount 4, QuestWeeklyCount 3, QuestWeekOffsetSeconds 345600, QuestRollCheckSeconds 60, BoostMaxMinutes 240, TimedTipsMax 1.0, BoostGoldLuckMax 0.5.

**Order.** F73 needs F52 (golden fish), F53 (crates) and F64 (the potion bag, which the boosts live in). The tip pile rows are skipped until F61 ships.

## 7. For the UI thread

- A Quests button on the HUD with a dot while anything is claimable, opening a window with the tabs Daily, Weekly and Achievements.
- Daily and Weekly rows: the quest text, a progress bar, the prize chips (the PrizeChips component), Claim when done and a small Reroll button while the reroll is unused. Above the rows: "3 of 4 done" with the set prize card, and "New quests in 5 h".
- Achievements: one card per achievement with five step pips, the count and the next target, and Claim when a step is met.
- The HUD tracker: one line under the next goal card with the closest unfinished daily, shown after onboarding.
- The boosts sit in the potion bag with a Use button, and their timers show in the HUD buff chips with the potions.
