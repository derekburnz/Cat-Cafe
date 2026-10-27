# Cat Cafe Vertical Slice: Feature List and Thread Handoffs

Draft v0.5, 2026-10-27 (v0.1 on 2026-10-25; v0.4 adds section 2b from Derek's rough draft playtest, with the reasoning in [world-and-feel.md](world-and-feel.md); v0.5 adds section 2c from Gavin's round 2 answers). Owner: game-designer thread. Readers: engineer (Build cat cafe rough draft), asset-artist (Create cat cafe 3D models), ui-designer (Design cat cafe UI), QA (Plan cat cafe playtests), reviewer, growth. Design reasoning is in [gdd.md](gdd.md), every number in [data-model.md](data-model.md), the UI API in [ui-contract.md](ui-contract.md), Gavin's answers in [feedback/](feedback/) (round 1 2026-10-26, round 2 2026-10-27).

Priorities: P0 must exist for the ten-minute loop test, P1 should ship in the slice, P2 can slip. Sizes S, M, L. The slice is done when the QA loop script in section 8 passes with no blocker tickets, data saves, and the check gate is green.

## 1. What v0.3 changes and the build order

v0.2 (F01 to F21) is built on main. v0.3 replaces parts of it with Gavin's mechanics. Build in this order, one feature per branch, so there is something playable after each step:

1. F22 Data v3: rarities with Mythical, the 20-cat catalog plus reserved ids, roles, tiers, profile v3 and its migration. Everything else reads these tables.
2. F26 Net circles. The riskiest feel and the most fun; prototype it early on touch.
3. F23 Clock 5 and 5, waves of ten, five areas with gates (three as grayboxes).
4. F24 Tiers and rank up, then F25 roles with upright uniforms and Equip Best over ten slots.
5. F28 Bait bowl at the cafe.
6. F27 Rescue minigames.
7. F30 Gold.
8. F29 Carry bumps (v0.5: Shove, F41).
9. F31 Night income and rich customers.
10. F32 Night food dealer.
11. F33 Naming cats.
12. Update F13 tutorial beats, F16 analytics and F17 leaderboards for v0.3.

v0.4 (Derek, 2026-10-26 23:03, after playing the rough draft) jumps the queue: F34 catching stakes, F35 the back alley layout and F19 fast travel are P0 and go next, then F36 to F39 alongside the remaining v0.3 rows. Section 2b has the rows.

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
| F14 announcements | Kept; adds gold cats and rank ups |
| F15 cosmetic customers | Kept by day; v0.5 closes the cafe at night with no customers (F44) |
| F16 analytics | New events (data-model 16) |
| F17 leaderboards | "Grand Cafe" tag at Tier 5 replaces "Cafe Owner" |
| F18 cat stats, Equip Best | Kept; gold multiplier, ten slots, favoriteRole |
| F18 visiting, F19 fast travel | Kept; fast travel is P0 in v0.4: Cafe, Alley and Areas buttons top centre, greyed while carrying |
| F20 clock | Lengths change in F23 |
| F21 rescue hold | Replaced by F27 minigames |

## 2. v0.3 features

| id | feature | P | size | owner | depends on | done when |
|---|---|---|---|---|---|---|
| F22 | Data v3: `Mythical` rarity with circles, shrinkSeconds, rescueHits; catalog sections 3a and 3b (20 cats) with `area` and `favoriteRole`, 3c ids reserved; `TierDef` table; role `SpotDef`s with `tier`; upgrades without cafe_level and park_access; shop and dealer `LureDef`s with `source` and five-rarity odds; profile v3 and the 2 to 3 migration (data-model 14) | P0 | M | engineer | | A v2 save loads as v3 with tier 1, refunds applied, two cats working, no coins lost; specs cover the migration |
| F23 | Clock 300 and 300 s; waves of 10 per area; five areas with spawn points and trap anchors, Neighbourhood, Woods and Sewer as grayboxes; gates solid for locked players; server refuses catch, rescue and bump in locked areas | P0 | S | engineer, asset for gates | F22 | Ten strays per unlocked area at each night start; a Tier 1 player inside the Park gate cannot catch |
| F24 | Tiers: `RankUp` with cost, distinct cats and rarity checks; tier multiplier in income; tier caps on tables, espresso and net; decor `requiresTier`; area unlocks; cafe expansions as plot variants; rank up card data in ProfileSync | P0 | M | engineer, ui | F22, F23 | Rank to Tier 2 with 1,500 coins and 5 different cats; refused with 4; income rises 25%; the Park gate opens |
| F25 | Roles: Barista, Waiter, Greeter, Entertainer slots by tier; `favoriteRole` 1.5x; a working cat stands upright in its uniform at its station, the cat room shows it on all fours; Equip Best over up to 10 slots | P0 | M | engineer, asset for poses and uniforms, ui | F22, F24 | Assign a Tabby to Barista and it stands in an apron earning 1.5x; Equip Best matches a hand-computed best on ten slots |
| F26 | Net circles: `GrabBegin` builds the schedule from rarity and net level; `CatchSchedule`, `CatchPress`, `CatchResult`; latency-corrected judging; per-circle telemetry. v0.4: the retry and flee rules and the scoring move to F34 | P0 | M | engineer, ui | F22 | A forged early or late press is a Miss; a Mythical with a Basic Net shows uneven circle speeds |
| F27 | Rescue minigames: traps by area (Alleyway trash_bin and garbage_bag, Park tree and trashcan); `bar` and `shake_catch` kinds; `RescueBegin`, `RescuePress`, `RescueCancel`, `RescueChallenge`, `RescueResult`; paws, retry, the cat never lost; 10% gold hidden until freed | P1 | M | engineer, ui, asset for traps | F22, F23 | Free a Common from a bin in two hits; three misses end the attempt and the cat is still there; a tree rescue ends with one catch circle |
| F28 | Bait bowl: `lure_bowl` at the plot's BaitBowl anchor; `UseLure(lureId)` rolls and saves the cat; 600 s timer runs offline; `BaitReady`, bait card with Tame and Let go; `ResolveBait`; odds and per-cat split on food cards | P1 | S | engineer, ui | F22 | Put Kibble in, log off for 10 minutes, rejoin and see the same cat waiting; Tame adds it, Let go clears it, the food is gone either way |
| F29 | Carry bumps: carrier attributes; Bump prompt for non-carriers; `Bump` checks (range, grace, safe zone, cooldowns, immunity); 50% knock loose; dropped stray with the 8 s owner window, the bumper barred, unlimited paws for the old carrier (v0.4) and a 120 s minimum stay; immunity for the next carrier; `BumpEnabled` switch | P1 | M | engineer, ui | F07, F26 | Bump a carrier in the Alleyway: half the time the cat drops, only the old carrier can catch it for 8 s, the bumper never can and the old carrier never runs out of paws on it; no bump works near the carrier's door or in the first 3 s; the re-catcher cannot be bumped |
| F30 | Gold: roll per method, `Gold` attribute and sparkle on strays, reveal on rescue and bait, 1.5x rating, gold page in the book, announce every gold | P1 | S | engineer, ui, asset for sparkle VFX | F22, F26 | A forced gold (Debug) earns 1.5x and appears on the gold page |
| F31 | Night income 0.6x settled across phase boundaries; night-owl customers at half rate; rich customers by day with `ClaimRichTip` and auto-collect on expiry | P1 | S | engineer, ui, asset for the rich customer | F04, F23 | Rate drops to 60% at nightfall and recovers at dawn; a rich tip pays 45 s of the day rate whether claimed or not |
| F32 | Night food dealer: cart and NPC on the street at night; per-player three-slot stock seeded by UserId and the global 600 s window; `DealerStock`, `BuyDealerFood`; dealer foods usable in the bowl | P1 | M | engineer, ui, asset for the cart and NPC | F23, F28 | The same stock after a rejoin or a server change within one dealer window; a bought slot cannot be bought again in that window; a Tier 5 player sees Star Treat far more often than Tier 1 over many windows (Debug) |
| F33 | Naming cats: `RenameCat` with TextService filtering, DisplayName over working cats, rename in the cat room | P2 | S | engineer, ui | F25 | A name shows over the cat for other players; a filter failure keeps the old name with a toast |

## 2b. v0.4 features (Derek's playtest, 2026-10-26)

| id | feature | P | size | owner | depends | done when |
|---|---|---|---|---|---|---|
| F34 | (v0.5: the paws in this row are replaced by F40's chase) Catching stakes: the first Miss ends the attempt with no roll and cancels the rest; all Good or Perfect is a sure catch; `patience` per rarity replaces `fleesOnFail`; paws per player per stray in a server table; jump back 6 to 10 studs; StrayWarySeconds for the player who missed; at 0 paws GrabBegin refuses that player and their prompt hides; unlimited paws for the dropOwner and the tutorial Common; Perfect charm bonus, doubled for Purrfect, none while `flags.autoPress` or on a Dropped stray (S36); the flag clears at 85%; new `CatchSchedule` and `CatchResult` payloads (data-model 10, 15) | P0 | M | engineer, ui, vfx, sound | F26 | A Miss on circle 1 of a Rare ends it at once and shows 1 paw left; a second Miss hides the prompt for that player but not for a second player; 20 mixed Good and Perfect attempts all catch; an all-Perfect Common arrives with 8 more charm |
| F35 | World layout v2: two back alleys behind the cafe rows meeting in the Alley Square, at least 8 times the old alley; back doors open from Tier 1, check-in at either door; 24 alley spawn points with `Zone` lane or square, Epic and rarer on square points only; traps one bin per back alley and the bags in the Square; gates moved (world-and-feel.md section 2); NormalWalkSpeed 20 and CarryWalkSpeed 16; tutorial stray behind the player's own cafe | P0 | M | engineer, asset for dressing | F23 | From any back door a stray spawn is under 2 s away on foot; the Square and every unlocked gate are one travel tap away; a carry from the farthest Square spawn to the farthest cafe's nearer door is under 25 s; a Tier 1 player walks out of the back door into the Alleyway |
| F19 | Fast travel: `Travel(destination)`; Cafe, Alley and Areas buttons top centre (Grow a Garden style); the Areas panel shows five area cards, locked ones greyed with their tier; greyed while carrying; refused during a catch or rescue (N47); lands at the destination's entry; 3 s cooldown | P0 | S | engineer, ui | F35 | Travel works from anywhere when not carrying and is refused by the server while carrying or into a locked area |
| F36 | Cafe shell v2: roof with overhang and chimney, arched windows, recessed door, awning, trim, back door; glass street front; roof fades on the owner's screen while inside; facade pastel by plot number; interior per the sketch; front garden strip; name sign with the owner's headshot, tier and rate; tier dressing sets 1 to 5 swapped on rank up with a confetti puff | P1 | L | asset, engineer, vfx | F24, F35 | From the street you see cats working inside; the sign shows name, tier and rate; ranking up adds the next tier's pieces |
| F37 | Cafe life: customers queue, sit, show order bubbles and leave hearts; coin pops for the owner; station idles for the four roles; "+$X/s" tags in rarity color within 40 studs; up to four jobless cats roam and nap (highest rating first); ambient VFX and sound; culling beyond 80 studs and roaming paused with nobody within 60 | P1 | M | engineer, vfx, sound, ui | F25, F36 | Eight running cafes hold 30 fps or more on a phone-sized viewport in the street |
| F38 | For Rent plots: an empty plot uses the cafe shell with shutters half down, dust sheets, a For Rent sign, boxes and broom, a sleeping doorstep cat (not catchable) and the lamp on at night; joining reverses it (shutters up, sign to OPEN, lights on, the Tabby walks in); invite prompt on the sign at P2 | P1 | S | asset, engineer, vfx | F36 | With one player on the server the other seven plots are For Rent shops, never grey boxes |
| F39 | UI patterns pass (world-and-feel.md section 6): P0 travel buttons, catch HUD misses (v0.5: no paw row), gate signs with progress, money with rate; P1 next goal tracker, new cat reveal, left side menu with red dots, rate tags, area title cards, dealer restock list, server shout-outs, tutorial trail, collection book silhouettes; FredokaOne with UIStroke, green 3D buttons, world labels within 30 studs | P0 and P1 | M | ui, engineer for gate data | F34, F19 | A first-time player finds travel, the next goal and the catch result without being told |

## 2c. v0.5 features (Gavin's round 2, 2026-10-27)

Gavin's answers are in [feedback/gavin-2026-10-27.md](feedback/gavin-2026-10-27.md). These rows change rows already built or in progress; build them in this order.

| id | feature | P | size | owner | depends | done when |
|---|---|---|---|---|---|---|
| F40 | Chase after a miss (replaces F34's paws): a Miss still ends the catch with no roll; the stray sprints `fleeStuds[rarity]` (12 to 32) away from the player at StrayFleeSpeed 26 inside its area, rests StrayRestSeconds 1.5, then anyone can try again while the player who missed waits StraySelfRetrySeconds 1 (S44); the end point is clamped to the roam rects and the run stops at the first prop (N84); a Dropped stray stays put while its owner window runs (N86); tries unlimited; `FleeingUntil` attribute; GrabBegin refuses "It's running!" until it stops; `CatchSchedule` and `CatchResult` lose `pawsLeft`; remove patience, the paw table, StrayWarySeconds and the paw row | P0 | S | engineer, ui, vfx, sound | F34 | A missed Rare sprints about 16 studs, nobody can grab it while it runs, then the same player can try again as often as they like; in a deliberate-miss loop a second player gets the next try within 1 s of the stop |
| F41 | Shove (replaces F29's Bump prompt): any player can shove another while both are inside a catching area the shover has unlocked; ShoveKnockbackStuds 10 applied on the target's client; never on a player holding a catch or rescue lock; back door safe radius kept; cooldown 8 s, same target 20 s, then nobody can shove that target for ShoveTargetImmuneSeconds 4 (S45); no shove from a player holding a catch or rescue lock and the key is never E or Space (N85); shoving a carrier keeps the 50% knock-loose with every 10c protection; a Shove button and key inside areas only; the remote and constants may keep `Bump` names | P1 | M | engineer, ui, sound, vfx | F29 | Two players in the Alleyway can shove each other; nobody can shove on the street, in a cafe or mid-catch; a shoved carrier drops the cat about half the time; three players shoving one target land one shove per 4 s |
| F42 | Gold coats: every cat gets a gold model (Derek, 2026-10-27, round 3 Q4 option B; was frost), and players see "Gold", never "Shiny" (Derek, 13:18); GoldChanceNet and GoldChanceBait 0.05; food cards show 5% | P1 | M | asset, engineer, ui | F30 | A forced gold stray shows its gold coat and sparkle; food cards read 5% |
| F43 | Shared dealer stock: seed `hash(dealerWindow)` only, one DealerSlotWeights row (50 / 33 / 14 / 3); per-player bought marks unchanged | P1 | S | engineer, ui | F32 | Two players on different servers in the same window see the same three foods; each can buy each slot once |
| F44 | Night and the bowl: the cafe closes at night (no customers, Closed sign with a moon, working cats nap at their stations, 60% income unchanged, night owls removed); the `BaitBowl` anchor moves outside to the back step facing the Alleyway | P1 | S | engineer, asset, vfx | F31, F28 | At nightfall customers leave and the cats curl up at their stations; the bowl sits on the back step |
| F45 | Derek's 2026-10-27 12:07 round: hold E for CatchHoldSeconds 0.5 on the Catch and Rescue prompts; circles pressed with Space; a Drop button on the carry banner and the G key fire `DropCat()` (data-model 10c, 15); SAFE ZONE stripes at the edges of the catching areas; the "opens at Tier" labels over locked slots are gone and Upgrades gets a Roles section | P1 | S | engineer, ui | F41 | A tap of E near a stray does nothing and a half-second hold starts the circles; Drop in the Alleyway leaves the cat at your feet and only you can catch it for 8 s; Drop on the street sends it back to the Alleyway |
| F46 | Themed cats (Derek, 2026-10-27 13:22): every Rare and up in the Alleyway and the Park becomes a "<Theme> Cat" with one signature prop (data-model 3a and 3b: Pirate, Rocker, DJ, Bandit, Ninja, Wizard, Nerd, Explorer, Sleepy, Fancy, Fairy, Astro); ids stay; new names, favorite roles and descriptions in the catalog; each prop is a `CatCafe_Accessory_<Prop>` with a `PropSlot` of Head, Face or Back on the cat model; a working cat leaves off the role piece in that slot; no neck props | P1 | M | asset, engineer, ui | F42 | A Nerd Cat stray wears its glasses; working as a barista it wears the apron and cap; a DJ Cat working as a greeter wears its headphones and sash but no boater; a gold Wizard Cat keeps its hat |
| F47 | Tip Jar playtime gifts (data-model 11b): twelve steps from 2 to 120 minutes of a session, coins scaled to the day rate or foods; `ClaimTipJar(step)` and `TipJarState`; claimed steps in server memory, reset each session; a HUD jar with a fill ring and a row of steps with Claim buttons | P1 | S | engineer, ui | F22 | At 2 minutes step 1 pays max(50, 30 s of day rate) once; step 3 at 9 minutes is refused; after a rejoin the jar starts again at step 1 |
| F48 | Book rewards (data-model 11b): per area at 3, 6 and 10 cats and all 10 as gold cats; `ClaimBookReward(areaId, milestoneId)`; profile `bookRewards`; Book decor rows in section 7; a reward strip under each area tab in the Book with a Claim button | P1 | S | engineer, ui, asset (Book decor) | F22, F30 | A save with 3 Alleyway cats claims 300 coins once and a second claim is refused; a Park milestone with 2 Park cats is refused; all 10 Alleyway cats give a Salmon and the Alley Mural Print, placed |

## 3. Placeholder rules for the rough draft

As in v0.2: every placeholder uses the final name and attributes so swapping is a file replace, not a code change.

- Cats: `CatCafe_Cat_<Name>` with `Body`, `Head`, `Tail`, PrimaryPart `Body`, facing -Z. Working cats use the upright pose the asset thread already delivered (PR #24) plus a colored Part for the uniform (apron, bow tie, sash, hat) until uniforms exist.
- Gold: a sparkle on `Body` while the cat's `Gold` attribute is true (the vfx-animator's Effects/Cats; sprite `CatCafe_VFX_ShinySparkle`).
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
| 3 | Gold sparkle VFX | `CatCafe_VFX_ShinySparkle` | Readable on a phone at 30 studs |
| 4 | Alleyway traps | `CatCafe_Alley_TrashBin`, `CatCafe_Alley_GarbageBags` | Stuck pose per trap (head and paws poking out) |
| 5 | Park traps | `CatCafe_Park_RescueTree` (with a shakeable branch), `CatCafe_Park_TrashCan` | Branch is its own part so it can wobble |
| 6 | Role stations | `CatCafe_Furniture_GreeterPodium`, `CatCafe_Furniture_StageCatTree` | Barista uses the counter, Waiter stands between tables |
| 7 | Bait bowl by the door | reuse `CatCafe_Item_FoodBowl`, plus food models for the four dealer foods `CatCafe_Item_Sardines`, `_Caviar`, `_MoonMilk`, `_StarTreat` | Food sits in the bowl while waiting |
| 8 | Night dealer | `CatCafe_NPC_Dealer`, `CatCafe_Street_DealerCart` | Mysterious but friendly: hood, lantern, star-patterned cart |
| 9 | Rich customer | `CatCafe_NPC_Customer_Rich`, `CatCafe_Prop_TipPile` | Top hat; the tip pile is gold coins |
| 10 | Area gates and grayboxes | `CatCafe_Park_Gate` (exists), `CatCafe_Neighbourhood_Gate`, `CatCafe_Woods_Gate`, `CatCafe_Sewer_Gate` | Sets for areas 3 to 5 come after the slice |
| 11 | Cafe expansions | `CatCafe_Plot_Expansion1` to `4` | Floor and wall extensions, the patio at 3; v0.4: the expansions become the backyard patio between the cafe and the back alley |

v0.4 additions (world-and-feel.md sections 2 to 5), in build order: 1) the cafe shell v2 (pitched or rounded roof with chimney, arched windows, recessed door, awning, trim, back door, glass street front, interior per the sketch) with a facade color per plot; 2) the For Rent dressing (shutters, dust sheets, sign, boxes, broom, sleeping doorstep cat pose); 3) tier dressing sets 1 to 5 (chalkboard, flower boxes, bistro tables, neon OPEN sign, string lights, fish tank, gold trim, rooftop sign, red carpet); 4) back alley and Alley Square dressing (dumpster corner, hop-on crates, fire escape with a ledge, laundry line, puddles, string lights, a mural of our cats, bench and lamp); 5) gates as arches with a see-through barrier and a sign board; 6) a manhole for the Sewer. Names are the asset thread's, following `CatCafe_<Category>_<Name>`.

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
| Shove (v0.5, was Bump prompt) | a Shove button and key shown only inside catching areas, aimed at the nearest player within 6 studs; toasts "You knocked it loose!", "It held on tight!", "You got shoved!" | press | P1 |
| Rich tip | world marker over the tip pile, toast on collect or auto-collect | collect | P1 |
| Clock chip | sun or moon, countdown, "Tips 60%" at night | none | P0 |
| Gold | sparkle badge on cards and in the book, a gold page with its own count | none | P1 |
| Rename dialog | text box, 20 character limit, filtered result | save, cancel | P2 |
| Fast travel | v0.4: Cafe, Alley and Areas buttons top centre; Areas opens five area cards, locked ones greyed with the tier they need; all greyed while carrying | travel | P0 |
| Catch misses (v0.4, v0.5) | PERFECT, GOOD and MISS pops at the ring, a Miss ends the overlay with a small shake and the cat sprints off with "It got away! Chase it!", the Purrfect burst and "Charm +N"; no percentage and, from v0.5, no paw row | press | P0 |
| v0.4 patterns | the rest of world-and-feel.md section 6: gate signs, goal tracker, reveal card, side menu with red dots, rate tags, area title cards, dealer restock list, shout-outs, tutorial trail, book silhouettes | | P0 and P1 |

## 7. Reviewer focus

In order: `CatchPress` judging (server clock, latency cap, order, first press only, schedule ownership, the CircleGapMin spec, the self-retry wait after a miss), `Bump` (every protection in data-model 10c, the bumper barred from the dropped stray, the owner window, no sprint for a dropped stray while that window runs, ShoveTargetImmuneSeconds per target, no shove from a lock holder, server tables over attributes, the off switch), `RankUp` requirement checks, `UseLure` rolling at placement and `ResolveBait` (no reroll by rejoin), dealer stock seeding and once-per-window buys, `RenameCat` filtering and failure path, `ClaimRichTip` and the expiry auto-credit (no double pay), the v2 to v3 migration and refunds, locked-area checks on every catch remote, then the v0.2 list (ownership on place and sell, affordability, session locking, rate limits).

## 8. QA loop script (Phase 2 exit test, v0.3)

Fresh account, phone-sized viewport, 10 minute limit.

1. Join. Plot assigned, Tabby working as Barista in an apron, HUD shows $50 and a positive rate within 5 s.
2. Walk out of the back door into the Alleyway. A Common stray is waiting right behind your cafe even by day. Start a catch: one slow circle. Good or Perfect catches it; a Miss costs one of its three paws and you try again after 5 s.
3. Walk home at carry speed, check in. Cat found popup, book shows 2 / 50.
4. Assign the new cat as Waiter. It stands up in a bow tie. Rate rises.
5. Buy Table 1 at $100, then the bait bowl at $400 when affordable, and put Kibble in. The countdown shows 10:00.
6. First night by minute two: ten strays and at least one stuck cat (guaranteed per area). Rescue it with the bar.
7. Free play until minute 10. Expected: three or four different cats, two roles filled, two tables, a bait cat on the way, the rank up card showing what Tier 2 still needs.
8. Leave for 10 minutes, rejoin. Offline popup shows about 25% of the day rate times 600 s, and the bait cat is waiting at the bowl. Tame it.
9. Pass criteria: steps 1 to 7 under 10 minutes, no console errors, no blocker tickets from the reviewer.

Extra checks for v0.3: two-player shove test (shoves only inside areas, none mid-catch, the 8 s owner window, the shover barred and the 50% roll over 20 tries on a carrier), any mix of Good and Perfect always catches and a Miss always ends the attempt (v0.4), a missed cat sprints and can be retried without limit (v0.5), travel greyed while carrying, For Rent plots on a near-empty server, dealer stock identical after a rejoin or a server change in the same window, a rescue attempt that stops pressing ends at its deadline, Tier 2 reached in 10 to 20 minutes of normal play, the circle feel on a phone on mobile data. The reviewer's findings S23 to S31 and N28 to N30 (docs/reviews/2026-10-26-design-v0.3.md) belong in the test plan of the feature PR that builds them.

## 9. Post-slice backlog

Scheduled by phase in [common-features.md](common-features.md). Unscheduled: content for Neighbourhood, Woods and Sewer (30 cats, traps, sets), role boosts for specific cats (Gavin, Q12), a dealer upgrade that improves his odds, a second bait bowl, patio and second floor content, cat toys, staff outfits, the daily special customer (Gavin, Q13: content ideas to expand the game), free decor placement, the customer demand model, seasonal cats, trading, game passes and a cash product gated by PolicyService, friends list features.
