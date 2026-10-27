# Cat Cafe Data Model and Balance Tables

Draft v0.5.1, 2026-10-27 (v0.5.1 adds the reviewer's S44, S45 and N84 to N86 from docs/reviews/2026-10-27-design-v0.5.md: the self-retry wait after a miss, target-side shove immunity, reachable sprint end points, no shoving from a minigame and a still dropped stray during its owner window; v0.5 folds in Gavin's round 2 answers, [feedback/gavin-2026-10-27.md](feedback/gavin-2026-10-27.md): a missed cat sprints away with unlimited tries, Shove replaces Bump, the bowl moves outside, shinies get their own colour at 5%, one shared dealer stock, the cafe closes at night; v0.2 earlier the same day; v0.3.1 adds the reviewer's findings S23 to S31 from docs/reviews/2026-10-26-design-v0.3.md; v0.4 makes a missed circle end the catch, adds patience paws and the Perfect charm bonus, the back alley layout and walk speeds from Derek's playtest, and syncs the engineer's F22 choices; reasoning in [world-and-feel.md](world-and-feel.md)). Owner: game-designer thread. v0.3 folds in Gavin's answers ([feedback/gavin-2026-10-26.md](feedback/gavin-2026-10-26.md)); the "v0.3 change" notes say what moved so the engineer can diff against what is built. Every number is a first guess. Catalog tables go in `src/shared/Catalog.luau`, tuning numbers in `src/shared/Config.luau`, so QA can tune without touching logic. Field names match [ui-contract.md](ui-contract.md) where they exist; new fields are listed for the UI thread in [features.md](features.md) section 6. Context and reasoning are in [gdd.md](gdd.md).

## 1. Conventions

- Ids are lower snake_case strings and never change once saved: `tabby`, `tables`, `neon_sign`, `tuna`, `barista_1`. Display names can change freely.
- Model names derive from ids per the style guide: cat `tabby` is `CatCafe_Cat_Tabby`, `maine_coon` is `CatCafe_Cat_MaineCoon`.
- Currency is coins, stored as an integer, shown as `$`. Rates are coins per second.
- Rarity strings are exactly `Common`, `Rare`, `Epic`, `Legendary`, `Mythical`. v0.3 change: `Mythical` replaces `Secret` (no cat ever used Secret, so no save holds it).
- Time is server time. Never trust a client clock. Durations that must survive a rejoin (bait) use `os.time()`; sub-second timing (circles, rescue bars) uses `workspace:GetServerTimeNow()` on both sides.
- Chances are stored as 0 to 1 and shown as whole percentages, or one decimal under 1%.
- In code a role slot is still called a spot (`SpotDef`, `spotId`, `spotType`) so the save field and the UI intents keep their names; only the values change (section 5).

## 2. Rarity

| rarity | incomePerSecond | circles | shrinkSeconds | fleeStuds | rescueHits | sellValue | firstCatchReward | color |
|---|---|---|---|---|---|---|---|---|
| Common | 1 | 1 | 1.40 | 12 | 2 | 25 | 50 | #8E97B2 |
| Rare | 3 | 2 | 1.15 | 16 | 3 | 150 | 300 | #5FA8FF |
| Epic | 8 | 3 | 0.95 | 20 | 4 | 600 | 1,500 | #C07CFF |
| Legendary | 25 | 4 | 0.80 | 26 | 5 | 3,000 | 8,000 | #FFC94D |
| Mythical | 75 | 5 | 0.65 | 32 | 6 | 12,000 | 30,000 | #FF5E7E |

`circles` and `shrinkSeconds` drive the net (section 10), `rescueHits` the rescue bar (section 10b). v0.5 change (Gavin, round 2 Q2): `fleeStuds` replaces the v0.4 `patience`; it is how far a stray sprints after a missed catch before anyone can try again (section 10). Tries are unlimited for every rarity. v0.3 change: `baseCatchChance` is gone; the circles decide the catch. The Mythical color is a proposal for the UI thread.

## 3. Cat catalog (50 cats, 10 per area)

Each area has four Common, two Rare, two Epic, one Legendary and one Mythical, and each cat lives in exactly one area (Gavin, Q5; area-unique is a round 2 question). `favoriteRole` is one of `barista`, `waiter`, `greeter`, `entertainer`; a cat working its favorite role earns 1.5 times its rating. `incomePerSecond` repeats the rarity rate for the UI's `CatDef`.

v0.3 change: `area` is a single area id (no more `both`), `favoriteSpot` becomes `favoriteRole`, eight new cats fill out the Alleyway and the Park, and three areas get provisional rosters.

### 3a. Alleyway (`alley`), in the slice

| id | name | rarity | favoriteRole | description | art notes |
|---|---|---|---|---|---|
| tabby | Tabby | Common | barista | The starter. Stripes, snacks, naps. | stripes; fur_orange, fur_orange_dark, eye_amber |
| tuxedo | Tuxedo | Common | waiter | Dressed for dinner, waiting for it. | patches; fur_black, fur_white chest, eye_green |
| ginger | Ginger | Common | greeter | Warm, round, always in the sun. | solid; fur_orange, eye_green |
| smoke | Smoke | Common | entertainer | Grey as a rainy morning. | solid; fur_grey, eye_green |
| calico | Calico | Rare | greeter | Three colors, three opinions. | patches; fur_white, fur_orange, fur_black |
| tortie | Tortie | Rare | barista | Brindled and bossy. | patches; fur_brown, fur_orange, eye_amber |
| sphynx | Sphynx | Epic | entertainer | No fur, all attitude. | solid; blush, eye_blue; the one shape exception |
| maine_coon | Maine Coon | Epic | waiter | Big as a backpack, gentle as a pillow. | stripes; fur_brown, fur_cream ruff; scale 1.2 (new) |
| void | Void | Legendary | barista | Pure black with glowing eyes. Makes the darkest espresso. | solid; fur_black, eye_amber glow, sparkle |
| midnight | Midnight | Mythical | greeter | Fur like the night sky, freckled with stars. | solid; night_sky, star speckles, glow (new) |

### 3b. Park (`park`), in the slice

| id | name | rarity | favoriteRole | description | art notes |
|---|---|---|---|---|---|
| snow | Snow | Common | waiter | All white, hates the muddy paths. | solid; fur_white, eye_blue |
| cream | Cream | Common | barista | The color of a latte, and smells faintly of one. | solid; fur_cream, eye_amber (new) |
| brownie | Brownie | Common | entertainer | Chocolate stripes, chases every leaf. | stripes; fur_brown, fur_brown_dark (new) |
| blue | Blue | Common | greeter | Silver-blue and very polite. | solid; fur_grey blue tint, eye_green (new) |
| siamese | Siamese | Rare | barista | Loud. Supervises the espresso machine. | points; fur_cream, fur_brown points, eye_blue |
| bengal | Bengal | Rare | entertainer | Spotted and fast. Climbs everything. | spots; fur_orange, fur_brown spots, eye_green |
| ragdoll | Ragdoll | Epic | greeter | Huge, fluffy, goes limp when carried. | points; fur_white, fur_grey points; scale 1.2 |
| persian | Persian | Epic | waiter | A cloud with a squashed face and opinions about cushions. | solid; fur_cream long coat (new) |
| blossom | Blossom | Legendary | greeter | Pink-cream fur, and petals follow her everywhere. | patches; blush, fur_cream, petal particles (new) |
| aurora | Aurora | Mythical | entertainer | Fur that shifts color like the northern lights. | gradient; galaxy_blue, mint, glow (new) |

### 3c. Neighbourhood, Woods and Sewer (provisional, after the slice)

Names and favorite roles are placeholders so ids can be reserved; the asset thread does not model these yet.

| area | Common | Rare | Epic | Legendary | Mythical |
|---|---|---|---|---|---|
| `neighbourhood` | biscuit Biscuit (barista), pepper Pepper (waiter), socks Socks (greeter), butter Butter (entertainer) | munchkin Munchkin (entertainer), fold Fold (waiter) | chonk Chonk (barista), postie Postie (greeter) | marshmallow Marshmallow (waiter) | comet Comet (entertainer) |
| `woods` | moss Moss (greeter), acorn Acorn (barista), bramble Bramble (waiter), fern Fern (entertainer) | pinecone Pinecone (barista), forest_cat Forest Cat (greeter) | toadstool Toadstool (entertainer), firefly Firefly (waiter) | old_oak Old Oak (barista) | wisp Wisp (greeter) |
| `sewer` | rusty Rusty (waiter), soot Soot (barista), pipes Pipes (entertainer), puddle Puddle (greeter) | lantern Lantern (waiter), bubbles Bubbles (entertainer) | gears Gears (barista), glimmer Glimmer (greeter) | bottlecap Bottlecap King (waiter) | eclipse Eclipse (barista) |

Which cat within a rarity: a uniform pick among that area's cats of that rarity (four Commons, two Rares, two Epics, one each above). Bait picks across all unlocked areas (section 8).

## 4. Cat instances, shiny and names

A cat the player owns is an instance: `{ uid, catId, variant, caughtAt, spotId, level, xp, charm, rescued, name, method }`.

- `uid`: unique string from the server.
- `variant`: `base` or `shiny`. v0.3 change: Golden and Galaxy are dropped; there is no merging. A shiny earns ShinyMultiplier 1.5 and shows a sparkle on its model, its card and its book entry. v0.5 (Gavin, round 2 Q5: "A shiny also has a different color variation"): every cat also gets its own shiny coat, an alternate set of palette swatches on the same mesh, made by the asset thread; the style (frost, gold or lavender) is a round 3 question. Shiny chance by how the cat was found: net stray ShinyChanceNet 0.05 (v0.5, was 0.02; rolled at spawn and visible as the shiny coat and sparkle on the stray), bait ShinyChanceBait 0.05 (v0.5, was 0.02; rolled when the food goes in, revealed when the cat arrives), rescue ShinyChanceRescue 0.10 (rolled at night start, revealed when the cat comes out). A knocked-loose cat keeps its variant and charm.
- `spotId`: the role slot the cat works, or nil in the cat room (section 5).
- `level`, `xp`, `charm`: the per-cat stats in section 4b, unchanged.
- `rescued`: true for a rescued cat. v0.3 change: it no longer pays more (RescuedTipsMultiplier is 1.0); the rescue reward is the shiny chance. The flag stays for the book and analytics.
- `name`: the player's name for this cat, or nil to show the catalog name. Validation (S30): trim, then 1 to CatNameMaxLength (20) characters counted with `utf8.len` (not `#`); reject invalid UTF-8, control characters, newlines, `<` and `>`. RenameCat filters it once with `TextService:FilterStringAsync` and refuses with a toast if filtering errors or the filtered text is all hashes, so the old name stays. The save keeps the raw name; whenever the name is shown (the cat starts working, or the profile loads with the cat working; at most 10 cats) the server filters it again for broadcast (`GetNonChatStringForBroadcastAsync`) and sets `DisplayName`, because the filter changes over time. If that display filter fails, `DisplayName` falls back to the catalog name.
- `method`: `net`, `rescue`, `bait` or `starter`, for the book and analytics. A v2 cat saved as rescued migrates with method `rescue` (engineer's F22, PR #38).

## 4b. Cat stats: charm, level, XP and rating (`src/shared/CatStats.luau`)

Built 2026-10-26 by the cat stats thread and unchanged in v0.3 except the multipliers named below. Everything is deterministic given the saved fields; the server sends it in `CatView`.

- `charm` 0 to 100, rolled once (now at spawn for strays and rescues, at food placement for bait) and never changed after the cat is owned. v0.4 change: a net catch adds the Perfect bonus to the stray's charm at the moment of the catch (section 10, step 5). The average of two uniform rolls times 101, floored and clamped. Most cats sit near 50; about 8% are 80 or above.
- `stars` 1 to 5 from charm in bands of 20.
- `charmMultiplier = 1 + (charm - 50) / 50 x CharmSpread` (0.20): 0.8x to 1.2x. The starter Tabby has charm 50.
- `level` 1 to CatMaxLevel (10), `levelMultiplier = 1 + CatLevelBonus x (level - 1)` (0.05), so level 10 is 1.45x.
- `xp` counts seconds working a role slot; XP from level n to n + 1 is `CatXpBase x n` (60 x n). Only online time counts.
- `rating = rarity rate x charmMultiplier x levelMultiplier x variantMultiplier`. `variantMultiplier` is ShinyMultiplier for a shiny, else 1. A perfect max-level shiny Midnight rates 75 x 1.2 x 1.45 x 1.5 = 195.75.
- `maxRating(catId)` is the rating at charm 100 and max level, base variant, for the book's potential line; the book also shows the shiny figure.
- Sort order (`CatStats.isBetter`): rating, then rarity, then catId, then uid.
- Equip Best (`src/shared/EquipBest.luau`, remote `EquipBest`): unchanged algorithm, now over at most 10 role slots with `favoriteRole` in place of `favoriteSpot`.

## 5. Roles (replaces spot types)

v0.3 change (Gavin, Q12): the six spot types become four roles. Each role slot is a station in the plot model where the assigned cat stands upright in that role's uniform. All roles pay the same in v0.3: `rating x favoriteMultiplier` where favoriteMultiplier is 1.5 when the slot's role equals the cat's `favoriteRole`. Role-specific boosts for certain cats are later content.

| role (`spotType`) | station | uniform | slot ids in opening order |
|---|---|---|---|
| barista | counter with the espresso machine | apron | barista_1 (T1), barista_2 (T3), barista_3 (T5) |
| waiter | between the tables | bow tie | waiter_1 (T1), waiter_2 (T2), waiter_3 (T4) |
| greeter | inside the door | sash | greeter_1 (T2), greeter_2 (T4) |
| entertainer | cat tree stage | party hat | entertainer_1 (T3), entertainer_2 (T5) |

`SpotDef` becomes `{ id, spotType, tier }`; `tier` replaces `cafeLevel` as the tier that opens the slot. Slots per tier: 2, 4, 6, 8, 10.

## 5b. Tiers (replaces cafe level and Renovate)

v0.3 change (Gavin, Q18): no rebirth and nothing resets. `tier` is a profile field from 1 to 5, raised only by the `RankUp` remote when every requirement is met. Coins are spent on rank up (Gavin confirmed, round 2 Q6). "Different cats" counts entries in `collection` (distinct catIds, shinies not counted twice).

| tier | name | cost | different cats | also needs | role slots | tierMultiplier | opens area | shop caps (tables, espresso, net) | decor and other unlocks |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Corner Cafe | start | | | 2 | 1.00 | alley | 2, 2, 1 | bait bowl |
| 2 | Cozy Cafe | 1,500 | 5 | | 4 | 1.25 | park | 4, 3, 2 | plants, rug; cafe expansion 1 |
| 3 | Busy Cafe | 8,000 | 12 | one Epic or rarer | 6 | 1.50 | neighbourhood | 6, 4, 3 | neon sign; expansion 2 |
| 4 | Famous Cafe | 30,000 | 20 | one Legendary or rarer | 8 | 1.75 | woods | 6, 5, 3 | fish tank, patio; expansion 3 |
| 5 | Grand Cafe | 120,000 | 30 | two different Legendary or rarer cats | 10 | 2.00 | sewer | 6, 5, 3 | "Grand Cafe" leaderboard tag; expansion 4 |

Each column is reachable from the areas already open: Tier 2 needs 5 of the Alleyway's 10, Tier 3 needs 12 of 20, Tier 4 20 of 30, Tier 5 30 of 40. "Cafe expansion n" is a plot model variant the world builder swaps in (more floor, the patio at T4); in the graybox it is extra floor Parts. The UI shows a rank up card with each requirement ticked or not. Rarity requirements mean that rarity or rarer (reviewer N44): the check counts distinct catIds in `collection` whose rarity rank is at least `needsRarity`, so a Mythical meets "one Epic" and a Legendary plus a Mythical meets Tier 5. The card reads "1 Epic or better" and "2 Legendary or better".

`TierDef = { tier, name, cost, distinctCats, needsRarity?, needsRarityCount?, slots, multiplier, area, caps = { tables, espresso, net } }`.

## 6. Upgrade catalog

UI `UpgradeDef` fields. `costs[n]` is the cost of level n. `startLevel` is 1 for espresso, 0 otherwise. v0.3 change: `cafe_level` and `park_access` are removed (tiers do both), `requiresCafeLevel` becomes `requiresTier`, and `requiresTierAtLevel` caps levels by tier (the caps column in section 5b).

| id | name | description | maxLevel | costs | requiresTierAtLevel | effect per level |
|---|---|---|---|---|---|---|
| tables | Tables | Each table seats two more customers and adds tips | 6 | 100, 250, 600, 1500, 3500, 8000 | 3 to 4 need T2, 5 to 6 need T3 | +0.10 cafe multiplier, +2 seats |
| espresso | Espresso machine | Better coffee, bigger tips from every cat | 5 | 0, 300, 1200, 4000, 12000 | 3 needs T2, 4 needs T3, 5 needs T4 | +0.15 cafe multiplier per level above 1 |
| net | Net | Wider timing windows and steadier circles | 3 | 500, 3000, 15000 | 2 needs T2, 3 needs T3 | section 10 net table |
| lure_bowl | Bait bowl | A bowl by your door; put food in and a cat comes by | 1 | 400 | | enables bait (section 8) |

Net level names for the UI: 0 Basic Net, 1 Sturdy Net, 2 Pro Net, 3 Master Net.

## 7. Decor catalog

UI `DecorDef` fields; `requiresCafeLevel` becomes `requiresTier`. Bonuses apply only while placed. Decor a v2 save placed above its new tier stays placed with no refund (engineer's F22).

| id | name | cost | category | effect | requiresTier | bonus |
|---|---|---|---|---|---|---|
| plants | Window plants | 150 | Plants | +5% tips | 2 | +0.05 |
| rug | Cozy rug | 400 | Floor | +5% tips | 2 | +0.05 |
| neon_sign | Neon cat sign | 1,500 | Wall | +10% tips | 3 | +0.10 |
| fish_tank | Fish tank | 5,000 | Furniture | +10% tips, cats stare at it | 4 | +0.10 |

## 8. Bait (lure catalog and the bowl)

v0.3 change (Gavin, Q7): bait moves from shared lure spots in the areas to one bait bowl at your own cafe, the wait is 10 minutes, and the cat that arrives is offered as Tame or Let go. Lure spots, reservations, the calm bonus and refunds are gone.

Rules:

- The bowl is the `lure_bowl` upgrade, one per player. v0.5 (Gavin, round 2 Q4: "The bowl sits out side of your cafe"): the plot's `BaitBowl` anchor moves outside, to the back step facing the Alleyway, where the strays would come from. Other players can see the bait cat eating, but only the owner can Tame or Let go.
- `UseLure(lureId)` near the bowl (12 studs) with the bowl empty and food in stock consumes one food at once. The server rolls everything then and saves it in `profile.bait`: rarity from the food's odds, the cat uniformly among that rarity's cats in every area the player has unlocked, charm, and shiny (ShinyChanceBait). Rolling at placement means rejoining cannot reroll.
- The cat is ready at `placedAt + LureWaitSeconds` (600, server `os.time()`), and the timer runs while the player is offline. The HUD shows the countdown. Until ready, ProfileSync sends only `lureId` and `readyAt`, never the rolled `catId`, `variant` or `charm`, so the reveal is not spoiled (N30).
- When ready and the owner is in the server, the cat model sits eating at the bowl and the bait card shows its name, rarity, stars and sparkle with two buttons: Tame and Let go. `ResolveBait("tame")` adds the instance (method `bait`) straight to the cat room, fires `CatCaught` and empties the bowl; no net and no carry. `ResolveBait("letgo")` empties the bowl. The food is used either way.
- Odds are on every food card before purchase, with the per-cat line ("Legendary 2.6%, split equally across the 2 Legendary cats in your areas, 1.3% each"). A tier up that opens a new area changes the per-cat split, and the card says so. Every food card (shop and dealer) also shows the shiny chance (5% from v0.5) and the charm star odds, because both change income: 1 star 7.8%, 2 stars 23.5%, 3 stars 35.7%, 4 stars 24.3%, 5 stars 8.7% (growth thread; required if coins are ever sold, shown from day one).
- Catnip (common-features item 14, launch) shifts only the wave spawn rolls in the areas. It never changes bait or dealer rolls, so food card odds stay fixed.

Shop foods (`LureDef`, `source = "shop"`):

| id | name | cost | attracts | odds Common / Rare / Epic / Legendary / Mythical | description |
|---|---|---|---|---|---|
| kibble | Kibble | 25 | Common | 70 / 25 / 4 / 0.9 / 0.1 | Cheap and crunchy. Brings the regulars. |
| tuna | Tuna | 100 | Rare | 40 / 45 / 12 / 2.6 / 0.4 | The good stuff. Rare cats come running. |
| salmon | Salmon | 500 | Epic | 15 / 45 / 30 / 8.5 / 1.5 | Nobody can resist it, not even the Void. |

## 8b. The night food dealer

v0.3 addition (Gavin, Q10). A cart with the dealer NPC parks on the street at night start and leaves at day start. Proximity prompt (12 studs) opens the dealer screen.

- v0.5 (Gavin, round 2 Q9: "Every server shares one stock"): one stock for everyone. Three slots, each one food from the dealer table, rolled from `DealerSlotWeights` (one row now; tiers no longer change it) and seeded only by the global time window, `dealerWindow = floor(os.time() / DealerWindowSeconds)` (600), as `Random.new(hash(dealerWindow))`, so every player on every server sees the same three foods and a rejoin or a server hop cannot reroll (S27). Each player can still buy each slot once per window (round 3 question: once each, or a limited amount everyone races for); bought slots are saved in `profile.dealer = { window, bought }` (`bought` keyed by the strings "1" to "3" so the save stays JSON-shaped, engineer's F22), cleared only when the current window is greater than the saved one (N32: server clocks differ by a second or two, so a hop at a boundary can go from W + 1 back to W), so a rejoin or a server hop cannot buy twice. Server nights are not aligned with windows, so a window can roll over mid-night: the stock refreshes then and the dealer screen shows "Fresh stock in m:ss".
- Stock and prices are shown before buying. Bought dealer food goes into `lures` and is used in the bowl like shop food, with its odds on its card.
- `BuyDealerFood(slot, lureId)`: night, cart within 12 studs, slot 1 to 3, not bought this window, affordable. The server recomputes the stock from the seed at purchase time rather than trusting a cached or client value, and refuses the buy when the recomputed slot holds a different food than `lureId` (reviewer S42: a Buy that lands just after a window roll must not buy the new item the player never saw). After every BuyDealerFood, bought or refused, the server sends `DealerStock` so the Buy button gets a definite answer.
- Later: an upgrade that improves the dealer's weights (Gavin's "upgrade or someway"), not in v0.5. With one shared stock an upgrade could only add a personal fourth slot.

Dealer foods (`LureDef`, `source = "dealer"`):

| id | name | cost | odds Common / Rare / Epic / Legendary / Mythical | description |
|---|---|---|---|---|
| sardines | Moonlit Sardines | 800 | 30 / 45 / 20 / 4.5 / 0.5 | Silvery and still glowing a little. |
| caviar | Caviar | 3,000 | 10 / 35 / 38 / 14 / 3 | Tiny, shiny and very fancy. |
| moon_milk | Moon Milk | 10,000 | 0 / 20 / 45 / 28 / 7 | Nobody knows where he gets it. |
| star_treat | Star Treat | 40,000 | 0 / 0 / 40 / 45 / 15 | It twinkles. Mythical cats can smell it from the next area. |

Each dealer food's `attracts` chip is its likeliest rarity: sardines Rare, caviar Epic, moon_milk Epic, star_treat Legendary (engineer's F22).

`DealerSlotWeights` (chance per slot of sardines / caviar / moon_milk / star_treat), v0.5 one row for everyone (the old Tier 3 row): 50 / 33 / 14 / 3. The v0.3 per-tier rows (Tier 1 70 / 25 / 5 / 0 up to Tier 5 30 / 36 / 24 / 10) are retired.

## 9. Areas, the clock and spawning

Clock (Gavin, Q1): DayLengthSeconds 300 then NightLengthSeconds 300, exposed as `Phase` and `PhaseEndsAt` on the `Clock` folder in ReplicatedStorage. A new server starts in day with ServerStartDaySeconds 120 left. Lighting, the cafe sign (sun or moon), customers, the dealer cart and the HUD chip follow `Phase`.

Night waves (Q2, Q3): at every night start each area despawns its uncaught strays and spawns WaveSize (10) strays at once from its odds; a dropped (knocked-loose) stray counts as uncaught only if it was dropped more than DroppedMinStaySeconds (120) before the wave starts; a younger one skips that wave (S32). Leftovers stay catchable by day until the next night. Rescue traps roll at night start too. Areas spawn whether or not anyone has them unlocked, so a player who ranks up mid-night finds a wave waiting.

| id | name | unlock | spawnPoints | waveSize | rescue traps | odds Common / Rare / Epic / Legendary / Mythical |
|---|---|---|---|---|---|---|
| alley | Alleyway | Tier 1 | 24 | 10 | trash_bin x2, garbage_bag x1 | 72 / 22 / 5 / 0.9 / 0.1 |
| park | Park | Tier 2 | 14 | 10 | tree x2, trashcan x1 | 60 / 28 / 9 / 2.5 / 0.5 |
| neighbourhood | Neighbourhood | Tier 3 | 14 | 10 | shed, gutter (provisional) | 50 / 32 / 13 / 4 / 1 |
| woods | Woods | Tier 4 | 16 | 10 | hollow_log, bramble_bush (provisional) | 42 / 34 / 17 / 5.5 / 1.5 |
| sewer | Sewer | Tier 5 | 16 | 10 | drain_pipe, grate (provisional) | 35 / 35 / 20 / 7.5 / 2.5 |

v0.4 layout (engineer, 2026-10-26, after Derek found the old alley too far and too small; design in [world-and-feel.md](world-and-feel.md) section 2): the Alleyway is two back alleys behind the cafe rows that meet in an Alley Square at the north end, at least 8 times the old 60 x 44 box. Every cafe's back door opens onto it from Tier 1, and check-in works at either door. Its 24 spawn points carry `Zone`: `lane` (two behind every cafe, 16) or `square` (8). Epic, Legendary and Mythical strays take only free `square` points (any free point if none is free); Commons and Rares take any. One trash bin per back alley, the garbage bags in the Square. The Park gate stays at the street's south end; the Neighbourhood, Woods and Sewer gates go where world-and-feel.md suggests unless the engineer finds better spots.

Locked areas: a gate model at the entrance is solid on the client for players below the tier, and the server refuses GrabBegin, RescueBegin and Bump in an area the player has not unlocked, so walking past the gate gains nothing.

Area cats (Gavin confirmed, round 2 Q10): a cat spawns only in its own area and never in another; several copies of the same cat can be in its area at once. Bait is not an area spawn, so a bait cat can be any cat from the player's unlocked areas.

Tutorial rule: a player with `tutorialStep` below 2 always finds a Common stray waiting, v0.4 at the `lane` spawn point behind their own cafe so it is right outside the back door. Strays are workspace models with attributes (section 13).

## 10. Net: closing circles

v0.3 change (Gavin, Q6): the hold-and-release ring and the flat catch chance are replaced by a sequence of closing circles judged on the server. v0.4 change (Derek, 2026-10-26: "making the game actually matter if you miss the catch windows"): the first Miss ends the catch with no roll and all Good or Perfect is a sure catch. v0.5 change (Gavin, round 2 Q2): the patience paws are gone; a missed cat sprints away and anyone can chase it and try again, with no limit on tries.

Flow:

1. The stray's prompt fires `GrabBegin(strayId)`. Server checks as before (exists, unlocked area, LockedBy 0 or self, 10 studs, not carrying, cooldown), plus v0.5: the stray is not sprinting or catching its breath, and the caller is not inside their own StraySelfRetrySeconds after missing it (step 5, S44). It locks the stray and builds the schedule: `n = circles[rarity]`; circle 1 starts CircleLeadInSeconds (0.6) from now; each circle's shrink time is `shrinkSeconds[rarity] x (1 + u)` with `u` uniform in `[-jitter, +jitter]` for the player's net level; a gap of CircleGapMin to CircleGapMax (0.40 to 0.75 s) separates circles. The target moment of circle i is its start plus its shrink time. The lock lasts until the last target plus GoodWindow plus 1 s, or v0.4 until a Miss ends the attempt, whichever comes first.
2. The server fires `CatchSchedule(strayId, circles, windows)` to that player (v0.5 drops `pawsLeft`): `circles = { { startsAt, shrinkSeconds, x, y } }` in server time (x and y are screen positions 0 to 1 so circles do not sit in one spot), `windows = { perfect, good }` in seconds for drawing the bands.
3. The client draws each circle shrinking onto its ring and fires `CatchPress(strayId, index)` on each press. The client sends no time: the server stamps each press with `GetServerTimeNow()` on arrival and subtracts half the player's round-trip ping (`Player:GetNetworkPing() / 2`, capped at CatchLatencyCapSeconds 0.15).
4. Judging each circle: `error = abs(press - target)`. Within `perfect` is Perfect, within `good` is Good, else Miss (v0.4: grades only, no scores). Only the first press per index counts, presses must come in index order, and a press before a circle's start is ignored. A circle with no press by its target plus `good` plus CatchLatencyCapSeconds is a Miss. Invariant (S24, a Config spec): `CircleGapMin > max(good over net levels) + CatchLatencyCapSeconds`, so a late press for one circle can never land on the next; today 0.40 > 0.18 + 0.15. Raise CircleGapMin whenever `good` is widened.
5. v0.4: the attempt ends at the first Miss or after the last circle, with no roll.
   - Fail (a Miss): the server stops judging and cancels the circles left. v0.5 (Gavin, round 2 Q2: "Any miss ends the catch and the cat sprints away for a bit making the player catch up to it again to retry. unlimited tries for all cats regardless of rarity but the rarer the cat the harder it is to catch"): the stray sprints `fleeStuds[rarity]` (section 2, 12 for a Common up to 32 for a Mythical) straight away from the player at StrayFleeSpeed (26, faster than walking), then catches its breath for StrayRestSeconds (1.5) and goes back to wandering. The end point is clamped to the area's `roam` rects and the run stops short at the first prop on its path, so the cat always lands where players can reach it (reviewer N84). Until it stops, GrabBegin from anyone refuses with "It's running!". Once it stops, everyone else can try at once and the player who missed can try again StraySelfRetrySeconds (1) later (reviewer S44: without the wait, one player could miss on purpose and win every race back to the stray, keeping a Legendary from the whole area). The wait lives in the stray's server entry (`selfRetryAt[userId]`). There is no limit on tries for any rarity, so there are no paws. Exception (reviewer N86): a Dropped stray does not sprint while its old carrier's owner window runs (DropOwnerPrioritySeconds, section 10c); it stays put and the old carrier can retry after StraySelfRetrySeconds. After the window it sprints like any stray. The stray mirrors `FleeingUntil` for the client (section 13). Toast: "It got away! Chase it!". Rarer cats are harder through more and faster circles (section 2) and a longer chase.
   - Walking out of range or finishing a rescue mid-catch (S21, S33) is a Miss.
   - Success (every circle Good or Perfect): the player enters carry (section 10c). Charm bonus: `gain = PerfectCharmBonus (4) x perfectCount`, times PurrfectCharmMultiplier (2) when every circle is Perfect, and 0 for a profile with `flags.autoPress` or when the stray is Dropped (reviewer S36: a dropped cat already carries its bonus, and unlimited tries would let two friends shove and re-catch it up to charm 100); the caught cat's `charm = min(100, strayCharm + gain)` and its stars follow (section 4b).
   - The server fires `CatchResult(strayId, grades, success, charmGain)` (v0.5 drops `pawsLeft`): `grades` lists the judged circles up to and including any Miss, `charmGain` is 0 on a fail. The UI shows each grade as it lands and the charm line; there is no percentage.

Net levels (windows are half-widths in seconds either side of the target; jitter is the spread on each circle's shrink time):

| net | name | perfect | good | jitter |
|---|---|---|---|---|
| 0 | Basic Net | 0.045 | 0.11 | 0.30 |
| 1 | Sturdy Net | 0.055 | 0.13 | 0.20 |
| 2 | Pro Net | 0.065 | 0.155 | 0.10 |
| 3 | Master Net | 0.08 | 0.18 | 0 |

Feel targets for QA (v0.5): a new player with a Basic Net should catch a Common in one or two tries (one slow circle, Good is enough), and a missed Common is a short hop away. A Rare or Epic should feel tense but fair. A Mythical with a Basic Net should take several tries and real chases, and a Master Net should make it fair. Test on a phone on mobile data as well as Wi-Fi: phone ping wanders by 30 to 50 ms against a 45 ms Basic Perfect window (N28). If the Basic Net feels mean on touch, widen `good` before touching anything else, and raise CircleGapMin with it (S24).

Exploit note (reviewer signed off 2026-10-26): the server owns the schedule and the clock, so a client cannot forge a Perfect, but a script that watches the circles and presses on time will score well. That is accepted for the slice (Gavin wants all-Perfect to be 100%). v0.4 raises the stakes: all Good or Perfect is now a sure catch, so a script that presses on time catches every cat it reaches; supply (ten strays per area per night, shared) is still the limit. The exploit check uses the server's own stamped errors, never TelemetryReport (S23): CatService keeps a 50-circle ring buffer per player and sets `profile.flags.autoPress` when the Perfect rate over the last 50 circles is above AutoPressFlagRate (0.95). v0.4, what the flag does (reviewer, 2026-10-26): while set, the profile gets no Perfect charm bonus, and the server sends an `autopress_flag` analytics event when it sets and when it clears. It clears itself when the buffer holds a full 50 circles and their rate is AutoPressClearRate (0.85) or below; the buffer is in memory and empty after a rejoin, so a short buffer never clears a saved flag (reviewer N46). Nothing else is taken away automatically, because a false positive on a child costs more than a script catching cats; Derek reviews flagged accounts from analytics. A script that mixes in Goods stays under the flag, which is also accepted. AnalyticsService has no per-player view, so the check cannot live there. No error-spread test, because network jitter alone spreads a script's arrivals by about 10 ms.

## 10b. Rescue minigames

v0.3 change (Gavin, Q8): the 4 s hold becomes a short minigame on an area-specific trap. A failed attempt never loses the cat.

- At night start each rescue trap holds a stuck cat with RescueSpawnChance 0.6, and every area gets at least RescueMinStuck (1): if no trap rolled a cat, one random trap is filled anyway, so a new player always meets a rescue on the first night (QA, 0.4 cubed is one server in 16 otherwise). Rescue odds are the area odds with every non-Common weight doubled and renormalised (Alleyway 56.3 / 34.4 / 7.8 / 1.4 / 0.16, Park 42.9 / 40.0 / 12.9 / 3.6 / 0.7). Charm and shiny (ShinyChanceRescue 0.10) are rolled then and kept server-side until the rescue succeeds: not on the stuck cat's model, prompt or attributes (N30). Stuck until rescued or the next night.
- `RescueBegin(rescueSpotId)` checks as before (occupied, unlocked area, lock free or own, 10 studs, not carrying), locks the trap to the player for the attempt and fires `RescueChallenge(rescueSpotId, challenge)`.
- Kind `bar` (trash_bin, garbage_bag, trashcan and the provisional traps): a marker slides back and forth along a bar at RescueBarSpeed[rarity] bar lengths per second, starting at a server-set time and phase, with a target zone RescueZoneWidth[rarity] wide at a server-set position. `RescuePress(rescueSpotId)` is stamped and latency-corrected like a circle press; the server computes where the marker was and allows RescueTolerance 0.03 of the bar. A hit moves the zone to the next server-set position; `rescueHits[rarity]` hits frees the cat. Each miss costs one of RescuePatience (3) paws; out of paws ends the attempt.
- Kind `shake_catch` (tree): `rescueHits[rarity] - 1` bar hits shake the branch, then the cat drops and one catch circle (Common shrink time, the Pro Net windows whatever net you own) must score Good or Perfect to catch it. A miss means the cat lands, climbs back up and the attempt ends.
- Every attempt has a deadline (S28): it ends as a fail at RescueAttemptMaxSeconds (15) after RescueBegin, when the player moves more than 14 studs from the trap, dies or leaves, or on RescueCancel. The server keeps the lock and the deadline in its own table.
- Ending without success: the trap unlocks and the cat stays stuck. Other players can try after RescueRetrySeconds (3); the same player waits RescueSelfRetrySeconds (6), so one player or script cannot re-lock the trap at the instant it opens and hold it all night.
- Success: the cat is revealed (sparkle if shiny), the player enters carry with `rescued = true`.

| rarity | RescueBarSpeed | RescueZoneWidth |
|---|---|---|
| Common | 0.8 | 0.30 |
| Rare | 1.0 | 0.24 |
| Epic | 1.2 | 0.19 |
| Legendary | 1.4 | 0.15 |
| Mythical | 1.6 | 0.12 |

## 10c. Carry and shove

v0.3 change (Gavin, Q9): one cat at a time on the way home, and other players can knock it loose. This replaces the v0.2 no-stealing rule.

v0.5 change (Gavin, round 2 Q3: "Instead of Bump, make it a shove mechanic. Players are able to shove other players in areas where they can catch cats"): Bump becomes Shove. Any player can shove any other player, carrying or not, but only while both stand inside a catching area the shover has unlocked; the street, the cafes and the yards are safe. A shove pushes the target ShoveKnockbackStuds (10) away from the shover. Characters are client-owned, so the server sends the impulse to the target's client and the engineer picks how to apply it. Shoving a carrier also rolls the knock-loose below, with every protection kept. Our plan, both round 3 questions: a player inside a catch or rescue minigame cannot be shoved, and a shove knocks a carried cat loose half the time. In code the remote, the attributes and the constants may keep their `Bump` names; the player-facing word is Shove. The server sends the target's client only a direction and ShoveKnockbackStuds, never a strength taken from the shover. v0.5.1 (reviewer S45): after a shove lands, nobody can shove that player again for ShoveTargetImmuneSeconds (4), so a group cannot chain-shove one player against a wall; the carry protections below are unchanged. Reviewer N85: a player holding a catch or rescue lock cannot shove either, the Shove key is never E, Space or any key the circles or the rescue bar use, and the Shove button hides while either minigame is up.

- Carry is as built: success sets carry state, walk speed CarryWalkSpeed (16 since v0.4), the held cat model, `CheckIn` at the own door (8 studs) adds the instance. Leaving mid-carry still saves the cat. A carrying player cannot start a catch, a rescue or a bump.
- The carrier's character gets attributes `CarryingCatId`, `CarryStartedAt`, `BumpImmune`.
- `Bump(targetUserId)`: server checks `targetUserId` is an integer (`Guard.int`) naming a player in the server (`Players:GetPlayerByUserId`) other than the bumper (N29), the bumper is not carrying, both players are inside one catching area the bumper has unlocked (v0.5), the bumper is within BumpRangeStuds (6), the target holds no catch or rescue lock (v0.5) and is outside its own safe zone (its plot plus BumpSafeRadiusStuds 15 around both of its doors); the bumper is off BumpCooldownSeconds (8, v0.5, was 12) and has not shoved this target in the last BumpSameTargetSeconds (20, v0.5, was 60); the bumper holds no catch or rescue lock (N85); nobody has shoved the target in the last ShoveTargetImmuneSeconds (4, S45), kept in the server's shove table. Every valid shove pushes the target (v0.5). The knock-loose roll below runs only when the target is carrying, not BumpImmune and at least BumpGraceSeconds (3) into the carry. BumpEnabled false in Config turns the remote off and hides the prompt.
- Then roll BumpChance (0.5). Success: the cat drops at the carrier's feet as a stray with `Dropped` true, its catId, variant, charm and rescued flag kept, and scurries 6 to 10 studs. The server records `droppedBy` (the bumper) and `dropOwner` (the old carrier) in its own table (S25). For DropOwnerPrioritySeconds (8) only the old carrier can start a catch on it; after that anyone can, except the bumper, who can never catch a stray they knocked loose. A Dropped stray never despawns or leaves its area and stays until caught (S26); after a missed catch it sprints like any stray once the owner window is over (N86, section 10), and tries are unlimited for everyone (v0.5). It also survives any night wave that starts within DroppedMinStaySeconds (120) of the drop (S32), so a bump timed just before nightfall cannot delete the cat before the owner window is used. A bump can delay a kid's Legendary but never lose it outright. Whoever catches a dropped stray is BumpImmune for that carry. Fail: both players get "It held on tight!" and the carrier is BumpImmune for 3 s.
- Grace, immunity, cooldowns and drop claims live in server tables; the character and stray attributes are display only (N29). The 6-stud range check uses client-owned character positions, so it only bounds honest play; the cooldowns are what limit a teleporting exploiter, which is accepted.
- The bumper never receives the cat. Nothing is taken from a cafe, only from arms on the way home.
- v0.5: Shove is a button on mobile and a key on desktop, shown only inside catching areas and aimed at the nearest other player within 6 studs (UI thread's choice of key and look); the server validates regardless.

## 11. Income and offline

- `incomePerSecond = sum over working cats of (rating x favoriteMultiplier) x cafeMultiplier x tierMultiplier x phaseMultiplier`.
- `tierMultiplier` from section 5b. v0.3 change: it replaces `prestigeMultiplier` and `renovations`, in the same place in `Economy.incomePerSecond`.
- `phaseMultiplier` is 1.0 by day and NightIncomeMultiplier (0.6) by night (Gavin, Q10). Settling must split the window at phase boundaries: `Economy.settle` integrates the multiplier over `[lastTick, now]` using `Clock.phaseAt`, and ProfileSync sends the current rate, which drops at nightfall.
- `favoriteMultiplier` is 1.5 when the slot's role is the cat's `favoriteRole`.
- `cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + sum of placed decor bonuses` (unchanged).
- Accounting unchanged: `coins` and `lastTick`, settle on every read or spend, the client predicts between syncs.
- Offline unchanged: `offlineGain = dayRateAtLogout x OfflineRate (0.25) x min(now - lastSeen, OfflineCapSeconds 3600)`. `rateAtLogout` stores the day rate.

## 12. Customers and rich customers

- Customers are client-simulated as before. By day: a customer every CustomerSpawnSeconds (6) while a seat is free. v0.5 (Gavin, round 2 Q8: "Cats earn 60% at night because they aren't working and 100% when Cafe is running"): the cafe closes at night. No customers come and the door sign flips to Closed with a moon; working cats curl up and nap at their stations while the 60% keeps coming in. The v0.3 night owls and CustomerSpawnSecondsNight are gone.
- Rich customer (Gavin, Q10), server-driven because it pays: by day, every RichCheckSeconds (60), each occupied plot with income above 0 and at least one table (tables level 1 or more, because the rich customer, coin pile and RichTipAnchor sit on table 1; N81) rolls RichChance (0.15). On a hit the server records `{ ownerUserId, serial, amount = max(50, floor(dayRate x RichTipSeconds 45)), expiresAt = now + RichTipStaySeconds (90) }` in its own table keyed by plot, and mirrors amount and expiry to the plot attributes `RichTipAmount` and `RichTipExpiresAt` for display only. Each client shows a rich customer (top hat, gold coin pile on a table). `ClaimRichTip()` by the owner within 12 studs of the plot's tip anchor before expiry adds the amount. If unclaimed, the server adds it when it expires, so it is never lost; claiming is just sooner and more fun. One rich tip at a time per plot. Owner safety (S29): the expiry credit checks the owner UserId and serial still match; pay exactly once by zeroing the record before crediting on both the claim and the expiry path; if the owner leaves before expiry, the save-on-leave path credits it; releasing a plot clears the record and both attributes.

## 13. Instance attributes (world data, no remote needed)

Stray cat model (tag `Stray`): `StrayId`, `CatId`, `CatName`, `Rarity`, `Area`, `LockedBy` (UserId or 0), `SpawnedAt`, `Charm`, `Stars`, `Shiny` (bool, never set on a stuck cat before its rescue), `Dropped` (bool), `DropOwnerUntil` (display of the old carrier's priority window), `FleeingUntil` (v0.5, server time the sprint and rest end, display only). v0.3 change: `ReservedFor` is gone (no lured strays in areas).

Rescue trap (tag `RescueSpot`): `RescueSpotId`, `Area`, `TrapType` (`trash_bin`, `garbage_bag`, `tree`, `trashcan`, ...), `Occupied`, `LockedBy`, `RetryAt`. The stuck cat model shows `CatId`, `CatName`, `Rarity` (shown before the attempt so players can choose) but not `Shiny`.

Carrier character: `CarryingCatId`, `CarryStartedAt`, `BumpImmune`.

Shoved character (v0.5, asked by the vfx-animator for the shove puff and dizzy stars): `ShovedAt` (server time of the latest shove that landed on this player) and `ShovedBy` (the shover's UserId). Display only; the cooldowns and ShoveTargetImmuneSeconds read the server's shove table.

Clock folder in ReplicatedStorage: `Phase`, `PhaseEndsAt`.

Attributes are for display. Server decisions (locks, deadlines, bump grace and claims, rich tips, the bait roll, hidden shiny) read the server's own tables.

Dealer cart (tag `DealerCart`): `Open` (bool).

Plot model (tag `Plot`): `OwnerUserId`, `PlotIndex`, `Tier`, `RichTipAmount`, `RichTipExpiresAt`, `BaitReadyAt` (0 when empty). Children: `Spots/<slotId>` station parts with attribute `SpotType` (the role), `DecorAnchors/<decorId>`, `BaitBowl`, `RichTipAnchor`, `Door`, `CustomerWaypoints`, `Expansions/<n>`.

Working cat model (under `Plot/Cats`): `Uid`, `CatId`, `OwnerUserId`, `Role`, `DisplayName` (the filtered name or the catalog name), `Shiny`.

## 14. Player profile (save data, version 3)

| field | type | default | notes |
|---|---|---|---|
| version | integer | 3 | 3 (2026-10-26, design v0.3) |
| coins | integer | 50 | |
| lifetimeCoins | integer | 0 | |
| lastTick, lastSeen | integer | join time | |
| rateAtLogout | number | 0 | day rate |
| tier | integer | 1 | new, section 5b |
| upgradeLevels | map id to level | espresso 1, tables 0, net 0, lure_bowl 0 | `cafe_level` and `park_access` removed |
| decorOwned, decorPlaced | map id to true | empty | |
| lures | map id to count | empty | shop and dealer foods |
| bait | `{ lureId, placedAt, catId, variant, charm }` or nil | nil | new, section 8 |
| dealer | `{ window, bought = { [slot] = true } }` | `{ window = 0, bought = {} }` | new, section 8b; `window` is the global dealer window |
| cats | map uid to cat instance | one `tabby` on `barista_1`, charm 50, level 1, method `starter` | section 4 adds `name`, `method`; `variant` can be `shiny` |
| collection | map catId to firstCaughtAt | tabby | drives the book and "different cats" |
| shinyCollection | map catId to firstCaughtAt | empty | new, the shiny page |
| stats | catsCaught, catsSold, grabsAttempted, grabsSucceeded, perfectCircles, circlesTotal, rescues, rescueAttempts, baitsTamed, baitsLetGo, bumpsGiven, bumpsLanded, bumpsTaken, luresUsed, playtimeSeconds, sessions | 0 | new counters added |
| tutorialStep | 0 to 5 | 0 | 0 new, 1 saw the alley, 2 caught, 3 assigned a role, 4 bought a table, 5 set bait (done) |
| settings | music, sfx | true, true | |
| telemetry | `{ onboardingStep, achieved = { [step] = true } }` | `{ onboardingStep = 0, achieved = {} }` | new; the funnel logs each onboarding step once and only in order, because Roblox marks every earlier step complete when a later one is logged, so a rank up before bait would otherwise fake the bait steps (growth, analytics-plan) |
| flags | `{ autoPress }` | `{ autoPress = false }` | new; set by the circle ring buffer (section 10), review only |

Removed: `equippedLure` (UseLure takes the food id), `renovations`.

Migration 2 to 3: `tier = 1`; refund the coins spent on `cafe_level` levels above 1 and on `park_access` so test saves keep their value; drop both from `upgradeLevels`; cap `tables`, `espresso` and `net` at the Tier 1 caps and refund levels above the cap; clear every cat's `spotId`, then run Equip Best once on load to fill `barista_1` and `waiter_1`; set `method = "net"` on caught cats and `"starter"` on the first tabby; drop `equippedLure` and `renovations`. Forward only. The v2 cost tables for `cafe_level` (0, 250, 800, 2500, 8000) and `park_access` (1000) are frozen inside `ProfileSchema` for the refund, because the live Catalog no longer has them (S31).

Newer-save guard (S31): if a saved `version` is above the code's version, do not load and do not save that profile; kick with "The game just updated, please rejoin". This stops an old server from rebuilding a v3 save as v2 and dropping `tier`, `bait`, `dealer` and names. When v3 is published, restart all servers.

## 15. Remotes (`src/shared/Remotes.luau`)

Every client to server call is validated on the server. Default rate limit 10 calls per second per player per remote. Reject silently on a limit and log the UserId.

| name | kind | args | server checks | result |
|---|---|---|---|---|
| GrabBegin | event | strayId | stray exists, area unlocked, LockedBy 0 or self, not sprinting (v0.5), not the caller's StraySelfRetrySeconds after their miss (S44), for a Dropped stray not the bumper and within the old carrier's priority window only the old carrier, 10 studs, not carrying, GrabCooldownSeconds | locks, fires CatchSchedule (section 10) |
| CatchPress | event | strayId, index | LockedBy self, attempt open, index is the next unjudged circle, not before its start; 10 per second | judges the circle; a Miss or the last circle ends the attempt and fires CatchResult, no roll (v0.4) |
| RescueBegin | event | rescueSpotId | occupied, area unlocked, unlocked or own, past RetryAt (RescueSelfRetrySeconds for the player who just failed), 10 studs, not carrying | locks with a deadline, fires RescueChallenge (section 10b) |
| RescuePress | event | rescueSpotId | LockedBy self, attempt open; 10 per second | scores the press; on success to carry, on out of paws ends; fires RescueResult |
| RescueCancel | event | rescueSpotId | LockedBy self | ends the attempt, sets RetryAt |
| CheckIn | event | none | carrying, 8 studs of own Door | adds instance, CatCaught, first-catch reward |
| Bump | event | targetUserId | integer UserId of another player in the server, then section 10c (caller holds no lock, target not shoved by anyone within ShoveTargetImmuneSeconds); 1 per BumpCooldownSeconds | v0.5 Shove: pushes the target; if it is carrying, rolls and drops the cat as a stray on success; Toast both ways |
| PlaceCat | event | uid, spotId | owns uid, slot exists in own plot, slot open at the player's tier, slot empty, cat not already working | sets spotId, rate, upright model with uniform |
| UnplaceCat | event | uid | owns uid, working | clears spotId, cat to the cat room |
| EquipBest | event | none | profile loaded; 1 per 2 s | best placement over open slots |
| SellCat | event | uid | owns uid, not the last working cat | removes, adds sellValue |
| RenameCat | event | uid, name | owns uid, string, valid UTF-8, 1 to 20 `utf8.len` after trim, no control characters, newlines, `<` or `>`, 1 per 5 s; filter succeeds | saves the raw name, sets DisplayName from a broadcast filter (section 4) |
| RankUp | event | none | tier below 5, cost affordable, distinct cats, rarity requirement; 1 per 2 s | spends, tier + 1, unlocks, Announce, ProfileSync |
| BuyUpgrade | event | upgradeId | in catalog, below maxLevel, tier cap for the next level, affordable | level + 1, spends |
| BuyDecor | event | decorId | in catalog, not owned, requiresTier met, affordable | owned and placed |
| ToggleDecor | event | decorId, placed | owned | sets placed |
| BuyLure | event | lureId | shop food (source shop), affordable | count + 1. No PolicyService gate (section 8 and the monetization notes) |
| UseLure | event | lureId | lure_bowl owned, bowl empty, count above 0, 12 studs of own BaitBowl | consumes, rolls and saves `bait`, sets BaitReadyAt |
| ResolveBait | event | choice (`tame` or `letgo`) | bait exists, ready, owner within 20 studs of own BaitBowl | tame adds the cat; both empty the bowl |
| BuyDealerFood | event | slot, lureId | night, 12 studs of the cart, slot 1 to 3, not bought this window, affordable; stock recomputed from the seed and the slot must still hold `lureId` (S42) | count + 1, marks bought; sends DealerStock either way |
| ClaimRichTip | event | none | own plot has an unexpired tip, 12 studs of RichTipAnchor | adds the tip, clears it |
| TelemetryReport | event | name, value | allowlist, 10 per minute | analytics only |
| ClaimOffline | event | none | pending above 0 | adds coins |
| TutorialAdvance | event | step | step is tutorialStep + 1 | saves step |
| CatchSchedule | server to client | strayId, circles, windows | | UI draws the circles |
| CatchResult | server to client | strayId, grades, success, charmGain | | UI grades, charm line and toast (v0.5) |
| RescueChallenge | server to client | rescueSpotId, challenge | | UI draws the bar or the shake |
| RescueResult | server to client | rescueSpotId, hits, pawsLeft, done, success | | UI |
| DealerStock | server to client | slots = { { lureId, cost, bought } }, restocksAt | | sent at night start, at each window change during night, when the screen opens and after every BuyDealerFood, bought or refused |
| BaitReady | server to client | catView | | UI bait card |
| ProfileSync | server to client | partial `PlayerState` | | adds `tier`, `bait`, `shinyCollection`, `rankUp` progress |
| CatCaught | server to client | catId, isNew, shiny, isNewShiny | | cat found popup |
| OfflineEarnings, Toast | server to client | as before | | |
| Announce | server to all | text | | Epic and up, every shiny, every rank up to Tier 3 and up |

Removed: GrabEnd (replaced by CatchPress), RescueEnd (replaced by RescuePress), EquipLure.

v0.4 addition, `Travel(destination)` (engineer's F19, the shape is theirs): `home` or an area id; the area is unlocked, the player is not carrying, holds no catch or rescue lock (reviewer N47) and TravelCooldownSeconds (3) has passed; moves the character to that destination's entry point.

## 16. Analytics events (AnalyticsService)

The plan is the growth thread's [analytics-plan.md](../../growth/analytics-plan.md). v0.3 asks it to add: onboarding steps `first_role`, `first_bait`, `first_bait_resolved`, `tier_2`; custom events `catch_circles` (rarity, net level, perfect count; per-circle error goes to the exploit check), `rescue_attempt` (trap type, rarity, success), `bait_resolved` (food, rarity, tame or letgo), `bump` (success, rarity, area), `rank_up` (tier, minutes played), `dealer_buy` (food, tier), `rich_tip` (claimed or auto), `cat_renamed`, `shiny_found` (method, rarity); progression `tier` 1 to 5 in place of `cafe_level`. Sinks add `rank_up` and `dealer`. The growth thread also added `bump`, `drop_outcome` and `left_after_bump` to judge griefing in the alpha (analytics-plan.md, PR #33). v0.4 asks for `catch_circles` to add `missed`, `purrfect` and `charmGain` (v0.5 drops `pawsLeft` and adds `tryNumber`, the player's tries on that stray), `shove` (knocked loose or not, area) in place of `bump`, a custom event `autopress_flag` (set or cleared), and `travel` (destination) to see whether players still walk.

## 17. Tuning constants (`src/shared/Config.luau`)

Changed or new in v0.3 (everything not listed keeps its v0.2 value):

| constant | value | was | used by |
|---|---|---|---|
| DayLengthSeconds | 300 | 180 | ClockService |
| NightLengthSeconds | 300 | 120 | ClockService |
| WaveSize | 10 | 6 | CatService |
| NightIncomeMultiplier | 0.6 | new | Economy |
| ShinyMultiplier | 1.5 | new | CatStats |
| ShinyChanceNet, ShinyChanceBait, ShinyChanceRescue | 0.02, 0.02, 0.10 | new | CatService |
| CircleLeadInSeconds | 0.6 | new | CatService |
| CircleGapMin, CircleGapMax | 0.40, 0.75 | new | CatService; spec: CircleGapMin > max(good) + CatchLatencyCapSeconds |
| CircleScorePerfect, CircleScoreGood | 1.0, 0.5 | new | CatService |
| NetWindows | per section 10 table | new | CatService, UI |
| CatchLatencyCapSeconds | 0.15 | new | CatService |
| RescueSpawnChance | 0.6 | 0.5 | CatService |
| RescueMinStuck | 1 | new | CatService, stuck cats guaranteed per area per night |
| RescueBarSpeed, RescueZoneWidth | per section 10b table | new | CatService, UI |
| RescueTolerance | 0.03 | new | CatService |
| RescuePatience | 3 | new | CatService, UI |
| RescueRetrySeconds | 3 | new | CatService, for other players |
| RescueSelfRetrySeconds | 6 | new | CatService, for the player who just failed |
| RescueAttemptMaxSeconds | 15 | new | CatService |
| RescuedTipsMultiplier | 1.0 | 1.10 | CatStats |
| LureWaitSeconds | 600 | 45 | CafeService |
| BaitBowlRangeStuds | 12 | new | CafeService |
| BumpEnabled | true | new | CatService |
| BumpRangeStuds | 6 | new | CatService |
| BumpChance | 0.5 | new | CatService |
| BumpGraceSeconds | 3 | new | CatService |
| BumpSafeRadiusStuds | 15 | new | CatService |
| BumpCooldownSeconds | 12 | new | CatService |
| BumpSameTargetSeconds | 60 | new | CatService |
| DropOwnerPrioritySeconds | 8 | new | CatService, only the old carrier can catch a dropped stray |
| DroppedMinStaySeconds | 120 | new | CatService, a dropped stray skips a wave that starts sooner than this after the drop |
| CustomerSpawnSecondsNight | 12 | new | client customers |
| RichCheckSeconds | 60 | new | CafeService |
| RichChance | 0.15 | new | CafeService |
| RichTipSeconds | 45 | new | CafeService |
| RichTipStaySeconds | 90 | new | CafeService |
| DealerRangeStuds | 12 | new | DealerService |
| DealerWindowSeconds | 600 | new | DealerService, global stock window |
| CatNameMaxLength | 20 | new | CafeService |
| RenameCooldownSeconds | 5 | new | CafeService |
| AnnounceMinRarity | Epic (plus every shiny) | Epic | CatService |

Changed or new in v0.4:

| constant | value | was | used by |
|---|---|---|---|
| patience (Catalog rarity field) | 3, 2, 2, 1, 1 | fleesOnFail | CatService, UI paw row |
| StrayWarySeconds | 5 | new | CatService, the player who just missed |
| StrayJumpBackStuds | 6 to 10 | new | CatService |
| PerfectCharmBonus | 4 | new | CatService |
| PurrfectCharmMultiplier | 2 | new | CatService |
| AutoPressFlagRate | 0.95 | `Circles.AUTO_PRESS_RATE` | CatService |
| AutoPressClearRate | 0.85 | new | CatService |
| NormalWalkSpeed | 20 | 16 | CatService, PlotService |
| CarryWalkSpeed | 16 | 13 | CatService |
| TravelCooldownSeconds | 3 | new | Travel (F19) |
| alley spawnPoints | 24 | 14 | Catalog areas |

Changed or new in v0.5 (Gavin's round 2):

| constant | value | was | used by |
|---|---|---|---|
| fleeStuds (Catalog rarity field) | 12, 16, 20, 26, 32 | patience | CatService |
| StrayFleeSpeed | 26 | new | CatService |
| StrayRestSeconds | 1.5 | new | CatService |
| StraySelfRetrySeconds | 1 | new (v0.5.1, S44) | CatService |
| ShinyChanceNet, ShinyChanceBait | 0.05, 0.05 | 0.02, 0.02 | CatService, food cards |
| ShoveKnockbackStuds | 10 | new | CatService, target client |
| BumpCooldownSeconds | 8 | 12 | CatService (Shove) |
| BumpSameTargetSeconds | 20 | 60 | CatService (Shove) |
| ShoveTargetImmuneSeconds | 4 | new (v0.5.1, S45) | CatService (Shove) |
| DealerSlotWeights | 50 / 33 / 14 / 3, one row | per tier | DealerService |

Removed in v0.5: patience, StrayWarySeconds, StrayJumpBackStuds, CustomerSpawnSecondsNight.

CircleScorePerfect and CircleScoreGood no longer decide anything in v0.4; keep them only if a test or analytics wants a number.

Removed: GrabHoldSeconds, GrabMinHoldSeconds, NetBonus, LureBonus, RingBonusPerfect, RingBonusGood, RingPerfectWindow, RingGoodWindow, RingLatencyGraceSeconds, CatchChanceMin, CatchChanceMax, LureDespawnSeconds, LureReserveSeconds, RescueHoldSeconds, RescueLockSeconds (the attempt holds the lock), RenovateBonus. GrabLockSeconds becomes "schedule length plus 1 s".

Unchanged and still used: ServerPlayers 8, StartCoins 50, FavoriteMultiplier 1.5, TableBonus 0.10, EspressoBonus 0.15, OfflineRate 0.25, OfflineCapSeconds 3600, AutosaveSeconds 60, ServerStartDaySeconds 120, GrabRangeStuds 10, GrabRetrySeconds 2, GrabCooldownSeconds 2, CheckInRangeStuds 8, the cat stats constants, the customer constants, RemoteRateLimitPerSecond 10, MaxIdLength 40, TutorialGuaranteedStrayStep 2. World layout numbers stay the engineer's in `Config.World`, now with three more area centers and gates.
