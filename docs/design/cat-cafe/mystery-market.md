# The Mystery Market and the Backpack (#2565)

Status: proposed by the game-designer thread, 2026-11-09. Derek2 chose the weekly rotation and the always-on shop with a featured sale (section 2). He still approves the price and the item list before anything is built.

Derek2, 2026-11-09: "a mystery market guy that sells one rare item at a time and his current item in rotation being sold is a backpack for 300 gold fish the backpack lets you hold up to one more cat before you have to run back and instead of putting your net away you keep it out and the cat goes in your backpack sticking it's head out and then next one you catch goes into hands and you put net away, if you get tackled you drop both"

## 1. The seller

- **Who.** Moss, a travelling cat in a hooded cloak, with a covered cart under a lantern. Moss is new and ours (rule 8), and doesn't look like the night food dealer or the Fish Market's shopkeeper. Model `CatCafe_Square_MysteryCart` (Model-Agent), tag `MysteryMarket`, on the Town Square across from the pity sign.
- **What.** Derek2, 2026-11-09: "I will make it so the featured item is discounted like a sale but can be bought anytime from the mystery market just for more expensive". So every item is on sale at its full price all the time, and one featured item each week is discounted. Every item is a permanent perk or a cosmetic, bought once with golden fish. Nothing is random (rule 9), nothing is sold for Robux, and nothing is limited.
- **How it differs from the other sellers:**
  - The night food dealer (data-model §8b) sells food you use up, at night only.
  - The Fish Market (golden-fish.md §3) has a fixed list.
  - The Yard Sale is player to player.
  - Moss is the only one with a weekly featured sale and one-off items.

### 2a. The window
A walk-up prompt (14 studs, like the Fish Market) opens Moss's window:
- **This week's featured item** at the top, large, with a "SALE" ribbon. It shows the sale price with the full price struck through ("300 ~~400~~"), what the item does in one line, and "Sale ends in 4d 06h".
- **Next week's featured item** below it, as a "?" silhouette with "Next sale: 4d 06h". That keeps the mystery.
- **Every other item** in a list under that, at its full price, each with a Buy button.

An owned item shows "You have this!". An item above the player's tier shows "Opens at Tier 3" with the Buy button greyed out. The sale wording only describes the real price difference (section 2d).

### 2b. Global rotation
The rotation runs on the global clock, so every server shows the same item at the same moment, like the pity cat and `Clock.dayKinds`:
- The slot is `floor((now - MysteryEpoch) / MysteryRotateSeconds)`.
- `MysteryRotateSeconds` is 604800 (one week). `MysteryEpoch` is a Saturday 00:00 UTC, so each new item arrives with the Saturday drop (release.md).
- The featured item is `Catalog.mysteryItems[slot % #items + 1]`.
- No DataStore is needed, and there is no stock: anyone can buy any item at any time.
- The featured item costs `MysterySaleShare` (0.75) of its full price, rounded to the nearest 5.

One featured sale a week, the same for everyone, gives the game a "what's at the cart this week?" reason to come back, and the "?" teaser keeps the mystery. It works on its own and still lines up with Cafe Events and the Saturday update.

### 2c. Nothing is limited
Every item can be bought at any time at full price, and each one comes back on sale when the list cycles round (every 5 weeks with the 5 items in section 4). This keeps Derek2's rule from #2485: "free event rewards can come back later but no need to really give limited items". Until the other items are built, the list holds the Backpack alone, so it is featured, on sale, every week.

### 2d. Fair sale rules (young audience)
- The full price is the real everyday price, and a player can always pay it.
- The sale is the same length every week and ends when the card says. It is never extended, and there is no fake countdown.
- No "last chance" pop-ups. The sale shows only on Moss's window, the board and the What's New line.
- Golden fish only, so no Robux is involved. Monetization-Agent checks this section with the build.

## 3. The Backpack (first item)

| | |
|---|---|
| Price | **400 golden fish**, or **300** in its featured week, once |
| Opens at | **Tier 3** |
| What it does | Hold one more cat before running back |
| Card text | "Backpack: carry 2 cats! The first rides on your back." |

### 3a. How it works
- **First catch.** You catch a cat with your hands free. The net stays out and the cat goes into your backpack, awake, with its head and front paws out of the top. You can keep hunting.
- **Second catch.** The next cat goes into your hands as it does now, and the net goes away. Now you're carrying two.
- **Other ways in.** A rescued cat, or a dropped cat you pick up, follows the same order: pack first, then hands.
- **Check-in.** Crossing the camp line, the packed cat hops into the `CampBasket` first, then the held one 0.3 s later. One toast covers both: "2 cats checked in!".
- **Speed.** The packed cat doesn't change walk speed, so `CarryWalkSpeed` (16) applies only once your hands are full, as now. A Swift Potion works as usual.
- **Drop button.** The first press drops the held cat and the second drops the packed one.
- **Without the Backpack** nothing changes: one cat, net away.

### 3b. Tackles and other rules
- **A tackle drops both** (Derek2). Each cat walks home to its own catch spot (`DropReturnWalkSpeed`), and anyone can pick it up on the way, as now. A tackler with a Backpack can scoop up both.
- **A packed cat counts as carrying for being a target.** You can be tackled and shoved (since #2193 there's no timed immunity). You also can't tackle anyone while a cat is in your pack, so you can't hunt and steal at the same time.
- **A packed cat blocks** the cannon, `Travel` and changing areas, the same as a held one (reviewer N47). Dusk, the night sweep, a death and leaving the game treat it like a held cat.
- **Safe zone and getaway burst** work the same. The burst after a catch still pushes others away.
- **Pity cats and event showers.** The MemoryStore claim happens on the catch, so a packed pity cat is yours just like a held one.
- **Bait cats** are tamed at the cafe and never carried, so nothing changes for them.

### 3c. Is 300 fair?
- golden-fish.md §2 puts late-game fish income, after the discoveries run out, at about 8 to 12 an hour, and that was before #2266 and #2497 cut it. The early game pays more because first catches and rank ups pay fish. So the 300 sale price is most of a day's saving for a mid-game player, between the Big Bowl (150) and Golden Espresso level 5 (400). The 400 full price matches Golden Espresso level 5. It's a goal, not an impulse buy.
- **Tier 3** keeps it out of the first hour (Tier 3 is at about 53 minutes), and it's where the deep areas begin, which is where fewer round trips matter most.
- **Gameplay measures with Pace before the build merges:**
  - The median play time to own 300 fish at Tier 3, the sale price. Aim for **2 to 5 hours of play**. If it's outside that, tune the full price only, in steps of 50, and keep the sale at 0.75 of it.
  - The catches an hour with and without the Backpack.
  - The tier times with the Backpack bought as soon as it can be. The guards in economy-ladder §3 v5 must still hold: Tier 4 in 5 to 6 h and Tier 5 in 9 to 14 h. If the Backpack pushes Tier 4 under 5 h, it opens at Tier 4 instead, rather than the tier costs moving again.

### 3d. Look
- **The backpack** (Model-Agent): a small canvas pack with a cat-ear flap, welded to the back like `HeldCat` (massless, so the walk doesn't change). It hides the avatar's own back accessories only while a cat is in it.
- **The packed cat** (Animation-Engineer): awake, with an ear wiggle and a look around every few seconds. Reduce Motion keeps it still.
- **The cart and Moss** (Model-Agent), plus the card (UI-Engineer, `Screens/MysteryMarket.luau`).

## 4. Candidate items for the rotation (Derek2 picks)

Each one is permanent, bought once with golden fish, and not random.

| Item | What it does | Full price | Sale price | Opens at | Note |
|---|---|---|---|---|---|
| **Backpack** | carry 2 cats (section 3) | 400 | 300 | Tier 3 | first |
| Long Net | `NetReachStuds` 7 to 8 | 320 | 240 | Tier 2 | small, felt on every swing |
| Cat Whistle | press to see an arrow to the nearest stray for 10 s, every 60 s | 260 | 195 | Tier 2 | helps in the big areas |
| Lantern Sign | a cafe decoration that lights up at night, Rare (+4%, like the Party Bunting) | 260 | 195 | Tier 1 | cosmetic with a small bonus |
| Cat Scarf | an outfit piece every working cat can wear, cosmetic only | 200 | 150 | Tier 1 | |

Not on the list: anything that raises Luck (the Luck ladder is already full, LuckMax x3), more walk speed (it would weaken tackles), and anything also sold for Robux.

### 4b. More featured items (Derek2, 2026-11-09: "what other featured items we could do could add them every couple days")

A longer pool, so the shelf grows. A **new item joins the shelf every 2 to 3 days** at full price, one small PR each, with Model-Agent's art. The weekly sale picks from everything on the shelf. Each item gets "NEW!" on Moss's window and a What's New line on the day it arrives. Every row follows the same rules: permanent, golden fish only, not random, no Luck, no walk speed, never sold for Robux. Prices are full price, and the sale is 0.75 of it.

| Item | Kind | What it does | Full price | Opens at |
|---|---|---|---|---|
| Spyglass | tool | strays' rarity tags show from 60 studs instead of the usual distance | 240 | Tier 2 |
| Paw Gloves | tool | one extra paw in every rescue | 320 | Tier 3 |
| Trail Map | tool | the area's hiding spots and rescue traps show on the minimap for the day | 280 | Tier 3 |
| Snack Pouch | tool | a free Small Snack (the net-catch drop food) at each sunrise, once a game day | 260 | Tier 2 |
| Window Flower Box | decor | a Common decoration for the cafe front, +2% (Common crate bonus) | 160 | Tier 1 |
| Moss's Lantern | decor | a hanging lantern, Rare, +4%, glows at night | 260 | Tier 2 |
| Wind Chimes | decor | a cafe decoration that chimes when a customer tips big (sound only, no bonus) | 180 | Tier 1 |
| Cafe Awning | cafe look | a striped awning over your cafe door in one of 4 colours | 220 | Tier 2 |
| Explorer Hat | player look | a hat for your own avatar while in the game | 200 | Tier 1 |
| Paw Print Trail | player look | soft paw prints behind you as you walk (Reduce Motion hides it) | 240 | Tier 2 |
| Moss's Cloak | player look | a hooded cloak like Moss's, for your avatar | 300 | Tier 3 |
| Cat Beret | cat look | an outfit piece for working cats | 180 | Tier 1 |
| Star Collar | cat look | a collar with a little star tag, for working cats | 220 | Tier 2 |
| Jukebox song | cafe music | one more song for the free Jukebox (sound-designer) | 150 | Tier 1 |

Notes:
- The tools change play. Each one gets a Pace check before it joins, and Paw Gloves and the Trail Map get a playtest. The decor and looks need art but no balance work.
- The decor bonuses use the crate bonus already in the game, so a fish-bought piece is never better than a crate or pass piece of the same rarity.
- With 5 items now and about 3 new ones a week, the shelf passes 15 in about a month. The weekly sale then cycles round about every 15 weeks, which is fine because everything can be bought at any time.

## 4c. The market corner (look)

Where: the **west end of the Town Square's east-west lane**, inside the closed west arch (-63, 0), around (-52, 0). The lane points straight at it from the cannon, and nothing else stands there (town-layout-v3 §3: the four stations are in the corners and the night dealer parks at (28, -16)). It faces east toward the cannon. It is about 22 studs wide (z -11 to 11) and 14 deep (x -63 to -49), and the cross's paving stays clear. Plan: [mystery-market-corner.svg](mystery-market-corner.svg).

Three looks for Model-Agent to block out. **A is recommended.**

- **A. The covered wagon (recommended).** A round-topped wagon, about 12 x 7 studs, in deep teal with a patched cream canvas hood stitched with little stars, big wooden wheels, and a paw-print door at the back. Moss sits on the front step under a hanging lantern.
  - The wagon's side folds down into a counter with a pedestal, where the featured item turns slowly in 3D (the Backpack on a cat-shaped stand).
  - A chalkboard on an easel reads "This week: SALE", and a smaller board with a "?" shows next week's silhouette.
  - Around it: a round rug, stacked crates and baskets, a string of lanterns from the wagon to two posts, and a tied-up pony-cat plush.
  - It reads as "a traveller who stopped here", which fits a seller who changes stock.
- **B. The bazaar tent.** A striped tent (plum and gold) with curtains tied back, rugs, hanging bottles and a low table with the featured item under a glass dome. It's cosy and mysterious, but busier to build and harder to read from the cannon.
- **C. The landed balloon.** A small hot-air balloon basket on the ground with the balloon tethered 20 studs up, which is visible from anywhere in town. Each Saturday the balloon bobs and drops a puff of confetti when the new sale starts. It's the most eye-catching, but the biggest model and the most motion. It could be a later upgrade to A: the wagon could get a balloon flag.

For all three:
- **Lighting.** Warm lantern light, brighter at night with a few fireflies (Reduce Motion: none). Moss is the only seller lit like this, so the corner reads as special.
- **Sound** (sound-designer): soft wind chimes near the cart, and a little bell when someone buys.
- **Markers.** A "?" icon over the cart on the town map and the place marker list ("Mystery Market"), with a gold dot while a sale is on and you can afford the featured item. No pop-up and no HUD nag.
- **Names** (asset-pipeline): `CatCafe_Square_MysteryCart`, `CatCafe_Square_MysteryRug`, `CatCafe_Square_MysteryLanterns`, `Npc_Moss`, `Prop_MysteryPedestal`.

## 5. Contracts (proposed, final names are Gameplay's)

- **Config:**
  - `MysteryEpoch` (a Saturday 00:00 UTC) and `MysteryRotateSeconds` 604800.
  - `MysterySaleShare` 0.75, plus `BackpackCost` 400 (full price) and `BackpackMinTier` 3.
  - `BackpackHopGapSeconds` 0.3.
- **Catalog:** `Catalog.mysteryItems`, a list of `{ id, name, text, cost, minTier, kind }`.
- **Shared module:** `shared/MysteryMarket.luau`, pure, with a spec, containing `slot(now)`, `featuredAt(now)`, `nextAt(now)`, `priceOf(item, now)` and `canBuy(profile, item, now)`.
- **Profile:** `profile.mystery = { [itemId] = true }`.
- **Carry state:** a second slot, `packedStrayId`, saved and validated like the held cat.
- **Remote:** `BuyMystery(itemId, shownPrice)`.
  - The server checks that the item exists, the tier, that it isn't owned, the fish, and a rate limit of 1 a second.
  - The server works out the price from its own clock. If that price is above `shownPrice` (the sale ended while the window was open), it refuses with "The sale just ended" and the window refreshes. The client never sets the price.
- **Analytics:** `mystery_buy` (item, slot, tier, fish before), and `backpack_trip` (cats checked in per trip, and drops by tackle).

## 6. QA checks

1. Two servers show the same featured item and the same countdown to the second, and it changes at the same moment in both.
2. The Backpack costs 300 in its featured week and 400 in any other week. It can't be bought below Tier 3, without the fish, or twice. Buying it the moment the sale ends is refused with "The sale just ended", never charged at 400.
3. With the Backpack, the first catch goes in the pack with the net out, and the second goes in the hands with the net away. Both check in on one crossing of the camp line, with one toast.
4. A tackle drops both cats, each walks home to its own spot, and the tackler can pick them up. A player with a packed cat can't tackle.
5. A packed cat blocks the cannon and `Travel`, and is handled like a held cat at dusk, on death and on leaving.
6. Without the Backpack, catching and carrying are exactly as before.
7. Nothing at the cart can be bought with Robux, and no purchase prompt opens from it.

## 7. Comparable games (secondary sources, directional only)

- **Grow a Garden's travelling merchants.** Guides say a merchant comes about every 4 hours, stays about 30 minutes, and that there are several themed merchants with their own stock. One themed merchant appeared only once, on a holiday. That fits the "a seller who comes and goes" feel. A once-only merchant is the kind of truly limited item Derek2 has ruled out for us, so ours always cycles back. Sources: [Beebom](https://beebom.com/grow-a-garden-traveling-merchants-guide/), [Sportskeeda](https://www.sportskeeda.com/roblox-news/all-travelling-merchants-grow-garden).
- **Carry capacity in Escape Tsunami for Brainrots.** Carry capacity goes up by +1 per upgrade, to 7, with steeply rising prices. Guides call 3 or 4 enough. Upgrades can be bought with Robux and reset on rebirth. We keep it to one extra slot, for fish only, never lost. Source: [Beebom](https://beebom.com/how-to-carry-more-brainrots-in-escape-tsunami-for-brainrots).
- **Steal a Brainrot.** It's built on carrying and losing what you carry. Its gear and pass guides show how carrying games add tools to protect a carry. Our answer is the camp line, the safe zones and the walk-home drop, so a tackle costs you time but never hands the cat straight to the tackler. Source: [Deltia's Gaming](https://deltiasgaming.com/roblox-steal-a-brainrot-all-gear-and-game-passes).

## 8. Questions for Derek2

1. ~~Rotation length~~: weekly, at the Saturday drop (Derek2, 2026-11-09). Every item can be bought any time at full price, and the featured item is on sale (Derek2, 2026-11-09).
2. Is 400 fish full price and 300 on sale, at Tier 3, right? Pace checks for 2 to 5 hours of saving.
3. Which of the four other candidates go on the list, and which of the 4b items should come first?
4. Which look for the corner: A (the wagon, recommended), B or C?
