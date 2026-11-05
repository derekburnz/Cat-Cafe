# Lawn decor v2: much higher prices and the Garden Nursery in the Park (#1200)

Decided 2026-11-04 by the friend (live notes on #1200, relayed by the Coordinator), who owns this project's calls; written up by Design-Agent. Owner: game-designer. Readers: Model-Agent, Gameplay-Engineer, UI-Engineer, QA. This changes [front-lawn.md](front-lawn.md) section 2 (prices) and section 3 (where pieces are bought). Spots, styles, placing, the free tier gifts, the look and the budgets stay as they are.

The friend: "raise lawn decor prices by a lot" and "sell lawn decor from a Lawn selling station in the Park or the Neighbourhood, instead of the Decor inventory window. Owned pieces can still be placed from Decor."

## 1. New prices: a rarity ladder (fixed coins)

The friend's rule (follow-up on #1202): each piece has a **rarity**, and the price climbs about 5 times per step, with bigger jumps at the top. So the best pieces are huge goals.

| rarity | price | step | badge |
|---|---|---|---|
| Common | 10,000 | | grey |
| Uncommon | 50,000 | x5 | mint green |
| Rare | 250,000 | x5 | blue |
| Epic | 1,000,000 | x4 | purple |
| Legendary | 5,000,000 | x5 | gold |
| Mythical | 50,000,000 | x10 | pink |
| Golden | 500,000,000 | x10 | shining gold |

Every piece and style, with its rarity and price:

| piece or style | kind | tier it opens | rarity | was | now |
|---|---|---|---|---|---|
| Tulip Bed | small spot | 2 | Common | 500 | 10,000 |
| Sandwich Board | small spot | 2 | Common | 500 | 10,000 |
| Red Brick | path | 2 | Common | 2,000 | 10,000 |
| White Picket | fence | 2 | Common | 2,000 | 10,000 |
| Potted Cat Topiary | small spot | 1 | Uncommon | 1,000 | 50,000 |
| Mailbox | small spot | 1 | Uncommon | 1,000 | 50,000 |
| Stepping Stones | path | 2 | Uncommon | 10,000 | 50,000 |
| Low Hedge | fence | 2 | Uncommon | 10,000 | 50,000 |
| Lamp Post | small spot | 2 | Rare | 3,000 | 250,000 |
| Bird Bath | small spot | 2 | Rare | 3,000 | 250,000 |
| Garden Gnome Cat | small spot | 2 | Rare | 5,000 | 250,000 |
| Bicycle with Basket | big spot | 2 | Epic | 8,000 | 1,000,000 |
| Garden Bench | big spot | 2 | Epic | 8,000 | 1,000,000 |
| Paw Print Path | path | 3 | Epic | 200,000 | 1,000,000 |
| Iron Railing | fence | 3 | Epic | 200,000 | 1,000,000 |
| Umbrella Table | big spot | 3 | Legendary | 100,000 | 5,000,000 |
| Little Fountain | big spot | 3 | Legendary | 160,000 | 5,000,000 |
| Balloon Bunch | small spot | 4 | Legendary | 800,000 | 5,000,000 |
| Fairy Light Arch | big spot | 4 | Mythical | 1,200,000 | 50,000,000 |
| Flower Cart | big spot | 4 | Mythical | 1,600,000 | 50,000,000 |
| Flower Box Fence | fence | 4 | Mythical | 1,600,000 | 50,000,000 |
| Cat Tree Sign | big spot | 5 | Golden | 16,000,000 | 500,000,000 |
| Golden Paw Statue | big spot | 5 | Golden | 50,000,000 | 500,000,000 |
| Grey Slabs | path | 1 | | free | free |

- **What this means in play** (economy-ladder.md pace model day rates of about 200, 4,000, 100,000 and 300,000 coins a second at Tiers 2 to 5):
  - A Common is under a minute at Tier 2.
  - An Epic is about 1½ hours at Tier 2, or 4 minutes at Tier 3.
  - A Legendary is about 20 minutes at Tier 3.
  - A Mythical is about 8 minutes at Tier 4.
  - A Golden piece is about 30 minutes at Tier 5.
- **The ladder now does the job of the tier gates.** Tier gates still decide when a piece can be bought. The Golden pieces are the long-term goals.
- **Rarity sets a real money bonus since #1283** (section 6). Uncommon (mint) and Golden (shining gold) are lawn-only colours, so a lawn rarity is never mixed up with a cat or crate rarity.
- **Prices are fixed coin amounts**, the same with or without a money pass. Nothing is random.
- **The free gifts stay free.** The Tier 2 Garden Bench and Tier 3 Umbrella Table (front-lawn.md section 1b) are now an Epic and a Legendary, so the gifts are worth more than before.
- **Nobody loses anything.** Owned pieces stay owned and placed, and nothing is refunded or charged again. A player who bought a Golden Paw Statue for 50,000,000 keeps it.
- **The Commons open at Tier 2 (#1382, 2026-11-05).** QA-Planner's Pace run in #1449 found that a player who buys the best lawn piece as soon as they can reached Tier 2 in 25.1 minutes, over the 20-minute bound, because they spent 10,000 on a Common at Tier 1 with Tier 2 at 13,500. The ladder above already prices Commons as Tier 2 buys ("under a minute at Tier 2"), so the four Tier 1 Commons now open at Tier 2. The nursery shows them with "Opens at Tier 2". The price and the bonus stay. Pieces a player already owns stay owned and placed. Players who saved for the rank up were never slowed.
- **Tuning.** If QA's pace numbers show a tier is much faster or slower than the model, the ladder stays as it is and pieces move up or down a rung.

## 2. The Garden Nursery in the Park

- **Where.** At the Park camp (Tier 2), near the Picnic Basket and off the camp's main path. The Park is the garden-themed area and opens a tier before the Neighbourhood, so lawn shopping starts as soon as the first lawn spots are useful. Model-Agent picks the exact spot.
- **The model.** `CatCafe_Camp_Park_GardenNursery`, tag `LawnStall`: a small wooden potting stall with a green-and-white striped awning and a chalk sign reading "Garden Nursery". Its shelves hold a few tiny copies of the lawn pieces (a tulip pot, a gnome cat, a mini lamp post), and a gardener cat in a sun hat and green apron stands behind it. It has a `PromptAnchor` attachment 3 studs up at the front and a `BubbleAnchor` on the cat. Rare-row quality bar (luck-and-rare-moments.md 2c), like the lawn pieces.
- **Speech bubble.** The gardener cat joins cat-bubbles.md's list with "Plants, paths and pretty things!" (31 characters), shown always.
- **The window.** Holding E on the "Nursery" prompt within 14 studs (`LawnStallRange`) opens the **Garden Nursery** window. It has three tabs, **Pieces**, **Paths** and **Fences**. Each row shows a picture, name, spot size and its rarity badge, the note ("glows at night"), the price, and a gold **Buy** ("Owned" in grey once bought, or "Opens at Tier 3" in grey). Buying plays the purchase sparkle, and the toast reads "Tulip Bed is yours! Place it from Decor, Front lawn." Walking more than 14 + 4 studs away closes it.
- **No rotation.** Every piece and style is always for sale. The lawn is the "pick exactly what you want" decor (Set 6, decided 2026-11-04), so a rotating stock would only make players wait for the piece they came for. There's nothing limited and no restock timer.
- **Tier 1 players** can't reach the Park yet, so the nursery opens for them at Tier 2. Tier 1 cafes still have the kept shrubs and flower beds (front-lawn.md 1b), and the Decor tab says "Lawn pieces are sold at the Garden Nursery in the Park (Tier 2)".

## 3. The Decor screen's Front lawn tab

- **Stays:** the Mine rows, Edit lawn with its rings, placing and clearing pieces, and the path and fence chips for owned styles.
- **Goes:** the Shop rows, and the "shop's pieces below" part of the spot picker. The picker lists only owned pieces that fit, and when there are none it reads "Get lawn pieces at the Garden Nursery in the Park".
- Unowned styles no longer show as chips.

## 4. Contracts

- **Catalog:** every `Catalog.lawn` and `Catalog.lawnStyles` row gets its `price` and a new `rarity` ("Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythical" | "Golden") as in section 1, and `Catalog.lawnRarityPrices` holds the ladder, so a price is the ladder value of its rarity. `LawnTierGifts` is unchanged. `Theme` gains the two lawn-only badge colours, `uncommon` (mint) and `golden` (shining gold).
- **Config:** `LawnStallRange` 14.
- **Remotes:** `BuyLawn(id)` keeps its name and checks, but its place check changes. The caller must be within `LawnStallRange` of a `LawnStall`-tagged model, not at their own plot, and the server checks the distance, never trusting the client. Tier, coins and not already owned are checked as today; 2 a second; it logs the coin sink `lawn`. `SetLawnSpot` and `SetLawnStyle` don't change.
- **Profile:** no change. `lawnOwned` already holds what was bought.
- **Analytics:** `lawn_buy` (value coins, fields piece id and tier), if not already sent.
- **Who builds:**
  - Model-Agent: the stall and the gardener cat.
  - Gameplay-Engineer: the prices and the `BuyLawn` range check.
  - UI-Engineer: `Screens/LawnStall.luau` (the window), the Front lawn tab without its Shop rows, and the new empty-state lines.
  - QA: section 5.

## 5. QA checks

1. Prices: every piece and style costs its rarity's ladder price from section 1, the same with or without a money pass, and its row shows the rarity badge.
2. Range: `BuyLawn` fired from the player's own plot or anywhere away from the nursery is refused. Fired within 14 studs of it, it succeeds.
3. Decor: the Front lawn tab has no Buy buttons. With no owned piece for a spot, its picker shows the nursery line.
4. Owned before v2: a player who bought a Golden Paw Statue at 50,000,000 keeps it placed after the update, and nothing is charged.
5. Gifts: ranking up to Tier 2 still gives a free Garden Bench, placed in an empty big spot.
6. A Tier 1 player sees the Decor line pointing to the Park (Tier 2) and can't buy, because the Park is still locked.

## 6. Lawn pieces earn, and Equip Best places them (#1283)

Decided by Coordinator for the friend, overnight 11-05, from Derek's 11-04 ask: lawn pieces should work with Equip Best, auto-pick their slots, and "have more than a cosmetic effect".

### 6a. The bonus

Each piece and style that is **out** on the lawn adds money, by its rarity:

| rarity | Common | Uncommon | Rare | Epic | Legendary | Mythical | Golden |
|---|---|---|---|---|---|---|---|
| money while out | +1% | +1.5% | +2% | +3% | +5% | +8% | +12% |

- **A full best lawn**, with every piece owned, adds about **+46%**:
  - 2 big spots with the 2 Golden pieces: +24%;
  - 4 small spots (Balloon Bunch, then three Rares): +11%;
  - a Paw Print Path or Iron Railing path: +3%;
  - a Flower Box Fence: +8%.

  That sits beside the crate decor's "+35% for 7 placed" and is reached only by Tier 5 savers.
- **Early on it's small:** a Tier 2 lawn of Commons and Uncommons plus the free Garden Bench (Epic) is about +8%.
- **It never pays back fast.** A Common (10,000) at Tier 2 pays itself back in about 80 minutes of play, and a Golden (500M) at Tier 5 in about 4 hours. So the lawn is a long-term upgrade, not a tier skip (rule v0.8). QA's Pace.spec run with a player who buys the best affordable lawn piece whenever they can must keep every tier inside economy-ladder.md check 3. If not, the bonus row goes down a step; the prices stay.
- **Where it adds:** in `cafeMultiplier`, alongside decor (`Economy.cafeMultiplier`). The Money boosts card (#1151) gets its own row, "Lawn (6 out) +18%".
- **Free gifts count.** The Tier 2 Garden Bench (Epic, +3%) and Tier 3 Umbrella Table (Legendary, +5%) give their bonus like any piece.

### 6b. Equip Best and automatic slots

- **One button.** The Decor window's existing **Equip Best** fills the decor spots and the lawn in one go, with one toast: "Best decor and lawn out: +53% money".
- **The rule, per spot size (small and big):** the highest bonus first, then the higher rarity, then the newest owned. Path and fence each take the best owned style the same way.
- **On buy:** a new piece goes straight onto the lawn if it beats the weakest piece out in its size, or fills an empty spot. The toast says "Tulip Bed is out on your lawn (+1% money)". Nothing to place by hand.
- **No manual placing.** Edit lawn, the spot rings, the picker and Clear (front-lawn.md section 3) go. The Decor window's Lawn chip just lists what you own, with "Out" or "Stored" and each piece's bonus.
- **Server decides.** The server picks the pieces and works out the bonus, and the client never names a spot or a bonus. The existing `lawn` and `lawnStyles` saves hold the result. There's no new save field. `SetLawnSpot` and `SetLawnStyle` are retired (they refuse with "The lawn sets itself now"), and `EquipBestDecor` covers the lawn.
- **Existing lawns:** on a player's first load after this ships, the server runs `bestLawn` once and replaces any manual layout with its picks. Nothing owned is lost: pieces not picked are stored, and the bonus comes from what's out.
- **Looks stay.** A player who liked a cheaper piece's look loses that choice. That trade is Derek's ask ("auto pick slots the same way decor does"). If players miss it, a later "Pin this piece" toggle can keep one chosen piece out.

### 6c. Contracts

- **Config:** `LawnRarityBonus = { Common = 0.01, Uncommon = 0.015, Rare = 0.02, Epic = 0.03, Legendary = 0.05, Mythical = 0.08, Golden = 0.12 }`.
- **Economy:**
  - `Economy.lawnBonus(profile)` sums the bonus of each out piece and style;
  - `cafeMultiplier` adds it;
  - `Economy.bestLawn(profile)` returns the spot-to-piece and style picks (shared, with a spec).
- **Server:**
  - `EquipBestDecor` also applies `bestLawn`;
  - `BuyLawn` auto-places;
  - `SetLawnSpot` and `SetLawnStyle` refuse;
  - plot attributes as today, so every client builds the lawn.
- **UI-Engineer:** the Lawn chip's list, the Money boosts row, and removing the edit view.
- **Who builds:** Gameplay-Engineer (shared `Config` and `Economy`, so open a `claim` first), UI-Engineer, QA (section 6d).

### 6d. QA checks

1. Equip Best with a Tulip Bed, a Garden Bench and a Little Fountain owned puts the Fountain and the Bench in the big spots and the Tulip Bed in a small one. The Money boosts card shows "Lawn (3 out) +9%".
2. Buying a Golden Paw Statue with both big spots full swaps out the weaker big piece by itself.
3. `SetLawnSpot` fired by an exploit is refused, and the bonus comes only from the server's picks.
4. Pace.spec with best-affordable lawn buying keeps every tier inside check 3.

### 6e. Lawn is just another decor category, and pieces show their rarity (Derek2, 2026-11-05 22:38)

Derek2 after testing live: "decor looks good but should have effects and act like its another plants/floor/walls section no edit lawn bs". 6a to 6d already give the money and Equip Best. This adds the look of it:
- **A Lawn chip beside Plants, Floor and Walls**, with the same grid cards: picture, name, rarity colour, its bonus ("+3% money") and "Out" or "Stored". Paths and fences are cards in the same grid, tagged "Path" or "Fence". There's no Edit lawn button, no spot rings, no picker strip, no path or fence strip and no Clear. The only buttons are Equip Best (shared with decor) and the Nursery's "Where to buy" hint for pieces not owned.
- **One total line** at the top of the Lawn chip: "Lawn: 6 out, +18% money". It's the same number as the Money boosts row.
- **Pieces out on the lawn show their rarity** (vfx-animator, client only, mild and budgeted like the decor effects). Common and Uncommon have nothing. Rare gets a few slow sparkles. Epic gets a soft glow at the base. Legendary gets drifting motes in the rarity colour. Mythical gets a gentle aura. Golden gets a gold shimmer with occasional glints. Effects show only within about 60 studs, pause at night except the lamp-like pieces (Lamp Post, Fairy Light Arch), and switch off with the game's reduced effects setting.
- Nothing else changes: the bonus row, the best-pick rule and the save are as 6a to 6c say.

## 7. Lawn pieces sold only at the Yard Sale (#1464)

The friend, 2026-11-05: "update the decor/yard items to just work the same as the rest with equip best accept only obtainable from the yard sale shop that can roll common to mythic yard decor every day reset". Section 6 (#1382) already makes the lawn work like the rest with Equip Best. This section moves where pieces are sold. It replaces section 2.

- **Where:** only the Yard Sale (Neighbourhood camp, camp-stations.md section 3). The Garden Nursery is retired: its stall, `LawnStallPrompt` and the nursery window go, and its Park spot is free for something else (Model-Agent decides whether the stall model is reused). Pieces players already own stay owned and placed.
- **When it restocks:** at each global game day (#1437, one day is 390 s), the same stock on every server, seeded from the day number like the Corner Shop's window. If #1437 lands as option 2, the stock follows its global 390 s window instead. The card reads "New stock at sunrise".
- **How many rows:** 6 a day, each a different piece or style. A row is first rolled for rarity, then a piece of that rarity is picked at random. If that rarity has no piece left, the roll moves one rarity down.

  | rarity | chance per row |
  |---|---|
  | Common | 28% |
  | Uncommon | 25% |
  | Rare | 20% |
  | Epic | 14% |
  | Legendary | 8% |
  | Mythical | 4% |
  | Golden | 1% |

  About 1 day in 5 has a Mythical row, and about 1 day in 17 has a Golden one. Golden stays in the roll at 1% so the two top pieces aren't lost (the ask said Common to Mythical; Golden is the rare extra above it).
- **Buying:** fixed coins, the section 1 prices (10,000 to 500,000,000). Each player can buy each row once. A piece they already own shows "Owned" and can't be bought again. Nothing in the Yard Sale is random once it's on show: the player sees exactly what they buy, so it's not a paid random item, and it's coins only.
- **Tier gates stay.** A row above the player's tier shows "Opens at Tier N" and can't be bought. The Yard Sale itself opens at Tier 3, so the Tier 1 to 3 gates matter less now. The free Tier 2 Garden Bench and Tier 3 Umbrella Table gifts (front-lawn.md section 1b) stay, so a Tier 2 player still gets a lawn piece.
- **The free crate stays.** The Yard Sale keeps its free zone crate every 4 hours with its "!" (camp-stations.md section 3). The lawn stock is a second panel on the same card: "Free crate" on top, "Yard decor" below.
- **Equip Best** (section 6) places a piece as soon as it's bought.
- **Save:** per-player bought rows keyed to the day, like `cornerShop` (`{ day, bought }`), cleared when the day moves on and never on a step back. This needs a save version bump, so claim `DataService.luau`.
- **QA:** (1) Two servers show the same 6 rows on the same day, and the next day both change at once. (2) A row already bought, or a piece already owned, can't be bought again, and hopping servers doesn't refill it. (3) Over 100,000 seeded days, the rarities land within 0.3 points of the table, and no day repeats a piece. (4) The Garden Nursery is gone, and nothing else sells lawn pieces. (5) A Tier 3 player sees a Tier 4 row as "Opens at Tier 4".
