# Catch a Cat Cafe key stats

Owner: growth-analyst. Each read adds a section at the top. Source: the `analytics` workflow (Open Cloud Analytics, read only). Roblox only counts **live servers**. Studio playtests never show up, and each day appears about a day late.

## 2026-11-12: Nov 11, the first big day (949 new players)

Runs: Open Cloud analytics for Nov 11 (run 43190531565) and Nov 9 to 11 (run 43213882447). Nov 11 has 949 players in `onboarding_v6` and 861 in `first_hour_v2`, five times Nov 10, so these are solid numbers. Roblox had not filled sessions, day 1 retention or spend for Nov 11 at 12:15 UTC Nov 12; those come with the next read.

| Stat | Nov 10 (186) | Nov 11 (949) | Change |
|---|---:|---:|---:|
| First catch | 80% | 80% | 0 |
| Second cat, of players who served a customer | 76% | 89% | +13 pts |
| First table upgrade | 50% | 64% | +14 pts |
| Bait in the bowl | 47% | 61% | +14 pts |
| Tier 2 | 32% | 34% | +2 pts |
| First park catch | 25% | 27% | +2 pts |
| Still playing at 60 s | 82% | 78% | -4 pts |
| Still playing at 5 min | 47% | 50% | +3 pts |
| Still playing at 10 min | 32% | 38% | +6 pts |
| Still playing at 30 min | 12% | 18% | +6 pts |

Visits 2,178 at 12:00 UTC Nov 12 (1,670 at 23:47 Nov 11), favorites 111, likes 14 to 3. By device on Nov 11: phone 451, computer 221, tablet 149, console 114.

What changed in between: loading screen off (v497), cheaper early upgrades (#2996), the second cat goal (#3022), shorter nights, the tackle shield for new players.

Where players are lost now:
- **After the bait cat, before the first rescue**: 582 put bait out, 442 started a rescue (24% lost). It is the step players stall on most: 310 waited 30 s, 240 waited 60 s, 160 waited 120 s. The bait itself is quick (the cat arrives in 5 s; food in to tame or let go 10 to 16 s). Reading note: `first_bait_resolved` logs only after the rescue steps in this funnel, so its time is the rescue's, not the bait's.
- **The intro**: 83 players (9% of loaded) leave between `loaded` and `first_move`, 27 s apart (#3162).
- **Give up on touch screens**: rescues ending `cancelled` on Nov 9 to 11 were 24% on phones and 22% on tablets, 4% on computers and 1% on consoles (#3024, PR #3504). Phones lose 12% between rescue started and done, computers 1%.
- **Five cats**: 404 finished the first goal, 353 reached five cats (87%); 81 players waited over 120 s on it (#3529).

Leave points (`quit_state`, 534 leavers below Tier 2 with a device): after the bait cat 127 (220 s played on average), intro `tut_0_shown` 84 (45 s), after the first customer 70 (115 s), first goal done 45 (287 s). No device stands out. Night: 22% of leavers left at night (the night is 18% of the clock).

Tablets no longer fall behind phones: Tier 2 is 32% to 35% on every device.

Benchmarks (Creator Hub, Simulation genre, read 03:15 UTC Nov 12, small samples; money rows are kept in the private library, not here):

| Item | Ours | Genre 50th | Genre 90th |
|---|---:|---:|---:|
| Average playtime (min, 28 days) | 17.5 | 12.2 | 30.9 |
| Day 1 retention (56 days) | 3.8% | 6.41% | 12.85% |
| Day 7 retention | 0% (no cohort yet) | 0.57% | 2.17% |
| Qualified play-through | no data (0 Home impressions) | about 2.0% | about 4.7% |

Other reads:
- First five minutes (`step_ready`): a second stray is waiting at 73 s, the table is affordable at 90 s and the bowl at 105 s on average, so money is not what stops new players.
- Store (`store_v1`): opened 414 times, a tab viewed 266, Buy pressed 9.
- Arcade (Circle Streak, before Mouse Dash): 51 games by 27 players, 1 win.
- In-game feedback ask: shown 268 times, a face picked 102 times (38%). Session thumbs card: 8 answers.
- Tracking gaps: `first_hour_v3` (3 and 4 minute marks) and `arcade_v1` logged nothing on Nov 11; join source is `organic` for every player, so ad players cannot be split (#3530).

Next read: Nov 13, for Nov 12 (the 22:00 UTC update: Mystic Pool, Mouse Dash, Update Party, the gift), and Nov 11 sessions and day 1 retention once filled.

## 2026-11-11: launch weekend, Nov 8 to Nov 10 (real players)

Runs: Open Cloud analytics, Nov 8 to 9 (baseline, run 42831058300) and Nov 10 (run 42936503972). Ads: two 18+ campaigns from 13:50 UTC Nov 10; the older campaign paused. The Nov 8 to 9 baseline has 85 players in `onboarding_v6`; Nov 10 has 186 (step_time) and 190 in `first_hour_v2`. Over 100 players a day, so these now read as real behaviour.

| Stat | Nov 8 to 9 | Nov 10 | Change |
|---|---:|---:|---:|
| First catch | 62% | 80% | +18 pts |
| Still playing at 5 min | 35% | 47% | +12 pts |
| Still playing at 10 min | 19% | 32% | +13 pts |
| Still playing at 30 min | 6% | 12% | +6 pts |
| Bait resolved (of bowls) | 65% | 77% | +12 pts |
| Tier 2 | 20% | 32% | +12 pts |
| First park catch | 15% | 25% | +10 pts |

Visits: 451 at Nov 10 14:15, 620 at 01:00 Nov 11, 1,021 at 11:00 Nov 11. Favorites 50, likes 10 to 2.

What changed in between: the circle stop (#2922, v482), the bait cutscene (#2957, #2958, v483), the second cat nudge (#3038, v492), a second cat trail (#3042, v493) and 18+ ads. The circle stop shows clearly (149 of 151 hit the first circle). The second cat nudge cannot be judged yet: its events only exist from 16:49 UTC Nov 10 (see #3238).

Leave points (quit_state, 131 leavers below Tier 2 on Nov 10): after the first customer 35 (about 208 s), intro tut_0 19, first role 10, first bait 10, second cat 10, first goal 8, first move 8, joined 7, near stray 7. By device: phone 73, tablet 21, PC 19, console 16.

Other reads:
- Night: 20% of leaves are at night (the night is 18% of the clock; it was 30% on Nov 8 to 9). The night catch test (switch on 18:37 to 22:53 UTC Nov 10, #3035) gave 17 first-session night catches before it was turned off (#3169).
- Stations: 78% of station opens were by stepping on the pad, 22% by the button. The button is still used for Cannon (28%) and Bait (48%) (#2910).
- Rescues: tablets cancel 36% of rescue attempts, phones 24%, PC and console none (#3024).
- Store: 1 Starter Bundle (R$99). Prompts closed without buying: 2x Money 8, Cafe Pass 4, Second Bowl 3, King Cat Pack 1.
- Catch: phones missed at least once 37 times and saw a cat bolt 48 times (phone circle, #2913).

Next read: Nov 12, for Nov 11 (publish 497 at 00:03 UTC, loading screen off from 00:13, Alleyway held cats catchable #3181, night cut to 45 s nights #3253/#3255).

## 2026-11-03: the 7 days from 2026-10-27 to 2026-11-02

Run: https://github.com/derekburnz/Cat-Cafe/actions/runs/41677157662 (OWNER_KEY, days=7).

**Read this first: the sample is tiny.** 7 new players in the week, most likely Derek, friends and testers. There's no data at all for 11-01 and 11-02 because those playtests ran in Studio. Treat everything below as a smoke test that the events fire, not as player behaviour.

| Stat | Value |
|---|---|
| New players (7 days) | 7 (10-27: 1, 10-28: 4, 10-29: 2) |
| Returning player-days | 3 (10-29, 10-30, 10-31: 1 each) |
| Day 1 retention | 1 of 7 came back the next day (onboarding step 10) |
| Average session | 1.9 to 29.5 min a day, too few to average |
| First-session length | about half the new players stayed past 6.5 min, 1 past 15 min |
| Robux purchases | none logged (no pass or product events) |
| Codes redeemed | 2 by 2 players |

Onboarding funnel (players): joined 7, first catch 6, first table 6, first bait 5, **bait resolved 3** (the biggest drop, 2 of 5), tier 2 3, came back next day 1, tier 3 1.

What it hints at (check again on soft-launch data before acting):
- **The bait wait is where people leave.** 5 set bait, 3 saw it resolve. The 10-minute wait is longer than most of these first sessions. A thing to watch, not a reason to sell a skip (the gdd and monetization.md both rule out Robux for bait speed).
- **slots_full fired 99 times for 6 players**, the second most common event. Players hit the role-slot cap often. That's fine if it pushes them to rank up, but worth checking whether the message reads as a wall.
- The catch loop works: 49 tries, 46 caught, 44 checked in (catch_attempt). Lost between steps aren't trustworthy this week, though, because F93 renumbered the steps on 11-02.
- Most-used custom events: cat_caught 110, slots_full 99, travel 92, ui_opened 82, catch_circles 79, spin 77.

Next read: after the first week with real (non-tester) players. Until then, the daily 10:17 UTC run has the numbers.
