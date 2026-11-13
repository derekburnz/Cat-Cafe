# Achievements: easier targets, more steps, a prize of its own kind per line (#3694)

Status 2026-11-13: sections 1 to 4 and the Devoted fault built by Design-Agent (names of the new steps in 2a, the new ones in 3a, prize notes in 4a), except `a_pet25`, which waits for the pet a cat server build; the chat titles built too (section 5). Asked by Derek at 20:39 UTC: "lower the difficuilty of these achievements add some more and make the rewards slightly more unique/diff". Build: Gameplay-Engineer. Test: Review-QA-Agent. The issue holds the checklist.

## Rules for the change

- **Nothing earned is lost.** No achievement id is removed or renamed. A claimed achievement stays claimed and is never paid twice.
- A lowered target changes only `needs`. A player already past the new target sees it ready to claim at once.
- New achievements get new ids. Where their counter already exists in the save it counts from the player's real total; a new counter starts at 0 on the day it ships.
- The page shows the ones ready to claim first, then the ones closest to done, then the rest. Claimed ones go to the bottom.
- **Fault to fix:** Devoted shows seconds (97,153 of 360,000). Play time must read in hours: "27 of 50 hours".

## 1. Lower targets (same ids)

| Achievement | Was | Now |
|---|---|---|
| Cat Wrangler `a_catch1k` | catch 1,000 | catch 500 |
| Cat Legend `a_catch10k` | catch 10,000 | catch 2,500 |
| Steady Hands `a_perfect5k` | 5,000 perfect circles | 2,000 |
| Rescue Hero `a_rescue250` | 250 rescues | 100 |
| `a_bait200` (keeps its current name) | 200 bait cats | 100 |
| Gold Rush `a_gold50` | 50 gold cats | 25 |
| `a_tips2k` | 2,000 tip piles | 1,000 |
| Quest Keeper `a_quests100` | 100 daily quests | 60 |
| Week Champion `a_week10` | 10 full weeks | 5 |
| Devoted `a_hours100` | 100 hours | 50 hours |

The texts change with the numbers ("Catch 500 cats"). Sizes stay.

## 2. New steps in between (so one is always close)

| New id | Text | Size |
|---|---|---|
| `a_catch25` | Catch 25 cats | S |
| `a_catch250` | Catch 250 cats | M |
| `a_catch1000` | Catch 1,000 cats | L |
| `a_rare25` | Catch 25 Rare or better cats | M |
| `a_gold10` | Catch 10 gold cats | L |
| `a_perfect100` | Land 100 perfect circles | M |
| `a_rescue25` | Rescue 25 stuck cats | M |
| `a_bait25` | Tame 25 cats at your bait bowl | M |
| `a_quests10` | Finish 10 daily quests | S |
| `a_quests30` | Finish 30 daily quests | M |
| `a_week3` | Finish every weekly quest in 3 weeks | L |
| `a_hours1` | Play for 1 hour | S |
| `a_hours5` | Play for 5 hours | M |
| `a_hours25` | Play for 25 hours | L |
| `a_level10` | Raise a cat to level 10 | M |

Catch line after the change: 1, 25, 100, 250, 500, 1,000, 2,500.

### 2a. Names of the new steps (as built)

Cat Spotter (`a_catch25`), Cat Herder (`a_catch250`), Cat Tamer (`a_catch1000`), Rare Seeker (`a_rare25`), Gold Seeker (`a_gold10`), Sure Paws (`a_perfect100`), Helping Hand (`a_rescue25`), Bowl Regular (`a_bait25`), Quest Starter (`a_quests10`), Quest Fan (`a_quests30`), Week Keeper (`a_week3`), Settling In (`a_hours1`), Happy Visitor (`a_hours5`), Cafe Fixture (`a_hours25`), Rising Star (`a_level10`). Every name on the page is different. Play time reads "16/50 hours", rounded down.

## 3. New achievements for the newer features

| New id | Text | Size | Counter |
|---|---|---|---|
| `a_bin10` | Win 10 rummages at the Rummage Bin | M | new |
| `a_bin50` | Win 50 rummages | L | new |
| `a_yard10` | Take 10 Yard Sale lucky picks | M | new (with `yardSaleRoll`) |
| `a_traits10` | Roll 10 traits at the Mystic Pool | M | new, or the existing roll count |
| `a_traits50` | Roll 50 traits | L | same |
| `a_dash10` | Play 10 games of Mouse Dash | M | new, or the existing play count |
| `a_secret1` | Find a Secret cat | L | from the Index (with `secretCats`) |
| `a_secret3` | Find all three Secret cats | XL | from the Index |
| `a_pet25` | Pet your cats 25 times | M | new (with `petCats`) |
| `a_rest1h` | Rest in your cafe for 1 hour in total | M | new (with `afkCafe`) |
| `a_goldcrate5` | Open 5 golden crates | L | new |

An achievement whose feature switch is off is hidden until the switch is on, and does not count in "x of y claimed" until then. With everything on the page holds 70 (44 now, 15 steps, 11 new).

### 3a. As built

| Id | Name | Counter (save `stats`, or measure) | Switch |
|---|---|---|---|
| `a_bin10`, `a_bin50` | Bin Diver, Treasure Hunter | `binWins` | `alleyBin` |
| `a_yard10` | Lucky Picker | `yardPicks` | `yardSaleRoll` |
| `a_traits10`, `a_traits50` | Pool Regular, Pool Wizard | `traitRolls` (every roll, a first or a re-roll) | `traits` |
| `a_dash10` | Mouse Chaser | `dashRuns` (every game played to its end or quit) | `mouseDash` |
| `a_secret1`, `a_secret3` | Secret Spotter, Secret Keeper | `secretCats` (Secret kinds in the collection) | `secretCats` |
| `a_rest1h` | Cozy Napper | `restSeconds` (added when a rest ends or the player leaves), shown in hours | `afkCafe` |
| `a_goldcrate5` | Golden Opener | `goldenCratesOpened` | none |

- The six counters are new `stats` fields with no save version bump, as #1934 did: an older server drops them, which only loses those counts. They start at 0 on the day they ship, except Secret cats, which reads the collection.
- `flag` on the achievement names the live switch. While it is off the server leaves the achievement out of the view, refuses its claim ("Not open yet") and Claim all skips it; the window shows a row with a `flag` only once its view arrives, and "x of y claimed" counts the rows shown. With every switch on the page holds 69.
- `a_pet25` is left out until the pet a cat server part (#3651, switch `petCats`) is built; it then needs a `pets` counter and the same `flag`.
- Prizes (section 4's table): Rummage Bin and Yard Sale pay an Alley Crate (M) and a Golden Alley Crate (L); Mouse Dash 2 spins; Secret cats the finding line; resting the play time line; golden crates by size. The Mystic Pool's 1 and 3 Trait Tokens are paid as the golden fish they cost (10 and 30, `Traits.COST_FISH` a roll), since a prize cannot carry tokens yet.

## 4. Rewards: each line pays its own kind of thing

Today the prize depends only on the size: S a spin, M a Money Potion, L a Classic Crate, XL a Golden Classic Crate and a Big Money Potion, each with money and pass XP. New rule: the money and the Cafe Pass XP by size stay exactly as they are, and the **item** comes from the achievement's line. `Types.AchievementDef` gains an optional `prize` that replaces the size's item; without it the size's item is used as today.

| Line | S | M | L | XL |
|---|---|---|---|---|
| Catching (`catch`, `rare`) | 2 Tuna | 1 Salmon and 1 Tuna | a crate of the player's best open area | golden crate of the best open area and 1 Caviar |
| Gold cats | | Lucky Potion | 2 Lucky Potions | Golden Classic Crate and a Gold Rush Potion |
| Perfect circles | Steady Paw Potion | 2 Steady Paw Potions | 3 Steady Paw Potions and 10 golden fish | Golden Classic Crate and 3 Steady Paw Potions |
| Rescues | Swift Potion | 2 Swift Potions | 3 Swift Potions and a Classic Crate | |
| Bait bowl | 2 Tuna | 2 Salmon | 1 Caviar and 1 Salmon | |
| Finding cats (`cats`, `goldcats`, `mythical`, `secret`) | spin | crate of the best open area | golden crate of the best open area | 2 golden crates of the best open area |
| Daily and weekly quests | 2 spins | 3 spins | 5 spins and 10 golden fish | Golden Classic Crate and 5 spins |
| Play time, resting | 5 golden fish | 10 golden fish | 25 golden fish and a Money Potion | 50 golden fish and a Big Money Potion |
| Tiers, coins, tips, upgrades | as today by size | | | |
| Cat levels, petting | | Money Potion | 2 Money Potions | Big Money Potion and a Golden Classic Crate |
| Rummage Bin, Yard Sale | | Alley Crate | Golden Alley Crate | |
| Mystic Pool traits | | 1 Trait Token | 3 Trait Tokens | |
| Mouse Dash | | 2 spins | | |
| Crates, decor, potions, trades, gifts, wheel | as today by size | | | |

- Value by size stays about where it is, so the page does not pay more in total per achievement; it pays more often because there are more of them and they are closer.
- At most two pictures on a prize, three on XL (the existing rule).
- Everything here is earned in play. Golden fish, spins, crates, Trait Tokens, Lucky and Gold Rush Potions are never sold for Robux, and nothing on this page can be bought.
- If a lure or potion named here does not exist under that name in `Catalog`, use the nearest one of the same worth and say so in the PR.

### 4a. As built

- The lines are keyed by the achievement's measure (`Catalog.achievementLines`), so a new step on a line gets its line's item without a field of its own. `Catalog.achievementPrize(def)` merges the size's coins, coinSeconds and pass XP with the line's item; the server pays it and the Quests cards show the same.
- Lines with no row for a size (rescues XL, bait XL, gold S, cat levels S) and every line not in the table pay the size's prize as before.
- Spins go to the spin bank, which stops at its cap as it does for every spin prize.
- Section 3's lines (Rummage Bin, Yard Sale, Mystic Pool, Mouse Dash) get their rows when their achievements are added; Trait Tokens will need a prize field of their own then.

**Titles (second step, own PR if the title system needs work):** the XL achievements also give a chat title with the achievement's name: Cat Legend, Steady Hands, Devoted, Week Champion, Gold Rush. A player who already claimed one gets the title on the next join.

## 5. Chat titles (as built)

The five big achievements the issue names give a chat title with the achievement's name: Cat Legend (`a_catch10k`), Steady Hands (`a_perfect5k`), Devoted (`a_hours100`), Week Champion (`a_week10`) and Gold Rush (`a_gold50`). They are chat tags (`ChatTags.ACHIEVEMENT_TITLES`, ids `title_*`), offered after the Grand Opener tag and before the leaderboard ranks, and listed in the Bag's Titles tab as "Achievement: <name>" while locked.

- Read from the save's claimed achievements every time, so nothing new is saved and a player who claimed one before has it on the next join.
- A claim shows it at once: the server refreshes the tag and the Titles tab after the claim. With no title picked, the first one the player has in the order shows, as for every tag.
- The other XL achievements (Every Cat, Grand Opening, Coin Mountain, Master Cat, Secret Keeper) give no title yet.
