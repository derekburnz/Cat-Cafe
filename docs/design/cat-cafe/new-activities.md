# New activities: Rummage Bin, Cat Arcade, Swift Paws, Mouse Dash, Lucky Charm, Pet a cat

Draft v1, 2026-11-11, Design-Agent (friend's project). One place for the final specs that were settled in issue comments on 2026-11-10. **The issues are the build tickets; where this file and an issue disagree, the latest issue comment wins and this file gets fixed.** Ideas 2 and 3 came from player its_cuzu098, and both ship with a credit on the newest What's new page (#3067) and an "Idea by its_cuzu098" line on their card.

Shared rules for all three:
- Nothing is sold for Robux: no Robux skip, refill, extra try, continue or streak saver, now or later (Monetization-Agent's conditions).
- No green toasts (#3080). Results show inside each feature's own screen.
- No new HUD element. Phone first: tap anywhere, big targets.
- Each has a live flag in `LiveFlags.KEYS`, on by default, so turning it off needs no restart.

## 1. Rummage Bin (#3050, Alleyway)

Its job is to keep new players past 5 minutes (35% still playing at 5 min on the Nov 10 baseline).

- **Place:** `CatCafe_Camp_Alley_RummageBin` (model in #3058, looks `_Ready` and `_Empty`).
  - Since #3458 (Derek 2026-11-12: "move the rummage bin off to the side out of entrance more") it stands at camp (26, -10), turned 83.4 to face the landing pad, 5.7 studs outside the opening's edge and clear of the bench's sight line. It was at (10.5, -8), within 15 studs of the pad.
  - When it is ready a "!" shows over it (the `ReadyBang` component), and goes when it is empty.
  - The prompt reads "Rummage" when ready and "Empty for now 🐾" otherwise. There is no countdown.
- **Play:** the rescue bar with a **5-hit** attempt (`BinHits`, #3458; 2 before) and 3 paws.
  - Its own absolute bar: `BinZoneWidth` 0.22 and `BinBarSpeed` 0.80 (#3458, Derek: "require 5 hits and medium bit faster and a lot smaller area"; 0.42 and 0.64 before). It never follows the rescue tables.
  - An account's first 3 rummages also get `BinFirstEase` (zone x1.6, speed x0.6, so 0.35 at 0.48) and need the 5 hits too.
  - A miss costs nothing and allows a retry after 10 s.
- **Timing:** server side, per player, in its own DataStore `CatCafe_Bin` keyed by user id (#3104). It is **not** a profile save field, so it needs no save version step or restart.
  - Ready on the first visit, then 180 s after each of the first 3 uses, then every 900 s.
  - Nothing banks.
- **Prizes, one per success:**

  | Prize | Chance |
  |---|---:|
  | 2 Tuna | 34% |
  | 8 golden fish | 25% |
  | Salmon | 15% |
  | Lucky Potion | 12% |
  | Alley Crate | 12% |
  | Golden Alley Crate | 2% |

  Since #3460 (Derek 2026-11-12: "make the rummage bin rewards a bit better so people get a good starting boost"; before: Tuna 40%, 5 fish 25%, Salmon 12%, potion 11%, crate 10%, golden 2%). An account's first three wins are fixed and sit outside the table: 2 Tuna and 10 golden fish, then an Alley Crate and a Lucky Potion, then a Salmon and 10 golden fish (`BinFirstPrizes`).
  - **Loot card (#3464, Derek 2026-11-12: "show the loot obtained from rummage also").** A win shows a card, "You found:", with one row per thing won (icon, name, amount). It stays 4 seconds or closes on a tap, and a golden crate gets the gold frame. The server sends the whole win as a list.

  - The odds show on the card.
- **Flag:** `alleyBin`.
- **Judge by:** `played_5m` and `played_10m` by platform, `bin_play` and `first_bin`. Also `quit_state` with the area and the idle seconds.

## 2. Cat Arcade: Circle Streak (#3062, Town Square cabinet and menu row)

- **Cabinet:** `CatCafe_Town_ArcadeCabinet` (Animation-Engineer). The prompt reads "Play (1 🐟)". The same game opens from an "Arcade" row in the menu.
- **Run:**
  - Costs 1 golden fish, via `GoldenFish.spend`.
  - Uses the catch circles at fixed net level 1 windows, graded on the server through the `CatchPress` path. The client never sends a score.
  - **Perfect scores +2 and Good +1.** The first Miss ends the run, and reaching 100 points wins (the score is clamped).
- **Harder every 5 points** (as built in #3359, Derek2 2026-11-11: "starting speed 2x, scaling up much faster, game is too easy, keep the milestones reachable"; before that it started at 1.20 s and stepped every 10 points, 10 steps):
  - the circles start at a 0.60 s shrink (`ArcadeStartShrinkSeconds`, twice as fast as before);
  - every 5 points (`ArcadeStepEvery`), for 20 steps (`Arcade.MAX_STEP`) so it keeps climbing to 100: shrink x0.96 and windows x0.97;
  - a circle never shrinks faster than 0.30 s (`ArcadeShrinkFloorSeconds`), wobble included;
  - the gap tends toward `CircleGapMin`;
  - jitter goes 0.10 → 0.20 by 100.
  - That gives a shrink of about 0.47 s at 30 points, 0.40 s at 50 and the 0.30 s floor near 100, with the Good half-width going 0.13, 0.11, 0.096 and 0.070 s. 10 to 30 stay reachable for a normal player, 50 is a real test and 80 to 100 are for the best players. The milestones and prizes don't change.
- **Milestones:** each pays once per UTC day, and crossing a milestone pays it.

  | Points | 10 | 20 | 30 | 40 | 50 | 60 | 70 | 80 | 90 | 100 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Prize | 5 🐟 | 8 🐟 | Salmon | Lucky Potion | 15 🐟 | Classic Golden Crate | Caviar | 30 🐟 | Moon Milk | Star Treat + "Arcade Legend" title (once) |

  - That's at most 58 golden fish a day.
  - A new record pays nothing; it only updates Best.
  - The card shows the milestone list with today's ticks, and "Resets daily at 00:00 UTC".
- **Leaderboard:** All time, This week (resets Monday 00:00 UTC) and Server, top 50 each.
  - Your own rank is pinned at the bottom.
  - Ties at 100 rank by fewest circles: store `points*1000 + (999 - circles)`.
  - Stored in OrderedDataStores, written only on a new best (at most once per 60 s), and read with a 60 s cache.
- **No bot check** (Derek2: "not worried about bots yet").
- **Flags:** `arcade`, `arcadeBoard`.
- **Effects:** VFX-Agent's `Effects/ArcadeFx.luau` (`hit`, `milestone`, `goldenFish`).
- **Judge by:** `arcade_run`, and the share of players with 1+ fish who try it (15% or more in week one). The median run should be about 15–25 points.

## 3. Swift Paws (#3063, Golden Fish Market perk)

- **Levels:** +1 walk speed for 60 fish, +2 for 150 fish. It's permanent and capped at 2 levels, so it doesn't undercut the Robux Swift Potion.
- **Applies to:** normal walk (20 → 22) and carry (16 → 18), through one `walkSpeed(profile, carrying)` helper.
  - Not the catch rush, startled strays or the getaway push.
  - It stacks with the Swift Potion (+4).
- **Flag:** `swiftPaws`.
- **Judge by:** level 1 buys among players with 60+ fish. Swift Potion sales shouldn't drop; if they do, use the flag.

## 4. Cat Arcade: Mouse Dash (#3296, second Arcade game; a player idea)

**2026-11-11 23:30 UTC: superseded by [mouse-dash.md](mouse-dash.md).** Derek unpaused it ("build mouse dash if making it high enough quality it honestly should replace the current game"). The v2 spec there has nine holes, three hearts, golden mice, napping kittens, 100 points and the arcade's shared milestones. The text below is the v1 draft, kept for history.

Derek2, 2026-11-11: "arcade game 1 free attempt daily".

- **Where:** a second game on the same Arcade cabinet and menu row, as a tab beside Circle Streak.
- **Cost:** **1 free run each UTC day**. Every later run costs 1 golden fish (`GoldenFish.spend`), the same as Circle Streak. The button reads "Play (free)" or "Play (1 🐟)".
- **Run:**
  - Six mouse holes in a 3 × 2 grid. A mouse pops out of one hole and stays up for a short window, and the player taps it.
  - A catch is +1 point. The run ends on the first escape (the window closes with no tap) or the first tap on an empty hole.
  - One thumb, with big targets, so it works on a phone.
- **Server authority:** the server draws the whole run (each hole and its window) and grades each tap against its own clock, the same way as the `CatchPress` path. The client sends only "tapped hole n". It never sends a score.
- **Harder every 5 points:**
  - the window shrinks x0.93, from 1.1 s down to a 0.35 s floor;
  - the gap between mice shrinks x0.95.
  - From 20 points on, a decoy cat can pop up instead of a mouse. Tapping the decoy ends the run.
- **Milestones:** each pays once per UTC day, the same rule as Circle Streak.

  | Points | 10 | 20 | 30 | 40 | 50 |
  |---|---|---|---|---|---|
  | Prize | 3 🐟 | 5 🐟 | Salmon | 8 🐟 | Lucky Potion + "Mouser" title (once) |

  - That's at most 16 golden fish a day. The free run alone can pay back the next paid run from the 10 milestone.
  - "Mouser" is a chat title: add it to `ChatTags.TAGS` and `ORDER`, with a `TitlesLogic.HOW` line ("Mouse Dash 50 points"), so it shows in the Bag's Titles tab (#3291).
- **Best and leaderboard:** the same boards as Circle Streak (All time, This week, Server), under their own key `MouseDash`. They're written only on a new best, at most once per 60 s. Like Circle Streak, a scripted tapper could top the board; there's no bot check for now (Derek2: "not worried about bots yet").
- **Flags:** `mouseDash` (its own, so it can ship after Circle Streak).
- **Effects:** VFX-Agent: a dust puff when the mouse ducks back in, and a squeak on a catch (Sound-Agent).
- **Judge by:** the share of daily players who use the free run (40% or more in week one). The median run should be 10 to 15 points.

## 5. Lucky Charm (#3298, Golden Fish Market perk; a player idea)

Derek2, 2026-11-11: "no market luck because thats all decided stock per global, make it like crate luck or spin luck or foodbowl or overall luck".

- **Which luck:** **overall Luck** (shared/Luck). That's the one number that already lifts the Epic, Legendary and Mythical chances of bait and crate rolls.
  - **Not spin luck.** The Spin Wheel's odds are printed on its Odds button, so changing them per player would make the shown odds wrong.
  - **Not bowl luck alone.** `BowlLuck` is already the Bait Bowl upgrade's row.
- **Levels:**

  | Level | Luck | Cost |
  |---|---|---|
  | 1 | +0.1 | 100 🐟 |
  | 2 | +0.2 | 250 🐟 |
  | 3 | +0.3 | 500 🐟 |

  - Each level is worth one Lucky Cat statue level (`LuckPerStatueLevel` 0.1).
  - It adds inside `LuckMax` (3), like every other Luck source, and never goes past it.
  - It feeds the same Luck total that the odds cards read (`FoodOdds.atBowl` and the crate odds), so the printed odds always include it.
- **Earned only:** it's bought with golden fish only. It's never sold for Robux, never part of any Robux bundle, pack or pass, and can't be traded or gifted (Monetization-Agent, 11-11). Golden fish are earned only, so this never becomes paying for better odds (`monetization-policy`; Monetization-Agent to confirm).
- **Card line:** "Lucky Charm: +0.1 Luck on bait and crates, forever".
- **Flag:** `luckyCharm`. Built 2026-11-12 (#3503, `shared/LuckyCharm`, icon #3502) as specced, with the switch off until review, QA and a switch-on check pass.
- **Judge by:** level 1 buys among players with 100+ fish. Lucky Potion use shouldn't drop much; if it does, use the flag.

## 6. Pet a cat (#3651, a player's idea; switch `petCats`, not built yet)

Derek, 2026-11-12 17:48 UTC: "add the petting cat in shop to increase how much money they make by 2x and display a heart beside their money while it lasts make it 1 hour long". Then 17:49: "make the petting 1 cat only at a time and petting a new one changes it" and "online pay only".

- **How:** a "Pet" prompt on each cat in the player's own cafe. Owner only, in the cafe, distance checked, the remote rate limited with a 3 second server cooldown between pets. The cat purrs with a short heart puff.
- **Effect:** the petted cat's own per-second pay is doubled (`Config.PetMoneyBoost = 2`) for one hour (`Config.PetSeconds = 3600`), by the clock. A heart sits beside that cat's money label while it lasts and the label shows the doubled number.
- **One cat at a time (Derek).** Petting any cat makes it the happy cat for a full fresh hour and takes the heart off the previous cat at once. Petting the cat that already has the heart also resets it to a full hour (Design-Agent's pick: the simplest rule, and with one cat there is nothing to exploit). If the happy cat is sold, traded or leaves the cafe, the heart ends.
- **Stacking:** money passes and money potions multiply as always. With the party slot (update parties, events, the AFK rest in afk-cafe.md) it does not multiply: a petted cat is never above `EventMoneyMax` (2) from the pet and that slot together.
- **Online pay only (Derek).** Offline pay is unchanged and the hour keeps running while the player is away.
- **Words:** the cat's own prompt may read "Happy for 42 m". No toast when a heart ends, no nagging, nothing sold, no pass changes it.
- **Save:** one field on the player: the happy cat's id and the end time.
- **Size:** one cat at 2x is a small, friendly gain: about +10% for a ten cat cafe, more when the best cat is picked.
- **Credit:** the idea came from a player. Their name is never written in this repository; any in-game credit takes it from outside the repo.

## Related

- **Trait station** (#3196): its Quick Paws trait counts one cat at most, +1, for the same reason as the Swift Paws cap.
- **Starter rescue refill** (#3049): the other early-retention fix from the same round.
