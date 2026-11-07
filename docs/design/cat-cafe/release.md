# Release: badges, the release gate, store timing and the first four weeks (#1934 to #1937)

Status: specced 2026-11-07 by Design-Agent (friend's project), from Derek2's asks the same day: "continue researching and thinking of any changes and additions that might benefit the game to have on release and start implementing them however you suggest", then "go ahead with all and release planning for about 3-5 days from now". Research: Research-Agent's `release-ideas-2026-11-07.md` in the library.

**Release window: not set yet.** Set 12 Q6 (Derek2, 2026-11-07): "we figure out days and tiles later depending on some fixes". Research-Agent's suggestion (#1956) is kept as the default when he picks: public on a Wednesday at 20:00 UTC, ads from the next day. The plan below counts in days from **day 1, the first public day**. The freeze is 24 hours before day 1: from then on only fixes merge.

**What launch waits on (Set 13 Q1, Derek2):** "Leave for now I am going to finish all prs and issues before launch". There's no separate `release-blocker` list before launch. The game goes public once the open PRs and issues are finished, and Derek2 picks the day then. The ad account and ad targeting also wait until the game is finished (Set 13 Q2 and Q3). The Maturity & Compliance questionnaire is already done (Q6).

**Launch shape (Set 12 Q4, Derek2):** "first day public I will get friends to test then start ads day 2 ideally 10-15$ a day for 7 days and we decide if its worth continuing after that". So:
- **Day 1, public:** the game goes public, and 3 to 5 of Derek2's friends play and test it (Set 13 Q5). There's no feedback form: Derek2 passes on what they say, and QA-Planner turns it into issues. There are no ads and no outside posts yet. The What's New "We're open!" entry and `OPENING` go live.
- **Day 2 to day 8, ads:** a Roblox sponsored ad runs at **US$10 to $15 a day for 7 days** (about $70 to $105 in all), if the day 1 quick check in section 2 passes.
- **Day 9, the decision:** Derek2 decides whether ads and updates continue. Set 13 Q4 (Derek2): "most of the doing well actually means some home recommendations or a lot of home recommendations if there are not a lot of home rec's the game will probably be left as a learning experience and stop ads/updates." So the main signal is **Home recommendation impressions** in the Creator Hub analytics, which show whether Roblox is suggesting the game on players' Home pages. The section 2 marks (D1, session length) are compared with similar games' benchmarks as background. If Home recommendations are few, ads and updates stop and the game stays as a learning project.

## 1. Roblox badges (#1934)

Badges show on the game page and in a player's inventory. Each one is free to create, up to 5 a day per game (more cost R$100 each), so the 20 below are listed in **creation order**: 5 a day from 2026-11-07 means all 20 exist by 2026-11-10. Builders: Gameplay-Engineer (server awards), Model-Agent (512 x 512 icons, a round cafe-palette badge with one simple picture each), Tools-Agent or Derek (creating them in Creator Hub and putting the ids in Config).

| # | badge (name) | awarded when | day |
|---|---|---|---|
| 1 | Welcome to the Cafe | the tutorial ends (`tutorialStep` 5) | 1 |
| 2 | First Catch | the first stray caught | 1 |
| 3 | Cozy Cafe | Tier 2 | 1 |
| 4 | Grand Opening | roadmap step 8 (first-hour.md §1) | 1 |
| 5 | Purrfect! | the first PURRFECT catch (catch-rework.md §7d) | 1 |
| 6 | Bait Cat | the first bait cat tamed | 2 |
| 7 | Rare Find | the first Epic owned | 2 |
| 8 | Legendary Find | the first Legendary owned | 2 |
| 9 | Mythical Find | the first Mythical owned | 2 |
| 10 | Busy Cafe | Tier 3 | 2 |
| 11 | Famous Cafe | Tier 4 | 3 |
| 12 | Grand Cafe | Tier 5 | 3 |
| 13 | Cat Collector | 25 different cats | 3 |
| 14 | Cat Expert | 50 different cats | 3 |
| 15 | Golden Coat | the first gold cat | 3 |
| 16 | Rainbow Coat | the first rainbow cat | 4 |
| 17 | Page Complete | the first full area page in the Index | 4 |
| 18 | Helping Paw | the first team rescue helped (rescue-rally.md) | 4 |
| 19 | First Trade | the first completed trade | 4 |
| 20 | Purrfect Streak | a Purrfect streak of 5 | 4 |

- **Rules:** awarded by the server only, never for liking, favouriting, buying or inviting, and nothing has a streak that can be lost. Each badge's description is one plain line, for example "Rank your cafe up to Tier 3."
- **Contract:** `Config.Badges = { welcome = 0, firstCatch = 0, ... }`, where 0 means not created yet and is skipped. `BadgeService` awards are wrapped in pcall. A failed award goes into a per-player retry list, tried again at the next qualifying event and on join, and never blocks play. Each player's owned badges are cached once per join with `UserHasBadgeAsync`.
- **Catch-up:** on join, the server checks the profile for every badge the player already qualifies for and awards those quietly, so a badge created after launch still reaches players who earned it. No toast plays for catch-up awards. Live awards get Roblox's own badge notice and nothing extra from us.
- **Funnel:** `badge_awarded` with the badge key and minutes played.
- **QA:** a fresh account gets badges 1 to 5 in its first hour, once each, with no new console errors. An account that already ranked to Tier 3 gets badges 3 and 10 on join. A badge with id 0 is skipped silently.

## 2. The release gate and soft launch (#1935)

Owners: QA-Planner (runs the gate and writes `docs/playtests/2026-11-10-release-gate.md`), Tools-Agent (device and performance captures), Monetization-Agent (reads the funnels). Derek2 makes the go-wide call.

- **Stage 1, private check (before the freeze):** the full playtest on the device matrix below, on the dev place and then on the live place. The phone checks run in Studio's device emulator (Set 12 Q5, Derek2: "do it on an emulator in studio and track mobile users leave times so we can see if they have issues day 2"). Nothing new merges in the 24 hours before day 1 except fixes ("freeze").
- **Stage 2, day 1 quick check (24 hours after going public, before ads start):** marks 1, 4 and 5 below must pass. With 3 to 5 friends the percents mean little, so this check is mostly no errors and working purchases. A failed mark gets a `release-blocker` issue, and ads wait until it is fixed.
- **Stage 3, the ad week (day 2 to day 8):** marks 2 and 3 are read from the ad players, together with **phone leave times**: `session_end` and `new_player_left` already carry the device and the seconds played, so Monetization-Agent compares the median session and the bounce windows for phone against PC each day from day 2. A phone median under half the PC median, or a jump in phone leaves in one onboarding step, gets a `release-blocker` issue for that step.
- **Pass criteria** (all from the funnels that already exist):
  1. Tutorial completion (`onboarding_v4` step 5) is **80% or more** of players who load in.
  2. D1 return is **12% or more** on the soft launch's first day of players, the analytics plan's number. Under 8% means hold and fix first. Between 8% and 12%, Derek2 decides. Derek2, 2026-11-07: "go for the original plan numbers as those are realistic but don't expect it to go that well it is my first game".
  3. The median first session is **10 minutes or more**, and 25% or more of players reach 30 minutes.
  4. Client error rate: no new ClientErrors signature hits more than 1% of sessions, and no server error repeats in more than 1% of servers.
  5. Purchases work: every live pass and product passes its owner test before the freeze.
- **Device matrix** (each passes the first 15 minutes with no new console errors): a low-end Android phone (the lighter phone setting on), an iPhone, an iPad or tablet, a Windows desktop, and console. The phones, tablet and console run in Studio's device emulator (Set 12 Q5), and the live phone numbers come from the leave-time read in stage 3.
- **Performance marks:** time from load to first move is 20 s or less at the median on phone. Client memory stays under 1.2 GB on the low-end phone over 15 minutes. The server heartbeat stays at 55 Hz or more with 8 players. Tools-Agent records these from Studio and the live developer console.
- If any mark fails, the fix gets an issue labelled `release-blocker`, and the gate re-runs on just that item.

## 3. Store timing guard (#1936)

The research rule is that nothing pushes a paid item at a new player. Today nothing opens the Store or a purchase prompt by itself, and every prompt comes from a tap. This section makes that a tested rule and calms the first 30 minutes. Builders: UI-Engineer (client), Gameplay-Engineer (the play-time value).

- **The rule:** a purchase prompt (`PassShop.prompt` or a product prompt) opens only from a tap on a buy button the player is looking at. A guard in `PassShop.prompt` refuses any call without a tap in the last 2 seconds, and logs `store_guard_blocked` with where the call came from. A unit test covers it.
- **The first 30 minutes of total play** (`stats.playtimeSeconds` plus the session, under 1800):
  - The HUD money pill shows its "x2" icon without a price, and tapping it still opens the Store.
  - No toast, banner, What's New line or goal card mentions a paid item.
  - The Store tile is always there, and the Store itself shows everything as normal when a player opens it.
- **Never, at any play time:** no pop-up Store on join, no "offer ends" countdowns except the real Cafe Pass season end, and no prompt during a catch, a rescue or a cutscene.
- **Free players** can reach every tier, area and cat that isn't shop-only. That's already true, and the guard test lists it as a check, so a future change can't break it quietly.
- **QA:** on a fresh account nothing paid is advertised before 30 minutes, and the money pill gains its price at 30:00. A scripted call to `PassShop.prompt` with no tap is blocked and logged. Every buy button still works.

## 4. After launch: on hold (#1937)

Set 12 Q2 (Derek2, 2026-11-07): "don't worry about updates post release until we see game is doing well". So only the launch itself is planned:
- **Day 1:** What's New "We're open!" (the Grand Opening roadmap and the new catch) and the code `OPENING` (1000 coins + 300 coin-seconds, #1943). Everything else is fixes.
- **Days 2 to 8:** fixes only, from QA-Planner's bug list and the phone leave-time read (section 2, stage 3).
- **On hold until Derek2 says the game is doing well (the day 9 read at the earliest):** the Rescue Rally weekend, the forced Lucky, Golden and Rainbow Days, the decor and camp drops, and the codes `RALLY`, `COZY` and `SNOWY`. They are all built or easy to build: the codes are in `Catalog.codes` and inactive (#1943), and `Config.ForcedDays` stays empty (#1974). Turning one on is a one-row PR.
- The calendar that was drafted for this (#1973) is kept below as the menu to pick from when updates restart. Its dates are no longer the plan.

| drop (when updates restart) | turned on | code | owners |
|---|---|---|---|
| a **Rescue Rally weekend** (rescue-rally.md) | the Rally flag for Saturday and Sunday | `RALLY` | Gameplay |
| a **Lucky Day** and 3 new decor pieces from the existing crate list | a `lucky` row in `Config.ForcedDays` | none | Model-Agent, Gameplay |
| the Autumn Leaf set reminder (cafe-pass.md §3a), a new camp item and a **Golden Day** | a `golden` row | `COZY` | Model-Agent, Gameplay |
| a **Rainbow Day**, 2 more decor pieces and fixes | a `rainbow` row | `SNOWY` | Model-Agent, Gameplay |

- **Forced days:** `Config.ForcedDays` rows are `{ kind = "lucky" | "golden" | "rainbow", from, to }` in UTC unix seconds (#1974, #1975). Any in-game day whose sunrise falls inside a window gets that kind on every server. Outside the windows the normal random chances apply.
- **Honest wording:** no countdowns, no "hurry", and nothing paid named in text a new player sees (section 3). A code goes in the What's New line only.

### 4a. No winter event (Set 11 Q6, Derek2 2026-11-07)
Derek2: "this game probably wont live that long its a learning experience so don't worry about next winter or even next month focus on making it good for launch". The Winter Cafe event is dropped.
