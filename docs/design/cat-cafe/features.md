# Cat Cafe Vertical Slice: Feature List and Thread Handoffs

Draft v0.3, 2026-10-26 (v0.1 on 2026-10-25). Owner: game-designer thread. Readers: engineer (Build cat cafe rough draft), asset-artist (Create cat cafe 3D models), ui-designer (Design cat cafe UI), QA (Plan cat cafe playtests), reviewer, growth. Design reasoning is in [gdd.md](gdd.md), every number in [data-model.md](data-model.md), the UI API in [ui-contract.md](ui-contract.md), Gavin's answers in [feedback/gavin-2026-10-26.md](feedback/gavin-2026-10-26.md).

Priorities: P0 must exist for the ten-minute loop test, P1 should ship in the slice, P2 can slip. Sizes S, M, L. The slice is done when the QA loop script in section 8 passes with no blocker tickets, data saves, and the check gate is green.

## 1. What v0.3 changes and the build order

v0.2 (F01 to F21) is built on main. v0.3 replaces parts of it with Gavin's mechanics. Build in this order, one feature per branch, so there is something playable after each step:

1. F22 Data v3: rarities with Mythical, the 20-cat catalog plus reserved ids, roles, tiers, profile v3 and its migration. Everything else reads these tables.
2. F26 Net circles. The riskiest feel and the most fun; prototype it early on touch.
3. F23 Clock 5 and 5, waves of ten, five areas with gates (three as grayboxes).
4. F24 Tiers and rank up, then F25 roles with upright uniforms and Equip Best over ten slots.
5. F28 Bait bowl at the cafe.
6. F27 Rescue minigames.
7. F30 Shiny.
8. F29 Carry bumps.
9. F31 Night income and rich customers.
10. F32 Night food dealer.
11. F33 Naming cats.
12. Update F13 tutorial beats, F16 analytics and F17 leaderboards for v0.3.

| v0.2 feature | v0.3 status |
|---|---|
| F01 street, plots, areas | Kept; areas grow to five in F23 |
| F02 spots and placement | Replaced by F25 roles |
| F03 cat room | Kept; role picker and rename added (F25, F33) |
| F04 income | Kept; tier and phase multipliers in F24 and F31 |
| F05 night waves | Kept; sizes and areas in F23 |
| F06 net hold-and-release | Replaced by F26 circles |
| F07 carry and check-in | Kept; bumps added in F29 |
| F08 shop | Kept minus cafe level; tier caps in F24 |
| F09 lure spots | Replaced by F28 bait bowl |
| F10 profile | Migrates to v3 in F22 |
| F11 park access | Replaced by tier gates in F23 and F24 |
| F12 offline earnings | Kept (day rate) |
| F13 tutorial | Updated beats (section 8) |
| F14 announcements | Kept; adds shinies and rank ups |
| F15 cosmetic customers | Kept; night owls at half rate in F31 |
| F16 analytics | New events (data-model 16) |
| F17 leaderboards | "Grand Cafe" tag at Tier 5 replaces "Cafe Owner" |
| F18 cat stats, Equip Best | Kept; shiny multiplier, ten slots, favoriteRole |
| F18 visiting, F19 fast travel | Kept; fast travel gets five area buttons, locked areas greyed |
| F20 clock | Lengths change in F23 |
| F21 rescue hold | Replaced by F27 minigames |

## 2. v0.3 features

| id | feature | P | size | owner | depends on | done when |
|---|---|---|---|---|---|---|
| F22 | Data v3: `Mythical` rarity with circles, shrinkSeconds, rescueHits; catalog sections 3a and 3b (20 cats) with `area` and `favoriteRole`, 3c ids reserved; `TierDef` table; role `SpotDef`s with `tier`; upgrades without cafe_level and park_access; shop and dealer `LureDef`s with `source` and five-rarity odds; profile v3 and the 2 to 3 migration (data-model 14) | P0 | M | engineer | | A v2 save loads as v3 with tier 1, refunds applied, two cats working, no coins lost; specs cover the migration |
| F23 | Clock 300 and 300 s, `NightIndex`; waves of 10 per area; five areas with spawn points and trap anchors, Neighbourhood, Woods and Sewer as grayboxes; gates solid for locked players; server refuses catch, rescue and bump in locked areas | P0 | S | engineer, asset for gates | F22 | Ten strays per unlocked area at each night start; a Tier 1 player inside the Park gate cannot catch |
| F24 | Tiers: `RankUp` with cost, distinct cats and rarity checks; tier multiplier in income; tier caps on tables, espresso and net; decor `requiresTier`; area unlocks; cafe expansions as plot variants; rank up card data in ProfileSync | P0 | M | engineer, ui | F22, F23 | Rank to Tier 2 with 1,500 coins and 5 different cats; refused with 4; income rises 25%; the Park gate opens |
| F25 | Roles: Barista, Waiter, Greeter, Entertainer slots by tier; `favoriteRole` 1.5x; a working cat stands upright in its uniform at its station, the cat room shows it on all fours; Equip Best over up to 10 slots | P0 | M | engineer, asset for poses and uniforms, ui | F22, F24 | Assign a Tabby to Barista and it stands in an apron earning 1.5x; Equip Best matches a hand-computed best on ten slots |
| F26 | Net circles: `GrabBegin` builds the schedule from rarity and net level; `CatchSchedule`, `CatchPress`, `CatchResult`; latency-corrected judging; Common retry, rarer flee; per-circle telemetry | P0 | M | engineer, ui | F22 | All Perfect catches at 100%, all Good at 50%; a forged early or late press scores 0; a Mythical with a Basic Net shows uneven circle speeds |
| F27 | Rescue minigames: traps by area (Alleyway trash_bin and garbage_bag, Park tree and trashcan); `bar` and `shake_catch` kinds; `RescueBegin`, `RescuePress`, `RescueCancel`, `RescueChallenge`, `RescueResult`; paws, retry, the cat never lost; 10% shiny hidden until freed | P1 | M | engineer, ui, asset for traps | F22, F23 | Free a Common from a bin in two hits; three misses end the attempt and the cat is still there; a tree rescue ends with one catch circle |
| F28 | Bait bowl: `lure_bowl` at the plot's BaitBowl anchor; `UseLure(lureId)` rolls and saves the cat; 600 s timer runs offline; `BaitReady`, bait card with Tame and Let go; `ResolveBait`; odds and per-cat split on food cards | P1 | S | engineer, ui | F22 | Put Kibble in, log off for 10 minutes, rejoin and see the same cat waiting; Tame adds it, Let go clears it, the food is gone either way |
| F29 | Carry bumps: carrier attributes; Bump prompt for non-carriers; `Bump` checks (range, grace, safe zone, cooldowns, immunity); 50% knock loose; dropped stray with protect time; immunity for the next carrier; `BumpEnabled` switch | P1 | M | engineer, ui | F07, F26 | Bump a carrier in the Alleyway: half the time the cat drops, only the old carrier can catch it for 8 s, the bumper never can, and a failed catch on it never makes it flee; no bump works near the carrier's door or in the first 3 s; the re-catcher cannot be bumped |
| F30 | Shiny: roll per method, `Shiny` attribute and sparkle on strays, reveal on rescue and bait, 1.5x rating, shiny page in the book, announce every shiny | P1 | S | engineer, ui, asset for sparkle VFX | F22, F26 | A forced shiny (Debug) earns 1.5x and appears on the shiny page |
| F31 | Night income 0.6x settled across phase boundaries; night-owl customers at half rate; rich customers by day with `ClaimRichTip` and auto-collect on expiry | P1 | S | engineer, ui, asset for the rich customer | F04, F23 | Rate drops to 60% at nightfall and recovers at dawn; a rich tip pays 45 s of the day rate whether claimed or not |
| F32 | Night food dealer: cart and NPC on the street at night; per-player three-slot stock seeded by UserId and night; `DealerStock`, `BuyDealerFood`; dealer foods usable in the bowl | P1 | M | engineer, ui, asset for the cart and NPC | F23, F28 | The same stock after a rejoin or a server change within one dealer window; a bought slot cannot be bought again in that window; a Tier 5 player sees Star Treat far more often than Tier 1 over many windows (Debug) |
| F33 | Naming cats: `RenameCat` with TextService filtering, DisplayName over working cats, rename in the cat room | P2 | S | engineer, ui | F25 | A name shows over the cat for other players; a filter failure keeps the old name with a toast |

## 3. Placeholder rules for the rough draft

As in v0.2: every placeholder uses the final name and attributes so swapping is a file replace, not a code change.

- Cats: `CatCafe_Cat_<Name>` with `Body`, `Head`, `Tail`, PrimaryPart `Body`, facing -Z. Working cats use the upright pose the asset thread already delivered (PR #24) plus a colored Part for the uniform (apron, bow tie, sash, hat) until uniforms exist.
- Shiny: a `ParticleEmitter` named `ShinySparkle` on `Body` with palette sparkle.
- Traps: colored Parts named `CatCafe_Alley_TrashBin`, `CatCafe_Alley_GarbageBags`, `CatCafe_Park_RescueTree`, `CatCafe_Park_TrashCan` with a `CatAnchor` attachment.
- Areas 3 to 5: flat ground in a distinct palette color, walls, a gate Part named `CatCafe_<Area>_Gate`, spawn points and trap anchors.
- Dealer: an R15 rig with a dark hooded shirt and a Part cart named `CatCafe_Street_DealerCart`.
- Bait bowl: `CatCafe_Item_FoodBowl` at the plot's `BaitBowl` anchor.
- Rich customer: a customer rig with a black top hat Part.

## 4. Interface contracts between threads

- Ids and names: data-model section 1. Model names: `CatCafe_<Category>_<Name>`.
- World attributes and tags: data-model section 13.
- Catalog: data-model sections 2, 3, 5, 5b, 6, 7, 8 and 8b. New or changed UI types: `CatDef.favoriteRole` and single `area`; `SpotDef.tier`; `TierDef`; `LureDef.source` and five-rarity `odds`; `Rarity` gains `Mythical` and drops `Secret`.
- Remotes: data-model section 15. Reviewer checks each row.
- Asset delivery: one Model per asset in `assets/cat-cafe/rbx/`, cats facing -Z (LookVector), pivot at the base, per the style guide.

## 5. Asset list for the asset thread (v0.3 additions)

v0.2 assets stay. New, in the order the engineer needs them:

| priority | asset | name | notes |
|---|---|---|---|
| 1 | Role uniforms on the upright rig | `CatCafe_Accessory_Apron`, `CatCafe_Accessory_BowTie`, `CatCafe_Accessory_Sash`, `CatCafe_Accessory_PartyHat` | Attach to the upright cat; one set fits all 50 cats |
| 2 | Eight new slice cats | Maine Coon, Midnight, Cream, Brownie, Blue, Persian, Blossom, Aurora | Data-model 3a and 3b art notes; Midnight and Aurora are the Mythical hero assets |
| 3 | Shiny sparkle VFX | `CatCafe_VFX_ShinySparkle` | Readable on a phone at 30 studs |
| 4 | Alleyway traps | `CatCafe_Alley_TrashBin`, `CatCafe_Alley_GarbageBags` | Stuck pose per trap (head and paws poking out) |
| 5 | Park traps | `CatCafe_Park_RescueTree` (with a shakeable branch), `CatCafe_Park_TrashCan` | Branch is its own part so it can wobble |
| 6 | Role stations | `CatCafe_Furniture_GreeterPodium`, `CatCafe_Furniture_StageCatTree` | Barista uses the counter, Waiter stands between tables |
| 7 | Bait bowl by the door | reuse `CatCafe_Item_FoodBowl`, plus food models for the four dealer foods `CatCafe_Item_Sardines`, `_Caviar`, `_MoonMilk`, `_StarTreat` | Food sits in the bowl while waiting |
| 8 | Night dealer | `CatCafe_NPC_Dealer`, `CatCafe_Street_DealerCart` | Mysterious but friendly: hood, lantern, star-patterned cart |
| 9 | Rich customer | `CatCafe_NPC_Customer_Rich`, `CatCafe_Prop_TipPile` | Top hat; the tip pile is gold coins |
| 10 | Area gates and grayboxes | `CatCafe_Park_Gate` (exists), `CatCafe_Neighbourhood_Gate`, `CatCafe_Woods_Gate`, `CatCafe_Sewer_Gate` | Sets for areas 3 to 5 come after the slice |
| 11 | Cafe expansions | `CatCafe_Plot_Expansion1` to `4` | Floor and wall extensions, the patio at 3 |

Rescued cats no longer need the v0.2 tree, box and drainpipe props; the tree comes back as the Park rescue tree.

## 6. UI screens for the UI thread (v0.3 additions)

| screen or element | shows | actions | P |
|---|---|---|---|
| Catch circles | 1 to 5 circles closing on rings at server positions, Perfect and Good bands sized from `windows`, a grade per circle, the final chance and result | press (tap anywhere or a key) | P0 |
| Rank up card | current tier, next tier's name, each requirement ticked or not (coins, different cats, rarity), what it opens | Rank up | P0 |
| Cat room roles | each cat's favorite role icon; Assign picks a free slot by role; working cats show their role | Assign, Remove, Equip Best, Sell, Rename | P0 |
| Rescue minigame | bar with sliding marker and zone, paw lives, hit count; tree variant shakes then one catch circle | press, cancel | P1 |
| Bait bowl | empty, waiting (countdown) or ready; ready card with the cat, rarity, stars, sparkle | put food in (food picker with odds), Tame, Let go | P1 |
| Food cards | odds for five rarities and the per-cat split for the player's unlocked areas, shop or dealer source | buy | P1 |
| Dealer screen | three slots with food, price, odds, bought state, a moon timer to dawn | buy | P1 |
| Bump prompt | "Bump" on a carrier's cat for non-carriers; toasts "You knocked it loose!", "It held on tight!", "You got bumped!" | press | P1 |
| Rich tip | world marker over the tip pile, toast on collect or auto-collect | collect | P1 |
| Clock chip | sun or moon, countdown, "Tips 60%" at night | none | P0 |
| Shiny | sparkle badge on cards and in the book, a shiny page with its own count | none | P1 |
| Rename dialog | text box, 20 character limit, filtered result | save, cancel | P2 |
| Fast travel | five area buttons, locked ones greyed with the tier they need | travel | P2 |

## 7. Reviewer focus

In order: `CatchPress` judging (server clock, latency cap, order, first press only, schedule ownership, the CircleGapMin spec), `Bump` (every protection in data-model 10c, the bumper barred from the dropped stray, the owner window, no flee on a dropped stray, server tables over attributes, the off switch), `RankUp` requirement checks, `UseLure` rolling at placement and `ResolveBait` (no reroll by rejoin), dealer stock seeding and once-per-night buys, `RenameCat` filtering and failure path, `ClaimRichTip` and the expiry auto-credit (no double pay), the v2 to v3 migration and refunds, locked-area checks on every catch remote, then the v0.2 list (ownership on place and sell, affordability, session locking, rate limits).

## 8. QA loop script (Phase 2 exit test, v0.3)

Fresh account, phone-sized viewport, 10 minute limit.

1. Join. Plot assigned, Tabby working as Barista in an apron, HUD shows $50 and a positive rate within 5 s.
2. Follow the arrow to the Alleyway. A Common stray is there even by day. Start a catch: one slow circle. Hit it; Good or Perfect is fine, a miss allows a retry.
3. Walk home at carry speed, check in. Cat found popup, book shows 2 / 50.
4. Assign the new cat as Waiter. It stands up in a bow tie. Rate rises.
5. Buy Table 1 at $100, then the bait bowl at $400 when affordable, and put Kibble in. The countdown shows 10:00.
6. First night by minute two: ten strays and at least one stuck cat (guaranteed per area). Rescue it with the bar.
7. Free play until minute 10. Expected: three or four different cats, two roles filled, two tables, a bait cat on the way, the rank up card showing what Tier 2 still needs.
8. Leave for 10 minutes, rejoin. Offline popup shows about 25% of the day rate times 600 s, and the bait cat is waiting at the bowl. Tame it.
9. Pass criteria: steps 1 to 7 under 10 minutes, no console errors, no blocker tickets from the reviewer.

Extra checks for v0.3: two-player bump test (protections, the 8 s owner window, the bumper barred and the 50% roll over 20 tries), all-Perfect and all-Good catches give 100% and 50%, dealer stock identical after a rejoin or a server change in the same window, a rescue attempt that stops pressing ends at its deadline, Tier 2 reached in 10 to 20 minutes of normal play, the circle feel on a phone on mobile data. The reviewer's findings S23 to S31 and N28 to N30 (docs/reviews/2026-10-26-design-v0.3.md) belong in the test plan of the feature PR that builds them.

## 9. Post-slice backlog

Scheduled by phase in [common-features.md](common-features.md). Unscheduled: content for Neighbourhood, Woods and Sewer (30 cats, traps, sets), role boosts for specific cats (Gavin, Q12), a dealer upgrade that improves his odds, a second bait bowl, patio and second floor content, cat toys, staff outfits, the daily special customer (Gavin, Q13: content ideas to expand the game), free decor placement, the customer demand model, seasonal cats, trading, game passes and a cash product gated by PolicyService, friends list features.
