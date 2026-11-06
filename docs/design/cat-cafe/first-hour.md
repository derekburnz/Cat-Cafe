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
| 6 | A full cafe | every role slot of the tier filled at once | 1 spin | 30 min |
| 7 | Ten different cats | 10 distinct cats owned | 10 golden fish | 40 min |
| 8 | **Grand Opening!** Rank up to Tier 3 | `tier` 3 | 50 golden fish, 1 crate of the highest zone and the "Grand Opener" chat tag | 50 to 60 min |

- In total it pays 80 golden fish, 2 spins, 1 potion and 1 crate over the first hour. That's under one Fish Market crate's worth (40 fish) per 30 minutes, so the economy hardly moves. The tag is the keepsake.
- Milestones can finish in any order. A player who ranks up before buying a fifth cat still gets both. The card always highlights the lowest unfinished one.

### 1b. The card
- It appears when `tutorialStep` reaches 5 (the tutorial's end), just under the goal card, as one compact strip: "Grand Opening 3/8" with eight small dots, done ones filled gold.
- Tapping the strip opens it in place as a short list: done steps ticked with their reward, the next one highlighted, later ones shown plainly. There are no timers and no locks. Tapping again closes it, and the open or closed state is remembered (`roadmapOpen` setting).
- When a milestone finishes, its dot pops gold and a small toast slides in ("Grand Opening 4/8: Tier 2! +10 golden fish") with a short confetti puff. The reward is paid at once, with no claim button and no going back.
- After milestone 8, the Grand Opening plays a bigger moment once: a banner "Your cafe's Grand Opening!", a confetti burst over the cafe and the tag. Then the strip goes away for good.
- Accounts already at Tier 3 or above when this ships never see the card and get nothing back-paid, because the first hour is behind them.

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
- **Tier 3's cost goes up to compensate.** Both buys raise income, so Tier 3 would come sooner. Gameplay-Engineer raises `tierCosts[3]` (700,000 today) until the Tier 3 median sits at 45 to 55 minutes with the 10th percentile at 35 minutes or later, which also pulls up QA's fast runs near 20 minutes. Tier 2 (30,000) doesn't change.
- **Targets for Pace.spec "The first hour (#1896)":** the median longest gap between shop buys is 12 minutes or less, and with new cats and roadmap milestones counted it's 6 minutes or less. The 4-minute `xit` stays as the long-term goal.
- **Tier 2 at 10 to 20 minutes stays** the guard, and Tier 3 at 40 to 60 is the "big rank-up" moment. That is Grand Opening step 8 (section 1), so QA's reading of the issue matches the roadmap.
- **It fits the roadmap.** Steps 5 to 7 (a Park catch at about 20 minutes, a full cafe at about 30 and ten cats at about 40) already land in the same window as non-coin goals. With the two buys, something new happens about every 5 to 10 minutes from minute 15 to 50.
- Rank-up screen (RankUp.luau): it lists the next tier's unlocks from `requiresTier`, so Tables 5 and Espresso 4 drop out of Tier 3's list and appear in Tier 2's automatically. UI-Engineer checks that the Tier 2 card still fits.
- Claim: `shared/Catalog.luau` (tiers and upgrades) and `Config.luau` if `tierCosts` lives there. Gameplay-Engineer opens it.
