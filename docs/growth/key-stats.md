# Catch a Cat Cafe key stats

Owner: growth-analyst. Each read adds a section at the top. Source: the `analytics` workflow (Open Cloud Analytics, read only). Roblox only counts **live servers**. Studio playtests never show up, and each day appears about a day late.

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
