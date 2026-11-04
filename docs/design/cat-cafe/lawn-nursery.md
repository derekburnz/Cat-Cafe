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
| Tulip Bed | small spot | 1 | Common | 500 | 10,000 |
| Sandwich Board | small spot | 1 | Common | 500 | 10,000 |
| Red Brick | path | 1 | Common | 2,000 | 10,000 |
| White Picket | fence | 1 | Common | 2,000 | 10,000 |
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
- **Rarity is a label, not a bonus.** Lawn pieces still give no money bonus (front-lawn.md section 2). The badge only says how special a piece is, in the same rarity colours the game already uses. Uncommon (mint) and Golden (shining gold) are new, lawn-only colours, so a lawn rarity is never mixed up with a cat or crate rarity.
- **Prices are fixed coin amounts**, the same with or without a money pass. Nothing is random.
- **The free gifts stay free.** The Tier 2 Garden Bench and Tier 3 Umbrella Table (front-lawn.md section 1b) are now an Epic and a Legendary, so the gifts are worth more than before.
- **Nobody loses anything.** Owned pieces stay owned and placed, and nothing is refunded or charged again. A player who bought a Golden Paw Statue for 50,000,000 keeps it.
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
