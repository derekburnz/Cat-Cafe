# Fewer, better rewards and the two rotating shops (F94)

Status: decided by Derek in the Google Doc's Set 4 answers (read 2026-11-01), specced by the game-designer thread. His answers:

- Q5 (Daily Treat): "I think the amount of food given out in the game is a little too much right now you never run out and always have too much of the lower tier food so think out other rewards even if its just small amounts of the good currency. But overall good idea."
- Q6 (Tip Jar): "Can probably just have it be a couple of things but make it worthwhile don't need to overflow the reward panel images with so many things."
- Q9 (potions in the Golden Fish Market): "I would be down to add them, possibly think there should also be a day time 5min rotating item shop also and then night market can just be a stagnant thing that rotates per server every night."
- 2026-11-01 22:32 (Monetization-Agent's questions): "change tips to be called income/money less confusing for younger audiences".

It changes prize tables in data-model sections 11b, 11c, 11d, 11e and 12b, quests.md and golden-fish.md sections 5 and 5b, the dealer in data-model 8b and the Golden Fish Market in golden-fish.md section 3. Where they differ, this wins.

## 1. Three rules for every prize

1. **No shop food in prizes.** Kibble, Tuna and Salmon, the foods the coin shop sells, leave every reward table. Players buy them for coins, so the bowl becomes a coin sink again. Food still shows up as a prize only when it is a food the shop does not sell (Moonlit Sardines, Caviar, Moon Milk or the Star Treat), one or two at a time, as the headline of that prize.
2. **Small amounts of golden fish** take the place of the food, as Derek suggested.
3. **Two things a prize, three for the big ones.** A prize shows at most two pictures. The big ones show at most three: the Tip Jar's 120 minute gift, the Daily Treat's day 7, the quest sets, the XL achievements, the codes and the milestones that finish an Index track (`cats10`, `gold10`, `total25`, `total50`). A permanent bonus chip ("+2% money forever") and a name tag do not count as pictures.

## 2. The new prize tables

Coins are always `max(min, floor(dayRate x seconds))`, as now. Rows not listed are unchanged.

### 2a. Tip Jar (data-model 11b)

| step | minutes | now | was |
|---|---|---|---|
| 2 | 5 | 2 golden fish | 2 Kibble |
| 4 | 15 | 2 golden fish | 1 Tuna |
| 6 | 30 | 1 spin | 2 Tuna |
| 8 | 50 | 3 golden fish | 1 Salmon |
| 9 | 60 | coins: 600 s of day rate (at least 1,000) and 10 golden fish | the same plus 1 spin |
| 10 | 75 | 5 golden fish | 1 Moonlit Sardines |
| 11 | 90 | coins: 300 s of day rate (at least 600) and 1 spin | unchanged |
| 12 | 120 | 1 Classic Crate and 30 golden fish | 1 Caviar, 1 Classic Crate, 25 golden fish, 2 spins and a Tip Potion |

The odd steps keep their coins. A two hour session now pays 52 golden fish (was 35), 2 spins (was 4) and no food (was 8 foods).

**v2, much bigger (#1414, the friend, 2026-11-05: "at least 2x more suggested 5x for gold fish we don't have too be this stingey it should be really rewarding to play 30min+ like make 1x spin 5x spin").** Coins (both the minimum and the seconds) go up 2x, golden fish 5x, spins 5x and crates 2x. This replaces the table above:

| step | minutes | prize |
|---|---|---|
| 1 | 2 | coins: 30 s of day rate (at least 100) |
| 2 | 5 | 10 golden fish |
| 3 | 10 | coins: 60 s (at least 200) |
| 4 | 15 | 10 golden fish |
| 5 | 20 | coins: 90 s (at least 300) |
| 6 | 30 | **5 spins** |
| 7 | 40 | coins: 120 s (at least 500) |
| 8 | 50 | 15 golden fish |
| 9 | 60 | coins: 600 s (at least 2,000) and **50 golden fish** |
| 10 | 75 | 25 golden fish |
| 11 | 90 | coins: 300 s (at least 1,200) and **5 spins** |
| 12 | 120 | **2 Classic Crates and 150 golden fish** |

- **What a session pays.** One hour: 85 golden fish and 5 spins (was 17 and 1). Two hours: 260 golden fish, about 6 Market crates at 40, plus 2 Classic Crates and 10 spins (was 52 fish, 1 crate and 2 spins). Still at most three pictures a prize (section 1).
- **With the Spin Wheel v2 (section 2b, #1411).** 10 spins at 1-in-100 jackpot odds give about a 1-in-10 chance of a jackpot in a two hour session, so it stays a rare chase. At the v2 wheel's average of about 390 s of day rate a spin, the 10 spins add roughly an hour of income, which is the "really rewarding" part.
- **Spin bank.** `SpinBankCap` goes from 20 to 50 and `SpinAllMax` from 25 to 51 (the bank plus today's free spin), so a player who plays twice in a day keeps every spin.
- **Pace.** More coins, fish and crates mean faster coins and a faster cat count. QA-Planner runs Pace.spec on the build. If a tier comes in under its floor, its cost goes up and the rewards stay (rule v0.8, economy-ladder.md section 3).
- **Policy.** Nothing changes: the jar is free and can't be bought, and crates and spins from it are free random rewards with their odds shown.

### 2b. Spin Wheel (data-model 11c)

| slice | prize | weight |
|---|---|---|
| 1 | coins: 120 s of day rate, at least 200 | 30 |
| 2 | 3 golden fish (was 3 Tuna) | 22 |
| 3 | coins: 600 s of day rate, at least 1,000 | 18 |
| 4 | 1 Caviar (was 2 Salmon) | 15 |
| 5 | 8 golden fish (was 4) | 10 |
| 6 | 1 crate of the highest zone unlocked | 5 |

A spin is now worth about 1.5 golden fish on average (was 0.4), so fewer spins (section 2 cuts several) each feel better. The wheel model's slice faces come from data, so only the pictures change.

**v2, jackpots (#1411, the friend, 2026-11-05: "have it have some bigger hits so players have something to chase like Golden crate for low odds and like 100 gold fish but also a quick way to get money from the spins and make money the most common").** The wheel goes to 8 slices. Weights are in halves of a percent, so they stay whole numbers (total 200):

| slice | prize | weight | chance |
|---|---|---|---|
| 1 | coins: 120 s of day rate, at least 200 | 70 | 35% |
| 2 | coins: 600 s of day rate, at least 1,000 | 44 | 22% |
| 3 | 5 golden fish | 30 | 15% |
| 4 | coins: 1,800 s of day rate, at least 3,000 (new) | 24 | 12% |
| 5 | 1 Caviar | 18 | 9% |
| 6 | 1 crate of the highest zone unlocked | 12 | 6% |
| 7 | **Jackpot:** 1 golden crate of the highest zone unlocked (new, `crate = "highest_golden"`) | 1 | 0.5% |
| 8 | **Jackpot:** 100 golden fish (new) | 1 | 0.5% |

- **Coins first.** Coins land on 69% of spins (was 48%), and the average spin pays about 390 s of day rate (was 144 s), so a spin is a quick money top-up.
- **Something to chase.** The two jackpots together hit about 1 spin in 100. With one free spin a day plus the Tip Jar's, a regular player hits one every month or two, and the odds are always shown. Golden fish average 1.25 a spin (was 1.46), crates 0.065 (was 0.05).
- **Jackpot moment.** A jackpot gets the wheel's biggest win effect and sound, plus a toast for the winner: "Jackpot! 100 golden fish". There's no server-wide announcement, because that would push other players to spin.
- **Policy.** Spins stay free only: no Robux button, pass or product gives spins, so the wheel is not a paid random item (monetization-policy). Monetization-Agent confirms the Cafe Pass paid tier and any bundle give no spins. If one ever does, PolicyService gating and odds-before-buy apply first.
- **Build.** `Catalog.spinWheel` gets these 8 rows (frozen as before) and `crate = "highest_golden"` resolves to the golden version of the highest unlocked zone's crate. The Spin window's Odds list and slice faces show 8 slices, likeliest first, adding up to 100%. If the world wheel model has a fixed 6 wedges, Model-Agent adds two narrow gold wedges for the jackpots.
- **QA.** Over 200,000 seeded spins each slice lands within 0.1 point of its chance. A jackpot crate is the golden crate of the player's highest zone, and the Odds list shows 0.5% for each jackpot.

**v3, the Spin window tidy (#1816, Derek2 2026-11-06: "clean up the spin wheel ui in the spin wheel menu").** No odds or prizes change. Layout only:
- **Two columns.** On the left, the wheel at 60% of the window's width. On the right, top to bottom: the title "Spin Wheel", a big "Spins: 3" count, the Spin button (the window's only big button), "Use all" as a small text button under it (only with 2 or more spins), and "Odds" as a small text button at the bottom. Nothing else: no subtitle, no help line and no status line except a refusal ("Next free spin at sunrise"). On a phone, the right column moves under the wheel, in the same order.
- **Slices.** Each of the 8 slices shows one 56 px picture near the rim and one amount pill under it. Every pill has the same width and the same FredokaOne size. The size is set by the longest label at that screen size, so no slice's text is smaller than another's. Amounts are short: "+1.2K", "5 fish", "1 Caviar", "1 Crate", "100 fish". Coin slices show the coin amount for the player's current day rate.
- **Pictures.** Coin slices show the coin stack, small for slice 1, medium for 2 and the money bag for 4. Fish slices show the golden fish, Caviar shows its food icon, and crate slices show the real crate art of the crate they pay (`ShopIcons.crate`, the highest zone's crate, or its golden version for the jackpot). The "?" box is only a fallback for a missing picture. The two jackpot slices get a thin gold edge on the wedge itself, never a ring around the picture.
- **The win.** The landed slice's pill turns gold with dark text until the next spin, and nothing else stays lit. There's no ring around the picture.
- **Odds** opens the list as now. Each row has the same picture as its slice, a short name, and the chance, likeliest first.
- **QA.** The phone, tablet and desktop Spin scenes in the UI gate show 8 equal pills, the real crate art, no ring after a win, and no text under 12 px.

### 2c. Daily Treat (data-model 11e)

| day | now | was |
|---|---|---|
| 2 | 15 golden fish and 1 spin | 2 Salmon, 15 golden fish and 1 spin |
| 4 | 1 Classic Crate and 1 spin | 1 Caviar, 1 Classic Crate and 1 spin |
| 6 | a Lucky Potion and 10 golden fish | 3 Tuna and a Lucky Potion |
| 7 | 1 Golden Classic Crate, 1 Star Treat and 50 golden fish | the same plus 3 spins |

Days 1, 3 and 5 keep their coins. Day 7 keeps its Star Treat, the one food prize Derek okayed ("overall good idea").

### 2d. Quests (quests.md sections 2, 3 and 5)

| prize | now | was |
|---|---|---|
| the Big Request | 300 s of day rate (at least 400) and 5 golden fish | the same with 4 fish and 1 Tuna |
| the daily set | 1 Big Money Potion, 1 Gold Rush Potion and 10 golden fish | the same plus 1 spin |
| a weekly quest | 1,200 s of day rate (at least 2,000) and 15 golden fish | the same plus 1 spin and 1 Salmon |
| the weekly set | 1 Golden Classic Crate, 40 golden fish and 3 Big Money Potions | the same plus 3 Gold Rush, 2 Quick Bait and 3 spins |
| achievement M | 900 s of day rate (at least 1,000) and 1 Money Potion | the same plus 2 spins |
| achievement L | 1,800 s of day rate (at least 2,500) and 1 Classic Crate | the same plus 3 spins and a Big Tip Potion |
| achievement XL | 3,600 s of day rate (at least 5,000), 1 Golden Classic Crate and 1 Big Money Potion | the same plus 5 spins and a Gold Rush Potion |

Slot 1 to 4 dailies (coins and 2 fish) and S achievements (coins and a spin) are already two things.

### 2e. Index tracks (golden-fish.md sections 5 and 5b)

| milestone | now | was |
|---|---|---|
| `cats3` | coins and fish as now, no spin | coins, fish and 1 spin |
| `cats6` | the area's crate and: Alleyway 5 golden fish, Park 10 golden fish, Neighbourhood 2 Caviar, Woods 2 Moon Milk, Sewer 2 Star Treat | 3 Tuna, 3 Salmon, 3 Caviar, 3 Moon Milk or 3 Star Treat and the crate |
| `cats10` | the area's Golden Crate, 2 of its crates and its fish (25, 35, 50, 75, 100) | the same plus food and 2 spins |
| `gold1` | the area's crate and its fish, no spin | fish, 1 spin and the crate |
| `gold2` | coins and fish as now, no spins | coins, fish and 2 spins |
| `gold6` | coins as now and 10 more fish than now (50, 60, 70, 90, 110) | coins, food, fish and 3 spins |
| `gold10` | coins, 2 Golden Crates and fish as now, and the tag | the same plus 5 spins |
| `total25` | 1 Golden Classic Crate and 30 golden fish | the same plus 2 spins |
| `total50` | 150 golden fish, 2 Golden Classic Crates and 10 spins, and the tag | unchanged (three pictures and the tag) |

`gold4`, `gold8` and the other All Cats milestones are already two things. Every permanent bonus is unchanged. Players who already claimed a milestone keep what they got, as before (N173).

### 2f. Visitors and codes (data-model 12b and 11d)

- **Mystery Visitor gift:** a potion 60%, 10 golden fish 30% (was 10%), 1 spin 10%. The 2 Salmon (20%) goes. The full spin bank swap to 10 golden fish stays.
- **Cat Collector:** the value 2 row becomes 10 golden fish (was 3 Tuna and 1 spin). Every other row is unchanged.
- **Codes:** `launch` becomes 600 s of day rate (at least 1,000) and 25 golden fish (was also 2 spins and 3 Tuna). The group code becomes 1,800 s of day rate (at least 2,500), 100 golden fish and 1 Classic Crate (was also 5 spins, 2 Caviar and a Tip Potion). `playtest` stays as it is for testers and ends before the game goes public.

### 2g. What this does to the flows

For a regular who plays two hours a day at Tier 3 or 4:

| | before | after |
|---|---|---|
| free food a day | about 15, mostly Kibble, Tuna and Salmon | about one, always a dealer food |
| golden fish a day (Tip Jar, spins, Mystery gifts, dailies) | about 63 | about 90 |
| spins a day (the free one plus banked) | about 5 | about 3 |

(Since #1281, 11-05, the coin foods are bought at the Corner Shop's 5-minute rotation instead of the bowl; see corner-shop-v2.md section 1b. Prices and the coin sink are unchanged.) The bowl now runs on coins: a Tier 3 player who keeps it busy with Salmon spends about 5,000 coins an hour, under 1% of their income, so it never blocks anyone, but which food to buy is a choice again. The extra 25 to 30 golden fish a day go to the new Fresh Catch shelf (section 3).

## 3. The Fresh Catch shelf: potions every 5 minutes by day

**Since #1437 (built in #1473):** the window is one global game day, 390 s from `Config.ClockEpoch`, so the stock restocks at each sunrise, at the same moment on every server (data-model.md section 9). Read "5-minute window" below as that game-day window.

The Golden Fish Market gets a chalkboard on its stall, "Fresh Catch", and a third tab in its window. By day it sells potions for golden fish, with a stock that rolls every 5 minutes. This answers both of Derek's ideas at one station, with no new model beyond the board: potions in the Fish Market, and a daytime shop that rotates every 5 minutes.

- **The roll.** The stock uses the code the night dealer uses today (data-model 8b, v0.8), moved here: every FreshCatchWindowSeconds (300) a window `floor(os.time() / 300)` rolls an amount of each item from `FreshCatchAmountWeights`, seeded only by the window, so every server shows the same stock and nobody can hop servers for a better one. The amount is per player: each player can buy up to that many in the window.
- **By day only.** At night the board reads "Back at sunrise" and the tab is closed. The night belongs to the dealer (section 4).
- **What it sells:**

  | item | golden fish | 0 | 1 | 2 | 3 | average in stock |
  |---|---|---|---|---|---|---|
  | Money Potion (10 min, +25% money) | 10 | 10% | 30% | 40% | 20% | 1.7 |
  | Swift Potion (5 min, +4 speed) | 6 | 10% | 30% | 40% | 20% | 1.7 |
  | Steady Paw Potion (10 min, the next net's bands) | 12 | 30% | 45% | 25% | 0% | 0.95 |
  | Quick Bait Potion (30 min, bait 25% sooner) | 15 | 40% | 45% | 15% | 0% | 0.75 |
  | Big Money Potion (30 min, +50% money) | 25 | 60% | 35% | 5% | 0% | 0.45 |
  | Lucky Potion (10 min, +0.5 Luck and double gold on bait) | 25 | 60% | 35% | 5% | 0% | 0.45 |
  | Gold Rush Potion (30 min, +25% gold luck) | 30 | 75% | 25% | 0% | 0% | 0.25 |

- Since #1190 (the friend, 11-04), the board and the tab show no stock chances, no counts and no "Fresh catch in 3:12" clock: a row is buyable or reads "Sold out". The chances above stay server numbers.
- **A heads up.** When a window stocks a Gold Rush Potion, players in the server by day who have enough golden fish for it get one small toast, "Gold Rush Potions at the Fish Market!", at most once a window. Settings has a "Shop alerts" switch, on by default.
- Potions bought here go into the potion bag like any other. The PotionMaxMinutes cap and its "Full" refusal apply when drinking, not when buying.
- **Earn only.** Everything on the shelf costs golden fish, which are never sold for Robux, so nothing here is a paid random item. If Monetization-Agent's potion bundles ship, the Lucky and Gold Rush Potions stay out of any Robux bundle, because they change odds.

- **Its coin twin (#1030, OK'd by Derek 2026-11-03).** The Corner Shop ([corner-shop.md](corner-shop.md)) reuses this roll for a coins-only stock beside the Market, open day and night.

## 4. The night market: one stock per server per night

Derek wants the dealer's stock to stay put for the whole night and change every night on each server.

- **At dusk** each server rolls the dealer's stock once with its own `Random`, using `DealerAmountWeights` (data-model 8b, unchanged). It holds for the whole night, and the next dusk rolls again. The 5 minute windows and the "Fresh stock in m:ss" restock go.
- **Per player, per night.** Each player can buy up to the stocked amount of each food that night. The server keeps the counts in memory for the night and clears them at sunrise. `profile.dealer` is no longer read, and the next save version drops it.
- **Server hops.** A player who hops to another server sees that server's night. That is fine: every dealer food costs coins, and the per player amounts still hold in each server.
- **Remotes.** `DealerStock` becomes `{ night, stock = { { lureId, cost, amount, bought } } }`, where `night` is the server's night count. `BuyDealerFood(lureId, night)` is refused unless `night` is the current night, so a buy sent at sunrise as the cart leaves gets a clear answer.

## 5. "Money", not "tips", on screen

Derek's 22:32 ask. Wherever a player reads about their income, the word is money. Only the coins customers leave on tables keep the word tips.

- Potions: Tip Potion becomes **Money Potion** ("+25% money") and Big Tip Potion becomes **Big Money Potion** ("+50% money"). Their ids (`tip_potion`, `big_tip_potion`) stay, so saves keep working.
- Bonus chips: "+2% money forever" (Index), "+5% money a level" (Golden Espresso), "+10% money with pals" (F92), and "Money x1.5" in place of "Tips x1.5" wherever a multiplier shows.
- Kept: tip piles on the tables, Collect at the till and the Tip Jar's name, because those are real tips a customer leaves.
- The docs keep their internal names (TimedTipsMax and the rest), so no code changes beyond the shown text.

## 6. Contracts

- Catalog: the prize rows in section 2 (`Catalog.tipJar`, `spinWheel`, `dailyTreat`, `questPrizes`, `achievementPrizes`, `indexPrizes`, `collectorOffers`, `codes`, the Mystery gift table); the potions' `name` and `effect` text in section 5; new `Catalog.freshCatch` rows `{ id, kind = "potion" | "crate", potionId?, crateId?, fish }`.
- Config: FreshCatchWindowSeconds 300; FreshCatchAmountWeights as in section 3; DealerWindowSeconds goes.
- Profile (next save version): `freshCatch = { window, bought = { [itemId] = count } }`, the shape the dealer uses today, cleared when the current window is greater than the saved one (the N32 rule). `dealer` is dropped.
- Remotes: `BuyFreshCatch(itemId, window)` new: day, the caller within 14 studs of the `FishMarket` station, `window` the current one, `bought` below the amount, enough golden fish; 2 per second; it answers with `FreshCatchStock` (`{ window, restocksAt, stock = { { itemId, fish, amount, bought } } }`) after every buy, bought or refused. `DealerStock` and `BuyDealerFood` change as in section 4. `ShopAlert(itemId)` new, server to client.
- Analytics: the economy events get the sink `fresh_catch` (golden fish); a custom event `fresh_catch_buy` (value fish spent, fields item id, tier).
- Who builds: Gameplay-Engineer (prize rows, the Fresh Catch roll and remote, the per night dealer), UI-Engineer (the Fresh Catch tab, the board, the "money" text, the toast and its switch), Model-Agent (the chalkboard on the stall), QA-Planner (section 7).

## 7. QA checks

1. No reward table, wheel slice, gift or code (other than `playtest`) pays Kibble, Tuna or Salmon.
2. No prize shows more than two pictures, apart from the big ones in section 1, which show at most three. Permanent bonus chips and name tags do not count.
3. The Tip Jar's 120 minute gift is a Classic Crate and 30 golden fish. The wheel's slice 2 pays 3 golden fish and slice 4 a Caviar.
4. By day the Fish Market's Fresh Catch tab shows the same stock on two servers in the same 5 minute window, a player can buy each item up to its amount, and a buy sent across the restock is refused with the fresh stock.
5. At night the tab is closed, the dealer's stock stays the same all night, a second server's night stock differs, and the next night rolls a new one.
6. A Gold Rush Potion in stock toasts once per window to players with 30 golden fish or more, and never with "Shop alerts" off.
7. The potion bag reads Money Potion and Big Money Potion, and every income bonus reads "money"; tip piles still say tips.
