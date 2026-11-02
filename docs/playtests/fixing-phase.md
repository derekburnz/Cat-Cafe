# Fixing phase: before and during the ads

Owner: qa-playtester. Written 2026-11-01 from Derek's research notes of 2026-10-31 ("Roblox Game Dev Notes": ads
of 30k to 60k Robux for 1 to 2 weeks, bug fixes every day while they run so the core loop is always playable, a
feedback route, "tons of test checks to see where/what step people are getting stuck and quitting", next steps
super easy to understand, short context tutorials instead of one long one).

Other threads took parts of the same notes, and this plan builds on them rather than repeating them:
- **Easy start (F87, `docs/design/cat-cafe/easy-start.md`; parts 1 and 2 merged 2026-11-02 in #687 and #691):**
  the onboarding funnel v2 with 24 steps, `new_player_left`, `stuck_nudge`, stuck nudges at 40 s and a help card at
  90 s, fourteen one-time context tips (Derek's food bowl example is the first), and a Feedback page with three faces.
- **Feedback tile (#594, merged 2026-11-01):** a gold Feedback tile on the HUD's top right row opens the report
  window, which used to sit three taps deep under Settings > Help and got zero reports there.
- **analytics.yml (Tools-Agent, 2026-11-01):** threads read players per funnel step, the loss at each step,
  day 1 retention, session lengths and custom events from the Actions tab, without Creator Hub.
- **`quit_point` (Gameplay-Engineer, 2026-11-01):** logged when a player below Tier 2 leaves: seconds played, the
  last funnel step, the intro or tutorial step and where the character stood; `tutorial_step` now logs every step.

What this plan adds is the daily routine that uses them, the smoke test, the gate before the ads and the world
scan. The process rules in sections 1 and 2 are proposed in `docs/decisions.md` (qa-playtester, 2026-11-01).

## 1. The rule and the day

From the day the ads start until a week after they stop, the game has one job: a new player can play the core loop
(get to the Alleyway, catch a cat, bring it home, give it a job, buy a table, set bait, rank up) without hitting a
bug. A bug that breaks a step of the loop is fixed that day. Everything else goes in the queue. New features wait
unless they fix the worst drop in the funnel (section 4).

| When (Derek's day) | Who | What | Output |
|---|---|---|---|
| Morning, after 10:17 UTC, before Derek is on | QA-Planner (a cheap model, rule 11) | `npm run check` on main; the world scan against yesterday's (section 6); the scheduled analytics and bug-reports runs (section 4) | `docs/playtests/fixing/<date>.md` (section 5) with the top three fixes and their owner threads |
| Day | engineer threads | one fix per PR, each with a test row; reviewed; auto-merge | merged PRs |
| Before publish | QA-Planner in the dev copy, Derek on his phone | the smoke test (section 3) on the build that will go live | pass, or a named stop-the-line bug |
| Publish | Tools-Agent | publish only after a pass; with `restart_servers` players get warnings at 5, 3 and 1 minutes (#613, once Derek adds setup step 21), so allow about 5 minutes more | the version number in the day file |
| After publish | Derek, 3 minutes | join the live game on his phone: one catch, one check-in, no error | a line in the day file |

Stop the line (fix today, publish nothing else first):
- any smoke step in section 3 fails;
- a join or save error, or progress lost on rejoin;
- a Robux purchase that does not deliver;
- an exploit that gives coins, cats or items;
- a soft lock: stuck in an area, a cat that cannot be dropped or checked in, a window that will not close;
- a new red error in the server or client console during the smoke test;
- a quarter or more of new players lost on any one of the first nine funnel steps.

## 2. Ready for ads (the gate before any Robux are spent)

- [ ] The smoke test passes on a phone and on a PC three days running.
- [ ] The world scan shows nothing floating or clipping on the first ten minutes' route: the spawn, the way to the
  Alleyway (the back door today, the cannon with F84), the Alleyway's lanes and the player's own cafe inside and out.
- [ ] The funnel and `quit_point` (and F87's funnel v2 and `new_player_left` if they are built by then) show in the
  analytics workflow from friends' sessions in the published dev place (F87 QA check 10).
- [ ] The Feedback tile is live and a test report shows in the next bug-reports run, with no report text or user
  ids in the job log (the repo is public; F87 section 4).
- [ ] F87's first context tips are live: at least `bowl`, `stuck_cat` and `rank_up`.
- [ ] No open stop-the-line bug, and the next step audit (section 4b) has no gap left in the first fifteen steps.
- [ ] Derek's own go: the experience public, the maturity questionnaire answered, the ad set up.

## 3. Daily core loop smoke test (about 15 minutes)

A fresh profile in the dev copy (`Debug.resetProfile`), once on the phone preset and once on PC. Test plan section
4.1 (S1 to S19) has the exact tool calls and numbers; this is the short daily pass. Steps 2 and 4 follow whichever
build is live: the back door and the walk home today (S3, S5), the cannon and the camp once F84 is in (S58).

| # | Do | Pass when | Funnel v2 step |
|---|---|---|---|
| 1 | Join (`Debug.resetProfile()` and rejoin for a fresh account) | Within 10 s the first hint and its trail show and no intro plays (F87; the "?" tile plays it); the HUD shows `$50` and the rate within 5 s | joined |
| 2 | Go to the Alleyway | out of the back door, or Cannon, launch, 3 s of clouds and the camp pad | first_move, saw_alley |
| 3 | Catch the tutorial Common | its "!" shows from the spawn; a swing of the net (click, R2 or the Net button, F93) from a few studs away facing it starts one slow circle (F87: 1.6 s, bands twice a Common's); a late press keeps the cat and the circle comes back after 1 s, and a good press catches it | near_stray, catch_started, first_circle_hit, first_catch |
| 4 | Bring it home | Cat found popup, `+50`, and "Your first cat! <name> is your Waiter now" (F87) | first_checkin |
| 5 | Check its job | Collection (C): the first cat is the Waiter by itself (F87) and the rate rose at the check-in | first_role |
| 6 | Buy Table 1 | `$150`, rate x1.10, the table stands clear of the door path | first_table |
| 7 | Buy the bowl, put Kibble in | `$600` and `$30`; the countdown shows | bowl_bought, first_bait |
| 8 | Rescue a stuck Common (`Debug.spawnStuckCat`) | the rescue frees it and it counts as caught | first_rescue_started, first_rescue_done |
| 9 | `Debug.baitReady()`, Tame | the cat is yours; the tutorial strip goes | first_bait_resolved |
| 10 | Wait 60 s, collect tips | coins rise by the rate; the pile pays once | |
| 11 | `Debug.setPhase("night")`, then sunrise | the areas close and you are taken home; the rate holds; a wave at sunrise | |
| 12 | Rank up (`Debug.setCoins` and cats) | the card ticks each need; Tier 2; the Park opens | rank_up_card_seen, rank_up_ready, tier_2 |
| 13 | Rejoin (API access on) | coins, cats, jobs and bait are back; the offline card claims once | first_offline_claim |
| 14 | Send feedback from the Feedback tile | the thanks toast; it shows in the next bug-reports run | |
| 15 | Read both consoles | no new red errors and no new warnings since yesterday | |

## 4. Funnel checkpoints: reading where players stop

Today's 12-step funnel, `tutorial_step` and `quit_point` are live; F87 section 5 adds finer steps and
`new_player_left`. This is how QA reads them each morning.

Since #618 (Tools-Agent) both workflows run by themselves every day at 10:17 UTC: analytics.yml reads yesterday
and then the last 7 days, bug-reports.yml yesterday's reports and then today's so far. Find the newest run with
GitHub's list of workflow runs for `analytics.yml` or `bug-reports.yml`, filtered to the `schedule` event, one per
page, and read its summary or job log. Roblox fills a day about a day late, so a morning read is mostly about the
day before, and the 7-day part smooths small numbers. The Actions logs are public, so scheduled bug report logs
show a name's first letter and an id's last three digits and leave out the JSON; run bug-reports.yml by hand when a
ticket needs more. The analytics run fails with the setup guide's step 20 message until Derek gives the publish key
`universe.analytics:read`.

1. **Worst drop.** Over steps 1 to 15 (the first session), the step with the largest share of players lost from the
   step before. That is the day's first fix ticket, even if no one reported it.
2. **Where they left.** `quit_point` by last step and place, and with F87 `new_player_left` by bounce window
   (0 to 60 s, 61 to 180 s, 3 to 10 min): a pile at one step and one place in the first few minutes means the step
   itself is unclear or broken.
3. **Where they stall.** `stuck_nudge` by step: many `help_shown` on one step means the hint for it does not work.
4. **What they say.** Feedback faces and chips by day, and the bug-reports run: the share of "Not for me", and
   any chip that doubles from one day to the next.
5. **Catch and bait.** The catch_attempt and bait_cycle funnels: a drop between engaged and caught after a
   balance change is a stop-the-line candidate. Since F93 the catch funnel starts at the swing (1 swing_hit, 2
   engaged, 3 caught, 4 checked_in, 5 working), and `net_swing` counts each player's swings as `hit`, `miss_near` and
   `miss_empty` by device: many `miss_empty` swings on phones mean players cannot tell where the net reaches.

Thresholds: a quarter or more of players lost on one of steps 1 to 9 stops the line (section 1); a step that loses
more each day for two days goes to the top of the queue.

### 4b. Next step audit

After each step, what tells the player the next one, read from the client on 2026-11-01 (today's build, before F87
and F84). QA reads it again whenever the tutorial strip, goal card, hints or tips change.

| After | What tells them now | Gap |
|---|---|---|
| joined | the strip: "Go out your back door to the alley and press E on a cat"; a marker and trail to the tutorial stray (a cannon hint replaces it once the cannon is built) | the intro plays first by itself (F87 2a turns that off) |
| first_catch | nothing while carrying, since the strip hides | nothing says to take it home (F87 2c and 2e) |
| first_checkin | the strip: open the Collection and give it a job | none |
| first_role to first_bait | the strip, one line each, with a marker on the bowl | none |
| first_bait_resolved | the goal card (coins and cats bars to Tier 2) | when the cats bar is the one missing, nothing says "catch more cats" (F87 2h) |
| first stuck cat seen | nothing | F87 tip `stuck_cat` |
| tier_2 | the rank up confetti | nothing points at the Park (F87 tip `rank_up` shows before, not after) |

## 5. The day file

`docs/playtests/fixing/<date>.md`, written by QA each morning, read by Derek and the coordinator:

```
# Fixing day <date>
Live version: <n>   Dev build tested: <commit>
Smoke: pass / fail at step <n> (<what>)
Funnel: worst drop <step a> to <step b>, <x>% of <n> players; most left at <step> in <window>
Feedback: <n> love, <n> ok, <n> not for me; top chip <chip>; <n> reports, new tickets <ids>
World scan: <n> new floating, <n> new clipping since yesterday
Stop the line: <none or the bug>
Top three fixes: 1 <what> (<thread>), 2 ..., 3 ...
Published: version <n> at <time>; live check <ok or what broke>
```

## 6. World scan

`games/cat-cafe/tools/cloudcheck/worldscan.mjs` (`npm run worldscan`) runs the real `WorldBuilder.build()` in the
cloud with every model and lists drawn parts that float, open seams between faces where light shows through, and
models pushed into each other, with world positions. It takes about two and a half minutes. The first run
(2026-11-01) is in the project files under `QA-Planner/world-scan-2026-11-01/`. Each morning's scan is compared
with the day before, so a new floating or clipping part shows up the day it lands. Its limits are in the cloudcheck
README: boxes only, and nothing placed at runtime or in Studio.
