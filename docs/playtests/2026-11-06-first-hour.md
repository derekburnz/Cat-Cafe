# First-hour pacing audit (#1896), 2026-11-06

Author: QA-Planner. Source: `games/cat-cafe/tests/specs/Pace.spec.luau`, describe "The first hour (#1896)". It plays one hour for a new player (4 catches a day, 10 seeded runs) and logs every buy, rank up and new cat.
Not counted in the sim, so a real player has more to do than shown: spins, golden fish, crates, potions, quests, the Daily Treat, rescues.

## What the runs show
- The first buy comes within the first minutes. Tier 2 lands at about 11 minutes (median), Tier 3 median falls inside 40 to 60 minutes (the guard passes), single runs range from about 20 to 60.
- Shop buys come in bursts: 5 to 6 buys in the first 5 minutes, another burst right after each rank up, and in between 20 to 30 minutes with nothing affordable. Typical buys per 5 minutes in one run: `6 2 5 0 0 0 0 0 0 1 3 2`.
- Longest gap between buys: 16 to 50 minutes. Counting a new cat arriving as something new, it is 6 to 26 minutes. The goal of at most 4 minutes is missed by shop buys alone, and also with new cats counted.
- Dead time comes from the tier cap: each tier has a small set of cheap items, the player buys them all at once, and then the next item is the rank-up cost.

## Conflict in the issue's targets
"First rank-up between 40 and 60 minutes" clashes with the existing Tier 2 bound of 10 to 20 minutes (Pace.spec). The median Tier 3 already lands in the 40 to 60 window. Recommendation: keep Tier 2 at 10 to 20 and treat the Tier 3 median as the first-rank-up target; the spec now guards it.

## slots_full
`slots_full` is only a telemetry event in `CafeService` (a checked-in cat finds no free spot, logged with the tier). It does not block catching or any purchase, so it does not stop the first hour. The "rank up for more" wording is a Design/UI matter; nothing here depends on it.

## Smallest proposed number changes (for Design-Agent, needs a Config claim)
1. Split the dead window with one mid-tier step: an extra cheap item (decor or upgrade) that unlocks around minute 20 to 25 and another around 45, so the longest gap falls toward 10 minutes.
2. Faster early runs reach Tier 3 near 20 minutes; Design may want a small Tier 3 cost raise to pull the low end up.
3. Keep new cat arrivals every 2 to 5 minutes, which already carries the first 40 minutes.

## Tests
- `buys something in the first 3 minutes`: guard.
- `reaches Tier 3 between 40 and 60 minutes (median)`: guard.
- `always has something to buy within 4 minutes`: `xit`, the recorded goal.
