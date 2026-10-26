# Review: F26 net circles (PR #40)

Reviewer: luau-reviewer thread, 2026-10-26 about 19:35 UTC, on engineer commit 5f992ba only (the PR also carries the #38 branch). Read only; no game files changed. Checked against data-model v0.3.1 section 10 and `2026-10-26-design-v0.3.1.md`. Also checked: N36 on #38 is fixed in b546bf5.

## Verdict

The judging is right and S23 and S24 are in. One should-fix (S33): walking out of range before the last circle turns a failed catch into a free retry, so rare cats never have to flee. Two nits. CI on 7206995 is red only in client files that wait on the UI commit: `src/client/UI` and the three calls into the new `CatchPrompt` API in `UIController`. Server and shared code type-check clean.

## Checked and fine

| Rule (data-model 10) | Where | Result |
|---|---|---|
| Server owns the schedule | `Circles.schedule`, `onGrabBegin` | Built from the server RNG and `GetServerTimeNow`, then sent once. The client sends only `(strayId, index)`; extra arguments are ignored. |
| Press stamped on arrival, half ping capped | `onCatchPress`, `Circles.latency` | `arrival - min(GetNetworkPing() / 2, 0.15)`. A negative or NaN ping counts as 0. |
| In order, first press only, not before start | `Circles.press:148` | Expires overdue circles first. Then it ignores any index other than `nextIndex`, and any press before the circle starts. A judged circle advances `nextIndex`, so a repeat press does nothing. |
| S24 gap | `Circles.schedule`, `Config` | The next circle starts at the previous target plus a gap of at least 0.40. A deadline is target + good + 0.15, at most 0.33 after the target. A press for circle i + 1 can only be judged after circle i has expired, because `expire` runs on the arrival time and the press must be at or after the start. |
| S23 server numbers only | `recordCircles`, `Circles.looksScripted:207` | History is the server's grades for the last 50 circles, with expired circles counted as misses. The flag is above 95% and `profile.flags.autoPress` is kept for review only. It is not in `buildState`, so a scripter is not told. |
| No restart, no double finish | `onGrabBegin`, `finishCatch` | A live lock refuses every GrabBegin, the holder's own included. `finishCatch` checks `stray.attempt == attempt` and clears it before anything else, so the timer and the last press cannot both resolve. The timer fires after the last deadline, so every circle is judged before the mean is taken. |
| Carry wins (S21) | `finishCatch` | Still refuses while carrying. |
| Leaving | `PlayerRemoving` | Drops the history and every lock the player holds, and `setLock(0)` clears the attempt. |
| Rate limits | `Net.luau` | GrabBegin 1 per 2 s per player; CatchPress on the default 10 per second. |

## Findings

**S33 (should-fix) Leaving range before the end skips the flee.** In `finishCatch` (`CatService.luau:672`), a player out of range when the last circle resolves gets "Too far away" with retry, and no roll happens. A failed catch on anything rarer than Common is meant to make the cat flee. A player whose presses went badly can step back a few studs before the last deadline (or a script can move the character, whose position the client owns) and keep the cat for another try. Every rare stray then becomes a free retry, which undoes the flee rule. Fix: drop the range check at the end (range was checked at GrabBegin, and the circles are only UI), or treat being out of range as a failed catch, so Commons stay and rarer cats flee.

**N37 (nit) GrabRetrySeconds is not used.** After a failed Common, `setLock(stray, 0)` frees it at once. The GrabBegin limiter (1 per 2 s) has refilled by then, because the catch took longer than 2 s. So a script can re-lock the same Common the instant it frees and keep other players off it. Make GrabRetrySeconds (2) a wait for the player who just failed, on that stray only, so others can grab it straight away. This is the same pattern as S28 for traps.

**N38 (nit) The CatchPress index bound is the rarity count.** `Guard.int(rawIndex, 1, #Catalog.rarityOrder)` (`CatService.luau:767`) allows indexes 1 to 5, which only matches because Mythical has 5 circles. If a rarity ever gets a sixth circle, its presses are dropped and the circle always scores 0. Bound the index by the largest `circles` in `Catalog.rarities` (or the attempt's own `#circles`).

## For QA

The S24 rule (`CircleGapMin > max good + CatchLatencyCapSeconds`) should be a Config spec, so widening a net's `good` window fails the tests. `Circles` is pure and takes a roll function, so the spec can cover in-order judging, early presses, expiry and the 50-circle flag deterministically. The abuse client's `GrabEnd` case now targets a remote that no longer exists. Replace it with CatchPress spam (out of order, repeated, index 0 and 99, strings) and a second GrabBegin during a catch.

## Build checklist status

Done: S23 and S24 (net), S31 (save), N36. Open on this PR: S33. Still to build: S25, S26, S32 and N29 (bump), S27 and N32 (dealer), S28 (rescue), S29 (rich tip), S30 and N35 (rename), N30 (bait reveal), N37, N38.
