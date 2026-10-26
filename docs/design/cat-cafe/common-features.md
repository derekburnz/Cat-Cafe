# Genre-Standard Features for Purr Pot

Draft v0.1, 2026-10-25. Owner: game-designer thread. Derek asked for the common Roblox features found in games like Steal an Egg and Roll a Fisherman (Spin for a Fisherman) to be added to the design. This doc maps each one onto the cat cafe, gives it a phase, a size and any policy flag, and says which ones change the slice (almost none). Numbers go into [data-model.md](data-model.md) when a feature is scheduled; the loop itself stays as written in [gdd.md](gdd.md).

Phases: Slice is Phase 2 (vertical slice, now), Alpha is Phase 3 (friends alpha), Launch is Phase 4 (soft launch), Later is Phase 5.

## 1. What the reference games actually have

Checked 2026-10-25 against guides, not by playing. Steal an Egg: eggs spawn on a timer in themed stages gated by a Speed stat, you place an egg in your pen and it grows into a pet that earns money, night makes eggs grow 30x faster, rare eggs are announced across servers, a Pet Index gives rewards for completing a zone's set, a Fuse Machine takes three of the same pet and improves luck for rarer hatches, mutations multiply value (Silver 1.25x, Golden 2x, Rainbow 2.5x, Bloom 1.5x, Spirit Bloom 3x), limited-time eggs have their own index, bonus speed is offered for liking the game and joining the group, admin-run events hand out mutations, and there are no codes. Roll a Fisherman: you roll for anglers, collect the fish they produce, sell for cash, upgrade staff, expand the dock, and redeem codes for cash, gold and spins. Wider genre staples seen in the same family of games (Fish an Anime RNG, pet simulators): rebirth for a permanent multiplier, luck stat and luck potions, playtime chests, daily login streaks, index gems, offline earnings upgrades, weather events that change odds, auto-collect and VIP passes, codes released at milestones.

## 2. Summary

| # | Feature in the reference games | Purr Pot version | Phase | Size | Policy |
|---|---|---|---|---|---|
| 1 | Night cycle with a growth bonus | Now in the slice as the clock (gdd.md): 3 minute day, 2 minute night, strays spawn in night waves. Alpha adds Secret cats at night | Slice (F20) | S | none |
| 2 | Admin events, weather | Cat Parade: server event every 20 to 30 minutes, rare odds tripled for 2 minutes; Rain later | Alpha | S | none |
| 3 | Mutations with multipliers | Variants rolled at spawn: Silver 1.25x, Golden 2x, Galaxy 5x | Alpha | S | none |
| 4 | Pet Index completion rewards | Collection set rewards per rarity, plus the all-40 reward | Alpha | S | none |
| 5 | Speed stat to reach eggs first | Sneakers upgrade: +2 walk speed per level, 3 levels; matters more now that waves are a race | Alpha | S | none |
| 6 | Playtime chests | Tip Jar: a reward at 5, 10, 15, 20 and 30 minutes of a session | Alpha | S | none |
| 7 | Friend bonus | +10% tips while a friend is on the server | Alpha | S | none |
| 8 | Equipped pet that follows you | Shoulder Cat: one owned cat follows you and boosts catch chance | Alpha | M | none |
| 9 | Fuse Machine | Nap Pod: three of the same cat become one cat of the next variant tier, no randomness | Launch | M | none |
| 10 | Rebirth | Renovate: reset coins, upgrades and decor at cafe 5 for a permanent +25% tips and a new look | Launch | M | none |
| 11 | Daily login streak | Daily Treat: a seven-stamp card of coins, food and Catnip, one stamp per day, no reset on a missed day | Launch | S | no pressure: nothing is lost by skipping a day |
| 12 | Codes | Chalkboard: redeem codes for coins and food | Launch | S | none |
| 13 | Like and group rewards | Regulars Board: +5% tips for group members (verifiable); likes milestone handled as an announced gift | Launch | S | none |
| 14 | Luck potions | Catnip: 15 minute buff that shifts spawn odds one tier up, numeric effect on the shop card before purchase and modified odds shown while active | Launch | S | luck boosts must disclose their numeric effect before purchase and while active |
| 15 | Daily quests | Customer Requests: three daily tasks for coins and food | Launch | M | none |
| 16 | Rotating shop, conveyor | Adoption Van: parks on the street every 10 minutes with three visible cats for coins | Launch | M | none (you see the cat before paying) |
| 17 | Passes and VIP | Long Nap, Second Cat Room, VIP Decor Set, Cat Accessories; 2x Tips deferred | Launch | S each | per monetization.md |
| 18 | Private servers | Free private servers | Launch | S | none |
| 19 | Update board | What's New board in the street and a toast on join after an update | Launch | S | none |
| 20 | Global rare spawn announcements across servers | Cross-server Legendary alerts with MessagingService | Later | M | none |
| 21 | Weather | Rain: Puddle Secret cat, lure wait halved | Later | S | none |
| 22 | Egg growth timers | Kittens: caught cats earn 50% for 10 minutes, then grow; night grows faster | Later | S | none |
| 23 | Size variants | Chonk: small, normal, big with 0.9x, 1x, 1.2x | Later | S | none |
| 24 | Daily spin wheel | Free daily spin for coins, food and Catnip with odds shown; never for Robux | Later | S | paid random items if coins are ever sold |
| 25 | Cosmetics, trails, outfits | Barista outfits and cat accessories | Later | S | none |
| 26 | Fast travel buttons | Home, Alley and Park buttons, disabled while carrying | Slice P2 | S | none |
| 27 | Server hop | Join another server button | Later | S | none |
| 28 | Stealing, base locks | Decided no for now (decisions.md); carry raids are the fallback | Later | | |
| 29 | Trading | Decided no for now | Later | | |

Only item 26 touches the slice, as a P2 convenience. Everything else lands after the loop is proven, in the order above.

## 3. Alpha additions (Phase 3), in detail

1. Closing Time moved into the slice on 2026-10-26 after Gavin's update: the clock, lighting and night waves are feature F20. What stays for the alpha is Secret cats (Midnight in the alley) joining the night odds at 1%. Nothing is taken away at night and players are never teleported.
2. Cat Parade. Every 20 to 30 minutes the server announces a parade: for 2 minutes Rare, Epic and Legendary odds are tripled and the spawn cap rises to 10. A banner shows the countdown. This is the Admin Abuse style spike without an admin.
3. Variants. At spawn roll Silver 5%, Golden 1%, Galaxy 0.1% (Galaxy only at night or from the Nap Pod). A variant multiplies the cat's rate and recolors it with the palette swatches already reserved (fur_golden, galaxy_blue, sparkle). The collection book shows the variant as a badge, not a separate entry, so the 40 count stays honest.
4. Collection set rewards. Complete all Commons: +5% tips permanent and a collar accessory. All Rares: a bow accessory and 2,000 coins. All Epics: +10% tips. All Legendaries: a golden tip jar on the counter. All 40 at launch: a Galaxy Void. Shown in the book with progress bars.
5. Sneakers. Upgrade with three levels at 300, 1,500 and 6,000 coins, +2 walk speed each. Carry speed stays 80% of the new value. This is the Speed stat without gating areas behind it.
6. Tip Jar. A jar on the HUD fills over the session; tap it at 5, 10, 15, 20 and 30 minutes for 100, 250, 500, 1,000 and 2,500 coins plus one food at 15 and 30. Resets each session. Standard playtime reward.
7. Friend bonus. +10% tips while at least one Roblox friend is on the server, shown as a HUD chip. Cheap and it pushes the group to play together.
8. Shoulder Cat. Equip one owned cat from the cat room to follow you (Humanoid-free model that lerps behind the player). Bonus to catch chance: Common +2%, Rare +4%, Epic +6%, Legendary +10%. The cat still has to be unplaced, so it is a choice between income and luck.

## 4. Launch additions (Phase 4), in detail

9. Nap Pod. A machine in the cafe at cafe 4. Put in three cats of the same catId and the same variant, get one of the next variant tier (base to Silver to Golden to Galaxy). Deterministic, so there are no odds to display and no paid random item question. Gives duplicates a purpose beyond selling.
10. Renovate. At cafe 5 with 10,000 coins: coins, upgrades, decor and tables reset; cats, collection, variants, lures and passes stay. Each Renovate gives a permanent +25% tips, a new wall color and sign, and a star on the leaderboard. Maximum 10. The first ten minutes after a Renovate must feel fast, so the starting coins after a Renovate scale with the count.
11. Daily Treat. A seven-stamp card: 100 coins, Kibble, 250 coins, Tuna, 500 coins, Catnip, Salmon plus 1,000 coins, one stamp per calendar day you play. A missed day loses nothing; the card simply waits for the next stamp, and a full card starts a fresh one. This replaces the usual streak reset, which is a named parent complaint about Adopt Me and sits against the project's no-pressure rule.
12. Chalkboard. A chalkboard by the counter where codes are entered. Rewards are coins, food and Catnip only, never cats. Growth owns the codes list and release cadence.
13. Regulars Board. Join the Roblox group for +5% tips, checked on the server with GroupService. Likes cannot be verified in-game, so a likes milestone is handled as an update gift announced on the What's New board.
14. Catnip. Consumable buff, 15 minutes: each spawn's rarity roll is shifted one tier up with 25% probability. The shop card states that number before purchase and the HUD shows the modified odds while active, which is what the paid random items rules require of any luck boost (disclosure before buying and while running), so it is safe even if coins are later sold.
15. Customer Requests. Three tasks per day from the customers: catch 3 Commons, earn 2,000 tips, use one lure, place a cat on its favorite spot, catch a Rare in the park. Rewards are coins and food. A fourth task comes from the Daily Treat streak at day 7.
16. Adoption Van. Every 10 minutes a van parks on the street for 3 minutes with three cats for sale at coin prices by rarity (Common 200, Rare 1,000, Epic 5,000, Legendary 25,000). The stock is visible, so buying is never random. Gives a sink and a second path to a Legendary.
17. Passes. Per the growth thread's monetization.md: Long Nap (offline cap 2 hours), Second Cat Room, VIP Decor Set, Cat Accessories. 2x Tips stays deferred until two weeks of soft launch data. No cash product at soft launch, so lure food stays exempt.
18. Private servers, free.
19. What's New board and a one-time toast on join after each update.

## 5. Later (Phase 5), in one line each

20. Cross-server Legendary alerts (MessagingService) once there are enough servers for it to matter. 21. Rain weather with the Puddle Secret cat and halved lure wait. 22. Kittens: a growth timer on caught cats, test in alpha first because it delays the reward. 23. Chonk size variants. 24. A free daily spin, only if coins are never sold for Robux. 25. Barista outfits and cat accessories beyond the pass. 27. Server hop.

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
