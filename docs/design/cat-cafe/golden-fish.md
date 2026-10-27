# Golden Fish, Cafe Crates and Index Rewards (design v0.7 proposal)

Proposed 2026-10-27. Owner: game-designer thread. Readers: Derek, engineer, ui-designer, asset thread, growth. The numbers wait on Derek's reaction before the build starts. The contract fields at the end are the ones the engineer and the UI build to.

Derek, 2026-10-27:
- 18:26: "all these type of games have at least a main currency to buy things like upgrades etc and a rarer currency to buy either big buffs or permanent things or hard to find things like possibly cosmetic crates that drop cosmetics for your cafe that give boosts to everything in it can be really strong ... we could use money as our normal currency and rare golden fish coins as the rare one displayed how much you have on the side changing to K/M/B/T or whatever currency so it doesn't flow off screen can add hard ways to get them and add in things like spin the wheel or later in time progression rewards etc"
- 18:26: "Also have it do research on ideas from other roblox games for content and give me suggestions"
- 18:27: "it can be a cute coin with like a cat face on it"
- 18:29: "make the index rewards worth while so that people do them showing little symbols of whatever they are going to get as next reward and how much"
- 18:33: "dont do any decor straight up try and gear towards giving things like crates to open for decor or spins for the wheel for a chance at something… gives the player more to do and less forced"

## 1. The two currencies

| | Coins (normal) | Golden Fish (rare) |
|---|---|---|
| Shown as | `$` and the amount, as today | a cute gold coin with a cat face (Derek); the asset thread can add a tiny fish in its mouth to match the name |
| Earned from | cats working, tips, catches, selling cats, offline | hard things only: first catches, Legendary and Mythical catches, rank ups, Index milestones, the wheel, a long Tip Jar session (section 2) |
| Buys | tiers, upgrades, the coin decor shop, food | Cafe Crates, a Star Treat and three permanent perks at the Golden Fish Market (section 3) |
| Robux | never sold (monetization-policy option A) | never sold, and no Robux item gives, doubles or speeds golden fish |

Rules:
- Golden fish are earned only. No Robux path reaches them, directly or through another currency. Top Roblox games sell their rare currency for Robux, but a "layered currency" sold to children is what the May 2026 FTC complaint names (growth comps.md section 5). Keeping fish earn-only keeps the crates out of paid random items.
- Coins and fish never convert into each other.
- Both counters sit on the left side of the HUD, coins on top and fish below. Big numbers shorten with `Format.short`: exact with commas below 100,000, then K, M, B, T, Qa and Qi. The shortened number is cut down, never rounded up (1,999,999 shows 1.99M, not 2M), so it never shows more than the player has. Tapping a counter shows the exact amount.

## 2. Where golden fish come from

| source | golden fish | when |
|---|---|---|
| First catch of a cat (any way: net, rescue, bait) | Common 1, Rare 3, Epic 8, Legendary 20, Mythical 40 | slice, with F52 |
| First gold catch of a cat | twice the above | slice |
| Catching a cat you already have, by net or rescue (not bait) | Epic 1, Legendary 3, Mythical 8 | slice |
| Rank up to Tier 2, 3, 4, 5 | 10, 25, 50, 100 | slice |
| Index milestones | section 5 | slice |
| Spin Wheel | slice 5 becomes 4 golden fish (10%) | slice |
| Tip Jar step 12 (120 minutes) | 5, on top of the Caviar and the banked spin | slice |
| Daily Treat day 7 | 10 | launch |
| Customer Requests | 2 per finished request | launch |
| Chalkboard codes | as growth sets them | launch |
| Fish Pond (suggestion 3 in section 7) | 3 every 30 minutes, walk up and collect | later |
| Cafe Loyalty track (Derek's "time progression rewards", suggestion 6) | 10 per stamp | later |

Bait pays only the first-catch fish. A cat you already have that comes to the bowl pays none, so food bought with coins can't be farmed into fish.

Rough pace: a new player reaches 50 fish (the first crate) in about an hour, mostly from first catches, the Tier 2 rank up and the first Index milestones. Later, when discoveries run out, repeat Epic and better catches, the wheel and the Tip Jar give roughly 8 to 12 an hour, so a bought crate every four to six hours plus the crates the Index hands out. Fish stay rare, as Derek asked.

## 3. The Golden Fish Market (a walk-up station)

A fishmonger stall in the street plaza beside the Spin Wheel, run by a cat shopkeeper. Model `CatCafe_Street_FishMarket`, tag `FishMarket`, a prompt within 14 studs opens its window. Like the wheel, it keeps the HUD clear (Derek, 14:36). It sells for golden fish:

| item | cost | what it does |
|---|---|---|
| Cafe Crate (one per unlocked area) | 50 | opens at once, section 4 |
| Star Treat | 80 | the best food (dealer only today, 3% of slots), a fish route to Legendary and Mythical bait cats |
| Golden Espresso (perk, 5 levels) | 40, 80, 150, 250, 400 | +5% tips per level, forever |
| Big Bowl (perk, 1 level) | 150 | bait wait 10 to 8 minutes, forever |
| Extra Shelf (perk, 2 levels) | 100, 250 | +1 crate decor shelf per level |
| Catnip (launch) | 10 | the 15 minute luck buff, its numeric effect on the card |

The Market also opens crates the player already owns (from the Index and the wheel) for free.

## 4. Cafe Crates

Each area has one crate of 8 decor pieces in that area's theme. The pieces boost every tip in the cafe while they stand on a display shelf. A higher rarity gives a much stronger boost, so a lucky crate can be really strong, as Derek wanted.

| rarity | pieces per crate | chance (each piece) | tip bonus while on a shelf |
|---|---|---|---|
| Common | 3 | 54% (18% each) | +2% |
| Rare | 2 | 30% (15% each) | +4% |
| Epic | 1 | 11% | +8% |
| Legendary | 1 | 4% | +15% |
| Mythical | 1 | 1% | +25% and a little effect |

- **Golden Crate:** the same 8 pieces with only Epic or better: Epic 68.75%, Legendary 25%, Mythical 6.25%. It's never sold. It comes only from the gold Index milestones.
- **Lucky tenth:** the 10th crate in a row from the same area without an Epic or better is opened on the Golden Crate odds. Any Epic or better resets the count. The crate card says "Epic or better in 3 more crates" and shows the odds that apply to the next crate.
- **Duplicates:** a piece you already own gives golden fish back by its rarity instead (Derek, 18:41: "a duplicate piece should give fish back based on rarity of the dupe"): Common 10, Rare 20, Epic 40, Legendary 80, Mythical 150. Nothing is lost, and a duplicate Mythical pays for three more crates. On a 50 fish crate the average refund is about 20, so the economy stays where it was.
- **Shelves:** crate decor needs a display shelf. There are 2 shelves at Tier 1, then 3, 4, 5 and 6 at Tier 5, plus 2 more from the Extra Shelf perk. A new piece goes onto a free shelf by itself, and the Decor screen swaps pieces. Eight Mythicals and Legendaries on shelves add up to more than +150% tips. That's the long chase at the end of the game.
- **Full set:** owning all 8 pieces of an area's crate adds +5% tips forever, shelved or not. The Index page gets a gold frame.
- **Odds shown:** every crate card shows the rarity table and each piece's chance before opening (monetization-policy section 2). This applies even though crates are free, so nothing needs a redesign if a coins product ever ships.
- **Opening:** the server rolls with its own `Random` and pays at once. The window plays a two second reveal, so leaving mid-reveal keeps the piece.
- The Index decor shipped in F48 (Alley Mural Print, Park Bench, Mailbox Planter, Mushroom Lamp, Pipe Fountain) becomes the Epic of its area's crate. Anyone who already owns one keeps it. The gold Index decor is retired before anyone could earn it.

Draft piece names, for the asset thread to model from the area kits (they can be renamed):

| crate | Common | Rare | Epic | Legendary | Mythical |
|---|---|---|---|---|---|
| Alley | Milk Crate Stool, Tin Can Planter, Chalk Paw Sign | Fire Escape Shelf, Jar Lights | Alley Mural Print | Retro Jukebox | Midnight Lamp (glows, a moth circles) |
| Park | Flower Pot Trio, Pinecone Bowl, Picnic Blanket | Birdbath, Pond Lantern | Park Bench | Gazebo Corner | Blossom Tree (petals drift) |
| Neighbourhood | Paw Doormat, Lemonade Jug, Picket Shelf | Bicycle Planter, Garden Gnome Lamp | Mailbox Planter | Ice Cream Counter | Rainbow Sprinkler (a small rainbow) |
| Woods | Log Stool, Acorn Jar, Moss Rug | Lantern Stump, Birch Shelf | Mushroom Lamp | Hollow Log Booth | Aurora Window (northern lights) |
| Sewer | Bottle Cap Coasters, Pipe Shelf, Rubber Duck Row | Teapot Lamp, Sock Bunting | Pipe Fountain | Bathtub Sofa | Bottle Cap Throne (caps glint) |

## 5. Index rewards (rebalanced, no decor handed out)

Every area page in the Index now has two reward tracks: the normal track for the area's cats and its own gold track for the gold cats (Derek, 18:37: "gold index rewards should be it's own thing but the rewards for gold index should be smaller number gaps and better"). The prizes are coins, food, golden fish, banked wheel spins and crates, so every milestone gives the player something to do next. Some milestones also add a small permanent tip bonus (Derek, 18:36: "small permanent cash bonuses at certain index's and completing a full index of a zone should give a bonus also"). The Index shows each prize as a little picture with its amount (the UI thread is building this).

**Normal track**, three milestones per area:

| milestone | needs | tips forever | Alleyway | Park | Neighbourhood | Woods | Sewer |
|---|---|---|---|---|---|---|---|
| `cats3` | 3 of the area's 10 | | 600 s of day rate (min 300), 5 fish, 1 spin | min 1,000, 10 fish, 1 spin | min 3,000, 15 fish, 1 spin | min 10,000, 20 fish, 1 spin | min 30,000, 25 fish, 1 spin |
| `cats6` | 6 of 10 | +2% | 3 Tuna, 1 Alley Crate | 3 Salmon, 1 Park Crate | 3 Caviar, 1 Neighbourhood Crate | 3 Moon Milk, 1 Woods Crate | 3 Star Treat, 1 Sewer Crate |
| `cats10` | all 10 | +5% (zone complete) | 2 Salmon, 2 Alley Crates, 25 fish, 2 spins | 2 Caviar, 2 Park Crates, 35 fish, 2 spins | 2 Moon Milk, 2 crates, 50 fish, 2 spins | 2 Star Treat, 2 crates, 75 fish, 2 spins | 3 Star Treat, 2 crates, 100 fish, 2 spins |

**Gold track**, six milestones per area at smaller gaps and with bigger prizes:

| milestone | gold cats | tips forever | Alleyway | Park | Neighbourhood | Woods | Sewer |
|---|---|---|---|---|---|---|---|
| `gold1` | 1 | +1% | 10 fish, 1 spin, 1 Alley Crate | 15 fish, 1 spin, 1 Park Crate | 20 fish, 1 spin, 1 crate | 25 fish, 1 spin, 1 crate | 30 fish, 1 spin, 1 crate |
| `gold2` | 2 | +1% | 900 s of day rate (min 1,000), 15 fish, 2 spins | min 3,000, 20 fish, 2 spins | min 10,000, 30 fish, 2 spins | min 30,000, 40 fish, 2 spins | min 100,000, 50 fish, 2 spins |
| `gold4` | 4 | +2% | 1 Golden Crate, 25 fish | 1 Golden Crate, 35 fish | 1 Golden Crate, 45 fish | 1 Golden Crate, 60 fish | 1 Golden Crate, 75 fish |
| `gold6` | 6 | +2% | 1,800 s of day rate (min 2,000), 3 Salmon, 40 fish, 3 spins | min 6,000, 3 Caviar, 50 fish, 3 spins | min 20,000, 3 Moon Milk, 60 fish, 3 spins | min 60,000, 3 Star Treat, 80 fish, 3 spins | min 200,000, 4 Star Treat, 100 fish, 3 spins |
| `gold8` | 8 | +3% | 1 Golden Crate, 60 fish | 1 Golden Crate, 75 fish | 1 Golden Crate, 90 fish | 1 Golden Crate, 120 fish | 1 Golden Crate, 150 fish |
| `gold10` | all 10 | +6% (gold zone complete) | 3,600 s of day rate (min 5,000), 2 Golden Crates, 100 fish, 5 spins | min 15,000, 2 Golden Crates, 125 fish, 5 spins | min 50,000, 2, 150 fish, 5 spins | min 150,000, 2, 200 fish, 5 spins | min 500,000, 2, 250 fish, 5 spins |

Each area is worth +7% tips forever on its normal track and +15% on its gold track, so +22% an area and +110% for all five.

- Coins pay `max(min, floor(dayRate x seconds))`, the same as the Tip Jar, so the prize grows with the cafe and still feels big late in the game.
- Spins go into `spin.banked` (cap 20). If a claim would go over the cap, the rest of the prize still pays, the extra spins are dropped and the prize row says "Spins full".
- Crates go into `crates` and open at the Golden Fish Market.
- A permanent bonus counts from the moment the milestone is claimed, adds to `cafeMultiplier` and shows as a gold "+2% tips forever" chip next to the prize pictures.
- Players who already claimed a milestone under F48 keep what they got, and its old prizes are not paid again. A permanent bonus is part of the milestone, so an F48 claim of `cats6`, `cats10` or `gold10` gets its bonus on the next load. `gold1` to `gold8` are new for everyone.

### 5b. Cat Collector milestones (all areas together)

Derek, 18:36: "on top of just overall amount of different cat's captured". A sixth page in the Index, "All Cats", counts different cats across every area (gold cats not counted twice) and has ten milestones. Each one adds to the permanent bonus and pays fish, spins or a crate. The crate is the one from the player's highest unlocked area.

| milestone | different cats | tips forever | prize |
|---|---|---|---|
| `total5` | 5 | +2% | 10 fish, 1 spin |
| `total10` | 10 | +2% | 15 fish, 1 Cafe Crate |
| `total15` | 15 | +2% | 20 fish, 2 spins |
| `total20` | 20 | +3% | 25 fish, 1 Cafe Crate |
| `total25` | 25 | +3% | 30 fish, 2 spins |
| `total30` | 30 | +3% | 40 fish, 1 Cafe Crate |
| `total35` | 35 | +4% | 50 fish, 3 spins |
| `total40` | 40 | +4% | 60 fish, 1 Golden Crate |
| `total45` | 45 | +5% | 75 fish, 3 spins |
| `total50` | all 50 | +10% | 150 fish, 2 Golden Crates and a "Cat Master" name tag |

The track adds up to +38% tips forever. With both area tracks the whole Index is worth up to +148%, most of it from the long gold chase. The counts line up with the tier requirements (5, 12, 20 and 30 different cats), so a player who ranks up passes a Collector milestone on the way.

## 6. Spin Wheel changes (F49)

| slice | was | now | weight |
|---|---|---|---|
| 5 | 2 Moonlit Sardines | 4 golden fish | 10 |
| 6 | 1 Caviar | 1 Cafe Crate (the crate of the highest area the player has unlocked) | 5 |

Slices 1 to 4 stay the same. The slice faces come from data (areas-and-stations B3), so the model doesn't change. The Moonlit Sardines and the Caviar stay in the Tip Jar and with the dealer.

## 7. What other Roblox games do, and suggestions for us

Research on 2026-10-27, from the sources listed at the end. We borrow mechanics only, never names or art.

| game | rare currency | how it's earned | what it buys | what we take |
|---|---|---|---|---|
| Bee Swarm Simulator | Tickets | bear quests, mobs and bosses, badges (about 5 each), codes; also sold for Robux | the Ticket Tent: eggs, special bees, a Star Treat ("one of the only ways to obtain star treats without Robux") | a rare-currency shop with the best food and permanent things (our Market and its Star Treat) |
| Blox Fruits | Fragments | raids (up to 1,000), bosses (250 to 2,000), some chests | awakening fruits, vendor items | fish for the hardest catches (Legendary, Mythical, gold) |
| Pet Simulator 99 | Diamonds | a free spot every 30 minutes, gift bags from rank goals, group rewards, timed presents, flags in areas | pet slots, egg multipliers, magnet and other boosts, merchants, trading | a timed free pickup (Fish Pond), rank goals that pay fish, permanent slots (our Extra Shelf) |
| Grow a Garden | Sheckles, plus event currencies such as Honey | crops; events | cosmetic crates from a trader with a 10 hour cooldown, cheap ones for Sheckles, exotic ones for Robux; the drop odds are not shown | cosmetic crates for decor, but ours show odds and never take Robux |
| Restaurant Tycoon 2 | Diamonds | quests, daily rewards, codes, Robux | premium furniture and items | a restaurant game where the rare currency buys the best furniture |
| Roll a Fisherman (growth comps) | spins and crates | rolls, passes | Robux spins and crates (R$79 to R$749) and luck boosts | the warning: every paid spin and crate there is a paid random item |
| Adopt Me | event currencies (Candy, Gingerbread) | seasonal event tasks | that season's pets and items | seasonal event currency later, as a third and temporary one |

Suggestions for Cat Cafe, best first:
1. **Golden Fish Market and Cafe Crates** (this doc). This is the Ticket Tent idea plus Grow a Garden's cosmetic crates, made fair.
2. **Index rewards that hand out crates, spins and small permanent bonuses**, with a separate gold track and an all-areas Cat Collector track (section 5). It's PS99's rank-goal gift bags, built on our Index.
3. **Fish Pond.** A small koi pond in the plaza. Walk up every 30 minutes to scoop 3 golden fish. This is PS99's free diamond spot, and it gives a reason to come back to the plaza.
4. **Big Cat Visit.** About every 30 minutes, a huge, sleepy Chonk-style cat shows up in one unlocked area. Everyone in the area plays a shared catch circle together, and everyone who helps gets golden fish and a chance at a Golden Crate. This is Blox Fruits' raids and bosses, made cozy and cooperative, with no fighting.
5. **Badges that pay fish.** Roblox badges for goals like 100 catches, 10 rescues and every tier, at 5 fish each, as Bee Swarm does with tickets. It's cheap to build, and the badges also show on profiles.
6. **Cafe Loyalty track.** Derek's "time progression rewards". It's a long free track of stamps, one for every 30 minutes of total playtime, and each stamp pays fish, food, a spin or a crate. It never resets and nothing is lost for missing days. We never sell a paid track, because growth's no-pressure rules rule that out.
7. **Golden Hour.** A five minute server event where every fish source pays double. It's PS99's diamond boost, and our Cat Parade already gives it a slot.
8. **Seasonal crates.** For example, an Autumn Leaves crate whose decor comes back every year, like Adopt Me's seasonal currencies. We never say "last chance" (monetization.md).

## 8. Build plan

| id | feature | priority | size | owners |
|---|---|---|---|---|
| F52 | Golden fish: the profile field, the sources in section 2, the HUD counter with the cat-face coin, `Format.short` cut down instead of rounded, with Qa and Qi | P1 | M | engineer, ui, asset (coin icon) |
| F53 | Cafe Crates and the Golden Fish Market: the crate catalog, 40 pieces, shelves, the lucky tenth, duplicates, set bonus, perks, Star Treat, the station | P1 | L | engineer, ui, asset (stall and 40 pieces, the area kits first), vfx (reveal) |
| F54 | Index rewards rebalance (sections 5 and 5b) and the Spin Wheel changes (section 6) | P1 | M | engineer, ui |

Order: F52, then F53, then F54. F54 can ship its coins, food, spins, permanent bonuses and the new milestones before F53, but a crate prize needs F53 to open.

Contract (data-model sections 11b, 11c, 14, 15 and 17 take these when Derek okays the proposal):
- **Profile, save version 7:** `goldenFish` and `lifetimeGoldenFish` (integers), `crates` (map crateId to count, unopened), `crateLuck` (map area to opens since the last Epic or better), `fishPerks` (map perkId to level), `stats.cratesOpened` and `stats.fishEarned`. Migration 6 to 7 sets them to 0 or empty. The S60 reasoning applies: an older server would drop them. Sanitise on load: counts must be integers of 0 or more, `crateLuck` 0 to 9 and perk levels 0 to max.
- **`Catalog.crates[crateId]`:** `{ id, name, area, glyph, price?, odds = { Common = 54, Rare = 30, Epic = 11, Legendary = 4, Mythical = 1 }, pieces = { decorId, ... } }`. The crate ids are `alley_crate` up to `sewer_crate`, which have `price = 50`, and `alley_golden_crate` up to `sewer_golden_crate`, which have no price and the odds `{ Epic = 68.75, Legendary = 25, Mythical = 6.25 }`. Each piece's chance is its rarity's odds split equally among that rarity's pieces. A piece is a `DecorDef` with `source = "crate"`, `rarity` and `bonus` from the section 4 table.
- **`Catalog.indexPrizes[area][milestone]`**, the shape the UI thread asked for: `{ coins?, coinSeconds?, lures? = { [lureId] = n }, fish?, spins?, crates? = { [crateId] = n }, bonus?, tag? }`. `coins` is the minimum, and `coinSeconds` (when set) pays `max(coins, floor(dayRate x coinSeconds))`. `bonus?` is the permanent tip bonus as a fraction (0.02). `decorId` goes away. `Catalog.indexMilestones` becomes two tracks per area, `normal` (`cats3`, `cats6`, `cats10`) and `gold` (`gold1`, `gold2`, `gold4`, `gold6`, `gold8`, `gold10`), each row `{ id, track, needs }`. The Cat Collector track uses the area id `all` with `total5` to `total50`, counted from `collection`. `ClaimIndexReward(areaId, milestoneId)` accepts `all`, and `indexRewards.all` saves those claims.
- **`Catalog.spinWheel`:** slice 5 is `{ kind = "fish", count = 4 }`. Slice 6 is `{ kind = "crate", crate = "highest" }`, which the server resolves to the crate of the player's highest unlocked area.
- **`Catalog.fishShop`:** rows `{ id, kind = "crate" | "lure" | "perk", cost or costs, maxLevel? }` for section 3.
- **Remotes:**
  - `OpenCrate(crateId)`: within 14 studs of a `FishMarket` station, a known crate id whose area is unlocked and either a banked crate (used first) or a `price` with enough fish. 2 seconds between opens and 1 call per second. The server rolls (the lucky tenth uses the golden odds), adds the piece or its rarity's refund, puts the piece on a free shelf, updates `crateLuck` and fires `CrateResult(crateId, decorId, duplicate, refund)`. A refusal fires `CrateResult(crateId, "", false, 0)`.
  - `BuyFishItem(itemId)`: within 14 studs of the Market, a known row, affordable and below its max level. 2 per second.
  - ProfileSync adds `goldenFish`, `crates`, `crateLuck` and `fishPerks`.
- **Shelves:** `ToggleDecor` refuses to place a `crate` piece when every shelf is full. Pieces placed above the cap after a change stay placed.
- **Income:** `cafeMultiplier` adds the bonuses of the shelved crate pieces, +0.05 for each full set, +0.05 per Golden Espresso level and the `bonus` of every claimed Index milestone.
- **Analytics:** the economy currency `golden_fish`. Its sources are `first_catch`, `repeat_catch`, `rank_up`, `index_reward`, `spin_wheel` and `tip_jar`. Its sinks are `crate`, `lure` and `perk`. There is also a custom event `crate_opened` (crate, rarity, duplicate, lucky tenth), so the odds can be checked against results.
- **Constants:** CratePrice 50, CrateDuplicateRefund {Common 10, Rare 20, Epic 40, Legendary 80, Mythical 150}, CrateLuckyEvery 10, FishMarketRange 14, CrateOpenCooldownSeconds 2, CrateShelves {2, 3, 4, 5, 6} by tier, CrateSetBonus 0.05, the crate bonuses {0.02, 0.04, 0.08, 0.15, 0.25}, FishFirstCatch {1, 3, 8, 20, 40}, FishRepeatCatch {Epic 1, Legendary 3, Mythical 8}, FishRankUp {10, 25, 50, 100}, TipJarStep12Fish 5.

Monetization check (monetization-policy section 6): no Robux path ends in a crate, a fish or a spin. Every crate shows its odds and the lucky tenth's numbers before opening. Nothing is limited, timed or shown off as spending. If a coins product ever ships (growth option B), bait repeat catches already pay no fish. Crates would then still be unpaid, but the growth thread should re-check any new fish source against this rule.

## Sources

- Bee Swarm Simulator Wiki, Ticket Tent: https://bee-swarm-simulator.fandom.com/wiki/Ticket_Tent
- Pro Game Guides, tickets in Bee Swarm Simulator: https://progameguides.com/roblox/how-to-get-tickets-fast-in-bee-swarm-simulator-roblox/
- GGRecon, Blox Fruits fragments: https://www.ggrecon.com/guides/blox-fruits-fragments/
- PCGamesN, Pet Simulator 99 diamonds: https://www.pcgamesn.com/pet-simulator-99/diamonds
- Insider Gaming, Grow a Garden cosmetic crates: https://insider-gaming.com/how-to-open-crates-in-grow-a-garden-cosmetics/
- Restaurant Tycoon 2 diamonds: https://speed-test-lamp.ica.art/restaurant-tycoon-2-diamonds
- Roll a Fisherman and the FTC complaint: [docs/growth/comps.md](../../growth/comps.md)
