# The Day Cart: the Corner Shop's stock on a cart, one global roll a game day (#1577)

Status: specced by the game-designer thread (Design-Agent, friend's project), 2026-11-05, from Derek's Set 6 Q7 and Sets 7 to 9 answers. Derek2 confirmed on 11-05 that it rotates once per game day and is priced in coins. Builders: Gameplay-Engineer (stock roll, server), Model-Agent (the cart), UI-Engineer (the window).

## 1. What it is

Derek: the rotating shop gets "its own cart in town", apart from the Golden Fish Market. Coins only, no cosmetics or cats, the same for everyone, once a day. Each item rolls its own chance to be in stock, slightly lower for each step down the list. An item in stock rolls a quantity of 1 to 3.

The Corner Shop (corner-shop-v2.md) is already that shop: coins only, useful items, one roll per game day since #1437. So the Day Cart **is the Corner Shop moved onto a cart**, with Derek's new stock roll. There aren't two coin shops with the same goods.

- **Where.** A wooden market cart with an awning and a small "Day Cart" sign in the Town Square, on the side opposite the Golden Fish Market, so the coin shop and the fish shop read as two different places. Model-Agent picks the spot in the hometown layout and keeps the walk lines and the cannon clear. The Corner Shop building goes, or becomes the cart's backdrop if Model-Agent prefers. The prompt, window and remotes keep their Corner Shop names in code (`CornerShop*`); only the shown name changes to "Day Cart".
- **What it sells:** everything in corner-shop-v2.md sections 1 and 1b (the potions, the Cat Whistle, cat food, Kibble, Tuna and Salmon), minus the Shows row, which v3 already dropped. No cosmetics, cats, decor, golden fish, crates, spins or random items.
- **Prices:** as corner-shop-v2.md section 1 v3 and section 1b v2 (fixed coins, the bait foods tier-scaled). Later items cost more, as Derek asked.

## 2. The stock roll (replaces corner-shop-v2.md section 1's size roll)

- **The list.** Every row, sorted by its Tier 1 coin price from cheapest to dearest (Kibble and the Small potions first, the Cat Feast last). Today that's about 20 rows.
- **Chance to be in stock.** Row *i* (from 1) is in stock with `max(5%, 95% - 4.5% x (i - 1))`, so the first row is almost always there and the dearest are rare (`DayCartTopChance` 0.95, `DayCartStep` 0.045, `DayCartFloor` 0.05). On average about 11 rows a day.
- **Quantity.** A row in stock rolls 1 (50%), 2 (30%) or 3 (20%) (`DayCartQtyOdds`). That's how many each player can buy that day. The window shows "3 left", then "Sold out" (#1465).
- **The same cart for everyone.** One roll per global game day (#1555, one day is 390 s from `Config.ClockEpoch`), seeded from the day number, so every server and every player sees the same rows and amounts. Counts are per player, so one player's buys never empty the cart for anyone else. There's no shared scarcity and no "only 2 left for everyone" pressure.
- **Tier gates and daily limits** stay as in corner-shop-v2.md section 1 (Big rows from Tier 3, the Cat Feast from Tier 4, the Quick Bait, Steady Paw and Whistle daily caps), and the Fresh Catch shelf still sells the regular potions for fish.
- **No fake urgency.** The window says "New stock at sunrise" with no countdown pulse, and there are no sale banners or "last chance" lines.

## 3. Contracts

- Config: `DayCartTopChance` 0.95, `DayCartStep` 0.045, `DayCartFloor` 0.05, `DayCartQtyOdds` `{ 50, 30, 20 }`. The size table `CornerStockOdds` goes.
- `shared/CornerShop.luau`: `CornerShop.stock(day)` returns `{ [rowId]: amount }` from the list order and the seed, pure, with a spec. The save stays `cornerShop = { day, bought, ... }` (no version bump: `bought` is already keyed by row).
- World: the `CatCafe_Town_DayCart` model with a `PromptAnchor` attachment, like every station, at station(-17, -24) in the square's south-west quarter, opposite the Fish Market (Model-Agent, #1592). The old Corner Shop prompt is removed.
- UI: the window title reads "Day Cart". Each row shows its "n left", the stock odds stay hidden as in #1190, and the help line reads "Coins only. New stock at sunrise. The same cart for everyone."
- Analytics: `corner_shop_stock` gains `rows` (how many rows were in stock that day).

## 4. QA checks

1. Two servers show the same rows and amounts on the same game day, and both change at the same sunrise.
2. Over 100,000 seeded days, each row's in-stock rate is within 0.5 points of its formula, and the quantities are within 0.5 points of 50/30/20.
3. Buying 3 of a row in server A leaves the row at "3 left" for another player, and "Sold out" for the buyer even after hopping servers.
4. No cosmetics, cats, decor, fish or crates appear, and the cart takes coins only.
5. The cart stands clear of the walk lines and the cannon, and the old Corner Shop prompt is gone.
