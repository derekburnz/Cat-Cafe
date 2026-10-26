# Review: PR #3 (review fixes), PR #4 (cat stats) and PR #5 (UI ring bands)

Date: 2026-10-26, 11:50 UTC. Reviewer: luau-reviewer thread. Follows `2026-10-26-first-pass.md` (carried into the repo by PR #3).

Scope: PR #3 `engineer/review-fixes` (c535c36, base `lead/repo-docs-and-ci`) against the first-pass findings, plus the two PRs stacked on it: PR #4 `feature/cat-stats-equip-best` (190ef62) and PR #5 `ui/ring-config-shared-types` (cfd325c). Method: read in a repo clone, CI logs from the `check` workflow, StyLua and selene run locally on the branch export. Severity as before: blocker, should-fix, nit.

## Verdicts

| PR | Verdict | Why |
|---|---|---|
| #3 | Runtime fixes verified. Not mergeable until the gate is green. | luau-lsp in CI reports 20 strict type errors in 6 files (table below). Every first-pass item the PR claims is implemented correctly. |
| #4 | Sound. Two small fixes and a merge note. | Offline XP sentence in the doc does not match the code (S13); `EquipBest` remote needs a slow bucket (S14); `docs/decisions.md` will conflict with PR #5 (S15). No new CI errors of its own. |
| #5 | Sound. One Studio check. | S2 and S9 closed as described. The HoldEnded event path still needs a Studio check (S12). No new CI errors; removes one. |

The PR author and the reviewer post from the same GitHub account, so GitHub will not accept a formal approve or request-changes review. The verdicts here and in the PR comments are the record.

**Update 12:00 UTC:** PR #3's gate went green at 6a8a5ba and the lead fast-forwarded its base onto it, so PR #3 is inside PR #1 (green, waiting on Derek). PR #4 and PR #5 merged that head and are green. Details in the follow-up at the end.

## PR #3: first-pass items

| Item | Status | Evidence |
|---|---|---|
| B1 carried cat lost on leave | Fixed | `DataService.luau:123-137` fires `onReleasing`, runs `finalize` under pcall, then forgets the session and ends it. `finalize` (`:47-70`) runs each finalizer under its own pcall before settling, so one bad finalizer cannot skip the save. `CatService.luau:676-681` hands the profile to `finishCheckIn`, which passes it to `CafeService.addCaughtCat` (`CafeService.luau:229-245`); that settles the passed profile instead of looking it up. Handler order checked: PlotService releases the plot first (its `PlayerRemoving` is connected first), so `refreshPlot` returns early on the leave path (`CafeService.luau:201-206`); the cat is already in `profile.cats` by then and nothing leaks. `BindToClose` uses the same `release`. |
| S1/S2 ring scored on the server | Fixed | `GrabEnd` carries only the stray id (`Remotes.luau:14`, `CatService.luau:507-532`). `Catching.ringResultFromHold` (`Catching.luau:19-37`) matches data-model section 10: nil under 0.15 s (dropped, lock kept), miss to 0.70, good to 1.20, perfect to 1.75, miss after. QA's spec covers every boundary. The 1.75 s auto-resolve (`CatService.luau:483-499`) is keyed on `stray.lockAt == lockAt`, so a GrabEnd that already cleared the lock, a despawn or a fresh lock all cancel it, and it drops the lock when the player left or the profile is gone. `resolveGrab` clears the lock before anything that could yield, so the two paths cannot both roll. One-way latency cancels between GrabBegin and GrabEnd; the 0.25 s grace covers jitter. |
| S3 Studio and live share one DataStore | Fixed | `DataService.luau:39` appends `_dev` under `RunService:IsStudio()`. |
| S4 autosave 300 s | Fixed | `DataService.luau:139` sets `AUTO_SAVE_PERIOD` to `Config.AutosaveSeconds`; the vendored ProfileStore reads the constant live (`ProfileStore.luau:2123-2138`). |
| S5 unclaimed offline coins vanish | Fixed | `DataService.luau:57-62` credits `pendingOffline` in `finalize` and zeroes it; `takePendingOffline` zeroes on claim, so no double credit. |
| S6 no per-player ceiling | Fixed | `Net.luau:18-25`: global bucket 30 per second per player, per-remote 10 per second, slow buckets GrabBegin 1 per 2 s, RequestSync and ClaimOffline 1 per 2 s, TutorialAdvance 1 per second. Client cadence checked: RequestSync once at start, CheckIn at most every 2 s while carrying, TutorialAdvance once (`WorldController.luau:64-85`), so honest play never trips them. All buckets forgotten on leave. |
| S10 carry cleanup depends on handler order | Fixed | `CatService.luau:692-697` clears the record only when the profile is already gone. |
| N6 handler errors kill the connection | Fixed | `Net.luau:88-105`: xpcall with traceback, logged once a second per player. |
| N10 out-of-range GrabBegin silent | Fixed | `CatService.luau:474-476` answers with a retryable GrabResult. |

## PR #3: the gate

The CI job "Rojo sourcemap, luau-lsp, Selene, StyLua" fails at the luau-lsp step, and `check.sh` stops there, so selene and StyLua have not run in CI yet. Locally on the branch export: StyLua clean (`Vendor/` is in `.styluaignore`), selene clean apart from shadowing warnings the repo config allows. The cloudcheck job passes (175 tests, 0 errors) because its WebAssembly type checker and luau-lsp 1.70.0 disagree on the rules below. CI is the gate (CLAUDE.md rule 6), so these block the merge even though none is a runtime bug. All are a cast or an optional annotation:

| luau-lsp error | Where | Fix |
|---|---|---|
| `Types X and nil cannot be compared` (indexing a `{ [K]: Instance }` map gives a non-optional type under this solver) | `Net.luau:77, 111, 119`; `PlotService.luau:29`; `CafeService.luau:100, 124, 144, 150, 178`; `CatService.luau:568, 636` | Annotate the local as optional, `local event: RemoteEvent? = events[name]`, or type the map values as optional |
| `Function only returns 1 value, but 2 are required` | `DataService.luau:51, 130` (`pcall(fn, ...)` where `fn` returns nothing) | The wrapper Net already uses: `pcall(function() fn(player, profile) return nil :: any end)` |
| `Expected Rarity, got string \| string \| ...` | `Catching.luau:71` (`return rarity` while iterating the odds map); `CatService.luau:274, 641` are its callers | `return rarity :: Types.Rarity` in `pickRarity`; the callers then pass |
| `Expected RingResult, got string` | `CatService.luau:532` (`ring` after the nil check) | `resolveGrab(player, profile, stray, ring :: Types.RingResult)` |
| `Expected string, got string?` | `CafeService.luau:294` (`carrying[player] = catId`) | `local carrying: { [Player]: string? }` |
| `Expected boolean, got boolean?` | `CafeService.luau:468` | Type `decorPlaced` values as `boolean?`, or assign `true` in one branch and `nil` in an else |
| `LocalUnused: catalog` | `UI/init.luau:66` | Already removed in PR #5 |

Tooling note for the lead: a PR cannot carry "0 type errors" from cloudcheck and 20 from CI at the same time. Either cloudcheck adopts the same solver rules as the pinned luau-lsp, or PR descriptions quote CI's number only. Until then, the two numbers will keep disagreeing on exactly this class of error.

## PR #3: new findings

**S12 (should-fix, verify in Studio) Completed-hold detection depends on event timing.** `UIController.luau:167-176` suppresses the GrabEnd when the client clock says the hold ran at least 1.5 s. If the engine fires `PromptButtonHoldEnded` before `PromptTriggered` on a completed hold (the order is not documented), `finishHold` in `UI/init.luau:691-697` fires `grabEnded` first, and only that clock comparison stands between a full hold and a GrabEnd the server scores as perfect (1.5 s sits inside the 1.20 to 1.75 s window). Impact: a full hold sometimes scores perfect instead of miss; an exploiter gains nothing they cannot already get by timing. PR #5 closes the `PromptTriggered` path but not this one. Fix: in the PR's test plan step 1, hold to the end on a real client and confirm the server receives no GrabEnd (a temporary print in `onGrabEnd`). If it does, make the HoldEnded handler defer one frame with `task.defer` and skip `grabEnded` when `PromptTriggered` arrived in between; the 16 ms sits inside the grace.

**N11 (nit)** The `lockExpired` "Too slow" branch in `onGrabEnd` (`CatService.luau:517-521`) is unreachable now that the 1.75 s timer clears the lock long before 3 s. Keep as a belt, or drop.

**N12 (nit)** `DataService.luau:159`: the `OnError` callback parameter `storeName` shadows the module local of the same name. Rename to `erroredStore`.

**N13 (nit, designer's call)** A GrabEnd dropped as spam (under 0.15 s) leaves the client prompt already closed while the server resolves 1.6 s later; the late GrabResult goes through `UI.catch.fail`, which copes, but the player sees a result with no prompt on screen.

## PR #4: cat stats and equip best

Checks out: F1 is closed (`Economy.catRate` uses `CatStats.rating`, so the server pays what the UI shows). Every `CatInstance` construction site sets the new fields (template and `addCaughtCat` through `CatStats.newInstance`, `migrate` with defaults and clamps). `CatStats.addXp` loops level-ups and caps at the max level. The Hungarian is rectangular (at most 7 spots by `max(cats, 7)` columns), so a large collection costs about 49 x N, not N cubed. The plan only uses open spots and owned cats, and nothing is spent, so the handler's single "profile loaded" check is right. Charm is rolled on the server. `prestigeMultiplier` guards NaN and negatives. The specs test the solver against brute force. CI: no new luau-lsp errors beyond PR #3's (line numbers shift). StyLua clean.

**S13 (should-fix) Doc and code disagree on offline XP.** data-model.md section 4b says "offline time while placed counts too", but `DataService.load` sets `profile.lastTick = now` before anything settles (on purpose, so the offline gap is never paid at the online rate), so `Economy.settle` never sees that gap and `grantPlacedXp` never runs for it. Pick one: change the sentence to "offline time earns no XP", or grant `offlineSeconds` (already capped at one hour by `Economy.offlineGain`) in `load`. The doc change is the safer one: full-rate XP for time away while coins pay 25 percent is generous and untested.

**S14 (should-fix) `EquipBest` needs a slow bucket.** `Net.luau` gives GrabBegin, RequestSync, ClaimOffline and TutorialAdvance their own buckets; `EquipBest` falls to the default 10 per second, and each call sorts the collection, solves, rebuilds the plot models (`refreshPlot`) and sends a full sync. Add `EquipBest = RateLimiter.new(1, 2)` to `slowLimiters` (engineer's file; a one-line ask on PR #3 or a follow-up).

**S15 (should-fix, merge mechanics)** PR #4 and PR #5 both append a new block at the end of `docs/decisions.md`. Whichever merges second conflicts. Trivial to resolve, but someone has to.

**N14 (nit)** `Economy.prestigeMultiplier` reads `(profile :: any).renovations` although `renovations` is now a typed field; keep the NaN guard, drop the cast so a rename is caught.

**N15 (nit)** `CafeService.catViews` builds a fresh table per sync (every 10 s plus every change). Fine at 8 players; worth remembering if syncs get more frequent.

## PR #5: UI ring bands and shared types

Checks out: S2 closed (`CatchPrompt.luau:46-50` derives good = {0, 0.533} and perfect = {0, 0.2} of the ring scale from Config, which is 0.70 to 1.50 s and 1.20 to 1.50 s of hold, the server's windows). S9 closed (`UI/Types.luau` re-exports the shared catalog types; UI state types stay local with optional stat fields, which also fits PR #4's `CatView`). The unused `catalog` local is gone, which removes one CI error. Demo uses the real catalog. `expire()` sends nothing on `PromptTriggered`, and `stopRing` returns a hint the controller ignores. CI: no new luau-lsp errors. StyLua clean.

S12 above applies here too: the `PromptButtonHoldEnded` path still fires `grabEnded`, so the Studio check decides whether the UI needs the one-frame defer.

## Still open from the first pass

- S7 (exclude `Vendor/` from the linters): closed on the base branch (`selene.toml` exclude, `.styluaignore`, luau-lsp `--ignore`).
- S8 (cloud shim), S9 (duplicate UI types), F1 (cat stats integration), F2 (`ringResultFromTiming`): closed by these PRs.
- S11 (Max Players 8): an experience setting in Studio, Derek's step.
- N8 (panel sizing): UI thread left it for the on-device pass.

Done gate as of this review: rojo sourcemap passes in CI; luau-lsp 20 errors (blocker, PR #3); selene and StyLua pass locally and have not yet run in CI; cloudcheck green; Studio playtest pending on Derek's PC.

## Follow-up 12:00 UTC

- **PR #3 gate: green at 6a8a5ba.** Commits 82f8566 and 6a8a5ba verified: optional annotations on the indexed Instance locals, the pcall wrappers in `DataService`, `Types.Rarity` on `Catalog.rarityOrder` and the `pickRarity` loop, `RingResult?` on the ring local, the `string?` carrying map, the `decorPlaced` assignment split, and two branch reorderings in `refreshDecor` and `refreshTables` that I checked case by case against the old conditions (same behaviour in all four cases each). `onUseLure` now destroys `active.bowl` instead of the captured local, the safer reference. Selene: the 11 refinement asserts got messages. The lead fast-forwarded `lead/repo-docs-and-ci` to 6a8a5ba, so PR #3's content is in PR #1, which is green on both jobs and waits on Derek. Ownership note: the assert messages and the dropped `catalog` local are in `src/client/UI/`, the UI thread's folder; PR #5 made the same `catalog` change independently and the merge was clean, so no harm done, but CLAUDE.md asks for a decisions.md note for edits outside your folder.
- **PR #4 at 2483a19** (engineer's head merged in): S13 closed by wording in data-model 4b and the `grantPlacedXp` comment (only settled online time earns XP, no offline grant). S14 closed: `EquipBest = RateLimiter.new(1, 2)` in `Net.luau` `slowLimiters`, recorded in the remotes table of data-model section 15. N14 closed: cast dropped, guards kept. 913243e drops a redundant nil check in `plan`. CI green on both jobs. S15 (the `decisions.md` append) still applies against PR #5.
- **PR #5 at 546f481** (engineer's head merged in): CI green on both jobs. S12 still open (Studio check in PR #3's test plan step 1, now PR #1's).
- **Gate rule from the lead:** CI's luau-lsp count is the number; cloudcheck is a pre-check that misses Instance-versus-nil comparisons, pcall return counts and singleton narrowing. The lead's thread has the real luau-lsp 1.70.0, rojo, selene and stylua binaries for a pre-push count.

| Item | Status |
|---|---|
| S12 completed-hold event order | Open, needs the Studio check |
| S13 offline XP wording | Closed in PR #4 |
| S14 EquipBest bucket | Closed in PR #4 |
| S15 decisions.md conflict | Open until the second of PR #4 and PR #5 merges |
| N11, N12, N13 | Open nits, engineer's call |
| N14 renovations cast | Closed in PR #4 |
| N15 catViews allocation | Noted |

## Follow-up 12:05 UTC: PR #7 (engineer/review-followups, d07bc45)

Sound, no blockers; CI green on both jobs. S12 closed: `UIController` records the engine's own `PromptTriggered` per stray (from the prompt's `StrayId` attribute, set by the server) and decides the GrabEnd in `task.defer` one frame later, so the full-hold case is caught whichever order HoldEnded and Triggered fire in; the clock test stays as a fallback and an honest release at 1.49 s goes up one frame late, inside the grace. N11 removed (`lockExpired` is still used by the spawn loop and `onGrabBegin`), N12 renamed. Nit: with PR #5's UI a full hold fires no `grabEnded`, so the two per-stray maps keep an entry until the next hold on that stray; a delayed cleanup in the `PromptTriggered` handler would keep them empty. N13 stays the designer's call. The Studio test plan on the PR (hold to the end with a print in `onGrabEnd`) remains the final proof.

| Item | Status |
|---|---|
| S12 | Closed in PR #7, Studio test still worth running |
| N11, N12 | Closed in PR #7 |
| N13 | Open, designer |
| S15 | Open until the second of PR #4 and PR #5 merges |

## Follow-up 12:10 UTC: PR #5 commit a67ff9b (UI side of S12)

Sound. `PromptButtonHoldEnded` now defers its decision one frame under a hold serial: if `PromptTriggered` closed the hold in between, or the ring loop already collapsed, the release counts as a full hold (miss flash, no `grabEnded`); otherwise `grabEnded` fires with the hint. Checked: the serial guard stops a deferred end from acting on a later hold; the "ring not ringing" test only holds after `expire()` or a hold that never started its ring, both correctly a full hold; the one-frame edge now errs toward "full hold" (a release inside the last 16 ms scores as a miss) instead of toward "perfect", which is the safer side for the economy. With PR #7's one-frame defer in the controller, an honest release reaches the server about 33 ms late, inside the grace at every band edge. The two guards (UI and controller) overlap; either alone would now hold, so one can go in a later tidy, not now. S12 is closed on both sides; the Studio hold-to-the-end test remains the proof.

## Follow-up 12:15 UTC: PR #8 (ui/clock-net-rescue, dda6c99, stacked on PR #5)

Sound, one should-fix; CI green on both jobs. Matches gdd v0.2 and data-model sections 9, 10 and 13 (`Clock` folder `Phase` and `PhaseEndsAt`; `Rescue` and `RescueSpotId` on the stuck cat's model with the `StrayId` fallback; 4 s bar, no band, no fail; `rescueEnded(..., true)` only on `PromptTriggered`). The UI fires no remotes. Leak inventory clean (clock Heartbeat stopped on every `setClock` and on destroy, `UI.clock.unbind` from `UI.destroy`, rescue loop stopped on `stopRescue`, `show`, `hide`, `destroy`). The client's `completed` flag is safe only because the server checks the hold age on RescueEnd (data-model remotes table); the engineer's implementation must keep that check.

**S16 (should-fix)** `HUD.setClock` counts down with `os.time() + offset`, and the `UI.clock.bind` path has no `serverNow`, so the chip trusts the device clock (data-model section 1 forbids this). A phone a few minutes off shows a wrong or frozen countdown. Use `workspace:GetServerTimeNow()`, the server's synchronised epoch time, and drop the `serverTime` plumbing.

Nits: N17 `(Config :: any).RescueHoldSeconds or 4` is an acceptable bridge (the live path takes the prompt's `HoldDuration`); drop the cast once the constant exists. N18 the rescue fill runs on `RenderStepped`; `Heartbeat` is enough.
