# The Corner Shop: a coin shop that restocks every 5 minutes (#1030)

**Since #1437 (built in #1473):** the window is one global game day, 390 s from `Config.ClockEpoch`, so the stock restocks at each sunrise, at the same moment on every server (data-model.md section 9). Read "5-minute window" below as that game-day window.

**v2 (2026-11-04, #1180 and #1181): [corner-shop-v2.md](corner-shop-v2.md) replaces sections 2 and 5 below and the buy-time cat picker in section 4.** It has fixed coin prices, Small to Big sizes, daily limits and cat food in the Bag. The stall, the 5-minute roll, the shows and section 3 stay.

Proposed 2026-11-03 by Design-Agent (friend's project) and OK'd by Derek the same day (16:55), for Derek's playtest note: "the fresh catch rotating every 5 minutes is good but there should be also a cash item shop where extra money can be spent". Owner: game-designer. Readers: Derek, Gameplay-Engineer, UI-Engineer, Model-Agent, VFX, QA. Linked from [rewards-and-shops.md](rewards-and-shops.md) section 3 (Fresh Catch), whose roll it reuses.

## 1. In one paragraph

A small corner shop stall in the Town Square (town-layout-v3.md), beside the Golden Fish Market and its Fresh Catch board; Model-Agent picks the exact spot. It sells a short list of fixed items **for coins only**. Like Fresh Catch, every 5 minutes it rolls how many of each item are in stock, the same on every server. Every price is a number of seconds of the player's own day rate, so an item costs the same minutes of play at Tier 1 and at Tier 5, with or without a money pass. Nothing in it is random, nothing in it speeds up the tiers, and it never pops up or nags.

## 2. What it sells

| item | what it does | price (seconds of day rate) | at least | 0 | 1 | 2 | 3 | average in stock |
|---|---|---|---|---|---|---|---|---|
| Swift Potion | +4 walk speed for 5 min, into the potion bag | 120 | 200 | 0% | 20% | 40% | 40% | 2.2 |
| Cat Snack | +1,200 XP for one cat the player picks (20 minutes of work) | 300 | 500 | 10% | 30% | 40% | 20% | 1.7 |
| Big Cat Snack | +6,000 XP for one cat (100 minutes of work) | 1,200 | 2,500 | 60% | 35% | 5% | 0% | 0.45 |
| Bubble Machine | bubbles drift from the cafe's door for 10 minutes; everyone sees them | 600 | 1,000 | 30% | 50% | 20% | 0% | 0.9 |
| Cafe Fireworks | a 20 second firework show over the player's cafe, seen by everyone nearby | 900 | 1,500 | 40% | 50% | 10% | 0% | 0.7 |

- **Price** = `max(atLeast, floor(seconds x dayRate))`, where dayRate is `Economy.incomePerSecond(profile)`: the cats, the cafe and the money pass in, running potions out. That is the same day rate offline pay uses (economy-ladder.md section 5). A 2x Money player pays twice the coins, so a pass makes the shop no cheaper in minutes, and nobody is pushed towards a pass to afford it.
- **Snack cap.** Snacks give at most `CornerSnackXpPerDay` (12,000 XP, about 3 h 20 of work) a UTC day, across all cats. The card shows "Snacks today: 4,800 / 12,000 XP". This keeps the cat level leaderboard (`topCatLevel`) about play, not spending, and a cat earns only +2% a level, so snacks never pay back their price within a tier.
- **Fireworks and bubbles** are for showing off to friends. Each cafe runs one show at a time: a second one waits until the first ends. They are client effects inside the VFX budgets (animation-vfx skill): the bubbles count as one steady emitter, the fireworks as one burst, and both shrink to the low budget in Low performance mode and become a short glow with Reduce Motion.

## 3. What it does not sell, and why

- **No Money Potion and nothing else that raises income** (a Busy Bell, a customer rush). It would pay back more than it costs, and the tiers would speed up (rule v0.8, economy-ladder.md check 3).
- **No Steady Paw or Quick Bait Potions.** They help catches, and they stay on the Fresh Catch shelf for golden fish, so that shelf stays worth a visit.
- **No dealer food.** The night dealer's amounts are what keep Caviar, Moon Milk and the Star Treat rare (economy-ladder.md section 4). Kibble, Tuna and Salmon are already sold for coins at the bowl.
- **No golden fish, crates, spins or anything random for coins.** Money passes multiply coins, so a coin route to random items would make them paid random items (monetization-policy section 2).
- **No looks-only decor.** The front lawn (front-lawn.md) is already the coin decor shop: bought once, chosen freely, never rotating. The Corner Shop card has a line, "Lawn pieces are in Decor, Front lawn", so it points players there and doesn't make a second, rotating copy of the same thing.
- **Nothing limited.** Every item comes back in a later window. (The stock chances were shown here until #1190; the friend had them removed from every shop.)

## 4. How it works in game

- **The stall.** Model `CatCafe_Street_CornerShop`: a striped awning, a shop cat behind the counter, jars and a little chalkboard. Tag `CornerShop`, a prompt within 14 studs (`CornerShopRange`) opens its window. Open day and night: it sells for coins, and the night is quieter for coins than the day.
- **The roll.** The same code as Fresh Catch: every `CornerShopWindowSeconds` (300) window `floor(os.time() / 300)` rolls each item's amount from `CornerShopAmountWeights`, seeded by the window and the salt "corner", so every server shows the same stock and it differs from the Fresh Catch roll. The amount is per player: each player can buy up to that many in the window.
- **The window.** (#1190: no restock clock, stock chances or counts; the parts in quotes below that show them are dropped.) A cocoa card "Restocks in 3:12" over "The same stock on every server", then a row per item: its picture, name, what it does, how often it is stocked ("In stock 9 times in 10"), a stock line ("x2 left", "You bought 2", "None this time") and a green Buy with the coin price ("Sold out", "None"). The Cat Snacks open a cat picker first (the cat menu's list, highest level first, each showing "Level 23, 1,400 XP to 24").
- **No alerts.** Unlike Fresh Catch, the Corner Shop never sends a toast. Nothing here is rare enough to tell anyone about.
- **Analytics.** The economy sink `corner_shop` (coins) and the custom event `corner_shop_buy` (value coins, fields item id and tier). After launch, growth reads how many coins flow here against the rank ups to see whether it works as a sink.

## 5. Contracts

- **Config:** `CornerShopWindowSeconds` 300, `CornerShopRange` 14, `CornerShopAmountWeights` as section 2, `CornerSnackXpPerDay` 12000.
- **Catalog:** `Catalog.cornerShop` rows `{ id, kind = "potion" | "snack" | "show", potionId?, xp?, showId?, seconds, atLeast }`: `swift_potion` (potion), `cat_snack` (xp 1200), `big_cat_snack` (xp 6000), `bubble_machine` (show, 600 s long), `cafe_fireworks` (show, 20 s long).
- **Shared:** `Economy.cornerPrice(row, dayRate)` returns `max(row.atLeast, floor(row.seconds * dayRate))`, so the server and the window show the same number.
- **Profile (next save version):** `cornerShop = { window, bought = { [itemId] = count }, snackDay, snackXp }`, cleared by window as `freshCatch` is (the N32 rule), and `snackXp` cleared when `snackDay` is not today (UTC).
- **Remotes:**
  - `BuyCornerShop(itemId: string, window: number, shownPrice: number, catId: string?)`: the caller within `CornerShopRange` of a `CornerShop` stall, `window` the current one, `bought` below the amount, the server's price not above `shownPrice` (if it is, it is refused and answers with the fresh stock, so a price never rises after the tap), enough coins; for a snack, `catId` a cat the player owns and the XP within today's cap (a snack that would go over the cap is refused with "Snacks are full for today"). It charges the server's price. 2 a second. It answers with `CornerShopStock` (`{ window, restocksAt, stock = { { itemId, price, amount, bought } }, snackXp }`) after every buy, bought or refused.
  - `CafeShow(userId: number, showId: string, endsAt: number)` server to all clients: the cafe whose owner bought a show plays it until `endsAt` (a client that joins late still sees the rest of it).
- **Analytics:** as section 4.
- **Who builds:** Gameplay-Engineer (the roll, the remote, the snack XP through `Economy.grantXp`, the show queue per cafe), UI-Engineer (the window and the cat picker), Model-Agent (the stall), VFX (the bubbles and the fireworks), QA (section 6).

## 6. QA checks

1. Two servers in the same 5 minute window show the same Corner Shop stock, and it differs from the Fresh Catch roll in that window at least sometimes over 50 windows.
2. A Swift Potion costs 120 s of the player's day rate (at least 200); with a 2x Money pass the coin price doubles, and a running Money Potion does not change it.
3. A buy sent across a restock is refused with the fresh stock. A buy with a `shownPrice` below the server's price is refused and nothing is charged.
4. Cat Snacks stop at 12,000 XP a UTC day and the card shows the count; the cap resets at 00:00 UTC.
5. Two players' fireworks over the same cafe play one after the other, not on top of each other; Low performance mode and Reduce Motion use their lighter versions.
6. Pace.spec with a player who spends every spare coin here: no tier time changes by more than the run-to-run noise, and none falls under economy-ladder.md check 3.
7. Nothing in the Corner Shop costs golden fish or Robux, and nothing in it is random.
