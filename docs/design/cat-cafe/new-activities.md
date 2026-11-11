# New activities: Rummage Bin, Cat Arcade, Swift Paws

Draft v1, 2026-11-11, Design-Agent (friend's project). One place for the final specs that were settled in issue comments on 2026-11-10. **The issues are the build tickets; where this file and an issue disagree, the latest issue comment wins and this file gets fixed.** Ideas 2 and 3 came from player its_cuzu098, and both ship with a credit on the newest What's new page (#3067) and an "Idea by its_cuzu098" line on their card.

Shared rules for all three:
- Nothing is sold for Robux: no Robux skip, refill, extra try, continue or streak saver, now or later (Monetization-Agent's conditions).
- No green toasts (#3080). Results show inside each feature's own screen.
- No new HUD element. Phone first: tap anywhere, big targets.
- Each has a live flag in `LiveFlags.KEYS`, on by default, so turning it off needs no restart.

## 1. Rummage Bin (#3050, Alleyway)

Its job is to keep new players past 5 minutes (35% still playing at 5 min on the Nov 10 baseline).

- **Place:** `CatCafe_Camp_Alley_RummageBin` (model in #3058, looks `_Ready` and `_Empty`).
  - It sits within 15 studs of the Alleyway camp pad, with no other prompt within 12 studs.
  - The prompt reads "Rummage" when ready and "Empty for now 🐾" otherwise. There is no countdown.
- **Play:** the rescue bar with a 2-hit attempt and 3 paws.
  - Its own absolute bar: `BinZoneWidth` 0.42 and `BinBarSpeed` 0.64. It never follows the rescue tables.
  - An account's first 3 rummages also get `BinFirstEase` (zone x1.6, speed x0.6).
  - A miss costs nothing and allows a retry after 10 s.
- **Timing:** saved per player (`bin = { nextAt, uses }`), server side.
  - Ready on the first visit, then 180 s after each of the first 3 uses, then every 900 s.
  - Nothing banks.
- **Prizes, one per success:**

  | Prize | Chance |
  |---|---:|
  | Tuna | 40% |
  | 5 golden fish | 25% |
  | Salmon | 12% |
  | Lucky Potion | 11% |
  | Alley Crate | 10% |
  | Golden Alley Crate | 2% |

  - The 1st rummage always gives Tuna, and the 2nd always gives an Alley Crate.
  - The odds show on the card.
- **Flag:** `alleyBin`.
- **Judge by:** `played_5m` and `played_10m` by platform, `bin_play` and `first_bin`. Also `quit_state` with the area and the idle seconds.

## 2. Cat Arcade: Circle Streak (#3062, Town Square cabinet and menu row)

- **Cabinet:** `CatCafe_Town_ArcadeCabinet` (Animation-Engineer). The prompt reads "Play (1 🐟)". The same game opens from an "Arcade" row in the menu.
- **Run:**
  - Costs 1 golden fish, via `GoldenFish.spend`.
  - Uses the catch circles at fixed net level 1 windows, graded on the server through the `CatchPress` path. The client never sends a score.
  - **Perfect scores +2 and Good +1.** The first Miss ends the run, and reaching 100 points wins (the score is clamped).
- **Harder every 10 points:**
  - shrink x0.96;
  - windows x0.97;
  - the gap tends toward `CircleGapMin`;
  - jitter goes 0.10 → 0.20 by 100.
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

## Related

- **Trait station** (#3196): its Quick Paws trait counts one cat at most, +1, for the same reason as the Swift Paws cap.
- **Starter rescue refill** (#3049): the other early-retention fix from the same round.
