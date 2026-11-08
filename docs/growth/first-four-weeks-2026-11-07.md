# Launch week, What's New entries, codes and the daily reads (updated 2026-11-07, #1937)
Owner: growth-analyst (Monetization-Agent). Source: `docs/design/cat-cafe/release.md` sections 2 and 4 (Design-Agent; Set 12 and Set 13 answers). Days are counted from **day 1, the first public day**. The release date is not set yet: launch waits until all open PRs and issues are finished and Derek2 picks the day then (Set 13 Q1: "I am going to finish all prs and issues before launch"). Every date below is "day N" until then. The Winter Cafe event is dropped (Set 11 Q6).

## Plan
| Day | What happens | Code |
|---|---|---|
| Before day 1 | All open PRs and issues finished (no separate release-blocker list). Freeze 24 hours before day 1: only fixes merge. Purchases pass their owner tests. | none |
| 1 | Game goes public; 3 to 5 of Derek2's friends play (no feedback form); no ads, no outside posts. "We're open!" entry goes live. I do the day 1 quick check, which is mostly "no errors, purchases work". | `OPENING` |
| 2 to 8 | Ads at about $10 to $15 a day if Derek2 turns them on (Set 12 Q4), run as in `ad-campaign-plan-2026-11-08.md` (8 test thumbnails, cuts on days 2 to 3, gates on days 5 and 7). The ad account and ad targeting are parked until the game is finished (Set 13 Q2 and Q3). Fixes only. I send the daily read (below). | none |
| 9 | Decision read. The main signal for "doing well" is **Home recommendation impressions** in Creator Hub analytics. D1 and session length are background only. Few Home recommendations means ads and updates stop and the game stays a learning project. Derek2 decides. | none |
| After 9, only when Derek2 says the game is doing well | Updates restart from the menu below. | `RALLY`, `COZY`, `SNOWY` |

Nothing in ads, targeting, store pages, prices or passes changes without Derek2's yes. I only read and report.

## Post-launch drops: on hold (Set 12 Q2: "don't worry about updates post release until we see game is doing well")
Kept as a menu, not a plan. Each is a one-row PR when Derek2 restarts updates; dates are decided then.
| Drop | Turned on | Code |
|---|---|---|
| Rescue Rally weekend | the Rally flag for Saturday and Sunday | `RALLY` |
| Lucky Day Saturday and 3 new decor pieces | a `lucky` row in `Config.ForcedDays` | none |
| Autumn Leaf set reminder, a new camp item, Golden Day Sunday | a `golden` row | `COZY` |
| Rainbow Day Saturday, 2 more decor pieces, bug fixes | a `rainbow` row | `SNOWY` (code name kept) |

## What's New entries (each under 60 words)
All entries are under 50 words. Nothing paid is named (the store guard in release.md section 3 keeps paid items out of new-player text), no countdown, no "hurry". A code goes in the entry only, never a pop-up. Only entry 1 is live at launch; 2 to 5 wait on the hold above.

1. **We're open!** (day 1)
   "Catch a Cat Cafe is open to everyone! Follow the Grand Opening goals to build your cafe and meet your first cats. Use the code OPENING at the Codes Cat for a little coin gift."
2. **Rescue Rally weekend** (on hold)
   "The Rescue Rally weekend is here! Help other players rescue cats and earn a thank you from the whole cafe. Use the code RALLY for a little coin gift."
3. **Lucky Day Saturday** (on hold)
   "Today is a Lucky Day! Rare cats show up a little more often, so it is a great day to explore. We also added three new decor pieces to dress up your cafe. Have fun, and thanks for playing!"
4. **Cozy Saturday and Golden Day** (on hold)
   "The Autumn Leaf set is still around, and there is a new item for your camp. Tomorrow is a Golden Day, so keep an eye out for shiny cats. Use the code COZY for a coin gift."
5. **Rainbow Day Saturday** (on hold)
   "Today is a Rainbow Day, the rarest day of all! Keep your eyes open for colourful cats around the cafe. We also added two more decor pieces and fixed bugs you told us about. Use the code SNOWY for a coin gift."

## Codes (built in #1943, inactive until their day)
Coins only, at most about 10 minutes of income:
| Code | Prize | Turns on | Ends |
|---|---|---|---|
| `OPENING` | 1000 coins + 300 coin-seconds | day 1 | 4 weeks later |
| `RALLY` | 1000 coins + 300 coin-seconds | on hold | 4 weeks after it starts |
| `COZY` | 1500 coins + 450 coin-seconds | on hold | 4 weeks after it starts |
| `SNOWY` | 2000 coins + 600 coin-seconds | on hold | 4 weeks after it starts |

Rules: free, never sold, no `requiresGroup`; no countdown anywhere; an expired code says "That code has expired"; one redeem per account (`codesRedeemed`). The `SNOWY` name stays so the code row does not change, and its entry does not mention snow.

## The daily read, days 2 to 8 (release.md section 2, stage 3)
Every day from day 2 I send the coordinator one short note by about the same time. It covers the previous 24 hours and uses `session_end` and `new_player_left`.
| Read | From | Why |
|---|---|---|
| Median session, phone vs PC (and tablet, console if any) | `session_end` value (seconds played) split by its device field | A phone median under half the PC median is a phone problem. |
| New players who leave in each bounce window, phone vs PC | `new_player_left` windows 0-60s, 61-180s, 3-10m, 10m+ | The first minutes are where onboarding breaks. |
| Where phone leavers were in the tutorial | `new_player_left` furthest onboarding step | A jump in phone leaves at one step points at that step. |
| Ad players vs organic | `session_start` join source | Shows whether the ads bring players who stay. |
| Counts next to every percent | all of the above | Under about 100 new players a day the percents are a hint, not a verdict, and I say so. |

Phone problems (a phone median under half the PC median, or a jump in phone leaves in one onboarding step) go to the coordinator and QA-Planner as a normal issue naming the step, the device mix and the counts. Derek2 has said there is no separate release-blocker list, so I do not use that label unless he brings it back. I do not change any ad or store setting.

## Day 1 quick check and the day 9 decision (release.md section 2)
Events are in `analytics-events-2026-11-06.md`. On day 1 only 3 to 5 friends play, so percents mean little and the check is mostly errors and purchases.
| Mark | Read from | When |
|---|---|---|
| Tutorial completion 80% or more | `onboarding_v4` step 5 divided by `session_start` new players | day 1 quick check |
| No error spike over 1% of sessions or servers | ClientErrors and server error counts (Tools-Agent) | day 1 quick check |
| Purchases work | owner tests before the freeze, then the first `robux_purchase` rows | day 1 quick check |
| D1 return 12% or more (under 8% hold and fix; 8% to 12% Derek2 decides) | `session_start` returning on day 1, among day 0 new players | ad week (background for day 9) |
| Median first session 10 minutes or more; 25% reach 30 | `session_end` | ad week (background for day 9) |

Day 9 read, in this order: (1) **Home recommendation impressions** from Creator Hub analytics, day by day, which is the call Derek2 makes (Set 13 Q4). I cannot open Creator Hub, so I ask Derek2 to share the Home recommendations number, or the chart, for days 1 to 9. (2) The marks above and the phone vs PC picture, compared with similar games' benchmarks, as background only. (3) Revenue by item (`robux_purchase`) and, if ads ran, the spend per new player from his ad page. Then I give a plain recommendation: continue ads and updates, or stop and keep it as a learning project. I never change ads or the store.
