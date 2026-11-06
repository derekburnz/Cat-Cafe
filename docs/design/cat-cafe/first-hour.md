# The first hour: the Grand Opening roadmap and a first "wow" cat (#1893, #1897)

Status: specced 2026-11-06 by Design-Agent (friend's project), from Derek2's ask the same day: "focus on things to try and keep the players staying passed the 10min mark ideally at least till 1h". Research: Research-Agent's `first-hour-retention-2026-11-06.md` in the library. That covers Roblox's onboarding advice to show short, mid and long goals before onboarding ends and to finish with a moment of joy. Builders: Gameplay-Engineer (milestone checks, payouts, the wow roll, save), UI-Engineer (the roadmap card, toasts), VFX-Agent (it reuses the F89 rare-moment effects). The catch minigame (#1884) is unaffected.

Rules for both parts: nothing is sold and there are no timers or "limited" words. Leaving loses nothing, and odds for everyone else stay exactly as they are.

## 1. The Grand Opening roadmap (#1893)

The tier pace is Tier 2 at about 15 minutes and Tier 3 at about 50 (economy-ladder.md). The roadmap turns that into eight visible steps, so a player always sees the next goal (the goal card), the next milestone (the roadmap) and the big payoff at the end.

### 1a. The milestones

Each milestone is read from the profile, so it needs no new tracking, and each one matches an `onboarding_v3` step.

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
- Funnel: custom event `grand_opening` with field step (1 to 8) and minutes played. `onboarding_v3` keeps its numbering.
- Phone, tablet, desktop and console: the strip uses the goal card's width and font. Its list fits on a phone without scrolling (eight 28 px rows).

## 2. The first "wow" cat (#1897)

- **Trigger:** the player's **second bait result**. With the 10-minute bowl wait that lands at about 15 to 25 minutes, the target window. If the first-bait speed-up from the research list ships, the second result still lands at about 15 minutes. If a player hasn't had a second bait result by 30 minutes of play, the guarantee moves to their next bait result, whenever it comes.
- **The roll:** that one result is Rare or better. Roll the bowl's normal odds; if it gives Common, take Rare instead (85% of the time) or Epic (15%). Everything else about the arrival is normal.
- **Honest preview:** while that bait is in the bowl, the bowl card says "Your next cat will be Rare or better!". It's true, it builds anticipation, and it isn't a paid random item, because bait is bought with coins only.
- **The moment:** the arrival plays the F89 rare-moment effects (rarity-coloured burst and banner) with "Your first Rare!" (or Epic). If the player already owns a cat of that rarity, it reads "A Rare visitor!".
- **Once per account:** save `firstWow = true` (same version bump as section 1c). The funnel step `first_wow_cat` is added as `onboarding_v3` step 38, with field rarity.
- Odds for every other roll and every other player stay the same, and the bowl's odds list is unchanged.

## 3. QA checks
1. A fresh account sees "Grand Opening 0/8" when the tutorial ends, and each step pays once, with its toast.
2. Doing steps out of order pays both, and the card highlights the lowest unfinished one.
3. After step 8 the Grand Opening banner plays once and the strip never returns. A Tier 3 or higher account never sees it.
4. A fresh account's second bait result is Rare or better, with the preview line and the rare-moment effects. The third result uses normal odds.
5. Rejoining between the bait set and its result keeps the guarantee, and it never happens twice.
6. Pace.spec: Tier 2 and Tier 3 times move by under 5% with the rewards. The phone and desktop playtest shows no new console errors.
