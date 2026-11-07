# First four weeks: calendar, What's New entries and codes (updated 2026-11-07, #1937)
Owner: growth-analyst (Monetization-Agent). Source: `docs/design/cat-cafe/release.md` section 4 (Design-Agent, PR #1973). The launch days and weekly drops depend on Derek2's Set 12 answers (Q2 small Saturday drops, Q6 launch days); if he picks otherwise, release.md section 4b says how the rows move and I move these entries with them. The Winter Cafe event is dropped (Set 11 Q6).

## Calendar
| When | The drop | Code |
|---|---|---|
| Wed 11-11 20:00 UTC (Q6) | Soft launch: public, no ads, no posts, no What's New | none |
| Fri 11-13 14:00 UTC (Q6) | Gate read (QA-Planner; I read the funnels) | none |
| Sat 11-14 14:00 UTC (Q6) | We're open: soft-launch fixes and the first Rescue Rally weekend, one combined entry | `OPENING` and `RALLY` |
| Sat 11-21 (Q2) | Lucky Day Saturday and 3 new decor pieces | none |
| Sat 11-28 (Q2) | Autumn Leaf set reminder, a new camp item, Golden Day Sunday 11-29 | `COZY` |
| Sat 12-05 (Q2) | Rainbow Day Saturday, 2 more decor pieces, fixes from bug reports | `SNOWY` (code name kept) |

If the gate fails, every row moves one week later and the week 4 drop is dropped (release.md 4b).

## What's New entries (each under 60 words)
All entries are under 50 words. Nothing paid is named (the store guard in release.md section 3 keeps paid items out of new-player text), no countdown, no "hurry". The code goes in the entry only, never a pop-up.

1. **We're open!** (Sat 11-14, one combined entry)
   "Catch a Cat Cafe is open to everyone! Thank you to everyone who played early, we fixed a lot thanks to you. This weekend is the first Rescue Rally, so help other players rescue cats. Use the codes OPENING and RALLY at the Codes Cat for a little coin gift."
2. **Lucky Day Saturday** (11-21)
   "Today is a Lucky Day! Rare cats show up a little more often, so it is a great day to explore. We also added three new decor pieces to dress up your cafe. Have fun, and thanks for playing!"
3. **Cozy Saturday and Golden Day** (11-28)
   "The Autumn Leaf set is still around, and there is a new item for your camp. Tomorrow is a Golden Day, so keep an eye out for shiny cats. Use the code COZY for a coin gift."
4. **Rainbow Day Saturday** (12-05)
   "Today is a Rainbow Day, the rarest day of all! Keep your eyes open for colourful cats around the cafe. We also added two more decor pieces and fixed bugs you told us about. Use the code SNOWY for a coin gift."

## Codes (built in #1943, inactive until their day)
Coins only, at most about 10 minutes of income, as set in release.md section 4:
| Code | Prize | Turns on | Ends |
|---|---|---|---|
| `OPENING` | 1000 coins + 300 coin-seconds | Sat 11-14 | 4 weeks later |
| `RALLY` | 1000 coins + 300 coin-seconds | Sat 11-14 | 4 weeks later |
| `COZY` | 1500 coins + 450 coin-seconds | Sat 11-28 | 4 weeks later |
| `SNOWY` | 2000 coins + 600 coin-seconds | Sat 12-05 | 4 weeks later |

Rules:
- Codes are free, never sold, and not tied to a purchase or the group (no `requiresGroup`), so every player can use them.
- No countdown anywhere. An expired code says "That code has expired" (existing text).
- One redeem per account (existing `codesRedeemed`).
- The `SNOWY` name stays so the code row does not change; the entry does not mention snow.

## Soft-launch funnel read (gate in release.md section 2)
Events are in `analytics-events-2026-11-06.md`. After 24 to 48 hours of soft launch (from Wed 11-11), I read these and report to the coordinator for Derek2's go/no-go:

| Gate mark | Read from |
|---|---|
| Tutorial completion 80% or more | `onboarding_v4` step 5 divided by `session_start` new players |
| D1 return 12% or more (under 8% hold and fix; 8% to 12% Derek2 decides) | `session_start` returning on day 1, among day 0 new players |
| Median first session 10 minutes or more; 25% reach 30 | session length |
| No error spike over 1% of sessions or servers | ClientErrors and server error counts (Tools-Agent) |
| Purchases work | owner test on 11-09 (QA) plus the first `robux_purchase` rows |

Soft launch has few players, so I give the counts next to each percent. Under about 100 new players the percents are a hint, not a verdict, and I say so.
