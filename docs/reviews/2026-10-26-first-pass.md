# Code review: Cat Cafe first pass

Reviewer: luau-reviewer (read-only, no files edited). Snapshot reviewed: `games/cat-cafe` as of **2026-10-26 01:49 UTC**. The engineer and UI threads were still editing while this was written, so line numbers can drift by a few lines. Scope: `src/server`, `src/shared`, `src/client`, `tests`, `tools/cloudcheck`. Checked in the order the role prescribes: client trust and remote validation, rate limiting, data saving, leaks, mobile performance, style.

Severity scale: **blocker** (breaks the slice or loses player data), **should-fix** (exploit, drift from the design, or gate failure), **nit**.

## Summary

Two blockers (one already fixed while this was being written), eleven should-fix items, ten nits. The server architecture is sound: every mutating remote re-reads the server profile, prices come from `Catalog`, removals happen before grants, ownership is a uid lookup on the server record, and ProfileStore session locking kicks on load failure instead of handing out a default profile. The blockers are a save-path ordering bug that loses a carried cat on leave and a field-name mismatch that errors the two shop screens on open.

## Gate status at the snapshot

| Check | Result |
|---|---|
| `stylua --check src tests` | 8 files still unformatted: `src/client/Controllers/CustomerController.luau`, `src/server/World/Placeholders.luau`, `tests/TestKit.luau`, `tests/StudioRunner.luau`, `tests/specs/{Catalog,Catching,Config,Economy}.spec.luau` (down from 32 earlier in the evening). `.styluaignore` now excludes `Vendor/`. |
| `selene src` | Ran with a hand-built Roblox std (the cloud cannot download the API dump). No warnings in `src` apart from a false positive on one-argument `assert` from my std file. `selene.toml` has no exclude for `src/server/Vendor/`, see S7. |
| `luau-lsp analyze` | Not runnable in the cloud. The engineer's `tools/cloudcheck/analyze.mjs` (same Luau checker in WebAssembly) reports **75 type errors in 46 scripts**, 24 of them in `UI/Demo.luau`. Grouped in S9. |
| Unit tests (`tools/cloudcheck/run-tests.mjs`) | 63 passed, 4 failed, 2 skipped. Three spec files (`Catalog`, `Catching`, `Economy`) never load because the shim rejects `return nil` from `Types.luau` (see S8). The one real failure is `Config.spec`: `Config.GrabMinHoldSeconds` is not in data-model section 17. |

## Blockers

### B1. A carried cat is lost when the player leaves or the server shuts down
- `src/server/Services/DataService.luau:115-117`: `release()` sets `sessions[player] = nil` **before** calling `finalize()`, which runs the `beforeRelease` finalizers.
- `src/server/Services/CatService.luau:639`: the finalizer calls `finishCheckIn(player, false)` which calls `CafeService.addCaughtCat`.
- `src/server/Services/CafeService.luau:234`: `addCaughtCat` looks the profile up again through `DataService.get` (now nil) and hits `assert(profile ~= nil, "profile not loaded")`. The error is caught by the pcall in `finalize` and logged as "finalizer failed". The cat is gone.
- Player impact: anyone who disconnects, gets kicked, or is on a server that shuts down while walking a cat home loses it. For a Legendary that is 3,000 coins of sell value and the collection entry. The code comment at `CatService.luau:638` promises the opposite.
- Fix: in `DataService.release`, move `sessions[player] = nil` to after `finalize(player, session)`. Finalizers already receive the `profile` argument, so an even safer fix is to pass it through: `finishCheckIn(player, false, profile)` and an `addCaughtCat` variant that takes the profile instead of re-fetching it. Also see S10 for the `carrying[player] = nil` on `PlayerRemoving` at `CatService.luau:655`, which only works today because `DataService.start()` is the last service started and Roblox fires the most recently connected handler first.
- Test to add: join, grab a Common, leave before check-in, rejoin, expect the cat in `profile.cats`.

### B2. Upgrades and Decor screens read `state.coins`, which does not exist (fixed in the UI thread's 01:49 UTC edit, verify in Studio)
- `src/client/UI/Screens/UpgradeShop.luau:208` and `:244`, `src/client/UI/Screens/DecorShop.luau:291` and `:319` use `state.coins`. The UI's own `PlayerState` (`src/client/UI/Types.luau:86`) and the controller (`UIController.luau:102`) send `money`. The cloud type check reports all four lines ("Key 'coins' not found").
- Player impact: `Format.money(nil)` calls `math.abs(nil)` and errors the moment the Upgrades or Decor modal opens (`render` runs in `onOpen`). The panel title never updates and the Buy buttons never get their enabled state. Because `init.luau:90-99` renders HUD, Upgrades, Decor and Collection in one call, an error in a visible shop also skips the Collection re-render for that update.
- Fix: `state.money` in all four places. The live files now read `state.money` (changed after this snapshot); the cloud type check should drop those four errors on the next run. Still worth one Studio open of each shop to confirm.

## Should-fix

### S1. The 1.5 s hold is no longer verified on the server, so grabs can be scripted
- `src/server/Services/CatService.luau:473`: a `GrabEnd` counts as a real attempt once `os.clock() - stray.lockAt >= Config.GrabMinHoldSeconds` (0.15 s). The earlier version used `ProximityPrompt.Triggered`, which the engine only fires after the full hold in range; that was removed in the latest edit. The ring result (`:452`) is still whatever the client sends.
- Exploiter impact: fire `GrabBegin`, wait 0.16 s, fire `GrabEnd` with `"perfect"`. That is base chance + 0.15 (+ gloves) on every stray in range, every 2 s, with no hold and no timing. Legendary becomes a 40 percent roll per attempt. In a friends alpha this is harmless; for soft launch it is an economy exploit (sell Legendaries for 3,000 each).
- Fix: compute the ring on the server from its own clock. `elapsed = os.clock() - stray.lockAt`; derive `ringScale = 1 - elapsed / Config.GrabHoldSeconds` and classify with the same bands the UI uses (see S2), widened by about 0.08 for jitter. Both messages take the same route, so server elapsed matches client elapsed within jitter. Reject anything under about 0.5 s as a miss and anything over `GrabLockSeconds` as "Too slow" (already done). Use the client's ring only as a sanity check (if it claims a better band than the server computed, take the server's).

### S2. Two different definitions of the timing ring
- Server side: `Config.RingPerfectWindow` / `RingGoodWindow` (0.30 s / 0.80 s **after the hold completes**) and `Catching.ringResultFromTiming`, which the server never calls.
- UI side: `src/client/UI/Screens/CatchPrompt.luau:322-323` uses `DEFAULT_PERFECT` {0.33, 0.41} and `DEFAULT_GOOD` {0.26, 0.48} as fractions of the ring **during** the 1.5 s shrink, and `init.luau:684-690` treats `PromptTriggered` (full hold) as a miss. These are different games. The data model (section 10) describes the server's version.
- Fix: pick one (the UI version is built and feels right for touch), move the bands into `Config` as fractions of `GrabHoldSeconds`, have `CatchPrompt` and the server (S1) both read them, delete the unused windows, and update data-model section 10 and 17 so `Config.spec` passes.

### S3. Studio and live share the same DataStore
- `src/shared/Config.luau:62` `ProfileStoreName = "CatCafeProfiles"`, used as is at `DataService.luau:35`. With "Enable Studio access to API services" on, a Studio playtest in the dev place writes to the production store (DataStores are per experience, not per place). The remote-security-checklist calls this out.
- Fix: `Config` stays pure, so in `DataService`: `local storeName = Config.ProfileStoreName .. (if RunService:IsStudio() then "_dev" else "")`. Optionally key on `game.PlaceId` so a published dev place also gets its own store.

### S4. Autosave is 300 s, the design says 60 s
- `Config.AutosaveSeconds = 60` is not referenced anywhere. ProfileStore defaults to 300 s (`Vendor/ProfileStore.luau:172`) and exposes `ProfileStore.SetConstant("AUTO_SAVE_PERIOD", n)` (`:1213`).
- Impact: a server crash loses up to 5 minutes of coins and purchases. (Note that `migrate` keeps the old `lastTick`, but `load` resets it to `now`, so the gap is not re-credited at the online rate. Good.)
- Fix: call `ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Config.AutosaveSeconds)` once in `DataService.start()` before any session opens.

### S5. Unclaimed offline earnings disappear
- `DataService.load` computes `pendingOffline` and holds it in memory; `finalize` writes `lastSeen = now`. If the player never presses Claim (popup dismissed, left early, UI error), the amount is gone on the next join.
- Fix: in `finalize`, credit any remaining `session.pendingOffline` to the profile, or persist it. Either way the popup still shows it when it fires.

### S6. Rate limiting has no global per-player bucket and lets `RequestSync` run at 10 per second
- `src/server/Services/Net.luau:16-17, 64`: one bucket per (player, remote) at 10 per second, plus a 1 per 2 s bucket for `GrabBegin`. Fifteen client remotes means a single client can push about 150 handled calls a second. `RequestSync` builds and serializes the full profile every call.
- Fix: a global per-player bucket (for example 30 per second) checked before the per-remote one, and a small override table: `RequestSync` and `ClaimOffline` at 1 per 2 s, `TutorialAdvance` at 1 per second. Keep the silent drop and the once-a-second warn.

### S7. The lint gate will lint the vendored ProfileStore
- `check.sh` runs `selene src` and `luau-lsp analyze ... src`. `src/server/Vendor/ProfileStore.luau` is `--!nonstrict`, 2,244 lines, and not ours. StyLua already ignores it via `.styluaignore`.
- Fix: `selene.toml`: `exclude = ["src/server/Vendor/**"]`. `check.sh` and `check.ps1`: add `--ignore "src/server/Vendor/**"` to the luau-lsp line. Also decide where `tests/` is linted: the spec files use `describe`, `it`, `expect` as globals, which selene flags as undefined; either give `tests/` its own `selene.toml` that declares them or keep tests out of `selene` (as `check.sh` already does) and say so in `tests/README.md`.

### S8. The cloud test runner rejects `return nil`, so three of five spec files never run
- `tools/cloudcheck` (owner: qa-playtester). `Catalog.spec`, `Catching.spec` and `Economy.spec` fail at load with "Module code did not return exactly one value: ReplicatedStorage.Shared.Types". `Types.luau` ends with `return nil`, which real Roblox accepts for type-only modules (Fusion's `PubTypes` does the same).
- Impact: the economy and catching math currently has no passing automated coverage even though the specs exist. The 63 passing tests are TestKit, Signal and Config.
- Fix: in the shim's `hostRequire`, accept a nil module result (cache a sentinel). Then re-run: expect the Economy and Catching specs to go green or to surface real failures.

### S9. 75 type errors to clear before `luau-lsp analyze` can pass
Grouped so one pattern fixes many:
- `FindFirstChild` / `FindFirstChildWhichIsA` results used as typed objects without a cast after the `IsA` check: `CatService.luau` (`attachHeldCat`, the `part`, `torso`, `humanoid` locals, roughly lines 355-405), `AssetRegistry.luau:25, 66, 70`, `CafeService.luau:76`, `Controllers/CustomerController.luau:41-135`, `Controllers/WorldController.luau:32-37`, `Controllers/UIController.luau:34-48`. Pattern: `local root = character:FindFirstChild("HumanoidRootPart"); if root and root:IsA("BasePart") then ... root :: BasePart`.
- UI types versus shared types: `UIController.luau:219-223` passes `Catalog.cats` etc. into `UI.init`, whose `Types.Catalog` fields are looser copies (`area: string?`, `startLevel: number?`). Either have `src/client/UI/Types.luau` re-export the shared `Types` for `CatDef`, `UpgradeDef`, `DecorDef`, `LureDef`, `SpotDef`, or cast once at the call site.
- ProfileStore's generic bound rejects `PlayerProfile` (`DataService.luau:35, 54, 74`) because optional fields are not JSON-table shaped in the checker's eyes. Simplest: `ProfileStore.Profile<any>` at the boundary and keep `profile: Profile` typed on our side.
- Remaining singles: `init.luau:132-135` (`levels.cafe_level` is `number?`), `init.luau:470-476` (`carryMarker` nil check), `Components/Tween.luau:27`, `Screens/CatCollection.luau:603-605, 843`, `Screens/Popups.luau:254, 280`, `Screens/UpgradeShop.luau` and `DecorShop.luau` (B2), `UI/Demo.luau` (24, `table.insert` arity; demo only).

### S10. `carrying` cleanup on `PlayerRemoving` depends on handler order
- `CatService.luau:655` clears `carrying[player]` in its own `PlayerRemoving` handler. The save-on-leave path (B1) needs it still set when the finalizer runs. Today that holds only because `DataService.start()` is called last in `Main.server.luau` and Roblox fires the most recently connected handler first.
- Fix: delete that line and let `endCarry` (called from the finalizer) clear it; keep a fallback that clears it only when `DataService.get(player)` was already nil (profile never loaded or session ended early).

### S11. Eight plots, but nothing caps the server at eight players
- `Config.ServerPlayers = 8` is informational. `PlotService.assign` warns and returns nil for player nine (`PlotService.luau:37`); `onCheckIn` then requires a plot, so that player can catch a cat and never put it down, and `startCarry` slows their walk speed for the rest of the session.
- Fix: set Max Players to 8 in the experience settings (there is no runtime API for it) and record that in `docs/setup-guide.md`. Defensive extra: if `assign` returns nil, disable the grab prompt for that player or auto-check-in on catch.

## Nits

- N1 `src/server/World/Layout.luau:4` says "No Roblox globals, so tests can check the numbers" but line 6 calls `game:GetService`. Pass `Config.World` in, or drop the comment.
- N2 `Config.GrabCooldownSeconds` (27) and `GrabRateLimitSeconds` (58) are the same number for the same thing. Keep one.
- N3 `Catalog.upgrades` espresso has `maxLevel = 3` and five costs (`Catalog.luau:100`). Harmless, but it reads like a leftover.
- N4 Toast "Tabby is resting on counter_1" shows a raw id (`CafeService.luau`, `addCaughtCat`). Use the spot type or a display name.
- N5 `Remotes.event(name: string)` accepts any string. A `RemoteName` union (as in the luau-conventions template) turns typos into analyze-time errors.
- N6 `Net.on` does not pcall the handler. A thrown error per malformed call is a cheap way for a fuzzing client to fill the server log; wrap with `pcall` and route to the once-a-second warn.
- N7 Server `Mover.walkTo` pivots up to 12 stray models every Heartbeat; each `PivotTo` replicates. Fine at 12. If stray counts grow, send targets and let clients interpolate.
- N8 UI sizes are design-pixel offsets under one `UIScale` (`Scale.luau`), which satisfies the "never offsets alone" rule. The 760x520 panel at the 0.75 touch floor needs 540 logical pixels of height on a 720-tall phone, which is tight once the top inset is taken. QA should check the shops on a 16:9 phone and on an iPad; `Panel` could clamp to `UDim2.fromScale(0.92, 0.86)` with a `UISizeConstraint` instead of fixed pixels.
- N9 `WorldMarker` reports distance as "m away" after dividing studs by 3.57. Fine for players, but say "studs" in code comments to avoid confusion later.
- N10 Every remote handler that fails validation returns silently, which is correct, but `GrabBegin` out of range also returns silently while the UI has already started the ring. Send `GrabResult(false, "Too far", true)` there too so the prompt closes cleanly.

## What checks out (no action)

- Ownership and state: `PlaceCat`, `UnplaceCat`, `SellCat` look the uid up in the server profile; `ToggleDecor` requires `decorOwned`; `EquipLure` requires a count above zero; spots check `cafeLevel` and occupancy on the server.
- Prices and grants: every price is read from `Catalog` on the server; `trySpend` checks and deducts in one step; `SellCat` removes the cat before crediting; a successful grab despawns the stray before `startCarry`. Handlers have no yields between check and mutate, so two racing remotes cannot double-grant.
- Distance checks on the server for grab begin, grab end, lure and check-in. The park gate opening is client cosmetic only; the server re-checks `park_access` on grab and lure.
- Data: ProfileStore session locking, kick with a friendly message when a session cannot start, `OnSessionEnd` kick, `BindToClose` releases, no default profile written over a failed load, `migrate` sanitizes every field and drops unknown ids, `lastTick = now` on load so the offline gap is never paid at the online rate, offline gain capped at 1 hour.
- Text shown to others: announcements use `DisplayName` plus catalog strings; no user-generated text exists yet. When cafe naming arrives, filter it (checklist item 11).
- Leaks: UI components track and disconnect their connections; `WorldMarker` and `CatchPrompt` stop their per-frame loops on hide; `RateLimiter`, `overLimitLog`, `plotOf`, `carrying`, `lureByPlayer` are cleared on `PlayerRemoving`; stray threads exit when `alive` is false.
- The UI never touches remotes; `UIController` is the only client code that fires them.

## Not yet reviewed

Added after the snapshot: `src/shared/CatStats.luau`, `src/shared/EquipBest.luau`, the `tests/` changes from 01:50 UTC and `docs/engineering/modules.md`. `src/server/Services/Debug.luau` was read: every entry point calls `RunService:IsStudio()` and it is a ModuleScript with no remote, so clients cannot reach it. Fine as is.

## Next review

I will re-read after the engineer and UI threads finish their current pass. Priority order for them: B1, B2, S1 and S2 together, S3, S4, then the gate items (S7, S8, S9).

## Follow-up 2026-10-26 06:50 UTC

Re-read against a fresh snapshot. Code last changed at 01:57 UTC; the design doc (`data-model.md`) changed at 06:43 UTC.

| Item | Status |
|---|---|
| B1 carried cat lost on leave | **Open.** `DataService.luau:118-120` unchanged. |
| B2 shops read `state.coins` | **Fixed** (UI thread, `state.money`). Studio check still pending. |
| S1 hold not verified on the server | **Open, now specified.** The designer rewrote data-model section 10: the server derives the ring from lock age (perfect 1.20 to 1.50 s after GrabBegin, good 0.70 to 1.50 s, earlier is a miss, later than 1.50 s plus `RingLatencyGraceSeconds` 0.25 is a miss, under `GrabMinHoldSeconds` 0.15 is dropped, and a hold with no GrabEnd is resolved by the server at 1.75 s). QA already wrote the tests: `Catching.spec` expects `Catching.ringResultFromHold` and `Config.spec` expects `RingLatencyGraceSeconds`; both are red until the engineer implements them. The `GrabEnd` remote no longer carries a ring argument in the doc; the client should stop sending one and the server should stop reading it. |
| S2 two ring definitions | **Resolved by the same doc change**: the band is the last 0.30 s (perfect) and last 0.80 s (good) of the 1.5 s shrink, which matches the UI's behaviour. `CatchPrompt` should derive its bands from `Config.RingPerfectWindow / GrabHoldSeconds` instead of its own `DEFAULT_PERFECT` {0.33, 0.41} (which is a 0.12 s window, narrower than the doc's 0.30 s). |
| S3 Studio and live share a DataStore | Open. |
| S4 autosave 300 s | Open (`Config.AutosaveSeconds` still unused). |
| S5 unclaimed offline earnings | Open. |
| S6 global remote bucket, `RequestSync` rate | Open. |
| S7 Vendor excluded from selene and luau-lsp | Open (`selene.toml`, `check.sh` unchanged). |
| S8 cloud runner rejects `return nil` | **Fixed** by changing `Types.luau` to `return {}`. 171 tests now pass; the 4 failures are the new ring tests above. |
| S9 type errors | **60 of 75 fixed.** The remaining 15 are all in the new `src/shared/CatStats.luau` (see F1). |
| S10 `carrying` cleared on `PlayerRemoving` | Open. |
| S11 Max Players 8 | Open (settings and setup guide). |
| StyLua | 7 files unformatted: `src/shared/CatStats.luau`, `src/shared/EquipBest.luau`, `tests/TestKit.luau`, `tests/specs/{Catalog,Catching,Config,Economy}.spec.luau`. |
| selene | One new warning: `init.luau:66` `catalog` is assigned but never used. |

### New findings

- **F1 (should-fix) Half-landed feature: cat stats and equip best.** `src/shared/CatStats.luau` and `src/shared/EquipBest.luau` come from the separate "Build cat stats and equip best" thread and are not yet required by anything (the Collection screen only has a button named "EquipBest"). `CatStats` reads `Config.CatMaxLevel`, `CharmSpread`, `CatLevelBonus`, `CatXpBase` and the type `Types.CatView`, none of which exist, and cites "data-model section 4b", which does not exist either. `CatInstance` has no `level`, `xp` or `charm` fields, and `ProfileSchema.migrate` drops unknown fields, so even if the server wrote them they would be lost on the next load. The first `require` of `CatStats` at runtime would fail on `math.clamp(x, 1, nil)`. Nothing breaks until something requires them, but they must land as one change: data-model section 4b, the four Config keys, `level`, `xp` and `charm` on `Types.CatInstance` plus `Types.CatView`, `ProfileSchema.migrate` keeping and clamping those fields (profile version 2), `CafeService.addCaughtCat` rolling charm on the server, a server tick that adds XP to placed cats, and `Economy.catRate` using `CatStats.rating` so the server pays what the UI shows. Until then the feature should stay behind a flag or out of `default.project.json`. The decisions log still says per-cat stats are post-slice; the designer should confirm the scope change in `docs/decisions.md`.
- **F2 (nit)** `Catching.ringResultFromTiming` (the old "after the hold completes" definition) is still exported and now contradicts section 10. Replace it with `ringResultFromHold` per the tests rather than keeping both.

### Things that check out in this pass
`Types.luau` returning `{}` is fine. The `FindFirstChild` casts in `CatService.attachHeldCat`, `AssetRegistry` and `CafeService.ensureLockLabel` are correct and keep the `IsA` checks. `ProfileStore.Profile<any>` at the DataService boundary with `migrate` as the only typed entry point is the right call.
