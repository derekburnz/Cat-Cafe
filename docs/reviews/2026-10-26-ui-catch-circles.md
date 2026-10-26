# Review: v0.3 UI part 1 (PR #43) and the F26 fix round

Reviewer: luau-reviewer thread, 2026-10-26 about 21:55 UTC. Read only; no game files changed. Covers the two `ui:` commits on PR #43 (c32e353 and 01a2761, on top of 92957ff) and the engineer's fix commit c452ccb on PR #40. Follows `2026-10-26-net-circles.md`.

## PR #40 fix round (c452ccb)

| Finding | Result |
|---|---|
| S33 forfeit | Out of range, or carrying, at the end is now a failed catch with no roll. The normal fail path runs, so anything rarer than Common flees. Closed. |
| N37 retry wait | After a failed catch the stray stays, and `retryUserId` / `retryUntil` make only that player wait GrabRetrySeconds. `lastCatchStart` spaces catch starts per player, and a player can run only one catch at a time. Closed. |
| N38 index bound | CatchPress is bounded by `MAX_CIRCLES`, the most circles any rarity has. Closed. |

No findings are open on F26's server side.

## PR #43: verdict

Sound, and view-only as the UI contract requires. No blocker or should-fix. One nit for the engineer and the UI thread together. The red unit-test job on 01a2761 is the shared-spec failures that #38 fixed with its QA commit (0d62d45), not this diff; it should clear when #43 takes main.

## Checked and fine

- **No time leaves the client.** `CatchCircles.show` takes an `onPress(index)` callback, and `init.luau:682` fires `events.catchPressed(strayId, index)` and nothing else. The local grade drawn on press is only a hint, and `showResult` replaces every circle with the server's score.
- **Same order as the server.** `_press` (`CatchCircles.luau:499`) runs `_expire` first, ignores a press before the circle's start without using it up, and moves to the next circle after one press. `_expire` (`:483`) treats a circle as missed after target + good + CatchLatencyCapSeconds, the server's deadline. If the client and the server disagree near a deadline (one-way latency), the server ignores the press and both sides count a miss, so the next press still goes to the same circle on both.
- **Rank up is a request.** The card works out the requirements only to light the button, and `events.rankUp` carries no arguments. The server has to check everything again when RankUp is built (F24).
- **Shiny.** The prompt and the circles header read the stray's `Shiny` attribute. The server never sets it on a stuck cat before the rescue (N30), so the reveal is not spoiled.
- **No RichText** anywhere in the client, so a cat name with `<` or `>` cannot inject markup (S30 still rejects them on the way in).
- **Leaks and mobile cost.** One RenderStepped connection while the circles are up, disconnected in `hide`, and `hide` runs at the start of every `show`. At most five circles resize per frame. Views are destroyed on hide, the press action is unbound on hide and on the result, and a missing result hides the overlay after 4 s. Cheap on a phone.

## Nit

**N39 (nit, engineer and UI) The client guesses whether the stray stayed.** `UI.catch.showResult` (`init.luau:693`) shows "Missed, try again" only for a Common and "It got away" for every other rarity. That is already wrong for a lured stray that stays, and it will be wrong for every dropped stray once bumps land, because S26 says a dropped cat never flees. The server knows the outcome, so add a `stayed` boolean to `CatchResult` and let the UI read it, rather than rebuilding the rule on the client.

## For QA (phone)

During the circles a full-screen tap layer sits above the touch thumbstick and jump button, and Space is sunk. A player cannot move while catching, which suits S33 (walking out of range forfeits). On a phone, check that the controls come back after the result banner and after the 4 s no-result timeout.

## Build checklist status

Done: S23, S24, S31, S33, N36, N37, N38. Open: N39. Still to build: S25, S26, S32 and N29 (bump), S27 and N32 (dealer), S28 (rescue), S29 (rich tip), S30 and N35 (rename), N30 (bait reveal).
