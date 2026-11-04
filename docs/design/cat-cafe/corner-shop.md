# The Corner Shop: a coin shop that restocks every 5 minutes (#1030)

v2 2026-11-04 (#1180): useful items with daily limits (sections 2 and 3). Proposed 2026-11-03 by Design-Agent (friend's project) and OK'd by Derek the same day (16:55), for Derek's playtest note: "the fresh catch rotating every 5 minutes is good but there should be also a cash item shop where extra money can be spent". Owner: game-designer. Readers: Derek, Gameplay-Engineer, UI-Engineer, Model-Agent, VFX, QA. Linked from [rewards-and-shops.md](rewards-and-shops.md) section 3 (Fresh Catch), whose roll it reuses.

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
| Steady Paw Potion (v2) | 10 min of wider catch bands on the net, into the potion bag | 300 | 300 | 20% | 40% | 30% | 10% | 1.3 |
| Quick Bait Potion (v2) | 30 min of bait waits 25% shorter, into the potion bag | 900 | 1,500 | 50% | 40% | 10% | 0% | 0.6 |
| Cat Whistle (v2) | for 10 min a paw marker shows over the nearest stray in the area you're in (day strays and night rescues) | 240 | 300 | 20% | 40% | 40% | 0% | 1.2 |

**v2 (2026-11-04, #1180, the friend's live note: "useful items, not only cosmetics").** Three useful items join, so the stall is mostly things that help you play: the Swift Potion, both Cat Snacks, the Steady Paw and Quick Bait Potions and the new Cat Whistle. The two shows stay as the fun extras. Each new item also has a **daily limit**, counted per player per UTC day and shown on its row ("2 of 3 today"):

| item | a day | why |
|---|---|---|
| Steady Paw Potion | 3 | a catch helper: enough for a busy session, not a whole day of easy catches |
| Quick Bait Potion | 1 | it speeds up getting cats, and cats gate the tiers, so one 30 minute run a day |
| Cat Whistle | 3 | finding a stray saves walking, not money |

The Fresh Catch shelf keeps selling the same two potions for golden fish, with no daily limit. The coin route is the capped one, so the fish shelf is still worth a visit. The Cat Whistle is new: a buff in the potion bag (`cat_whistle`, 10 minutes, its own chip). While it runs, the client puts a `WorldMarker` paw over the nearest stray or trapped cat in the player's current area, using the strays the server already replicates. It shows nothing through walls that the player couldn't walk to, and nothing in other areas.

- **Price** = `max(atLeast, floor(seconds x dayRate))`, where dayRate is `Economy.incomePerSecond(profile)`: the cats, the cafe and the money pass in, running potions out. That is the same day rate offline pay uses (economy-ladder.md section 5). A 2x Money player pays twice the coins, so a pass makes the shop no cheaper in minutes, and nobody is pushed towards a pass to afford it.
- **Snack cap.** Snacks give at most `CornerSnackXpPerDay` (12,000 XP, about 3 h 20 of work) a UTC day, across all cats. The card shows "Snacks today: 4,800 / 12,000 XP". This keeps the cat level leaderboard (`topCatLevel`) about play, not spending, and a cat earns only +2% a level, so snacks never pay back their price within a tier.
- **Fireworks and bubbles** are for showing off to friends. Each cafe runs one show at a time: a second one waits until the first ends. They are client effects inside the VFX budgets (animation-vfx skill): the bubbles count as one steady emitter, the fireworks as one burst, and both shrink to the low budget in Low performance mode and become a short glow with Reduce Motion.

## 3. What it does not sell, and why

- **No Money Potion and nothing else that raises income** (a Busy Bell, a customer rush). It would pay back more than it costs, and the tiers would speed up (rule v0.8, economy-ladder.md check 3).
- **Steady Paw and Quick Bait only with a daily limit (v2).** v1 kept them fish-only. Since #1180 they are on both shelves, but the coin route has the daily limits above, so the Fresh Catch shelf stays the way to get more.
- **No dealer food.** The night dealer's amounts are what keep Caviar, Moon Milk and the Star Treat rare (economy-ladder.md section 4). Kibble, Tuna and Salmon are already sold for coins at the bowl.
- **No golden fish, crates, crate keys, spin tokens or anything random for coins** (#1180 asked about keys and spins). Money passes multiply coins, so a coin route to random items would make them paid random items (monetization-policy section 2). Crates stay at the Golden Fish Market for golden fish (crate-prices.md), and spins stay free and never sold (data-model 11c).
- **No luck or Catnip for coins.** Luck changes the odds of every catch, so it stays a golden-fish item at the Market, like the Lucky and Gold Rush Potions on the Fresh Catch shelf.
- **No net or bowl upgrades.** Those are permanent upgrades in the coin upgrade shop already; a second, rotating copy would only confuse.
- **No looks-only decor.** The front lawn (front-lawn.md) is already the coin decor shop: bought once, chosen freely, never rotating. The Corner Shop card has a line, "Lawn pieces are in Decor, Front lawn", so it points players there and doesn't make a second, rotating copy of the same thing.
- **Nothing limited.** Every item comes back in a later window, and the stock chances are shown.

## 4. How it works in game

- **The stall.** Model `CatCafe_Street_CornerShop`: a striped awning, a shop cat behind the counter, jars and a little chalkboard. Tag `CornerShop`, a prompt within 14 studs (`CornerShopRange`) opens its window. Open day and night: it sells for coins, and the night is quieter for coins than the day.
- **The roll.** The same code as Fresh Catch: every `CornerShopWindowSeconds` (300) window `floor(os.time() / 300)` rolls each item's amount from `CornerShopAmountWeights`, seeded by the window and the salt "corner", so every server shows the same stock and it differs from the Fresh Catch roll. The amount is per player: each player can buy up to that many in the window.
- **The window.** A cocoa card "Restocks in 3:12" over "The same stock on every server", then a row per item: its picture, name, what it does, how often it is stocked ("In stock 9 times in 10"), a stock line ("x2 left", "You bought 2", "None this time") and a green Buy with the coin price ("Sold out", "None"). The Cat Snacks open a cat picker first (the cat menu's list, highest level first, each showing "Level 23, 1,400 XP to 24").
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
- **v2 (#1180):**
  - Catalog: three new `potion` rows, `steady_potion` (seconds 300, atLeast 300), `quick_bait_potion` (900, 1500) and `cat_whistle` (240, 300), each with `potionId` and a new `perDay` field (3, 1 and 3).
  - Potions: a new `cat_whistle` potion (10 minutes, effect "Shows the nearest stray", its own buff chip), which goes in the potion bag and counts toward PotionMaxMinutes like the others.
  - Config: `CornerShopAmountWeights` gains `steady_potion = { 20, 40, 30, 10 }`, `quick_bait_potion = { 50, 40, 10, 0 }` and `cat_whistle = { 20, 40, 40, 0 }`.
  - Profile (next save version): `cornerShop.day` and `cornerShop.today = { [itemId] = count }`, cleared when `day` isn't today (UTC). The snack fields stay as they are.
  - `BuyCornerShop` also refuses when `today[itemId]` has reached the row's `perDay` ("3 of 3 today, back tomorrow"), and `CornerShopStock` rows gain `today` and `perDay`.
  - Client: while `cat_whistle` runs, a `WorldMarker` paw sits over the nearest replicated stray or trapped cat in the player's current area. It is updated on a 0.5 s step and hidden in the intro and while carrying a cat.
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
8. v2: a second Quick Bait Potion in the same UTC day is refused with "1 of 1 today", and the limit resets at 00:00 UTC. Steady Paw and the Cat Whistle stop at 3. The Fresh Catch shelf still sells Steady Paw and Quick Bait for golden fish with no daily limit.
9. v2: with the Cat Whistle running, a paw marker shows over the nearest stray in the current area and moves to the next one after a catch. It shows nothing in another area, and nothing once the 10 minutes end.
10. v2: Pace.spec with a player who buys the daily Quick Bait and 3 Steady Paws every day: no tier time falls under economy-ladder.md check 3. If one does, raise the coin prices (rule v0.8).
