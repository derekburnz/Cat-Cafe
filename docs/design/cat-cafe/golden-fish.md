# Golden Fish, Cafe Crates and Index Rewards (design v0.7)

Proposed 2026-10-27; Derek okayed the numbers the same day at 19:27 ("looks good"), and the build is F52 to F54. Owner: game-designer thread. Readers: Derek, engineer, ui-designer, asset thread, growth. The all-areas Index track is called All Cats everywhere, because the Cat Collector is now a visitor (data-model section 12b). The contract fields at the end are the ones the engineer and the UI build to. v0.10 (2026-10-27 evening, the round 4 answers in [feedback/answers-2026-10-27-round4.md](feedback/answers-2026-10-27-round4.md)): each Index track gets its own kind of permanent bonus and the finishing milestones get bigger prizes (sections 5 and 5b), the Tip Jar's 60 and 120 minute steps pay more fish (section 2) and the Daily Treat's day 7 is bigger (data-model 11e).

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
| Buys | tiers, upgrades, the coin decor shop, food | cosmetic crates, a Star Treat and three permanent perks at the Golden Fish Market (section 3) |
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
| Tip Jar step 9 (60 minutes) | 10, with coins and a spin (v0.10) | slice |
| Tip Jar step 12 (120 minutes) | 25, with a Caviar, a Classic Crate, 2 spins and a Tip Potion (v0.10, was 5) | slice |
| Daily Treat days 2 and 7 | 15 and 50 (v0.10, data-model 11e; was 10 on day 7) | launch |
| Customer Requests | 2 per finished request | launch |
| Chalkboard codes | as growth sets them | launch |
| Fish Pond (suggestion 3 in section 7) | 3 every 30 minutes, walk up and collect | later |
| Cafe Loyalty track (Derek's "time progression rewards", suggestion 6) | 10 per stamp | later |

Bait pays only the first-catch fish. A cat you already have that comes to the bowl pays none, so food bought with coins can't be farmed into fish.

Rough pace: a new player's first crate usually comes free from the Alleyway's `cats6` milestone, and 60 fish for a bought one takes a bit over an hour, mostly from first catches, the Tier 2 rank up and the first Index milestones. Later, when discoveries run out, repeat Epic and better catches, the wheel and the Tip Jar give roughly 8 to 12 an hour, so a bought crate every five to seven hours plus the crates the Index and the wheel hand out. Crates are medium hard to get and the rare pieces stay rare (Derek, 18:54: "either make the crates medium difficulty to get and keep the odds or up the odds and keep crates hard to get up to you").

## 3. The Golden Fish Market (a walk-up station)

A fishmonger stall in the street plaza beside the Spin Wheel, run by a cat shopkeeper. Model `CatCafe_Street_FishMarket`, tag `FishMarket`, a prompt within 14 studs opens its window. Like the wheel, it keeps the HUD clear (Derek, 14:36). It sells for golden fish:

| item | cost | what it does |
|---|---|---|
| A crate (each unlocked zone's crate and the Classic Crate) | 60 | opens at once, section 4 |
| Star Treat | 80 | the best food (dealer only today, 3% of slots), a fish route to Legendary and Mythical bait cats |
| Golden Espresso (perk, 5 levels) | 40, 80, 150, 250, 400 | +5% tips per level, forever |
| Big Bowl (perk, 1 level) | 150 | bait wait 10 to 8 minutes, forever |
| Extra Decor Spot (perk, 2 levels) | 100, 250 | +1 decor spot per level |
| Catnip (launch) | 10 | the 15 minute luck buff, its numeric effect on the card |

The Market also opens crates the player already owns (from the Index and the wheel) for free.

## 4. Cafe Crates and the Decor Index

Derek, 18:48 and 18:49: "can make the cosmetics for cafe different wall papers flooring furniture decorations paint etc" and "also can plan on adding decoration crates for each zone and then a general cosmetic one also so that you can have cosmetic index's for each zone".

There are six crates: one per zone (Alley, Park, Neighbourhood, Woods and Sewer Crates) in that zone's theme, plus a general Classic Crate of timeless cafe styles. Each crate holds 10 cosmetics, two of each kind: wallpaper, flooring, paint for the outside of the cafe, furniture and decorations. Every piece boosts every tip in the cafe while it's in use, and a higher rarity gives a much stronger boost, so a lucky crate can be really strong, as Derek wanted.

| rarity | pieces per crate | chance (each piece) | tip bonus while in use |
|---|---|---|---|
| Common | 4 | 60% (15% each) | +2% |
| Rare | 3 | 27% (9% each) | +4% |
| Epic | 1 | 10% | +8% |
| Legendary | 1 | 2.5% | +15% |
| Mythical | 1 | 0.5% | +25% and a little effect |

- **Using pieces:** the cafe has one wallpaper, one floor and one paint at a time, and the Decor screen swaps them. Only the one in use counts. Furniture and decorations stand on decor spots: 2 at Tier 1, then 3, 4, 5 and 6 at Tier 5, plus 2 more from the Extra Decor Spot perk. A new furniture or decoration piece takes a free spot by itself, and a new wallpaper, floor or paint is offered with a "Use it" button. The paint shows from the street, so other players see it.
- **Medium to get, hard to complete:** Derek asked at 18:48 for crates "relatively hard to get so people don't find all the cosmetics", then at 18:54 let the designer pick between medium crates with these odds and better odds with hard crates. We kept the odds and made crates medium: 60 fish each, and the Index and the wheel hand out a fair number. Opening crates often is the fun part, and the low odds keep the rare pieces rare. On average a crate's Legendary takes about 40 crates and its Mythical about 190, so very few players will ever fill a Decor Index page, and owning a Mythical means something.
- **Golden Crates:** each crate has a golden version with the same 10 pieces and only Epic or better: Epic 80%, Legendary 17.5%, Mythical 2.5%. They're never sold. They come only from the gold Index milestones (that zone's golden crate) and the last All Cats milestones (the Golden Classic Crate).
- **Lucky twentieth:** if 19 crates of the same kind in a row have no Epic or better, the 20th opens on the golden odds. Any Epic or better resets the count. The crate card says "Epic or better in 3 more crates" and shows the odds that apply to the next crate. It stops a long unlucky streak without making the rare pieces easy.
- **Duplicates:** a piece you already own gives golden fish back by its rarity instead (Derek, 18:41: "a duplicate piece should give fish back based on rarity of the dupe"): Common 10, Rare 20, Epic 40, Legendary 80, Mythical 150. Nothing is lost, and a duplicate Mythical pays for two and a half more crates. On a 60 fish crate the average refund is about 18.
- **Decor Index:** the Index gets a Decor tab with one page per crate (Alley, Park, Neighbourhood, Woods, Sewer and Classics). Each page shows its 10 pieces as silhouettes until found, with their rarity, kind and bonus. A page has two milestones: `decor5` (5 of 10) pays 25 golden fish, and `decor10` (all 10) adds +5% tips forever and a gold frame on the page. No milestone gives a crate, so filling a page stays hard.
- **Odds shown:** every crate card shows the rarity table and each piece's chance before opening (monetization-policy section 2). This applies even though crates are free, so nothing needs a redesign if a coins product ever ships.
- **Opening:** the server rolls with its own `Random` and pays at once. The window plays a two second reveal, so leaving mid-reveal keeps the piece. The reveal shows the won piece's rarity from the start: it never spins past or flashes a better rarity first, so nothing looks like a near miss (VFX-Agent, monetization-policy). A tap skips it, Reduce Motion cuts it to a short fade, and Low performance mode drops the burst to the low budget.
- **Mythical effects:** each Mythical cosmetic gets one steady emitter or a texture scroll. It runs only near the player, counts against the steady-emitter budget and shows a still look in Low performance mode. Every placed cosmetic carries a `DecorId` attribute, so the effect and the client know which piece it is. The golden fish pickup sparkle is the catch sparkle in gold.
- The zone crates open with their zone (Tier 1 Alley, Tier 2 Park and so on). The Classic Crate is open from Tier 1.
- The Index decor shipped in F48 (Alley Mural Print, Park Bench, Mailbox Planter, Mushroom Lamp, Pipe Fountain) becomes the Epic of its zone's crate. Anyone who already owns one keeps it. The gold Index decor is retired before anyone could earn it.
- Those five keep their own anchors in the cafe, but while placed they count against the decor spot cap like any furniture or decoration piece, because they give the Epic tip bonus. At Tier 1 a placed Alley Mural Print leaves one spot for crate furniture, and toggling it off frees the spot. Coin-shop decor (plants, rug, neon sign, fish tank) gives no crate bonus and never counts (review N170, built that way in #316 and #317).

Draft pieces, for the asset thread (names can change). C, R, E, L and M are the rarities.

| crate | wallpaper | flooring | paint | furniture | decorations |
|---|---|---|---|---|---|
| Alley | Brick Wall (C), Midnight Sky (M: stars twinkle, a moon drifts) | Subway Tile (C), Puddle Glass (R: shines like a wet street) | Fire Escape Red (C), Graffiti Pastel (R) | Milk Crate Stools (C), Retro Jukebox (L) | Jar Lights (R), Alley Mural Print (E) |
| Park | Leafy Vines (C), Meadow Mural (R) | Garden Path (C), Clover Carpet (R) | Meadow Green (C), Duck Pond Blue (C) | Picnic Table Set (R), Park Bench (E) | Duck Fountain (L), Blossom Tree (M: petals drift) |
| Neighbourhood | Picket Stripes (C), Kitchen Gingham (R) | Checker Kitchen (C), Porch Planks (C) | Pastel Pink (C), Rainbow Shimmer (M: a slow rainbow over the cafe front) | Porch Swing (R), Ice Cream Counter (L) | Bicycle Planter (R), Mailbox Planter (E) |
| Woods | Birch Bark (C), Aurora Sky (M: northern lights) | Mossy Planks (C), Leaf Litter (R) | Forest Green (C), Toadstool Red (R) | Log Stools (C), Hollow Log Booth (L) | Lantern Stump (R), Mushroom Lamp (E) |
| Sewer | Pipe Works (C), Bottle Cap Mosaic (R) | Canal Tile (C), Glimmer Canal (M: water shimmers under glass) | Brass Teal (C), Copper Patina (R) | Crate Shelf (C), Bathtub Sofa (L) | Rubber Duck Row (R), Pipe Fountain (E) |
| Classic | Cream Stripes (C), Paw Print (R) | Oak Boards (C), Black and White Tile (C) | Latte Brown (C), Gold Leaf (M: gold trim that glints) | Bistro Set (R), Velvet Booth (E) | Hanging Plants (R), Cat Tree Tower (L) |

That's 60 pieces. 36 of them are wallpapers, floors and paints, which are textures or colours on the cafe shell, so they're cheap to make. The other 24 are furniture and decoration models. The Mythicals and their effects matter most for the look.

## 5. Index rewards (rebalanced, no decor handed out)

Every area page in the Index now has two reward tracks: the normal track for the area's cats and its own gold track for the gold cats (Derek, 18:37: "gold index rewards should be it's own thing but the rewards for gold index should be smaller number gaps and better"). The prizes are coins, food, golden fish, banked wheel spins and crates, so every milestone gives the player something to do next. Some milestones also add a small permanent tip bonus (Derek, 18:36: "small permanent cash bonuses at certain index's and completing a full index of a zone should give a bonus also"). The Index shows each prize as a little picture with its amount (the UI thread is building this).

v0.10 (round 4 Q12: "Thats good do different permanent bonuses and big reward bonuses at milestones depending on track also"): each track now has its own kind of permanent bonus, so the three tracks feel different and each one helps the thing it counts.
- Normal track: **tips forever**, unchanged (`bonus`, added to `cafeMultiplier`).
- Gold track: **gold luck forever** (`goldLuck`) in place of tips. Every gold roll (net strays at spawn, bait at placement, rescue at sunrise) is multiplied by `1 + goldLuck`, where `goldLuck` is the sum of the claimed milestones' values, capped at GoldLuckMax (1.5). So finding gold cats makes the next ones easier: the full gold Index takes the net and bait chance from 5% to 12.5% and rescue from 10% to 25%. Food cards and the Index show the chance with the luck in it. Whose luck counts: bait uses the player who sets the food. Net strays and rescue cats are rolled once for the whole server, so they use the highest `goldLuck` among the players in the server who have that area unlocked when the stray or trap is rolled, and base odds when nobody does. Since v0.9 the main wave spawns at sunrise, when everyone has been sent home, so it cannot depend on who stands in the area. One coat is still visible to everyone from the spawn, and playing beside a lucky friend helps. The area's Index Board shows the luck in use ("Gold luck +40% from Sam").
- All Cats track: **faster bait forever** (`baitSpeed`) in place of tips. Every bait wait is multiplied by `1 - baitSpeed` when the food goes in, capped at BaitSpeedMax (0.5), so the full track takes the day wait from 10:00 to 6:12 and the night wait from 5:00 to 3:06.
- Bigger prizes where a track is finished: `cats10` adds the area's Golden Crate, `gold10` a second Golden Crate and a gold name tag ("Alleyway Gold Master" and so on), `total25` a Golden Classic Crate and `total50` a second Golden Classic Crate and 10 spins.
- The trade off: tips forever now come from the normal tracks (+35% for all five areas) and the Decor Index (+5% a page), not +148% from the whole Index. Set 4 asks Derek and Gavin to check it.

**Normal track**, three milestones per area:

| milestone | needs | tips forever | Alleyway | Park | Neighbourhood | Woods | Sewer |
|---|---|---|---|---|---|---|---|
| `cats3` | 3 of the area's 10 | | 600 s of day rate (min 300), 5 fish, 1 spin | min 1,000, 10 fish, 1 spin | min 3,000, 15 fish, 1 spin | min 10,000, 20 fish, 1 spin | min 30,000, 25 fish, 1 spin |
| `cats6` | 6 of 10 | +2% | 3 Tuna, 1 Alley Crate | 3 Salmon, 1 Park Crate | 3 Caviar, 1 Neighbourhood Crate | 3 Moon Milk, 1 Woods Crate | 3 Star Treat, 1 Sewer Crate |
| `cats10` | all 10 | +5% (zone complete) | 2 Salmon, 2 Alley Crates, 1 Alley Golden Crate (v0.10), 25 fish, 2 spins | 2 Caviar, 2 Park Crates, 1 Golden Crate, 35 fish, 2 spins | 2 Moon Milk, 2 crates, 1 Golden Crate, 50 fish, 2 spins | 2 Star Treat, 2 crates, 1 Golden Crate, 75 fish, 2 spins | 3 Star Treat, 2 crates, 1 Golden Crate, 100 fish, 2 spins |

**Gold track**, six milestones per area at smaller gaps and with bigger prizes (v0.10: gold luck forever in place of tips):

| milestone | gold cats | gold luck forever | Alleyway | Park | Neighbourhood | Woods | Sewer |
|---|---|---|---|---|---|---|---|
| `gold1` | 1 | +2% | 10 fish, 1 spin, 1 Alley Crate | 15 fish, 1 spin, 1 Park Crate | 20 fish, 1 spin, 1 crate | 25 fish, 1 spin, 1 crate | 30 fish, 1 spin, 1 crate |
| `gold2` | 2 | +3% | 900 s of day rate (min 1,000), 15 fish, 2 spins | min 3,000, 20 fish, 2 spins | min 10,000, 30 fish, 2 spins | min 30,000, 40 fish, 2 spins | min 100,000, 50 fish, 2 spins |
| `gold4` | 4 | +5% | 1 Golden Crate, 25 fish | 1 Golden Crate, 35 fish | 1 Golden Crate, 45 fish | 1 Golden Crate, 60 fish | 1 Golden Crate, 75 fish |
| `gold6` | 6 | +5% | 1,800 s of day rate (min 2,000), 3 Salmon, 40 fish, 3 spins | min 6,000, 3 Caviar, 50 fish, 3 spins | min 20,000, 3 Moon Milk, 60 fish, 3 spins | min 60,000, 3 Star Treat, 80 fish, 3 spins | min 200,000, 4 Star Treat, 100 fish, 3 spins |
| `gold8` | 8 | +5% | 1 Golden Crate, 60 fish | 1 Golden Crate, 75 fish | 1 Golden Crate, 90 fish | 1 Golden Crate, 120 fish | 1 Golden Crate, 150 fish |
| `gold10` | all 10 | +10% (gold zone complete) | 3,600 s of day rate (min 5,000), 2 Golden Crates (v0.10, was 1), 100 fish, 5 spins, the "Alleyway Gold Master" tag | min 15,000, 2 Golden Crates, 125 fish, 5 spins, tag | min 50,000, 2, 150 fish, 5 spins, tag | min 150,000, 2, 200 fish, 5 spins, tag | min 500,000, 2, 250 fish, 5 spins, tag |

Each area is worth +7% tips forever on its normal track (+35% for all five) and, since v0.10, +30% gold luck on its gold track (+150% for all five, the GoldLuckMax cap). Before v0.10 the gold track paid +15% tips an area.

- Coins pay `max(min, floor(dayRate x seconds))`, the same as the Tip Jar, so the prize grows with the cafe and still feels big late in the game.
- Spins go into `spin.banked` (cap 20). If a claim would go over the cap, the rest of the prize still pays, the extra spins are dropped and the prize row says "Spins full".
- Crates go into `crates` and open at the Golden Fish Market.
- A permanent bonus counts from the moment the milestone is claimed, adds to `cafeMultiplier` and shows as a gold "+2% tips forever" chip next to the prize pictures.
- Players who already claimed a milestone under F48 keep what they got, and its old prizes are not paid again. A permanent bonus is part of the milestone, so an F48 claim of `cats6`, `cats10` or `gold10` gets its bonus on the next load (for `gold10` that is the gold luck since v0.10). `gold1` to `gold8` are new for everyone.

### 5b. All Cats milestones (all areas together)

Derek, 18:36: "on top of just overall amount of different cat's captured". A sixth page in the Index, "All Cats", counts different cats across every area (gold cats not counted twice) and has ten milestones. Each one adds to the permanent bonus and pays fish, spins or a crate. The crate is the one from the player's highest unlocked area. v0.10: the permanent bonus here is faster bait forever in place of tips (section 5).

| milestone | different cats | bait faster forever | prize |
|---|---|---|---|
| `total5` | 5 | +2% | 10 fish, 1 spin |
| `total10` | 10 | +2% | 15 fish, 1 Classic Crate |
| `total15` | 15 | +2% | 20 fish, 2 spins |
| `total20` | 20 | +3% | 25 fish, 1 Classic Crate |
| `total25` | 25 | +3% | 30 fish, 2 spins, 1 Golden Classic Crate (v0.10) |
| `total30` | 30 | +3% | 40 fish, 1 crate of the highest unlocked zone |
| `total35` | 35 | +4% | 50 fish, 3 spins |
| `total40` | 40 | +4% | 60 fish, 1 Golden Classic Crate |
| `total45` | 45 | +5% | 75 fish, 3 spins |
| `total50` | all 50 | +10% | 150 fish, 2 Golden Classic Crates (v0.10, was 1), 10 spins and a "Cat Master" name tag |

The track adds up to 38% faster bait (BaitSpeedMax 0.5 leaves room). Before v0.10 it paid +38% tips, and the whole Index was worth up to +148% tips. The counts line up with the tier requirements (5, 12, 20 and 30 different cats), so a player who ranks up passes a Collector milestone on the way.

## 6. Spin Wheel changes (F49)

| slice | was | now | weight |
|---|---|---|---|
| 5 | 2 Moonlit Sardines | 4 golden fish | 10 |
| 6 | 1 Caviar | 1 crate (the crate of the highest zone the player has unlocked) | 5 |

Slices 1 to 4 stay the same. A crate from the wheel is a 5% treat, about one in twenty spins. The slice faces come from data (areas-and-stations B3), so the model doesn't change. The Moonlit Sardines and the Caviar stay in the Tip Jar and with the dealer.

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
1. **Golden Fish Market, cosmetic crates and the Decor Index** (this doc). This is the Ticket Tent idea plus Grow a Garden's cosmetic crates, made fair.
2. **Index rewards that hand out crates, spins and small permanent bonuses**, with a separate gold track and an all-areas All Cats track (section 5). It's PS99's rank-goal gift bags, built on our Index.
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
| F53 | Cafe Crates, the Decor Index and the Golden Fish Market: six crates and their golden versions, 60 pieces (wallpaper, flooring, paint, furniture, decorations), style slots and decor spots, the lucky twentieth, duplicates, Decor Index pages and milestones, perks, Star Treat, the station | P1 | L | engineer, ui, asset (stall, 24 models, 36 surface styles), vfx (reveal, Mythical effects) |
| F54 | Index rewards rebalance (sections 5 and 5b) and the Spin Wheel changes (section 6) | P1 | M | engineer, ui |

Order: F52, then F53, then F54. F54 can ship its coins, food, spins, permanent bonuses and the new milestones before F53, but a crate prize needs F53 to open.

Contract (data-model sections 11b, 11c, 14, 15 and 17 point here since v0.7; this list is the source):
- **Profile, save version 7:** `goldenFish` and `lifetimeGoldenFish` (integers), `crates` (map crateId to count, unopened), `crateLuck` (map crate pool, the zone or `classic`, to opens since the last Epic or better), `fishPerks` (map perkId to level), `stats.cratesOpened` and `stats.fishEarned`. Migration 6 to 7 sets them to 0 or empty. The S60 reasoning applies: an older server would drop them. Sanitise on load: counts must be integers of 0 or more, `crateLuck` 0 to 19 and perk levels 0 to max.
- **`Catalog.crates[crateId]`:** `{ id, name, area, glyph, price?, odds = { Common = 60, Rare = 27, Epic = 10, Legendary = 2.5, Mythical = 0.5 }, pieces = { decorId, ... } }`. The crate ids are `alley_crate` up to `sewer_crate` plus `classic_crate` (`area = "classic"`, open from Tier 1), which have `price = 60`, and `alley_golden_crate` up to `sewer_golden_crate` plus `classic_golden_crate`, which have no price and the odds `{ Epic = 80, Legendary = 17.5, Mythical = 2.5 }`. Each piece's chance is its rarity's odds split equally among that rarity's pieces. A piece is a `DecorDef` with `source = "crate"`, `crate` (its pool), `rarity`, `bonus` from the section 4 table and `kind` = `wallpaper`, `floor`, `paint`, `furniture` or `decoration`.
- **`Catalog.indexPrizes[area][milestone]`**, the shape the UI thread asked for: `{ coins?, coinSeconds?, lures? = { [lureId] = n }, fish?, spins?, crates? = { [crateId] = n }, bonus?, tag? }`. `coins` is the minimum, and `coinSeconds` (when set) pays `max(coins, floor(dayRate x coinSeconds))`. `bonus?` is the permanent tip bonus as a fraction (0.02). v0.10 adds `goldLuck?` (gold track) and `baitSpeed?` (All Cats track), also fractions; a milestone pays one kind. `decorId` goes away. `Catalog.indexMilestones` becomes two tracks per area, `normal` (`cats3`, `cats6`, `cats10`) and `gold` (`gold1`, `gold2`, `gold4`, `gold6`, `gold8`, `gold10`), each row `{ id, track, needs }`. The All Cats track uses the area id `all` with `total5` to `total50`, counted from `collection`. `ClaimIndexReward(areaId, milestoneId)` accepts `all`, and `indexRewards.all` saves those claims. The Decor Index uses the area ids `decor_alley` up to `decor_sewer` and `decor_classic` with the milestones `decor5` and `decor10`, counted from the owned pieces of that crate.
- **`Catalog.spinWheel`:** slice 5 is `{ kind = "fish", count = 4 }`. Slice 6 is `{ kind = "crate", crate = "highest" }`, which the server resolves to the crate of the player's highest unlocked zone. Index and All Cats prizes name their crate id, and `highest` resolves the same way.
- **`Catalog.fishShop`:** rows `{ id, kind = "crate" | "lure" | "perk", cost or costs, maxLevel? }` for section 3.
- **Remotes:**
  - `OpenCrate(crateId)`: within 14 studs of a `FishMarket` station, a known crate id whose area is unlocked and either a banked crate (used first) or a `price` with enough fish. 2 seconds between opens and 1 call per second. The server rolls (the lucky twentieth uses the golden odds), adds the piece or its rarity's refund, puts a furniture or decoration piece on a free decor spot, updates `crateLuck` and fires `CrateResult(crateId, decorId, duplicate, refund)` (the piece's rarity and kind come from its `DecorDef`), which the reveal effect also listens to. A refusal fires `CrateResult(crateId, "", false, 0)`.
  - `BuyFishItem(itemId)`: within 14 studs of the Market, a known row, affordable and below its max level. 2 per second.
  - ProfileSync adds `goldenFish`, `crates`, `crateLuck` and `fishPerks`.
- **Style slots and decor spots:** `ToggleDecor(decorId, true)` on a wallpaper, floor or paint takes the place of the one in use of that kind. On furniture or a decoration, it is refused when every decor spot is full. Pieces placed above the cap after a change stay placed. The cafe shell tags its inside wall parts `Wallpaper`, its floor parts `Floor` and its outside facade parts `Paint`, and the client applies the piece in use to every tagged part, so other players see the paint.
- **Income:** `cafeMultiplier` adds the bonuses of the crate pieces in use, +0.05 for each full Decor Index page, +0.05 per Golden Espresso level and the `bonus` of every claimed Index milestone.
- **Gold luck and bait speed (v0.10):** the server sums `goldLuck` and `baitSpeed` over the claimed milestones (capped at GoldLuckMax 1.5 and BaitSpeedMax 0.5) and sends both in ProfileSync. Gold rolls use `chance x (1 + goldLuck)`, with the Lucky Potion's double on top for bait. `UseLure` saves `readyAt = placedAt + wait x (1 - baitSpeed)`, so a later claim never moves a filling bowl.
- **Analytics:** the economy currency `golden_fish`. Its sources are `first_catch`, `repeat_catch`, `rank_up`, `index_reward`, `spin_wheel` and `tip_jar`. Its sinks are `crate`, `lure` and `perk`. There is also a custom event `crate_opened` (crate, rarity, kind, duplicate, lucky twentieth), so the odds can be checked against results.
- **Constants:** CratePrice 60, CrateDuplicateRefund {Common 10, Rare 20, Epic 40, Legendary 80, Mythical 150}, CrateLuckyEvery 20, FishMarketRange 14, CrateOpenCooldownSeconds 2, DecorSpots {2, 3, 4, 5, 6} by tier, DecorIndexBonus 0.05, DecorIndexHalfFish 25, the crate bonuses {0.02, 0.04, 0.08, 0.15, 0.25}, FishFirstCatch {1, 3, 8, 20, 40}, FishRepeatCatch {Epic 1, Legendary 3, Mythical 8}, FishRankUp {10, 25, 50, 100}, TipJarStep12Fish 5 (removed in v0.10: the Tip Jar rows carry their own fish), GoldLuckMax 1.5 and BaitSpeedMax 0.5 (v0.10).

Monetization check (monetization-policy section 6): no Robux path ends in a crate, a fish or a spin. Every crate shows its odds and the lucky twentieth's numbers before opening. Nothing is limited, timed or shown off as spending. If a coins product ever ships (growth option B), bait repeat catches already pay no fish. Crates would then still be unpaid, but the growth thread should re-check any new fish source against this rule.

## Sources

- Bee Swarm Simulator Wiki, Ticket Tent: https://bee-swarm-simulator.fandom.com/wiki/Ticket_Tent
- Pro Game Guides, tickets in Bee Swarm Simulator: https://progameguides.com/roblox/how-to-get-tickets-fast-in-bee-swarm-simulator-roblox/
- GGRecon, Blox Fruits fragments: https://www.ggrecon.com/guides/blox-fruits-fragments/
- PCGamesN, Pet Simulator 99 diamonds: https://www.pcgamesn.com/pet-simulator-99/diamonds
- Insider Gaming, Grow a Garden cosmetic crates: https://insider-gaming.com/how-to-open-crates-in-grow-a-garden-cosmetics/
- Restaurant Tycoon 2 diamonds: https://speed-test-lamp.ica.art/restaurant-tycoon-2-diamonds
- Roll a Fisherman and the FTC complaint: [docs/growth/comps.md](../../growth/comps.md)
