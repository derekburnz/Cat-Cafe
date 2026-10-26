# Review: PR #9 (QA abuse client and test harness types)

Date: 2026-10-26, 16:55 UTC. Reviewer: luau-reviewer thread. Follows `2026-10-26-review-fixes-prs.md`.

Scope: PR #9 `qa/abuse-client-and-harness-types` (e723211, base `main`). Method: read in a repo clone, cross-checked every assertion against the server code on `main` (18a3514), and ran cloudcheck and StyLua on a trial merge of the PR into current `main`. Severity as before: blocker, should-fix, nit.

## Verdict

Sound idea and safe to ship in the repo: the client cannot reach a live build. Three cases will report FAIL or PASS against a correct server, so the first Studio run would file false tickets. Fix S17 to S19 before that run; none of them touches game code.

## What checks out

- **Never ships.** The client is mapped only in `tests.project.json` (`StarterPlayerScripts.TestsAbuse`), `default.project.json` has no `tests` path, and the script returns at once unless `RunService:IsStudio()`. `_G.PurrPotAbuse` exists only in that build.
- **Grab cases match the server.** Fake stray, end without begin, instant end (dropped under 0.15 s, resolved at 1.75 s), late end (the 1.75 s timer clears the lock, so a GrabEnd at 2.0 s is ignored), no end and far grab all assert what `CatService` on `main` does. `runAll` spaces every GrabBegin more than 2 s apart, so the 1 per 2 s GrabBegin bucket never turns a case into a false FAIL.
- **Flood** expects at most 2 ProfileSync and one rate-limit log line, which is what `Net.luau` does (`RequestSync` 1 per 2 s, `logOnce` once a second).
- **Harness types.** The TestKit, StudioRunner and Catalog.spec changes are annotations only; behaviour is unchanged.
- **Trial merge with `main`:** cloudcheck 0 type errors in 49 scripts, 213 tests pass, 2 skipped. The tests-project type check reports 1 error, `EquipBest.spec.luau:55` (from PR #4, already noted in the PR body for the cat stats thread). CI's cloudcheck job does not type-check `tests/`, so it stays green.

## Findings

**S17 (should-fix) Money checks ignore income, so four cases fail against a correct server.** Every ProfileSync carries settled income (the starter Tabby earns 1.5 per second, and `before` is the last sync, up to 10 s old), and the server's refusal paths sync too (`CafeService.onBuyUpgrade` calls `CafeService.sync` after a blocker toast).
- `shop` (`AbuseClient.client.luau:460`): `BuyUpgrade("lure_bowl")` at cafe level 1 is refused with a toast and a sync, so `money() ~= before` is true on almost every run. FAIL.
- `doubleSpend` (`:510`): `gained == value` holds only if no coin accrued since the last sync. The test plan row says "coins up by exactly its sellValue", which no server can meet. FAIL.
- `badIds` (`:422`) and `ownership` (`:478`): FAIL whenever the 10 s periodic sync lands in the 1.5 s window, about one run in seven.
- Fix: record `state.incomePerSecond` and the time of the `before` sync, then allow `0 <= gained <= incomePerSecond x elapsed + 1` for "nothing bought or granted", and `value <= gained <= value + incomePerSecond x elapsed + 1` with `lost == 1` for the sale. The real failures stay visible: a spend shows as a drop, a double sale as a second `value`.

**S18 (should-fix) Bad ids: the test plan and the server disagree.** Test plan 4.3 says a bad id gets no toast, but `BuyUpgrade("jetpack")` is well formed (it passes `Guard.id`), so `Economy.upgradeBlocker` answers "Unknown upgrade" with a toast and a sync. `badIds` then reports FAIL on a correct refusal. Recommendation: accept a refusal toast for a well-formed unknown id, which is harmless and matches the plan's own rule that every refused action says why. Keep "no toast" for malformed values (wrong type, bad pattern, too long), which `Guard` drops silently. The other way, silence for unknown ids, is a server change in `CafeService` and the engineer's call.

**S19 (should-fix) `clientRingValue` cannot fail.** It returns PASS when the GrabResult arrives before 1.0 s (`:399`), but a server that honoured the client's `"perfect"` would also answer at 0.5 s. The GrabResult carries no ring, so the case cannot see what it names. Make it CHECK and cite the code review (`onGrabEnd` reads only the stray id), or have the Studio-only `Debug` module print the scored ring so the case can read it from the server output.

**N16 (nit) Two rows test the rate limiter, not the handler.** The second `TutorialAdvance` (`1e9`, `:418`) and the second `ClaimOffline` (`:522`) are dropped by their 1 per second and 1 per 2 s buckets, so `Guard.int`'s range check and `takePendingOffline`'s zeroing never run. Both protections are real; if the rows mean to exercise the handlers, space those calls past the bucket.

**N17 (nit)** `lateEnd` counts results since `os.clock() - 3.5` (`:328`). Use the start time from `grabWithRelease`, so a slow previous case can never add a stray result.

**N18 (nit)** `glovesLevel` reads `upgradeLevels["gloves"]` (`:201`). Design v0.2 renames the upgrade to `net`, after which `perfectFarm`'s expected numbers silently use level 0. Read the id from the catalog, or update it on the v0.2 branch.

**N19 (nit)** The gate runs StyLua on `src` only. On the trial merge, StyLua reports diffs in 5 files under `tests/`, including the new `AbuseClient.client.luau` (several lines over 100 columns). Either run `stylua tests` before pushing, or add `tests` to `check.sh` (lead's file).

## Stack status at 17:00 UTC

Every PR from #1 to #9 is merged; `main` is green at bff2fa4. PR #9 merged at 16:49 UTC at 97b4708, which adds a merge of `main` and a one-line `EquipBest.spec` type fix; `AbuseClient.client.luau` is unchanged from the reviewed e723211, so S17 to S19 and N16 to N19 now apply to `main` and go to QA as a follow-up PR from `main`. S15 (the `docs/decisions.md` conflict) was resolved cleanly on PR #5 before it merged. PR #8 (clock chip, Net copy, rescue bar) is in, with S16 closed.
