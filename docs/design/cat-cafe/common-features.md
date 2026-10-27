# Genre-Standard Features for Cat Cafe

Draft v0.1, 2026-10-25; v0.3 updates 2026-10-26 after Gavin's answers (rows 1, 3, 4, 8, 9, 10, 16, 21, 26 and 28). Owner: game-designer thread. Derek asked for the common Roblox features found in games like Steal an Egg and Roll a Fisherman (Spin for a Fisherman) to be added to the design. This doc maps each one onto the cat cafe, gives it a phase, a size and any policy flag, and says which ones change the slice (almost none). Numbers go into [data-model.md](data-model.md) when a feature is scheduled; the loop itself stays as written in [gdd.md](gdd.md).

Phases: Slice is Phase 2 (vertical slice, now), Alpha is Phase 3 (friends alpha), Launch is Phase 4 (soft launch), Later is Phase 5.

## 1. What the reference games actually have

Checked 2026-10-25 against guides, not by playing. Steal an Egg: eggs spawn on a timer in themed stages gated by a Speed stat, you place an egg in your pen and it grows into a pet that earns money, night makes eggs grow 30x faster, rare eggs are announced across servers, a Pet Index gives rewards for completing a zone's set, a Fuse Machine takes three of the same pet and improves luck for rarer hatches, mutations multiply value (Silver 1.25x, Golden 2x, Rainbow 2.5x, Bloom 1.5x, Spirit Bloom 3x), limited-time eggs have their own index, bonus speed is offered for liking the game and joining the group, admin-run events hand out mutations, and there are no codes. Roll a Fisherman: you roll for anglers, collect the fish they produce, sell for cash, upgrade staff, expand the dock, and redeem codes for cash, gold and spins. Wider genre staples seen in the same family of games (Fish an Anime RNG, pet simulators): rebirth for a permanent multiplier, luck stat and luck potions, playtime chests, daily login streaks, index gems, offline earnings upgrades, weather events that change odds, auto-collect and VIP passes, codes released at milestones.

## 2. Summary

| # | Feature in the reference games | Cat Cafe version | Phase | Size | Policy |
|---|---|---|---|---|---|
| 1 | Night cycle with a growth bonus | In the slice as the clock: 5 minute day, 5 minute night, waves of ten strays, night income at 60% and the night food dealer (v0.3) | Slice (F20, F23, F31, F32) | S | none |
| 2 | Admin events, weather | Cat Parade: server event every 20 to 30 minutes, rare odds tripled for 2 minutes; Rain later | Alpha | S | none |
| 3 | Mutations with multipliers | Gold version of every cat, 1.5x and a sparkle; 5% from net and bait, 10% from rescue. Replaces Silver, Golden and Galaxy (Gavin, Q16) | Slice (F30) | S | none |
| 4 | Pet Index completion rewards | Collection set rewards per area and per rarity, the all-50 reward and a gold page; distinct cats also gate tiers | Slice for the per-area milestones (F48, 2026-10-27); Alpha for rarity sets and the all-50 reward | S | none |
| 5 | Speed stat to reach eggs first | Sneakers upgrade: +2 walk speed per level, 3 levels; matters more now that waves are a race | Alpha | S | none |
| 6 | Playtime chests | Tip Jar: twelve steps from 2 to 120 minutes of a session (data-model 11b) | Slice (F47, 2026-10-27) | S | none |
| 7 | Friend bonus | +10% tips while a friend is on the server | Alpha | S | none |
| 8 | Equipped pet that follows you | Shoulder Cat: one owned cat follows you and widens your net's Good window a little | Alpha | M | none |
| 9 | Fuse Machine | Dropped: Gavin wants no merging of duplicates (Q16); gold cats replace it | | | |
| 10 | Rebirth | Tiers 1 to 5 with prerequisites (coins, different cats, a rarity), no reset: slots, areas, income multiplier, decor. Replaces Renovate (Gavin, Q18) | Slice (F24) | M | none |
| 11 | Daily login streak | Daily Treat: a seven-stamp card, one stamp per day, no reset on a missed day; v0.10 prizes in data-model 11e (bigger days 2 and 4, day 7 a Golden Classic Crate, a Star Treat, fish and spins) | Launch | S | no pressure: nothing is lost by skipping a day |
| 12 | Codes | The Codes Cat in the street plaza (F65, data-model 11d), which replaced the Chalkboard: walk into its circle and type a code | Launch | S | none |
| 13 | Like and group rewards | Regulars Board: +5% tips for group members (verifiable); likes milestone handled as an announced gift | Launch | S | none |
| 14 | Luck potions | Catnip: 15 minute buff that shifts wave spawn odds in the areas one tier up (never bait or dealer rolls), numeric effect on the shop card before purchase and modified odds shown while active | Launch | S | luck boosts must disclose their numeric effect before purchase and while active |
| 15 | Daily quests | Quests (F73, [quests.md](quests.md), Derek 2026-10-27): four dailies, three weeklies and 13 lifetime achievements; the full daily and weekly sets pay timed boosts. Replaces Customer Requests | Launch | L | no pressure: nothing is lost at a reset, no streaks, never sold |
| 16 | Rotating shop, conveyor | The night food dealer (in the slice, F32) is the rotating shop for food. Adoption Van stays at launch: three visible cats for coins every 10 minutes | Slice, Launch | M | none (stock seen before paying) |
| 17 | Passes and VIP | Long Nap, Second Cat Room, VIP Decor Set, Cat Accessories; 2x Tips deferred | Launch | S each | per monetization.md |
| 18 | Private servers | Free private servers | Launch | S | none |
| 19 | Update board | What's New board in the street and a toast on join after an update | Launch | S | none |
| 20 | Global rare spawn announcements across servers | Cross-server Legendary alerts with MessagingService | Later | M | none |
| 21 | Weather | Rain: bait wait shortened, more stuck cats; Puddle is now a Sewer Common | Later | S | none |
| 22 | Egg growth timers | Kittens: caught cats earn 50% for 10 minutes, then grow; night grows faster | Later | S | none |
| 23 | Size variants | Small, normal, big with 0.9x, 1x, 1.2x | Later | S | none |
| 24 | Daily spin wheel | Free daily spin for coins, food and Catnip with odds shown; never for Robux | Later | S | paid random items if coins are ever sold |
| 25 | Cosmetics, trails, outfits | Barista outfits and cat accessories | Later | S | none |
| 26 | Fast travel buttons | Home plus one button per area, locked areas greyed, disabled while carrying | Slice P2 | S | none |
| 27 | Server hop | Join another server button | Later | S | none |
| 28 | Stealing, base locks | Carry bumps on the way home only, with protections; nothing is taken from cafes (Gavin, Q9) | Slice (F29) | M | griefing protections in data-model 10c |
| 29 | Trading | Decided no for now | Later | | |

v0.3 pulls items 1, 3, 10, 16 (the dealer) and 28 into the slice and drops item 9. Item 26 stays a P2 convenience. Everything else lands after the loop is proven, in the order above.

## 3. Alpha additions (Phase 3), in detail

1. Closing Time moved into the slice on 2026-10-26: the clock, lighting and night waves are F20 and F23, night income and the dealer are F31 and F32. Mythical cats (Midnight in the Alleyway) are in the normal odds from the slice on, so nothing night-only is left for the alpha. Nothing is taken away at night and players are never teleported.
2. Cat Parade. Every 20 to 30 minutes the server announces a parade: for 2 minutes Rare, Epic and Legendary odds are tripled and the spawn cap rises to 10. A banner shows the countdown. This is the Admin Abuse style spike without an admin.
3. Gold (moved into the slice in v0.3 as F30, replacing Silver, Golden and Galaxy). Every cat has a gold version at 1.5x with a sparkle; numbers in data-model section 4. The Index shows gold cats on their own page, so the 50 count stays honest.
4. Collection set rewards. Complete an area's ten: a decor piece themed on that area. All Commons: +5% tips permanent and a welcome mat decor (no collars, Derek 2026-10-27). All Rares: a ribbon banner decor and 2,000 coins. All Epics: +10% tips. All Legendaries: a golden tip jar on the counter. All 50: a gold Ninja Cat. Shown in the Index with progress bars.
5. Sneakers. Upgrade with three levels at 300, 1,500 and 6,000 coins, +2 walk speed each. Carry speed stays 80% of the new value. This is the Speed stat without gating areas behind it.
6. Tip Jar. A jar on the HUD fills over the session; tap it at 5, 10, 15, 20 and 30 minutes for 100, 250, 500, 1,000 and 2,500 coins plus one food at 15 and 30. Resets each session. Standard playtime reward.
7. Friend bonus. +10% tips while at least one Roblox friend is on the server, shown as a HUD chip. Cheap and it pushes the group to play together.
8. Shoulder Cat. Equip one owned cat from the cat room to follow you (Humanoid-free model that lerps behind the player). Bonus to catch chance: Common +2%, Rare +4%, Epic +6%, Legendary +10%. The cat still has to be unplaced, so it is a choice between income and luck.

## 4. Launch additions (Phase 4), in detail

9. Nap Pod. Dropped in v0.3: Gavin wants no merging of duplicates. Duplicates sell for coins.
10. Tiers (in the slice in v0.3 as F24, replacing Renovate). Five tiers ranked up with coins, a count of different cats and from Tier 3 a rarity; nothing resets. Numbers in data-model section 5b.
11. Daily Treat. A seven-stamp card, one stamp per calendar day you play. v0.10 (round 4 Q9): the prizes are in data-model section 11e (F70): coins on days 1, 3 and 5, 2 Salmon with fish and a spin on day 2, a Caviar with a Classic Crate and a spin on day 4, Tuna and a Lucky Potion on day 6 and on day 7 a Golden Classic Crate, a Star Treat, 50 golden fish and 3 spins. (Draft v0.1 had 100 coins, Kibble, 250 coins, Tuna, 500 coins, Catnip, Salmon plus 1,000 coins.) A missed day loses nothing; the card simply waits for the next stamp, and a full card starts a fresh one. This replaces the usual streak reset, which is a named parent complaint about Adopt Me and sits against the project's no-pressure rule.
12. Chalkboard (replaced by the Codes Cat, F65, data-model 11d, Derek 2026-10-27; the first codes are `playtest`, `launch` and later `group`). A chalkboard by the counter where codes are entered. Rewards are coins, food and Catnip only, never cats. Growth owns the codes list and release cadence.
13. Regulars Board. Join the Roblox group for +5% tips, checked on the server with GroupService. Likes cannot be verified in-game, so a likes milestone is handled as an update gift announced on the What's New board.
14. Catnip. Consumable buff, 15 minutes: each spawn's rarity roll is shifted one tier up with 25% probability. The shop card states that number before purchase and the HUD shows the modified odds while active, which is what the paid random items rules require of any luck boost (disclosure before buying and while running), so it is safe even if coins are later sold.
15. Quests (F73, Derek 2026-10-27 21:59, replaces Customer Requests): four daily quests, three weekly quests and 13 lifetime achievements, with timed boosts for finishing every daily or every weekly; the spec is [quests.md](quests.md). The old plan: Customer Requests, three tasks per day from the customers: catch 3 Commons, earn 2,000 tips, use one lure, place a cat on its favorite spot, catch a Rare in the park. Rewards are coins and food. A fourth task comes from the Daily Treat streak at day 7.
16. Adoption Van. Every 10 minutes a van parks on the street for 3 minutes with three cats for sale at coin prices by rarity (Common 200, Rare 1,000, Epic 5,000, Legendary 25,000). The stock is visible, so buying is never random. Gives a sink and a second path to a Legendary.
17. Passes. v0.10 (round 4 Q14 and Q15): a monetization agent will research what to sell, and paid items may help a player, not only change looks, as long as everything sold can also be earned in the game (docs/decisions.md). Until then, per the growth thread's monetization.md: Long Nap (offline cap 2 hours), Second Cat Room, VIP Decor Set, Cat Accessories. 2x Tips stays deferred until two weeks of soft launch data. No cash product at soft launch, so lure food stays exempt.
18. Private servers, free.
19. What's New board and a one-time toast on join after each update.

## 5. Later (Phase 5), in one line each

20. Cross-server Legendary alerts (MessagingService) once there are enough servers for it to matter. 21. Rain weather with a shorter bait wait and more stuck cats. 22. Kittens: a growth timer on caught cats, test in alpha first because it delays the reward. 23. Size variants (small, normal, big). 24. A free daily spin, only if coins are never sold for Robux. 25. Barista outfits and cat accessories beyond the pass. 27. Server hop.

## 6. What changes in the existing docs

- gdd.md gets a Genre-standard features section that points here. The slice scope is unchanged except fast travel at P2.
- data-model.md gains tables for each feature when it is scheduled, starting with variants and Closing Time before the alpha.
- features.md gets F19 (fast travel, P2) now and the alpha list as F20 to F27 when Phase 3 planning starts.
- Palette swatches for variants already exist in the style guide (fur_golden, galaxy_blue, sparkle, night_sky for Closing Time).

## Sources

- Steal an Egg systems: https://allthings.how/steal-an-egg-every-hidden-secret-worth-knowing-roblox/
- Steal an Egg mutations and multipliers: https://allthings.how/steal-an-egg-all-mutations-and-multipliers/
- Steal an Egg stages, growth and fusing: https://roonby.com/2026/08/19/steal-an-egg-guide-how-to-get-the-rarest-eggs-and-build-the-best-pets/
- Roll a Fisherman loop and codes: https://www.pockettactics.com/roll-a-fisherman-codes
- Genre staples (rebirth, luck, index, playtime rewards): https://allthings.how/fish-an-anime-rng-full-guide-cash-and-food-farming-in-roblox/
- Market and policy context: docs/growth/comps.md and docs/growth/monetization.md
