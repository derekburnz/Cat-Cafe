# Corner Shop v2: tiered useful items at fixed prices, and the Bag (#1180, #1181)

Decided 2026-11-04 by the friend, who owns this project's calls. Their live notes on #1180 and #1181 were relayed by the Coordinator and written up by Design-Agent. Owner: game-designer. Readers: Gameplay-Engineer, UI-Engineer, VFX, QA. This replaces [corner-shop.md](corner-shop.md) sections 2 and 5 (stock, prices, contracts) and section 4's cat picker. The stall, the 5-minute roll, the shows and the "does not sell" list (section 3) stay as they are.

The friend's notes:
- #1180: "useful items, not only cosmetics", "scaling in tiers from weak to strong", "prices are fixed and don't change with the player's income", "the really good items are very expensive and come into stock less often; the weak ones are cheap and almost always in stock".
- #1181: "more ways to get cat food", "a Bag button on the left", "don't force a cat pick right after buying food".

## 1. The stock

Every item is sold for **coins**, at a **fixed price**. Sizes go Small, regular, Big and (for food) Feast. A bigger size lasts longer or gives more XP, costs much more, and is in stock less often.

| family | Small | regular | Big | Mega | a day (all sizes together) |
|---|---|---|---|---|---|
| Swift Potion (+4 walk speed) | 3 min · 300 | 10 min · 5,000 | 30 min · 500,000 | | no limit |
| Steady Paw Potion (wider net bands) | 5 min · 1,000 | 10 min · 20,000 | 30 min · 2,000,000 | | 4 |
| Quick Bait Potion (bait 25% sooner) | 10 min · 2,500 | 30 min · 60,000 | 60 min · 6,000,000 | | 2 |
| Cat Whistle (a marker on the nearest stray in your area) | 5 min · 800 | 10 min · 15,000 | 30 min · 1,500,000 | | 4 |
| Cat food (XP for one cat, goes to the Bag) | Small Snack, 600 XP · 400 | Cat Snack, 2,000 XP · 15,000 | Big Snack, 6,000 XP · 1,000,000 | Cat Feast, 20,000 XP · 80,000,000 | up to 20,000 XP bought |
| Shows (looks only) | | Bubble Machine, 10 min · 50,000 | Cafe Fireworks, 20 s · 250,000 | | no limit |

**How often each size is in stock** (the chance of 0, 1, 2 or 3 in a 5-minute window, the same for every family). These are server numbers only. Since #1190 the window shows no stock chances, no "n left" counts and no restock clock: a row is either buyable or reads "Sold out".

| size | 0 | 1 | 2 | 3 | average | shown to |
|---|---|---|---|---|---|---|
| Small | 0% | 10% | 30% | 60% | 2.5 | everyone |
| regular | 20% | 50% | 25% | 5% | 1.15 | everyone |
| Big | 70% | 25% | 5% | 0% | 0.35 | Tier 3 and up |
| Mega (Cat Feast) | 90% | 10% | 0% | 0% | 0.1 | Tier 4 and up |

- **Fixed prices, as the friend asked.** The price never changes with income, the tier, a money pass or the window. A rough feel for what a price means at each tier (day rates from the economy-ladder.md pace model): a Small item is a minute or two of income at Tier 1. A regular one is a minute or two at Tier 2. A Big one is 2 to 25 minutes at Tier 3 and under a minute at Tier 4. A Cat Feast is about 15 minutes at Tier 4 and 5 at Tier 5.
- **Why the daily limits matter now.** With fixed prices, late-game players find Small and regular items almost free. So the limits, not the prices, keep the useful items in balance: at most 2 Quick Bait Potions and 4 each of Steady Paw and Whistle a day, whatever their size, and at most 20,000 XP of food bought a day. The Swift Potion and the shows only help you walk or look nice, so they have no limit. The limits are enforced on the server and never shown on a row (#1190). A player who reaches one gets a short refusal toast when they try to buy: "That's all the Quick Bait for today, back tomorrow!"
- **Tier gates.** Big items show from Tier 3 and the Cat Feast from Tier 4. Below that the row reads "Opens at Tier 3" in grey, so a new player isn't shown a 6,000,000 coin price. Stock is still the same on every server; the gate only hides the row.
- **Durations, not strengths.** Sizes differ in how long they last (or how much XP they give). A Small and a Big Steady Paw give the same bands, so mixing sizes adds minutes to one buff chip and never shows two strengths at once. Each drink adds its minutes up to `PotionMaxMinutes` (24 hours), as today.
- **The Fresh Catch shelf** keeps selling the regular Steady Paw and Quick Bait Potions for golden fish, with no daily limit. That stays the way to get more than the coin limits allow.

## 1b. Bait foods move here from the bowl (#1281)

Decided by Coordinator for the friend, overnight 11-05, from Derek's 11-04 ask: "foods shouldn't be buyable from the bait bowl menu", sell them at the Corner Shop "with limited stock in its 5 minute rotations".

- **Which foods:** the three shop foods, Kibble (Common), Tuna (Rare) and Salmon (Epic). The dealer foods (Moonlit Sardines, Caviar, Moon Milk, Star Treat) stay with the night dealer, so they keep their rarity and their reason to visit at night.
- **Price:** each food keeps today's tier-scaled price, `Economy.foodPrice` (Kibble 100, Tuna 500, Salmon 2,500 at Tier 1, growing by `FoodTierPriceFactor`). This is the one exception to section 1's fixed prices, because a fixed bait price would be free late on and the bowl is a coin sink by design (rewards-and-shops.md section 2g).
- **Stock per 5-minute window**, using the section 1 roll with its own weights (chance of 0, 1, 2 or 3):

  | food | 0 | 1 | 2 | 3 | average |
  |---|---|---|---|---|---|
  | Kibble | 0% | 0% | 20% | 80% | 2.8 |
  | Tuna | 0% | 20% | 50% | 30% | 2.1 |
  | Salmon | 20% | 50% | 30% | 0% | 1.1 |

- **Enough to keep baiting.** A bowl takes a food every 8 to 10 minutes by day and every 5 at night, so about 1 food per window, or 2 with the Second Bowl pass. The shop offers about 6 a window. A normal player is never short. Salmon, the best coin food, sometimes isn't there, and that's the "limited" part. Bought food stacks in the player's `lures` (up to 99 of each), so one visit can stock up for a whole session or an offline night.
- **Bowl menu:** no Buy buttons. Each food row shows "You have 3" and **Use**. With none left it reads "Get more at the Corner Shop" in calm grey, and the dealer foods keep "Night dealer". Food earned elsewhere (Daily Treat, prizes) lands in the same `lures` and shows there.
- **The Bag** gets a third tab, **Bait**, listing the player's foods and counts. It has no Use button there, since bait goes in at the bowl.
- **Policy:** bait for coins is the same as before; only where it's sold moves. Coins are never sold for Robux, the bowl's odds stay shown before a food goes in, and the Corner Shop row shows the food's rarity badge and its clean picture (#1261).
- **Server:** `BuyLure` refuses every request with the toast "Bait food is at the Corner Shop now", and is removed in the next cleanup. Food rows go through `BuyCornerShop` like other rows: stock, coins, 2 a second, and no daily limit. The server charges `Economy.foodPrice` for the player's tier at the moment of the buy. Food rows are the only ones whose price moves, so `BuyCornerShop` takes an optional `shownPrice` for `kind == "food"` rows and refuses, with the fresh stock, when the server's price is above it (for example after a rank up while the window was open). Fixed-price rows ignore it.
- **Save:** none. It uses the existing `lures` map, with a new cap of 99 per food (`LureMax`) on **new buys only**. A stack already above 99 stays as it is (the sanitize doesn't clamp it), so nobody loses food; it just can't grow by buying until it's used below 99.

## 2. Still not sold, and why (unchanged from corner-shop.md section 3)

No crates, crate keys, spin tokens or anything random. Money passes multiply coins, so these would become paid random items (monetization-policy section 2). No luck or Catnip, no income or tip boosts (rule v0.8), no net or bowl upgrades, no dealer food and no lawn decor. Nothing is limited-time: every item comes back (stock chances are server numbers only since #1190).

## 3. Cat food goes to the Bag (#1181)

- **No cat pick on buy.** Buying a snack, or earning one, puts it in the Bag. The cat picker that opened on buy is gone.
- **The Bag button.** The left menu's 🧪 Potions pill (ui-contract.md, under Decor) becomes 🎒 **Bag**, with the total count of everything in it beside the key cap. The key is **B**, and P still opens it. It opens the Bag window with two tabs:
  - **Potions:** today's Potions window, as it is.
  - **Cat Food:** a row per food the player has: picture, name, "+2,000 XP", "x3" and a green **Feed**. Feed opens the cat list, highest level first, each showing "Level 23 · 1,400 XP to 24". Tapping a cat feeds one and shows "+2,000 XP" on its card. Foods the player has none of don't show; an empty tab reads "Cat food comes from the Daily Treat, rescues, catches and the Corner Shop."
- **From the cat's card too.** Each cat's card gets a small **Feed** button when the Bag has any food. It lists the foods the player has, and tapping one feeds this cat.
- **No feeding cap.** Food in the Bag can be fed at any time, any amount. There was a 20,000 XP a day cap on food bought until #1255 (below).
- **No daily XP cap on bought food either (#1255, 2026-11-05).** Derek asked to remove the cap, and it's gone. The pacing check, decided by Coordinator for the friend, overnight 11-05:
  - **The stock is the limit now.** A player who buys every food row in every window gets at most about 95,000 XP an hour (Small 2.5 x 600, regular 1.15 x 2,000, Big 0.35 x 6,000 and Feast 0.1 x 20,000, a window, times 12). A working cat earns 3,600 an hour.
  - **Cats top out at level 50** (`CatMaxLevel`, 1.98 times a level-1 cat). Going from 1 to 50 is about 147,000 XP, so a rich player can max one cat in about 1½ hours of buying everything. Maxing six role cats takes most of a day.
  - **The cost** of buying everything is about 100M coins an hour at the fixed prices. That's most of a Tier 4 player's income and trivial only at Tier 5. So snacks mostly help late-game players who would reach Tier 5 soon anyway. Six maxed cats against typical level-20 cats is about +40% income: a real reward, not a skip.
  - **Verdict: OK, with a check.** QA's Pace.spec gets a profile that buys every food row it can afford in every window. If any tier time falls under economy-ladder.md check 3, the Big Snack and Cat Feast prices double (rule v0.8: raise prices). A cap does not come back. The cat level leaderboard is bounded by the same stock for everyone, since late on everyone can afford it.
- **Earlier buys.** v1 Cat Snacks were fed at once on buy, so no save holds any yet; nothing to migrate.

### Where cat food comes from

| source | what | how often |
|---|---|---|
| Daily Treat | day 1: 2 Small Snacks; day 3 and day 5: 1 Cat Snack each (beside their coins, two pictures each) | once a week each |
| Night rescues | 1 Small Snack for every cat rescued from a trap | each rescue |
| Net catches | a 10% chance of a Small Snack with any net catch of a stray. The chance is in the catch help ("Sometimes a cat drops a snack: 1 in 10") | each catch |
| The Cat Collector | a new offer row, "2 Big Snacks", valued between his fish offers (Gameplay-Engineer sets its `value` next to the 20-fish row) | when he visits |
| The Corner Shop | the food row in section 1 | the 5-minute roll |

A daily player earns roughly 5,000 to 6,000 XP of food a day, about 1½ hours of a cat's work: one Daily Treat stamp, about 5 rescues and about 20 net catches. That's useful but doesn't push the cat level leaderboard much.

- **Why not quests or Index milestones.** Their prizes already show the most pictures a prize may show (rewards-and-shops.md section 1, rule 3), so adding food there would break that rule.
- **Food is not bait.** Rule 1 there ("no shop food in prizes") is about the bait foods (Kibble, Tuna, Salmon). Cat food is a Bag item that gives XP, so it doesn't count.
- **The catch drop is free.** It comes from play and is never bought, so it is not a paid random item. Its chance still shows.

## 4. Contracts

- **Catalog:**
  - `Catalog.cornerShop` rows become `{ id, family, size = "small" | "regular" | "big" | "mega", kind = "potion" | "food" | "show", potionId?, foodId?, showId?, price, needsTier? }`. The `seconds` and `atLeast` fields go.
  - The ids: `swift_potion_small`, `swift_potion`, `swift_potion_big`; `steady_potion_small`, `steady_potion`, `steady_potion_big`; `quick_bait_potion_small`, `quick_bait_potion`, `quick_bait_potion_big`; `cat_whistle_small`, `cat_whistle`, `cat_whistle_big`; `small_cat_snack`, `cat_snack`, `big_cat_snack`, `cat_feast`; `bubble_machine`, `cafe_fireworks`.
  - Potions: the new potion ids share their regular potion's buff (a `buff` field on the potion, for example `swift_potion_big.buff = "swift_potion"`) with their own `minutes`. `cat_whistle` is a new potion with the effect "Shows the nearest stray" and its own chip.
  - New `Catalog.catFood` rows `{ id, name, xp }`: `small_cat_snack` 600, `cat_snack` 2000, `big_cat_snack` 6000, `cat_feast` 20000.
  - `Catalog.dailyTreat` days 1, 3 and 5 gain their food, and `Catalog.collectorOffers` gains the "2 Big Snacks" row.
- **Config:**
  - `CornerShopSizeWeights = { small = { 0, 10, 30, 60 }, regular = { 20, 50, 25, 5 }, big = { 70, 25, 5, 0 }, mega = { 90, 10, 0, 0 } }`. This replaces the per-row `CornerShopAmountWeights`.
  - `CornerDailyLimits = { steady = 4, quick_bait = 2, whistle = 4 }`, by family. `CornerFoodXpPerDay` is removed with #1255 (it was 20000 and replaced `CornerSnackXpPerDay`). `snackXp` can stay unused in the save until a later bump.
  - `CatchSnackChance` 0.10 and `RescueSnack` "small_cat_snack".
- **Profile (next save version, coordinate with the idea-credits bump in claim #1113):**
  - `catFood = { [foodId] = count }`, known ids only, whole counts from 1 to 999.
  - `cornerShop` keeps `window` and `bought`, and gains `day`, `today = { [family] = count }` and `foodXpToday`, all cleared when `day` isn't today (UTC). `snackDay` and `snackXp` go.
- **Remotes:**
  - `BuyCornerShop(itemId, window)`: the caller within `CornerShopRange`, the current `window`, the row's `needsTier` met, the window's amount not used up, the family's daily limit not reached, and for food the day's bought XP plus the row's XP no more than 20,000; enough coins. It charges the row's `price`; `shownPrice` and `catId` go, since prices are fixed and food goes to the Bag. Potions go to the potion bag and food to `catFood`. 2 a second. It answers with `CornerShopStock` (rows gain `size` and `needsTier`; `today` and `perDay` stay server-side and are not sent, #1190).
  - New `FeedCat(foodId: string, catUid: string)`: the player owns the cat and has at least one of that food. It takes one, grants the food's XP through `Economy.grantXp` (level ups count in `stats.catLevelUps` as today) and answers with the cat's new level and XP. 4 a second.
- **Client:**
  - UI-Engineer: the Bag pill and window (Potions and Cat Food tabs), the Feed button on the cat card, the Corner Shop rows with size and the tier gate (no stock chances, counts, daily-limit lines or restock clock, #1190), and the removal of the buy-time cat picker.
  - The Cat Whistle marker, as in corner-shop.md's v2 note: a `WorldMarker` paw over the nearest replicated stray or trapped cat in the current area, updated on a 0.5 s step.
- **Analytics:** `corner_shop_buy` gains the field `size`. New `cat_fed` (value XP, fields food id and source: bought or earned).
- **Who builds:** Gameplay-Engineer (Catalog, Config, save, both remotes, the food sources); UI-Engineer (Bag, Feed, shop rows); VFX (the whistle marker's look, if needed); QA (section 5). This touches `Config.luau`, `Remotes.luau` and the save, so open a `claim` issue first.

## 5. QA checks

1. Prices: a Small Swift Potion costs 300 coins at Tier 1 and at Tier 5, with or without a 2x Money pass.
2. Rotation: over 200 windows, Small rows are in stock at least 95% of the time, Big rows about 30% and the Cat Feast about 10%. Two servers show the same stock in the same window.
3. Tier gates: at Tier 2 the Big rows read "Opens at Tier 3" and can't be bought (a forced `BuyCornerShop` is refused); at Tier 3 the Cat Feast still reads "Opens at Tier 4".
4. Daily limits: a third Quick Bait Potion of any size in one UTC day is refused with the toast "That's all the Quick Bait for today, back tomorrow!", and a fifth Steady Paw or Whistle with the matching toast. No row ever shows a daily count. Food has no daily XP limit since #1255: a Big Snack bought on top of 15,000 XP the same day goes through. All of these reset at 00:00 UTC.
5. Bag: buying a Cat Snack opens no picker, and the Bag's Cat Food tab shows "x1". Feeding it to a cat gives exactly 2,000 XP and the count drops; feeding with none left is refused.
6. Sources: Daily Treat day 1 gives 2 Small Snacks; a rescue gives 1; over 500 net catches the drop rate is within 2 points of 10%; the Collector can offer "2 Big Snacks".
7. Mixing sizes: drinking a Small then a Big Steady Paw shows one chip with 35 minutes, not two chips.
8. Pace.spec: a player who buys every daily limit (2 Big Quick Bait, 4 Big Steady Paw, and every food row in stock since #1255) every day. No tier time falls under economy-ladder.md check 3; if one does, lower the potion daily limits first, and for food double the Big Snack and Cat Feast prices (food has no daily limit since #1255).
9. Nothing in the Corner Shop costs Robux or golden fish, and nothing bought is random.
