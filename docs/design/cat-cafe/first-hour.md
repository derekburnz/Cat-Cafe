# The first hour: the Grand Opening roadmap and a first "wow" cat (#1893, #1897)

Status: specced 2026-11-06 by Design-Agent (friend's project), from Derek2's ask the same day: "focus on things to try and keep the players staying passed the 10min mark ideally at least till 1h". Research: Research-Agent's `first-hour-retention-2026-11-06.md` in the library. That covers Roblox's onboarding advice to show short, mid and long goals before onboarding ends and to finish with a moment of joy. Builders: Gameplay-Engineer (milestone checks, payouts, the wow roll, save), UI-Engineer (the roadmap card, toasts), VFX-Agent (it reuses the F89 rare-moment effects). The catch minigame (#1884) is unaffected.

Rules for both parts: nothing is sold and there are no timers or "limited" words. Leaving loses nothing, and odds for everyone else stay exactly as they are.

## 1. The Grand Opening roadmap (#1893)

The tier pace is Tier 2 at about 15 minutes and Tier 3 at about 50 (economy-ladder.md). The roadmap turns that into eight visible steps, so a player always sees the next goal (the goal card), the next milestone (the roadmap) and the big payoff at the end.

### 1a. The milestones

Each milestone is read from the profile, so it needs no new tracking, and each one matches an `onboarding_v4` step.

| # | milestone (card text) | done when | reward | about |
|---|---|---|---|---|
| 1 | Open your first table | tables level 1 | 5 golden fish | 3 min |
| 2 | Your first bait cat | the first bait result | 5 golden fish | 6 to 14 min |
| 3 | Five different cats | 5 distinct cats owned | 1 spin | 12 min |
| 4 | Rank up to Tier 2 | `tier` 2 | 10 golden fish | 15 min |
| 5 | Catch a cat in the Park | the first catch in the Park | 1 Swift Potion | 20 min |
| 6 | A full Tier 2 cafe | at Tier 2 or above, every role slot filled at once (Tier 1's two slots don't count) | 1 spin | 30 min |
| 7 | Twelve different cats | 12 distinct cats owned (Tier 3's own need) | 10 golden fish | 40 min |
| 8 | **Grand Opening!** Rank up to Tier 3 | `tier` 3 | 50 golden fish, 1 crate of the highest zone and the "Grand Opener" chat tag | 50 to 60 min |

- Steps 6 and 7 changed on 2026-11-06 after Gameplay-Engineer's Pace runs (PR #1917): "a full cafe" at Tier 1 finished at minute 1.3, and ten cats at minute 18. See §4b.
- In total it pays 80 golden fish, 2 spins, 1 potion and 1 crate over the first hour. That's under one Fish Market crate's worth (40 fish) per 30 minutes, so the economy hardly moves. The tag is the keepsake.
- Milestones can finish in any order. A player who ranks up before buying a fifth cat still gets both. The card always highlights the lowest unfinished one.

### 1b. The card
- It appears when `tutorialStep` reaches 5 (the tutorial's end), just under the goal card, as one compact strip: "Grand Opening 3/8" with eight small dots, done ones filled gold.
- Tapping the strip opens it in place as a short list: done steps ticked with their reward, the next one highlighted, later ones shown plainly. There are no timers and no locks. Tapping again closes it, and the open or closed state is remembered (`roadmapOpen` setting).
- When a milestone finishes, its dot pops gold and a small toast slides in ("Grand Opening 4/8: Tier 2! +10 golden fish") with a short confetti puff. The reward is paid at once, with no claim button and no going back.
- After milestone 8, the Grand Opening plays a bigger moment once: a banner "Your cafe's Grand Opening!", a confetti burst over the cafe and the tag. Then the strip goes away for good.
- Accounts already at Tier 3 or above when this ships never see the card and get nothing back-paid, because the first hour is behind them.

### 1d. The ribbon on the cafe (Model-Agent, 2026-11-06)
- **Before step 8:** a red ribbon with a big bow and a small "Grand Opening soon" pennant hangs across the cafe front at awning height, from the end of the tutorial. It's a plot model at the plot pivot, looks only, with no collision, and it stays clear of the door and the back step.
- **At step 8:** the ribbon snaps in two and the halves drop and fade, with the Grand Opening banner (VFX adds confetti, Sound adds a snip). The halves are separate parts so they can be tweened.
- **After:** pastel bunting and two balloon clusters by the door, for 2 hours of play after step 8, then gone. There's no remove button. Save: `grandOpening.finishedAt` (play-time seconds) next to `finished`. On the low setting, the balloons don't wobble.
- Accounts at Tier 3 or above when this ships never see it (section 1b).

### 1c. Contracts
- Save: `grandOpening = { done = { [number]: true } }`, an optional field defaulting to empty, plus `finished` true after step 8. This needs a save version bump, so claim `DataService.luau`.
- Server checks on the events that already exist (table buy, bait result, check-in, rank-up, Park catch, role assignment). It pays through `Payout`, sends `RoadmapStep(n)` to the client for the toast, and syncs in ProfileSync.
- Funnel: custom event `grand_opening` with field step (1 to 8) and minutes played. `onboarding_v4` (#1894) keeps its numbering.
- Phone, tablet, desktop and console: the strip uses the goal card's width and font. Its list fits on a phone without scrolling (eight 28 px rows).

## 2. The first "wow" cat (#1897)

- **Trigger:** the player's **second bait result**. With the 10-minute bowl wait that lands at about 15 to 25 minutes, the target window. If the first-bait speed-up from the research list ships, the second result still lands at about 15 minutes. If a player hasn't had a second bait result by 30 minutes of play, the guarantee moves to their next bait result, whenever it comes.
- **The roll:** that one result is Rare or better. Roll the bowl's normal odds; if it gives Common, take Rare instead (85% of the time) or Epic (15%). Everything else about the arrival is normal.
- **Honest preview:** while that bait is in the bowl, the bowl card says "Your next cat will be Rare or better!". It's true, it builds anticipation, and it isn't a paid random item, because bait is bought with coins only.
- **The moment:** the arrival plays the F89 rare-moment effects (rarity-coloured burst and banner) with "Your first Rare!" (or Epic). If the player already owns a cat of that rarity, it reads "A Rare visitor!".
- **Once per account:** save `firstWow = true` (same version bump as section 1c). The funnel step `first_wow_cat` is added as `onboarding_v4` step 46 (v4 from #1894 is v3's 37 steps plus 8), with field rarity.
- Odds for every other roll and every other player stay the same, and the bowl's odds list is unchanged.

## 3. QA checks
1. A fresh account sees "Grand Opening 0/8" when the tutorial ends, and each step pays once, with its toast.
2. Doing steps out of order pays both, and the card highlights the lowest unfinished one.
3. After step 8 the Grand Opening banner plays once and the strip never returns. A Tier 3 or higher account never sees it.
4. A fresh account's second bait result is Rare or better, with the preview line and the rare-moment effects. The third result uses normal odds.
5. Rejoining between the bait set and its result keeps the guarantee, and it never happens twice.
6. Pace.spec: Tier 2 and Tier 3 times move by under 5% with the rewards. The phone and desktop playtest shows no new console errors.

## 4. Filling the Tier 2 dead window (#1896, from QA-Planner's audit in PR #1907)

QA's first-hour sim (`docs/playtests/2026-11-06-first-hour.md`) found buys come in bursts and then nothing is affordable for 20 to 30 minutes. That window is Tier 2: the last Tier 2 item costs 25,000 (the Basic to Steady net) and the next coin goal is Tier 3 at 700,000. Decided 2026-11-06 by Design-Agent under Derek2's go-ahead:

- **Two existing upgrade levels move down into Tier 2.** Tier 2's caps go from `tables = 4, espresso = 3` to `tables = 5, espresso = 4` (Catalog.tiers). So Tables level 5 and Espresso level 4 can be bought at Tier 2. No new items, art or remotes.
- **Their prices are re-fitted** so the Pace.spec median buys Tables 5 at about minute 22 and Espresso 4 at about minute 42 (QA's dead windows at 20 to 25 and around 45). Today's prices (200,000 and 400,000) are the starting point. Gameplay-Engineer fits them; Tier 3 players see the same price.
- **Tier 3's cost goes up to compensate.** Both buys raise income, so Tier 3 would come sooner. Gameplay-Engineer raises Tier 3's `cost` in Catalog.tiers (700,000 today) until the Tier 3 median sits at 45 to 55 minutes with the 10th percentile at 35 minutes or later, which also pulls up QA's fast runs near 20 minutes. Tier 2 (30,000) doesn't change.
- **Targets for Pace.spec "The first hour (#1896)":** the median longest gap between shop buys is 12 minutes or less, and with new cats and roadmap milestones counted it's 6 minutes or less. The 4-minute `xit` stays as the long-term goal.
- **Tier 2 at 10 to 20 minutes stays** the guard, and Tier 3 at 40 to 60 is the "big rank-up" moment. That is Grand Opening step 8 (section 1), so QA's reading of the issue matches the roadmap.
- **It fits the roadmap.** Steps 5 to 7 (a Park catch at about 20 minutes, a full cafe at about 30 and ten cats at about 40) already land in the same window as non-coin goals. With the two buys, something new happens about every 5 to 10 minutes from minute 15 to 50.
- Rank-up screen (RankUp.luau): it lists the next tier's unlocks from `requiresTier`, so Tables 5 and Espresso 4 drop out of Tier 3's list and appear in Tier 2's automatically. UI-Engineer checks that the Tier 2 card still fits.
- Claim: `shared/Catalog.luau` (tiers, caps and upgrade costs only; no Config change). Gameplay-Engineer opens it.

### 4a. Fitted numbers and the third buy (2026-11-06, Gameplay-Engineer's PR #1912, 20 Pace runs)
- **Fitted:** Tables 5 costs 170,000 and is bought at a median of 22.4 minutes. Espresso 4 costs 700,000, bought at 42.4. Tier 3 costs 900,000, with a median of 49.8 minutes and the fastest tenth at 37.9. Tier 2 lands at 12.1.
- **Still short:** the median longest gap is 16.1 minutes, against the target of 12. Counting new cats it is 10.7, against 6. A dearer Tier 3 lengthens the save before it, so the gap sits between minutes 22 and 42.
- **Decided: a third buy in that gap.** Lucky Cat level 3 moves into Tier 2 (cap `lucky_cat = 3`), priced so the median buy lands at about minute 32. It adds Luck, not income, so Tier 3 hardly moves. Re-check Tier 3 and keep its median at 45 to 55 minutes.
- **Count the roadmap in the "something new" gap.** Grand Opening steps (section 1) pay a reward and play a toast, so the Pace model counts them along with new cats. Steps 5 to 7 land at about 20, 30 and 40 minutes.
- The targets stay at 12 and 6. If they're still missed after these two changes, the guard keeps today's 18 and 12, and Design looks again with live data from the `grand_opening` funnel instead of the model.

### 4b. Second fit (PR #1917) and the roadmap re-time
- **Logged:** Lucky Cat 3 at Tier 2 costs 300,000 and is bought at 31.2 minutes. 600k pushed Tier 3 to 60 minutes. Tier 3 now lands at 54.3 minutes (fastest tenth 47.2), Tier 2 at 12.1, Tables 5 at 22.4 and Espresso 4 at 41.5. The longest gap is 15.7 minutes for buys and rank-ups, and 11.0 counting new cats and roadmap steps. The guard passes, and the 12 and 6 targets stay as the `xit`.
- **Decided:** roadmap steps 6 and 7 are re-timed into the gap (table in §1a). Step 6 needs every role slot filled at Tier 2 or above. Step 7 needs 12 different cats, which is also Tier 3's need, so it shows real progress toward the rank-up.
- After this re-run, no more model tuning. The next look uses the live `grand_opening` funnel (step times by player) and the `onboarding_v4` drop-off.
- **Re-run in PR #1917, middle of 20 runs (minutes):** step 1 at 1.3, step 2 at 12.3, step 3 at 8.3, step 4 at 12.1, step 5 at 14.9, step 6 at 12.1 (it lands on the Tier 2 rank-up, so the two toasts play together), step 7 at 25.0 (10th to 90th percentile 17.2 to 30.4) and step 8 at 54.3. The quiet stretch from minute 31 to 41 has the Lucky Cat and Espresso buys in it. Live data decides any further change.

## 5. Index: where to find the missing cats (#1919)

The Index already shows silhouettes and "lives in the <Area>" (F97, CatCollection). This section adds a clear "how" and a first-hour nudge. Builder: UI-Engineer. Nothing is sold, and odds don't change.

- **The hint line.** A missing cat's description slot ("Not found yet") becomes one line built from data that already exists:
  - Its area is open: "Not found yet. Catch one in the <Area>, or it may come to your bait." Bait picks from every open area (data-model §8), so the line is true.
  - Its area is still locked: "Not found yet. The <Area> opens at Tier n."
  - Epic and above add: "Shy: walk up slowly." That matches the Skittish mood from Catch v3 (catch-rework.md §7a).
  - Shop-only cats keep their current line.
- **Count on the reveal.** The new-cat reveal card (and the Tame card for a bait cat) gets one small line, "Park 4 / 10", in the area's colour. The Index button's dot behaves as it does today.
- **Goal-card nudge.** While Grand Opening step 7 (twelve cats, §1a) is the next step, the goal card reads "Find N more cats" with an Index icon. Tapping it opens the Index on the page of the newest open area with the most missing cats.
- **Funnel:** `index_hint_tap` (with area) when that goal card opens the Index.
- **QA:** a missing Park cat at Tier 2 shows the catch-or-bait line, and a missing Woods cat shows "opens at Tier 4". The reveal shows the right count. The nudge appears only while step 7 is next and opens the right page.

## 6. A session recap card at about 40 minutes (#1920)

The research's end-of-session hook. A Roblox game can't show anything as the player leaves, and the Roblox menu covers our UI. So the card comes once per session, at a calm moment late in the first hour. It also has to help the player stay, so it leads with what's next. Builders: UI-Engineer (the card) and Gameplay-Engineer (the timer and the lines).

- **When:** once per session, after 40 minutes of play in this session (`RecapAfterSeconds` 2400), and after the tutorial. It waits until the player isn't catching, carrying, in a minigame or in a menu, and has been idle for 5 seconds. It never shows twice in a session, and Settings has a "Session recap" toggle that defaults to on.
- **The card:** a small card that slides up from the bottom, with no dark background, a close button and a 12 second auto-hide. Up to four lines, each shown only when it's true:
  1. "Today: N new cats, $X earned", for this session.
  2. What's next: "Grand Opening 6/8: Twelve different cats", or after the Grand Opening, the goal card's next goal.
  3. "Your bait cat arrives in M min. It waits for you", when bait is cooking.
  4. "Your cafe earns while you're away: 50% for up to 8 h" (from `OfflineRate` and `OfflineCapSeconds`, or the pass values when owned), then "Tomorrow: Daily Treat day D and new quests".
- **Rules:** there's no countdown, no "don't leave" or "you'll lose" wording, and no store link. Leaving loses nothing.
- **Funnel:** `session_recap` with the minutes played and the step the player is on, and `session_recap_close` with how long it was up.
- **QA:** a fresh account sees the card once, at about 40 minutes and only when idle. It never shows during a catch or carry. Each line appears only when it's true, and the offline line matches Config and the pass. With the toggle off, nothing appears.

### 4c. Re-fit after Catch v3 (PR #1917, 2026-11-06)
Catch v3 (#1910) made catching easier to recover, which sped up the first hour: Tier 3 at 56.2 minutes and Espresso 4 at 46.6. Gameplay-Engineer re-fitted two prices (a forced re-fit, not new tuning): **Espresso 4 costs 550,000** (was 700,000) and **Tier 3 costs 800,000** (was 900,000). Middle run: Tables 5 at 22.6 minutes, Lucky Cat 3 (still 300,000) at 30.9, Espresso 4 at 42.6, Tier 2 at 11.7 and Tier 3 at 53.8 (fastest tenth 36.0). Pace.spec passes. These numbers replace the ones in §4a and §4b.

### 4d. One more cheap buy for the quiet windows (2026-11-07, QA-Planner's pre-release list, item 6)
After the §4c re-fit, the coin buys land at about 11.7 (Tier 2), 22.6 (Tables 5), 30.9 (Lucky Cat 3), 42.6 (Espresso 4) and 53.8 (Tier 3) minutes. The longest gaps are about 11 minutes, from 11.7 to 22.6 and from 30.9 to 42.6. Coin decor is never sold (F97), so the only cheap buys are upgrade levels.

- **Bait Bowl level 3 moves into Tier 2.** The Tier 2 cap changes from `lure_bowl = 2` to `lure_bowl = 3` (Catalog.tiers). Its price drops from 240,000 to a fitted price of about 70,000, so the median buy lands at about minute 17. That splits the first gap in two. The Bait Bowl makes bait faster and luckier and adds no income, so Tier 3 barely moves. No new items, art or remotes.
- **Second buy, only if the model still shows a long gap:** if the median gap from Lucky Cat 3 to Espresso 4 is still over 10 minutes after the change above, Gameplay-Engineer moves the Bait Bowl 3 buy into that window instead, at about 150,000 and about minute 36. In that case the gap from Tier 2 to Tables 5 is left as it is. Use one placement or the other, never both.
- **Guards stay:** Tier 2 at 10 to 20 minutes, and Tier 3's median at 45 to 55 with the fastest tenth at 35 or later. If Tier 3 slips past 55, lower its cost a little instead of moving the bowl again.
- **New Pace.spec target:** the median longest gap between coin buys is **10 minutes or less** (it was 12). Counting new cats and roadmap steps, the 6-minute target stays.
- **Rank-up screen:** Bait Bowl 3 moves from Tier 3's unlock list to Tier 2's on its own (`requiresTier`). UI-Engineer checks that the Tier 2 card still fits.
- **Claim:** `shared/Catalog.luau` (tier caps and the `lure_bowl` cost only). Builder: Gameplay-Engineer.
- **QA:** a fresh account can buy Bait Bowl 3 at Tier 2 and can't before it. A player who already bought it at Tier 3 keeps it, with no refund or change. Pace.spec passes the new target.

### 6a. One reason to come back tomorrow (2026-11-07, Derek2's pick of item 11)
The D1 return rate is the launch number, and Home recommendations follow it (release.md). Two small changes, using lines and screens that already exist, with no new systems:

- **A first-session recap at 15 minutes.** Most first sessions end before 40 minutes, so a player's first session shows the recap card after 15 minutes (`RecapFirstSessionSeconds` 900). Later sessions keep `RecapAfterSeconds` 2400. The calm-moment rules, once per session, the toggle and the 12 s auto-hide are unchanged.
- **One "Tomorrow" line, picked in this order:** line 4 of the card names the single best thing waiting:
  1. "Your bait cat will be waiting for you", if bait is cooking and will be ready after the player leaves.
  2. "Tomorrow: Daily Treat day D, PRIZE", naming the next day's prize from the Daily Treat table (for example "2 Cat Snacks"), if tomorrow's treat isn't claimed yet.
  3. "Tomorrow: new daily quests", otherwise.

  The offline income line ("Your cafe earns while you're away: 50% for up to 8 h") stays as its own line above it. The card still has no countdown, no "you'll lose" wording and no store link.
- **The welcome back card shows the same thing.** On rejoin, the existing welcome back card (offline earnings, F95) gets one line under the coins, picked in the same order but in the present tense: "Your bait cat is ready!", "Daily Treat day D is ready", or "New daily quests are here". It's worked out on join from the save (bait ready time, `dailyTreat` day and claim, quest reset), so nothing new is saved. If none of these is true, the line is left out.
- **Funnel:** `session_recap` gains `tomorrow` (`bait`, `treat` or `quests`). A new `welcome_back_hook` event has the same value, so Monetization-Agent can check whether players with a named hook return more.
- **Builders:** UI-Engineer (the card line and the welcome back line). Gameplay-Engineer adds the 900 s Config value and the pick, as a pure function `ReturnHook.pick(profile, now)` with a spec.
- **QA:** a fresh account sees the recap at about 15 minutes in its first session and at 40 minutes in later sessions. The Tomorrow line follows the order above. Rejoining the next day shows the matching welcome back line. Nothing shows a timer or the store.

