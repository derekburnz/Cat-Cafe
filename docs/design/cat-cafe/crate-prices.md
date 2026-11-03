# One crate price and the Market rework (#1029)

Proposed 2026-11-03 by Design-Agent (friend's project), for Derek's playtest note on v181: "crate prices maybe should change or re-work the golden fish market". Owner: game-designer. Readers: Derek, Gameplay-Engineer, UI-Engineer, QA. It changes [golden-fish.md](golden-fish.md) sections 2 to 4, [rewards-and-shops.md](rewards-and-shops.md) section 3 and [camp-extras.md](camp-extras.md) section 2; those docs point here.

## 1. What changes, in one table

| | before | after |
|---|---|---|
| A crate at the Market (any zone crate or the Classic Crate) | 60 golden fish | **40** |
| 5 crates of one kind at the Market | 300 | **180** (the 5-crate bundle, 36 each) |
| Classic Crate on the Fresh Catch shelf | 50, in stock 10% of windows | **gone** (the Market's 40 is cheaper) |
| Yard Sale (Neighbourhood, Tier 3) | the Classic Crate and one zone crate a day, 40 each | **one free crate a day**: that day's zone crate |
| Odds, lucky twentieth, duplicate refunds, golden crates | 60 / 27 / 10 / 2.5 / 0.5; golden odds on the 20th; 10 / 20 / 40 / 80 / 150 | unchanged |

So one crate has one price everywhere it is sold, the bundle is the only quantity price and it reads as one, and the Yard Sale stops being a cheaper copy of the Market.

## 2. Why these numbers

- **One price.** Three prices for one Classic Crate (60, 50, 40) read as random. 40 is the lowest of the three, so nobody pays more than before for any crate.
- **About two to four crates a day.** A daily player at Tier 3 to 4 earns about 90 golden fish a day (rewards-and-shops.md 2g), plus about 50 from the Fish Pond at Tier 4 and 5. At 40 that is 2 crates a day at Tier 2 and 3 to 4 at Tier 3 to 5 with the Yard Sale's free one, against about one a day today. Late on, duplicates refund about 18 fish a crate (0.6 x 10 + 0.27 x 20 + 0.1 x 40 + 0.025 x 80 + 0.005 x 150), so a collector who has most pieces opens a crate for about 22 net. The refunds stay as they are: rule v0.8 says raise costs, never cut rewards.
- **The rare pieces stay rare, because the odds do not move.** A crate's Legendary still takes about 40 crates and its Mythical about 190. Focusing one page at 4 crates a day, that page's Mythical takes about 7 weeks on average, so `decor10` (+5% money forever, all 12 pieces) stays a long goal. At one crate a day it was 6 months, which is too far for a reward anyone can see coming.
- **The bundle** saves 20 fish on 5 crates (10%). It is a plain quantity price for golden fish, which are never sold for Robux, so it is not a paid random item. The window never says "best value" in a way that pushes; the card reads "5 crates: 180 (36 each)".
- **The Yard Sale** gave a Tier 3 buyer 40 fish of savings a day (two crates at 20 off). A free crate a day is the same 40 fish of value, it needs no fish in hand, and it is a reason to visit the Neighbourhood each day. It also fits "further areas pay more": Tier 3's camp gives one crate a day (40 fish of value), Tier 4's Fish Pond lands up to 96 fish a day.
- **Why not option B (a rotating "crate of the day" at 30 and the rest at 50).** It brings back two prices for one crate and a reason to wait for the right day, which is the thing Derek did not like. The daily reason to visit comes from the Yard Sale and the Fresh Catch shelf instead. Option B's other part, the lucky count on every crate card, is already in golden-fish.md section 4 and now shows on the Market's crate list too (section 3 below).

## 3. The Market window after the rework

Three tabs, the first open by default:

1. **Crates.** One card per crate the player can buy (each unlocked zone's crate and the Classic Crate). Each card shows: the crate's name and picture, "Owned: n" when the player has banked ones, the lucky line ("Epic or better in 3 more crates", or "Next crate opens on golden odds"), an **Odds** button that opens the rarity table and each piece's chance (golden odds when the next crate gets them), and two buttons: **Open (40)** (or **Open (owned)** when one is banked, which uses a banked one first as today) and **Buy 5 (180)**. Golden crates the player owns show as their own cards with only **Open (owned)**.
2. **Perks and treats.** Golden Espresso, Big Bowl, Extra Decor Spot, Star Treat and Catnip, as today.
3. **Fresh Catch** (by day). As rewards-and-shops.md section 3, without the crate row.

- **Buy 5** banks 5 crates of that kind and does not open them. The card then reads "Owned: 5" and the player opens them one at a time with the reel as today, so every crate still shows its own odds and its own lucky count before it opens. This keeps the bundle out of the reel code and keeps "the next crate's odds" true at every open.
- The lucky count counts opens, not buys, so banking 5 changes nothing until they open.
- A player who can't afford a button sees it greyed with "Need 12 more fish"; no pop-up, no nudging.

## 4. Fresh Catch without the crate

- The row "Classic Crate, 10 fish off, 50" leaves `Catalog.freshCatch`, and `classic_crate` leaves `FreshCatchAmountWeights`. The other seven rows and their weights stay.
- The heads up toast (`ShopAlert`) now fires only for the Gold Rush Potion.
- A save whose `freshCatch.bought` still has `classic_crate` keeps it harmlessly until the window rolls over (the N32 rule clears it).

## 5. The Yard Sale as a free daily crate

- Stock: one crate a UTC day, the plain crate of one of the player's open zones (the same rotation `CampExtras.yardStock` uses today for its second crate, a new zone each day). The Classic Crate leaves its stock.
- The card shows the crate and a **Take** button (it said a price and **Buy**). Taken, it reads "Taken, new crate at 00:00 UTC" and the crate is banked for the Market, as bought ones are today.
- It holds today's crate only and does not stack, as today. The picker line reads "Yard Sale: free crate" when one is waiting.
- It is free and never sold, so nothing here is a paid random item. The odds still show on the card (its Odds button, as on the Market).

## 6. Contracts

- **Config:** `CratePrice` 60 to **40**. New `CrateBundleCount` 5 and `CrateBundlePrice` 180. `YardSaleCratePrice` goes. `FreshCatchAmountWeights.classic_crate` goes.
- **Catalog:** the `classic_crate` row leaves `Catalog.freshCatch`. `Catalog.crates[...].price` (where set) reads `Config.CratePrice`.
- **Remotes:**
  - New `BuyCrateBundle(crateId: string)`: within `FishMarketRange` of a `FishMarket`, the crate a buyable kind (not golden) whose zone the player has open, `CrateBundlePrice` golden fish; banks `CrateBundleCount` of that crate; 1 a second. Answers with the existing fish and crates state; a refusal toasts why ("Need 12 more golden fish").
  - `BuyYardSale(crateId)` keeps its name and checks, minus the fish: today's crate, not taken today, the Yard Sale open for the tier, within reach. It banks the crate.
  - `ShopAlert(itemId)`: only `gold_rush_potion` now.
- **Profile:** no change. `crates` already banks counts, and `yardSale = { day, bought }` keeps its shape (one id in `bought`).
- **Analytics:** the economy sink `crate` (golden fish) gets the custom field `bundle = true` on a bundle buy; the Yard Sale's take logs the source `yard_sale` as a crate source, not a sink.
- **UI (ui-contract.md):** the Market's Crates tab as in section 3 (new `buyCrateBundle(crateId)` action next to `openCrate`), the Fresh Catch tab without the crate row, the Yard Sale card's **Take** button (`buyYardSale` keeps its name; the "covered" fish check goes).
- **Who builds:** Gameplay-Engineer (Config, Catalog, the new remote, the Yard Sale's stock and free take), UI-Engineer (the Crates tab, the Yard Sale card), QA (section 7, and a Pace.spec rerun).

## 7. QA checks

1. The Market sells every zone crate and the Classic Crate at 40, and nowhere in the game sells a crate at any other single price.
2. Buy 5 takes 180 fish and banks 5 crates of that kind; with 179 fish it is refused and nothing is banked.
3. Opening 5 banked crates in a row: each shows its own odds and lucky line before it opens, and a 20th open with no Epic or better uses the golden odds as before.
4. The Fresh Catch shelf never stocks a crate; the toast fires only for a Gold Rush Potion.
5. The Yard Sale shows one zone crate a day, the same on two servers that day, free, takeable once, banked to the Market.
6. Duplicate refunds still pay 10 / 20 / 40 / 80 / 150.
7. Pace.spec rerun: more crates mean decor tip bonuses arrive sooner. If any tier time falls under economy-ladder.md check 3, the rank up costs go up (rule v0.8), not the crate rewards down.
