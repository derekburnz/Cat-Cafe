# Purr Pot test plan (vertical slice)

Owner: qa-playtester. Draft v0.1, 2026-10-26. Sources: [gdd.md](../design/cat-cafe/gdd.md) (core loop),
[features.md](../design/cat-cafe/features.md) (done-when per feature, loop script in section 8),
[data-model.md](../design/cat-cafe/data-model.md) (every number), the `playtest-report` skill (report and ticket
format, severity scale). QA tests, it does not fix: every failure becomes a ticket for its owner.

## 1. What runs where

| Layer | Where | When | How |
|---|---|---|---|
| Unit tests of pure shared modules (`tests/specs/*.spec.luau`) | Cloud threads, or any PC with Node 20 | Every change under `src/shared`, before every review | `cd games/cat-cafe/tools/cloudcheck && npm test` |
| Strict type check and lint, cloud stand-in | Same | Same | `npm run analyze` (game), `npm run analyze -- --tests` (specs too) |
| The real done gate | Derek's PC, Rokit toolchain | Before any task is called done | `cd games/cat-cafe && ./check.ps1` (Windows) or `./check.sh` |
| Unit tests inside Studio (real Roblox globals) | Derek's PC | Before every playtest build | Section 3.2 |
| Automated Studio playtest over Studio MCP | Derek's PC, driven by Claude Code | After every feature lands, before every friend playtest | Section 4 |
| Manual checklist, phone and PC | Derek, then friends | Every friend playtest round | Section 5 |
| Ten minute loop script (Phase 2 exit) | Derek first, then two friends | End of Phase 2 | Section 6 |
| Friend feedback | Google Form or Discord | Every round | [feedback-form.md](feedback-form.md) |

Results of every run go to `docs/playtests/YYYY-MM-DD.md` in the `playtest-report` format, evidence to
`docs/playtests/evidence/YYYY-MM-DD/`.

## 2. Preconditions

1. Commit first. Open the **dev copy** of the place, never the published one (studio rule 1).
2. Studio MCP on: Assistant > ... > Manage MCP Servers > Enable Studio as MCP server. In Claude Code run
   `list_roblox_studios` and keep the `studio_id`; every Studio tool call takes it.
3. Rojo: `rojo serve default.project.json` for playtests, `rojo serve tests.project.json` for unit tests in
   Studio (same tree plus `ReplicatedStorage.Tests`). Never publish a place that contains `ReplicatedStorage.Tests`.
4. Data: with **Enable Studio Access to API Services** off, ProfileStore runs in mock mode, so every play session
   is a fresh account (good for onboarding tests) and nothing persists (so skip persistence steps and expect
   `dataSaves = false` in the state). Turn it on only for the persistence and offline steps, using a dev-only
   DataStore name.
5. Phone checks use Studio's Device emulator (Test tab) at a 390 x 844 phone preset; multi-player checks use
   Test > Clients and Servers with 2 players.
6. Debug hooks (Studio-only, `src/server/Services/Debug.luau`, every call errors outside Studio). From
   `execute_luau` while playing: `local Debug = require(game.ServerScriptService.Server.Services.Debug)`, then
   `Debug.snapshot(player?)` (authoritative `PlayerState`, settled first), `Debug.setCoins(player?, n)`,
   `Debug.setLastTick(player?, secondsAgo)` (credits that much income on the next settle),
   `Debug.resetProfile(player?)`, `Debug.giveCat(player?, catId)`, `Debug.setUpgrade(player?, id, level)`,
   `Debug.spawnStray(catId, areaId?)` (returns the StrayId), `Debug.dataSaves()`. `player` may be a Player, a
   UserId, a name, or nil for the first player. Still missing: `setLastSeen` for the offline popup, so step S10
   uses a real leave and rejoin for now. Steps marked (hook) use these.

## 3. Unit tests

### 3.1 What is covered

| Spec | Checks | Source |
|---|---|---|
| `TestKit.spec` | The harness itself. If this fails, trust nothing else in the run. | |
| `Catalog.spec` | 12 slice cats with rarity, area, favorite spot; rarity table; 7 spots and their cafe levels; 6 upgrades with costs, start levels and gates; 4 decor; 3 lures with odds summing to 100; 2 areas; ids snake_case and unique; model names from ids | data-model 1, 2, 3, 5 to 9 |
| `Catching.spec` | chance formula and both clamps, ring windows, cheat ceiling (perfect ring adds at most 15%), flee rules, odds tables mapped onto rolls and swept 20,000 times, area filtering, uniform pick, rarity ladder fallback, percent text | data-model 8, 9, 10 |
| `Economy.spec` | start levels, cafe multiplier, cat rate with favorite and variant, income sum, lazy settle, offline gain and cap, affordability, upgrade and decor blockers in gate-before-coins order, spots by cafe level, seats, counts, and the loop script in numbers (table at $100 adds exactly 10%, 5 minutes away at the starter rate pays 112) | data-model 5, 6, 11, 14; features 8 |
| `Config.spec` | every constant in data-model section 17 by name and value, no undocumented constant, internal ordering (lock outlives hold, carry speed 80%) | data-model 17 |
| `Signal.spec` | connect, disconnect, once, disconnect all, one erroring handler does not stop the rest | |

Not covered by unit tests, by design: anything that needs DataStores, Players, RemoteEvents, physics or the
world. `ProfileSchema`, `DataService`, `CatService`, `CafeService`, `Net`, `WorldBuilder` and all of `src/client`
are Studio-only and covered by sections 4 to 6.

### 3.2 Running them

Cloud or PC: `cd games/cat-cafe/tools/cloudcheck && npm install --no-bin-links && npm test`. Exit code 1 on any
failure; `--verbose` prints one line per test, `--filter Economy` runs one spec, `--json report.json` writes a
machine readable summary.

Studio: serve `tests.project.json`, then in the command bar or via `execute_luau`:

```lua
local run = require(game:GetService("ReplicatedStorage").Tests.StudioRunner)
local s = run(nil, { verbose = true })
return string.format("%d passed, %d failed, %d skipped", s.passed, s.failed, s.skipped)
```

Pass criteria: 0 failed in both places. A spec that passes in the cloud but fails in Studio (or the reverse)
is a ticket against the harness, owner QA.

## 4. Automated Studio playtest (Claude Code over Studio MCP)

Conventions: `get_console_output` after every step, any new error or warning is recorded with its full text.
`screen_capture` after every step that changes what the player sees; save to
`docs/playtests/evidence/YYYY-MM-DD/<step>.png`. Read authoritative numbers with `execute_luau` on the server
(hook) and compare with the HUD. Studio's built-in `subagent` tool (playtest type) can run 4.1 end to end once
it is scripted; keep the manual tool sequence below as the reference.

### 4.1 Smoke run (about 6 minutes, before every friend playtest)

| Step | Tool calls | Expected | Feature |
|---|---|---|---|
| S1 Join | `start_stop_play` start. Wait 10 s. `get_console_output`. `execute_luau`: count `workspace` descendants tagged `Plot` with `OwnerUserId == player.UserId` | No errors. Exactly one plot owned. HUD shows `$50` and rate `1.5/s` within 5 s (hook: `snapshot.money == 50`, `incomePerSecond == 1.5`) | F01, F04, F10 |
| S2 World | `execute_luau`: `CollectionService:GetTagged("Stray")` count and positions; `search_game_tree` for `workspace.World` | Plots, alley, park, gate present. Between 1 and 6 strays after 2 minutes, never more than `MaxStraysPerArea` per area (sample 5 times, 20 s apart) | F01, F05 |
| S3 Walk to alley | `character_navigation` to the alley centre (`Config.World.AlleyCenterZ`, read it from `ReplicatedStorage.Shared.Config` with `execute_luau`) | Arrives in under 60 s. Tutorial arrow visible on the way (phone emulator run only) | F01, F13 |
| S4 Grab | `execute_luau`: nearest stray position. `character_navigation` to within 8 studs. `user_keyboard_input`: hold `E` for about 1.35 s then release (the server reads the time between GrabBegin and GrabEnd: 1.20 to 1.75 s is perfect, 0.70 to 1.20 s good). Repeat until caught (max 5 tries) | Prompt appears inside 10 studs only. Common: catch chance 0.90 bare, 0.95 with a perfect release; on a failed roll the stray stays and the prompt reopens after 2 s. Stray despawns on success, carry indicator shows, walk speed drops to 13 (hook: `Humanoid.WalkSpeed`) | F06, F07 |
| S5 Check in | `character_navigation` to own plot `Door` part. | Within 8 studs: Cat found popup, `+50` first-catch reward for a new Common, collection `2 / 12`, carry indicator gone, walk speed back to 16 | F07 |
| S6 Place | Open Collection (`user_keyboard_input` `C` or click the HUD button with `user_mouse_input`), pick the new cat, Place, choose `window_1` | Rate rises by the cat's rate (Tuxedo or Snow on the window: +1.5, any other Common: +1). Cat model appears on the spot | F02, F03 |
| S7 Buy | Wait until `$100` (about 34 s from join at the starter rate, less after the reward). Open Upgrades (`U`), buy Tables | Coins drop by 100, a table and two chairs appear, rate rises by exactly 10% | F08 |
| S8 Refusals | Try to buy Lure bowl and Park pass at cafe level 1, try Cafe level 2 with under $250 | Each refused with a toast (`Needs cafe level 2`, `Needs cafe level 3`, `Not enough coins`), no coins taken, no server error | F08 |
| S9 Persist (API access on) | `start_stop_play` stop, start again | Coins within rate x gap of the last value, cats and tables back, offline popup if away over 60 s | F10, F12 |
| S10 Offline | API access on: stop play, wait 2 minutes (or longer), start play again. With a `setLastSeen` hook this becomes a 5 s step | Popup shows `floor(rateAtLogout x 0.25 x secondsAway)`. Claim adds exactly that once; a second claim adds nothing | F12 |

Record pass or fail per step plus the console text. Any step that cannot run (hook missing, API access off) is
marked skipped with the reason, not failed.

### 4.2 Two player checks (Clients and Servers, 2 players)

1. Both clients walk to the same stray. Client A holds `E`, client B holds `E` one second later. Expected: B gets no
   prompt or a refusal while A's lock (3 s) is live; only one CatCaught fires. (F06 done-when.)
2. Client A catches an Epic (hook: `Debug.spawnStray("sphynx", "alley")`). Expected: both clients see the
   Announce toast. (F14.)
3. Client A places a cat and buys a table; client B walks into A's cafe. Expected: B sees the placed cat and the
   table. (F18, P2, record only.)

### 4.3 Abuse pass (server validation; anything accepted is a blocker, owner luau-reviewer)

Run from a client context: the second client window of a Clients and Servers session, or the QA LocalScript
`tests/abuse/AbuseClient.client.luau` (to be written once the remote list is frozen; it fires each case on a
key press and prints the server's reaction). Remote names are the list in `src/shared/Remotes.luau`.

| Case | Call | Expected server behaviour |
|---|---|---|
| Fake stray | `GrabBegin("not_a_stray")` | Ignored, no error in console |
| Far grab | Teleport the character 200 studs away (`execute_luau`), `GrabBegin(id)` then `GrabEnd(id)` 1.35 s later | Both refused by the 10 stud check |
| End without begin | `GrabEnd(id)` on a stray nobody locked | Refused |
| Someone else's lock | Client B `GrabEnd` on a stray A locked | Refused |
| Scripted perfect | 40 grabs of Commons with `GrabEnd` sent by script exactly 1.35 s after `GrabBegin` | Every one is a perfect ring; success rate still at most 0.95 and at most 15 points over the honest chance |
| Instant end | `GrabEnd(id)` 0.05 s after `GrabBegin` | Dropped (under 0.15 s), lock continues, no error |
| Late end | `GrabEnd(id)` 2.0 s after `GrabBegin` | Refused as stale: the server already resolved the attempt at 1.75 s (see No end), no error |
| No end | `GrabBegin(id)` and never send `GrabEnd` | At 1.75 s after begin the server resolves the attempt itself as a ring miss: chance rolled without bonus, lock released, a Common is usually caught and a Rare may flee. Client shows the miss flash at 1.5 s and then the server result |
| Perfect farming | `GrabEnd` sent by script at exactly 1.5 to 1.75 s after `GrabBegin` | Accepted as perfect by design (latency grace); the only gain is the capped 0.15 bonus. Log the hit rate, do not ticket |
| Client ring value | `GrabEnd(id, "perfect")` with the old extra argument | Argument ignored; result comes from timing only |
| Bad ids | `BuyUpgrade(41 character string)`, `BuyUpgrade(123)`, `BuyUpgrade(nil)`, `BuyUpgrade("jetpack")` | All refused, no server error (an error on bad input is a major ticket on its own) |
| Unaffordable | `BuyUpgrade("tables")` with `$0` | Refused with `Not enough coins`, coins unchanged |
| Gates | `BuyUpgrade("lure_bowl")` at cafe 1, `BuyDecor("neon_sign")` at cafe 3, `PlaceCat(uid, "cushion_1")` at cafe 1 | Refused |
| Ownership | `PlaceCat(other player's uid, "window_1")`, `SellCat(other uid)`, `UnplaceCat(other uid)` | Refused |
| Double spend | `SellCat(uid)` twice in one frame, `ClaimOffline()` twice | Second call adds nothing |
| Rate limit | 50 `RequestSync()` in one second | At most 10 handled, the rest dropped, one log line per second per player, no kick |
| Grab limit | `GrabBegin` twice within 2 s | Second dropped |
| Tutorial | `TutorialAdvance(4)` from step 0, `TutorialAdvance(-1)`, `TutorialAdvance("2")` | Refused; only `tutorialStep + 1` is accepted |
| Lures | `UseLure(spot)` without `lure_bowl`; `EquipLure("salmon")` with 0 held; `UseLure` twice (one active lure per player) | Refused |
| Client time | Change the client clock or send stale timestamps in any payload | No remote accepts a time argument; income uses server `os.time()` only (code read, reviewer confirms) |

### 4.4 Performance (phone emulator, P2, record only)

`execute_luau` on the client: average `RunService.Heartbeat` delta over 10 s in the cafe with customers on and
off (hook or a client attribute). Budget from F15: customers under 2 ms per frame; the whole scene under 16.7 ms
on the emulator's default quality. Record `Stats:GetTotalMemoryUsageMb()` at join and after 10 minutes.

## 5. Manual checklist (Derek first, then friends)

Run on a phone preset and once on PC. Tick each line, note the build date. Placeholders (`PH_` parts, Part cats)
are expected in the rough draft and are cosmetic tickets only.

Core loop (features.md section 2 done-when lines)
- [ ] F01 Join, own a plot, walk cafe to alley to park and back in under 60 s
- [ ] F02 Place and remove a cat, rate changes, survives rejoin
- [ ] F03 Collection shows owned cats with Place, Remove, Sell; silhouettes for unfound; `n / 12` count; selling a duplicate raises coins by the rarity's sell value (Common 25)
- [ ] F04 HUD rate equals the formula for any setup you build (compare with `Economy.incomePerSecond` by hand: rates 1, 3, 8, 25; favorite x1.5; multiplier 1 + 0.10 tables + 0.15 (espresso - 1) + decor)
- [ ] F05 Six strays in the alley within two minutes, never more; a stray that nobody catches wanders off after about 120 s
- [ ] F06 Hold to grab, release in the band; Rare and above flee on a miss with the "It got away" toast; Commons stay
- [ ] F07 Carry: slower walk, carry indicator, check in at the door; leaving mid-carry still saves the cat (API access on)
- [ ] F08 Buy every slice item in order; each is visible in the world; each refused when unaffordable or gated, with a toast
- [ ] F09 Lure bowl: buy, equip, use at a lure spot; a stray appears after 45 s; it is reserved to you until caught or despawn (90 s); on despawn the food is refunded; Tuna produces a Rare roughly 42% of the time over 20 tries; odds and the per-cat split are visible before buying
- [ ] F10 Rejoin keeps coins, cats, upgrades, decor, lures (API access on)
- [ ] F11 Park gate closed until Park pass; park spawns Tortie, Bengal, Ragdoll
- [ ] F12 Leave 10 minutes, return: popup shows 25% of the rate x seconds away, claim once
- [ ] F13 Fresh account finishes the loop in under 10 minutes without help; prompts never show again on repeat joins
- [ ] F14 Everyone sees the Epic and Legendary catch message
- [ ] F19 Fast travel buttons work and are greyed while carrying (P2)

Phone and UI
- [ ] All HUD text readable at 390 x 844; no element under the notch or behind the Roblox top bar
- [ ] Every tappable control at least 44 px; no accidental grabs when tapping HUD buttons near a stray
- [ ] Shop cards show cost, effect and (lures) odds before purchase; nothing is bought with one accidental tap on a card
- [ ] Every refused action shows a toast that says why
- [ ] Toasts and popups dismiss and never stack off screen
- [ ] No fake timers, no "last chance" wording, no pressure to spend (young audience rule)

Data and errors
- [ ] No red output in the console in a 10 minute session (yellow warnings listed in the report)
- [ ] Joining with Studio API access off shows a visible "progress will not save" notice (state `dataSaves = false`)
- [ ] Leaving during a purchase or a grab never duplicates coins or cats

## 6. Ten minute loop script (Phase 2 exit test) with expected numbers

Fresh account, phone preset, timer running. Numbers come from the specs in section 3 and hold for the current
catalog.

1. Join. Plot owned, Tabby on `counter_1`, HUD `$50`, rate `1.5/s` within 5 s.
2. Follow the arrow to the alley. A Common stray is there (tutorial guarantee below step 2). Hold, release in the band (the last 0.30 s of the 1.5 s hold). Bare chance 0.90, with a perfect release 0.95; a failed roll keeps a Common.
3. Walk home at speed 13, check in at the door. Popup, `+50` reward, collection `2 / 12`.
4. Place the new cat on `window_1`. Rate `2.5/s` (Ginger or Smoke) or `3.0/s` (Tuxedo or Snow).
5. Buy Tables at `$100` (reachable in under a minute). A table appears; rate x1.1 (`2.75/s` or `3.3/s`).
6. Free play to minute 10. Expected: Cafe level 2 bought (`$250`), three cats placed, one more purchase.
7. Leave for 5 minutes, rejoin. Offline popup shows `floor(rate x 0.25 x 300)`, for example `206` at `2.75/s`. Coins and cats match the moment you left.
8. Pass: every step done under 10 minutes, no console errors, no open blocker tickets. Analytics (hook or Creator Hub): funnel steps `joined`, `saw_alley`, `first_catch`, `first_checkin`, `first_place`, `first_table`, `cafe_level_2` fired once each, in order.

## 7. Reporting

One file per run, `docs/playtests/YYYY-MM-DD.md`, in the `playtest-report` format: summary, bugs, balance,
confusion, requests, quotes. Tickets use the skill's severity scale (blocker, major, minor, cosmetic), carry
repro steps, expected, actual, evidence path and an owner (engineer, ui-designer, asset-artist, designer). Exploit
shaped findings go to luau-reviewer as blockers. QA never writes the fix.

## 8. Open requests to other threads

1. Engineer: `Debug.setLastSeen(player?, secondsAgo)` for the offline popup, and a stable remote list so
   `tests/abuse/AbuseClient.client.luau` can be written (the rest of the Debug module landed on 2026-10-26).
2. Studio plan thread: the `playtest-report` skill section 2 still describes the per-serve loop ("tap a cat to
   serve"); replace it with section 4.1 of this plan.
3. Lead: `games/cat-cafe/tests/` and `games/cat-cafe/tools/cloudcheck/` are QA owned folders (proposed in
   `docs/decisions.md`).

## 9. Known gaps

The cloud harness cannot load modules that touch `Instance.new`, events, DataStores or `RunService:IsServer()`,
and its type check treats most `Enum` types loosely; `./check.sh` with luau-lsp is the truth for types. Nothing
here replaces a human playing on a real phone for ten minutes.
