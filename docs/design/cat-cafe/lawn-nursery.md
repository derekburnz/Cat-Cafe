# Lawn decor v2: much higher prices and the Garden Nursery in the Park (#1200)

Decided 2026-11-04 by the friend (live notes on #1200, relayed by the Coordinator), who owns this project's calls; written up by Design-Agent. Owner: game-designer. Readers: Model-Agent, Gameplay-Engineer, UI-Engineer, QA. This changes [front-lawn.md](front-lawn.md) section 2 (prices) and section 3 (where pieces are bought). Spots, styles, placing, the free tier gifts, the look and the budgets stay as they are.

The friend: "raise lawn decor prices by a lot" and "sell lawn decor from a Lawn selling station in the Park or the Neighbourhood, instead of the Decor inventory window. Owned pieces can still be placed from Decor."

## 1. New prices (fixed coins)

The rule: a piece costs a good chunk of play at the tier that opens it. That's about 5 to 10 minutes of income for a Tier 1 piece, 10 to 15 minutes at Tier 2, 15 to 30 minutes at Tier 3, 20 to 40 minutes at Tier 4 and 30 to 60 minutes at Tier 5, using the economy-ladder.md pace model's day rates (about 15, 200, 4,000, 100,000 and 300,000 coins a second). Today a piece is under a minute of income. Lawn pieces give no bonus, so these prices only make the lawn something to save for. They never slow a tier for a player who skips it.

| piece | spot | tier | was | now |
|---|---|---|---|---|
| Tulip Bed | small | 1 | 500 | 5,000 |
| Sandwich Board | small | 1 | 500 | 5,000 |
| Potted Cat Topiary | small | 1 | 1,000 | 8,000 |
| Mailbox | small | 1 | 1,000 | 8,000 |
| Lamp Post | small | 2 | 3,000 | 75,000 |
| Bird Bath | small | 2 | 3,000 | 75,000 |
| Garden Gnome Cat | small | 2 | 5,000 | 120,000 |
| Bicycle with Basket | big | 2 | 8,000 | 180,000 |
| Garden Bench | big | 2 | 8,000 | 180,000 |
| Umbrella Table | big | 3 | 100,000 | 4,000,000 |
| Little Fountain | big | 3 | 160,000 | 6,000,000 |
| Balloon Bunch | small | 4 | 800,000 | 100,000,000 |
| Fairy Light Arch | big | 4 | 1,200,000 | 180,000,000 |
| Flower Cart | big | 4 | 1,600,000 | 220,000,000 |
| Cat Tree Sign | big | 5 | 16,000,000 | 600,000,000 |
| Golden Paw Statue | big | 5 | 50,000,000 | 1,000,000,000 |

| style | kind | tier | was | now |
|---|---|---|---|---|
| Grey Slabs | path | 1 | free | free |
| Red Brick | path | 1 | 2,000 | 6,000 |
| Stepping Stones | path | 2 | 10,000 | 90,000 |
| Paw Print Path | path | 3 | 200,000 | 3,000,000 |
| White Picket | fence | 1 | 2,000 | 6,000 |
| Low Hedge | fence | 2 | 10,000 | 90,000 |
| Iron Railing | fence | 3 | 200,000 | 3,000,000 |
| Flower Box Fence | fence | 4 | 1,600,000 | 150,000,000 |

- **Prices are fixed coin amounts**, as for the Corner Shop v2, so they don't scale with income or passes.
- **The free gifts stay free.** Tier 2 still gives a Garden Bench and Tier 3 an Umbrella Table (front-lawn.md section 1b), so every cafe front gets something while the bought pieces become goals.
- **Nobody loses anything.** Pieces already owned stay owned and placed. The new prices apply only to new buys, and nothing is refunded or charged again.
- **Tuning.** The day rates above are the pace model's medians. If QA's numbers show a tier's real day rate differs, the prices for that tier move by the same factor, so the minutes-of-income rule holds.

## 2. The Garden Nursery in the Park

- **Where.** At the Park camp (Tier 2), near the Picnic Basket and off the camp's main path. The Park is the garden-themed area and opens a tier before the Neighbourhood, so lawn shopping starts as soon as the first lawn spots are useful. Model-Agent picks the exact spot.
- **The model.** `CatCafe_Camp_Park_GardenNursery`, tag `LawnStall`: a small wooden potting stall with a green-and-white striped awning and a chalk sign reading "Garden Nursery". Its shelves hold a few tiny copies of the lawn pieces (a tulip pot, a gnome cat, a mini lamp post), and a gardener cat in a sun hat and green apron stands behind it. It has a `PromptAnchor` attachment 3 studs up at the front and a `BubbleAnchor` on the cat. Rare-row quality bar (luck-and-rare-moments.md 2c), like the lawn pieces.
- **Speech bubble.** The gardener cat joins cat-bubbles.md's list with "Plants, paths and pretty things!" (31 characters), shown always.
- **The window.** Holding E on the "Nursery" prompt within 14 studs (`LawnStallRange`) opens the **Garden Nursery** window. It has three tabs, **Pieces**, **Paths** and **Fences**. Each row shows a picture, name and spot size, the note ("glows at night"), the price, and a gold **Buy** ("Owned" in grey once bought, or "Opens at Tier 3" in grey). Buying plays the purchase sparkle, and the toast reads "Tulip Bed is yours! Place it from Decor, Front lawn." Walking more than 14 + 4 studs away closes it.
- **No rotation.** Every piece and style is always for sale. The lawn is the "pick exactly what you want" decor (Set 6, decided 2026-11-04), so a rotating stock would only make players wait for the piece they came for. There's nothing limited and no restock timer.
- **Tier 1 players** can't reach the Park yet, so the nursery opens for them at Tier 2. Tier 1 cafes still have the kept shrubs and flower beds (front-lawn.md 1b), and the Decor tab says "Lawn pieces are sold at the Garden Nursery in the Park (Tier 2)".

## 3. The Decor screen's Front lawn tab

- **Stays:** the Mine rows, Edit lawn with its rings, placing and clearing pieces, and the path and fence chips for owned styles.
- **Goes:** the Shop rows, and the "shop's pieces below" part of the spot picker. The picker lists only owned pieces that fit, and when there are none it reads "Get lawn pieces at the Garden Nursery in the Park".
- Unowned styles no longer show as chips.

## 4. Contracts

- **Catalog:** the `price` of every `Catalog.lawn` and `Catalog.lawnStyles` row as in section 1. `LawnTierGifts` is unchanged.
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

1. Prices: every piece and style costs the section 1 amount, the same with or without a money pass.
2. Range: `BuyLawn` fired from the player's own plot or anywhere away from the nursery is refused. Fired within 14 studs of it, it succeeds.
3. Decor: the Front lawn tab has no Buy buttons. With no owned piece for a spot, its picker shows the nursery line.
4. Owned before v2: a player who bought a Golden Paw Statue at 50,000,000 keeps it placed after the update, and nothing is charged.
5. Gifts: ranking up to Tier 2 still gives a free Garden Bench, placed in an empty big spot.
6. A Tier 1 player sees the Decor line pointing to the Park (Tier 2) and can't buy, because the Park is still locked.
