# First four weeks: calendar, What's New entries and codes (2026-11-07, #1937)
Owner: growth-analyst (Monetization-Agent). Source: `docs/design/cat-cafe/release.md` section 4 (Design-Agent, PR #1939). Dates there are the plan; Derek2 decides go-wide on the day (Thu 11-12, or Sat 11-14 if the gate fails).

## Calendar
| When | The drop | Code |
|---|---|---|
| Thu 11-12 | We're open: Grand Opening roadmap and the new catch | `OPENING` |
| Sat 11-14 | Soft-launch fixes and the first Rescue Rally weekend | `RALLY` |
| Sat 11-21 | Lucky Day Saturday and 3 new decor pieces | none |
| Sat 11-28 | Autumn Leaf set reminder, a new camp item, Golden Day Sunday | `COZY` |
| Sat 12-05 | Winter Cafe begins (to 2027-01-02) | `SNOWY` |

If go-wide slips to 11-14, "We're open" and the Rally entry ship together and `OPENING` starts that day.

## What's New entries (each under 60 words)
All entries are under 50 words. Nothing paid is named (the store guard in release.md section 3 keeps paid items out of new-player text), no countdown, no "hurry".

1. **We're open!** (11-12)
   "Catch a Cat Cafe is open to everyone! Follow the Grand Opening goals to build your cafe, meet your first cats and find out what's next. Use the code OPENING at the Codes Cat for a little coin gift."
2. **Rescue Rally weekend** (11-14)
   "We fixed bugs from our first week and the first Rescue Rally weekend starts today. Help other players rescue cats and earn a thank you from the whole cafe. Use the code RALLY for a little coin gift."
3. **Lucky Day Saturday** (11-21)
   "Today is a Lucky Day! Rare cats show up a little more often, so it is a great day to explore. We also added three new decor pieces to dress up your cafe. Have fun, and thanks for playing!"
4. **Cozy Saturday and Golden Day** (11-28)
   "The Autumn Leaf set is still around, and there is a new item for your camp. Tomorrow is a Golden Day, so keep an eye out for shiny cats. Use the code COZY for a coin gift."
5. **The Winter Cafe** (12-05)
   "Snow has come to Cat Cafe Town! Meet snowflake cats in tiny scarves, do a winter quest each day and trade Snowflakes for winter decor. Everything can be earned free. Winter Cafe runs until 2 January. Use the code SNOWY for a coin gift."

## Codes
Rows go in `Catalog.codes` (same shape as `playtest`: `id`, `active`, `endsAt`, `prize`). Coins only, no fish, spins, crates, lures or potions.
| Code | Prize | Ends | Why |
|---|---|---|---|
| `opening` | coins = 10 minutes of income at Tier 1 | 2026-12-05 | A small fixed gift, not scaled to rich players. |
| `rally` | same as opening | 2026-12-05 | |
| `cozy` | coins = 10 minutes of income at Tier 3 | 2027-01-02 | |
| `snowy` | coins = 10 minutes of income at Tier 3 | 2027-01-31 | Long end date so the winter event is not missed. |

Rules:
- Exact coin numbers are Gameplay-Engineer's: take the Tier 1 and Tier 3 coins per second from `Config`, multiply by 600, round down. Never more than 10 minutes.
- Codes are free, never sold, and not tied to a purchase or the group (no `requiresGroup`), so every player can use them.
- Show the code in the What's New entry, not in a pop-up. No countdown anywhere. An expired code says "That code has expired" (existing text).
- One redeem per account (existing `codesRedeemed`).

## Soft-launch funnel read (gate in release.md section 2)
Events are in `analytics-events-2026-11-06.md`. After 24 to 48 hours of soft launch (from Tue 11-10), I read these and report to the coordinator for Derek2's go/no-go:

| Gate mark | Read from |
|---|---|
| Tutorial completion 80% or more | `onboarding_v4` step 5 divided by `session_start` new players |
| D1 return 25% or more | `session_start` returning on day 1, among day 0 new players |
| Median first session 10 minutes or more; 25% reach 30 | session length |
| No error spike over 1% of sessions or servers | ClientErrors and server error counts (Tools-Agent) |
| Purchases work | owner test on 11-09 (QA) plus the first `robux_purchase` rows |

Soft launch has few players, so I give the counts next to each percent. Under about 100 new players the percents are a hint, not a verdict, and I say so.
