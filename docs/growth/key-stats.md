# Catch a Cat Cafe key stats

Owner: growth-analyst. Each read adds a section at the top. Source: the `analytics` workflow (Open Cloud Analytics, read only). Roblox only counts **live servers**. Studio playtests never show up, and each day appears about a day late.

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
