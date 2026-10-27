# Purr Pot test plan (vertical slice)

Owner: qa-playtester. Draft v0.4, 2026-10-26 (v0.1 to v0.3.1 the same day; v0.4 follows design v0.4, docs PR #62,
with the reviewer's N45, N46, N47 and S36 folded in). Sources:
[gdd.md](../design/cat-cafe/gdd.md) (core loop), [features.md](../design/cat-cafe/features.md) (done-when per
feature, loop script in section 8), [world-and-feel.md](../design/cat-cafe/world-and-feel.md) (v0.4 world, cafes and
UI, QA acceptance checks in section 8),
[data-model.md](../design/cat-cafe/data-model.md) (every number), the `playtest-report` skill (report and ticket
format, severity scale). QA tests, it does not fix: every failure becomes a ticket for its owner.

**Which version applies.** Design v0.3 (Gavin's answers) replaces the hold-and-release net with closing circles,
lure spots with the bait bowl, cafe level with tiers, spots with roles and the rescue hold with minigames, and adds
carry bumps, shinies, the night dealer, night income, rich customers and cat names. The engineer builds it in the
order of features.md section 1 (F22 first). Every row below names its feature; a row whose feature has not landed
yet is skipped with the reason "not built", not failed. Until F27 lands, the v0.2 rescue row kept in section 10
still describes the build on `main`.

**Design v0.4** (Derek's rough draft playtest, 2026-10-26) jumps the queue: F34 catching stakes (the first Miss
ends the catch with no roll, any mix of Good and Perfect always catches, paws per player per stray, a Perfect charm
bonus), F35 the Alleyway behind the cafes with walk speed 20, F19 fast travel at P0, then F36 to F39 (cafe shell,
cafe life, For Rent plots, UI patterns). Rows that change say "(v0.4)" and keep the v0.3 behaviour in a "before
F34" or "before F35" clause, so the same table works on either build.

## 1. What runs where

Code and these docs live in the GitHub repo (`derekburnz/purr-pot`); the shared project folder is a staging copy.
QA branches from `main`, keeps to `games/cat-cafe/tests/`, `games/cat-cafe/tools/cloudcheck/` and
`docs/playtests/`, and opens a pull request.

| Layer | Where | When | How |
|---|---|---|---|
| Unit tests of pure modules (`tests/specs/*.spec.luau`) | Cloud threads, or any PC with Node 20 | Every change under `src/shared`, `src/server/World/Layout.luau` or the pure client `Audio` and `Effects` logic, before every review | `cd games/cat-cafe/tools/cloudcheck && npm test` |
| Strict type check and lint, cloud stand-in | Same | Same | `npm run analyze` (game), `npm run analyze -- --tests` (specs too) |
| The real done gate | Derek's PC, Rokit toolchain, and CI | Before any task is called done | `cd games/cat-cafe && ./check.ps1` (Windows) or `./check.sh` |
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
   Studio and the abuse pass (same tree plus `ReplicatedStorage.Tests` and `StarterPlayerScripts.TestsAbuse`).
   Never publish a place that contains either.
4. Data: with **Enable Studio Access to API Services** off, ProfileStore runs in mock mode, so every play session
   is a fresh account (good for onboarding tests) and nothing persists (so skip persistence steps and expect
   `dataSaves = false` in the state). Turn it on only for the persistence, offline, bait and dealer rejoin steps,
   using a dev-only DataStore name.
5. Phone checks use Studio's Device emulator (Test tab) at a 390 x 844 phone preset; multi-player checks use
   Test > Clients and Servers with 2 players. Latency checks use File > Studio Settings > Network > Incoming
   Replication Lag (set it back to 0 afterwards).
6. Debug hooks (Studio-only, `src/server/Services/Debug.luau`, every call errors outside Studio). Reach them
   through the `PurrPotDebug` bridge that `Main.server.luau` puts in ServerStorage (PR #50), from the command bar
   in Server view or from `execute_luau` on the server while playing:
   `game.ServerStorage.PurrPotDebug:Invoke("setPhase", "night")`, `:Invoke("setCoins", nil, 5000)`,
   `:Invoke("snapshot")`. Never `require` the Debug module there: those contexts get a fresh copy of every module
   whose services never started (`profile not loaded`, a clock nobody runs). Steps below write
   `Debug.name(args)` as shorthand for `PurrPotDebug:Invoke("name", args)`. `player` may be a Player, a UserId, a
   name, or nil for the first player.
   - On `main` now: `snapshot(player?)` (authoritative `PlayerState`, settled first), `setCoins(player?, n)`,
     `setLastTick(player?, secondsAgo)`, `resetProfile(player?)`, `setTier(player?, tier)`,
     `giveLure(player?, lureId, count?)`, `setLastSeen(player?, secondsAgo)` (returns the offline amount and shows
     the popup), `setSaveVersion(player?, version)`, `giveCat(player?, catId, rescued?)`,
     `setUpgrade(player?, id, level)`, `spawnStray(catId, areaId?)` (returns the StrayId), `setPhase("day" or
     "night")`, `clock()`, `spawnStuckCat(catId, rescueSpotId?)`, `counts(areaId?)`, `dataSaves()`. The server
     also prints a `[Catch]` line per graded circle in Studio.
   - Still asked for (section 8): shiny on `spawnStray` and `giveCat`, `readyBait`, `setDealerStock` or a dealer
     window offset, `spawnRichTip` and a forced bump roll. Steps marked (hook) use these; without the hook the step
     is skipped, not failed.

## 3. Unit tests

### 3.1 What is covered

| Spec | Checks | Source |
|---|---|---|
| `TestKit.spec` | The harness itself. If this fails, trust nothing else in the run. | |
| `Catalog.spec` | Cats, rarities, spots, upgrades, decor, lures, areas: ids snake_case and unique, odds sum to 100, model names from ids | data-model 1 to 9 |
| `Catching.spec` | Odds tables mapped onto rolls and swept 20,000 times, area filtering, uniform pick, rarity ladder fallback, rescue odds, percent text | data-model 8 to 10b |
| `Economy.spec` | Cafe multiplier, cat rate with favorite and variant, income sum, lazy settle, offline gain and cap, affordability, blockers in gate-before-coins order, seats, counts, the loop script in numbers | data-model 5, 6, 11, 14; features 8 |
| `CatStats.spec` | Charm roll and stars, level and XP, rating, sort order, view, migration of v1 cats, rescued flag | data-model 4, 4b |
| `EquipBest.spec` | Best placement against brute force, favorite bonus, locked spots | data-model 4b |
| `Clock.spec` | Phase at any time, countdown without jumps, start of each phase | data-model 9 |
| `Config.spec` | Every constant in data-model section 17 by name and value, no undocumented constant, internal ordering | data-model 17 |
| `Signal.spec` | Connect, disconnect, once, disconnect all, one erroring handler does not stop the rest | |
| `EffectsLogic.spec` | Effects v1 pure logic (vfx-animator, PR #77; QA edges): touch-only devices get the low budget; Purrfect only when every grade is Perfect, a CatchResult with no success flag is a failure; nearest picks within the radius (the edge counts), nearest first, at most the limit; a plot claim, release, owner swap and rank up told apart, a tier rise inside the 2 s claim grace or from tier 0 is not a rank up; every gate a skipped tier crosses opens, none already open; pulse, hiss, landing, confetti and butterfly curves stay bounded; phone bursts 12 or fewer, 4 steady emitters | effects list, Effects v1 |

v0.3 specs QA writes as each feature lands (the engineer is asked to keep these as pure functions in
`src/shared`, section 8):

| Feature | Spec | Checks |
|---|---|---|
| F22 | `Catalog.spec`, `ProfileSchema` cases in `CatStats.spec` | Mythical rarity row (5 circles, 0.65 s, 6 hits, 12,000 sell); 20 slice cats, 10 per area, four Common, two Rare, two Epic, one Legendary, one Mythical each; every `favoriteRole` one of four; 10 role slots with tiers (2, 4, 6, 8, 10 open per tier); five `TierDef`s; upgrades without `cafe_level` and `park_access`; shop and dealer foods with five-rarity odds summing to 100; the 2 to 3 migration (refunds from the frozen v2 cost tables, caps, `tier = 1`, `method`, Equip Best on load, no coins lost); a saved `version` above the code's is refused, not rebuilt |
| F23 | `Clock.spec`, `Config.spec` | 300 s day and 300 s night after a 120 s first day; WaveSize 10 fits every area's spawn points; RescueMinStuck 1 |
| F24 | `Economy.spec` | Rank up requirements: cost, distinct cats (shinies not counted twice), rarity needs; Tier 2 with 1,500 coins and 5 cats, refused with 4; tier multiplier 1.25 raises income 25%; tier caps on tables, espresso and net; decor `requiresTier` |
| F25 | `EquipBest.spec`, `Economy.spec` | Favorite role 1.5x; Equip Best matches brute force on ten slots |
| F26 | `Circles.spec` (on main) | Schedule: circle count by rarity, lead-in 0.6 s, gaps 0.40 to 0.75 s, shrink times within the net's jitter, Master Net with no jitter, lock length; judging: error within perfect is Perfect, within good Good, else Miss, latency cap 0.15 s; `Config.spec` invariant CircleGapMin above the widest good window plus the latency cap (0.40 > 0.18 + 0.15), so a late press can never land on the next circle. Before F34 the scores 1.0, 0.5 and 0 and their mean as the chance are tested too; F34 retires them |
| F34 | `Circles.spec`, `Catalog.spec`, `Config.spec`, a paws module if pure | The attempt ends at the first Miss: grades up to and including it, later circles never judged; success exactly when every circle is Good or Perfect, no roll; `patience` 3, 2, 2, 1, 1 replaces `fleesOnFail`; paws per player per stray, set on the first catch start, one lost per Miss, never below 1 for the `dropOwner` and the tutorial Common; StrayWarySeconds 5 for the player who missed, GrabRetrySeconds 2 for everyone else; charm gain 4 x Perfects, doubled when all are Perfect, 0 with `flags.autoPress` or on a Dropped stray (S36), caught charm `min(100, stray + gain)`; paws are dropped only when the stray despawns, never when the player leaves (N45); the flag sets above 95% Perfect over the last 50 and clears only when the buffer holds a full 50 at 85% or below, so a short buffer after a rejoin never clears a saved flag (N46) |
| F35 | `Catalog.spec`, `Config.spec`, the spawn pick if pure | 24 alley spawn points, 16 `lane` and 8 `square`; Epic and rarer take only free `square` points (any free point if none is free), Commons and Rares any; NormalWalkSpeed 20, CarryWalkSpeed 16; the tutorial Common at the `lane` point behind the player's own cafe |
| F19 | a travel check if pure | `home` or an area id; a locked area, carrying, holding a catch or rescue lock (N47) or inside TravelCooldownSeconds 3 is refused |
| F27 | new `Rescue.spec` | Bar marker position at any server time (speed, bounce, start phase), zone hit with tolerance 0.03, hits per rarity, three paws, `shake_catch` ends in one circle with Pro Net windows |
| F28 | `Catching.spec` | Bait roll: rarity from food odds, cat uniform over that rarity in unlocked areas, the per-cat percentages the card shows, ready at `placedAt + 600` |
| F29 | new `Bump.spec` (if the checks are a pure predicate) | Each protection on its own: range 6, grace 3 s, safe radius 15, cooldown 12 s, same target 60 s, immunity, carrying bumper, self as target, `BumpEnabled` false; drop claims: only the old carrier for 8 s, never the bumper, a dropped stray never flees |
| F30 | `CatStats.spec` | Shiny 1.5x in the rating; shiny chances 0.02, 0.02, 0.10 |
| F31 | `Economy.spec` | Settle across a phase boundary integrates 1.0 by day and 0.6 by night; offline pays the day rate; rich tip `max(50, floor(dayRate x 45))` |
| F32 | new `Dealer.spec` | Same stock for the same UserId, `floor(os.time() / 600)` window and tier, a new stock in the next window, bought marks cleared only by a window change; tier weights over 20,000 seeds (Star Treat 0% at Tier 1, about 10% per slot at Tier 5) |
| F33 | `Economy.spec` or a `Names` module | Trim, 1 to 20 characters by `utf8.len` (a 20 emoji name passes, 21 fails), invalid UTF-8, control characters, newlines, `<` and `>` refused, whitespace-only refused |

Not covered by unit tests, by design: anything that needs DataStores, Players, RemoteEvents, TextService,
physics or the world. `DataService`, `CatService`, `CafeService`, `Net`, `WorldBuilder` and all of `src/client`
except the pure `Audio/Logic`, `Audio/Cues`, `Effects/Logic` and `Effects/Presets` are Studio-only and covered by
sections 4 to 6.

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
`docs/playtests/evidence/YYYY-MM-DD/<step>.png`. Read authoritative numbers with
`game.ServerStorage.PurrPotDebug:Invoke("snapshot")` from `execute_luau` on the server and compare with the HUD. Studio's built-in `subagent` tool (playtest type) can run 4.1 end to end once
it is scripted; keep the manual tool sequence below as the reference.

### 4.1 Smoke run (about 8 minutes, before every friend playtest)

| Step | Tool calls | Expected | Feature |
|---|---|---|---|
| S1 Join | `start_stop_play` start. Wait 10 s. `get_console_output`. `execute_luau`: plots tagged `Plot` with `OwnerUserId == player.UserId` | No errors. Exactly one plot owned, `Tier` attribute 1. HUD shows `$50` and `1.5/s` within 5 s: the starter Tabby (charm 50, level 1) works `barista_1`, its favorite role (hook: `snapshot.money == 50`, `incomePerSecond == 1.5`, `tier == 1`). The Tabby stands upright in an apron | F01, F04, F22, F25 |
| S2 World and gates | `execute_luau`: five area folders under `workspace.World`, a gate per locked area; `CollectionService:GetTagged("Stray")` by `Area` attribute | Alleyway open; Park, Neighbourhood, Woods and Sewer gates solid for a Tier 1 player (`character_navigation` into the Park stops at the gate). By day the alley holds only leftovers and the tutorial Common. (v0.4) The Alleyway is two back alleys behind the cafe rows meeting in the Alley Square; 24 alley spawn points with `Zone` `lane` (16) or `square` (8); every cafe's back door is open at Tier 1; each locked gate shows its tier and the player's progress | F23, F35 |
| S3 Walk to alley | (v0.4) From the farthest cafe's back door, `character_navigation` to the nearest stray spawn point, then to the far side of the Square, then from the cafe to each unlocked gate; time each with `os.clock()` in `execute_luau` | (v0.4) `Humanoid.WalkSpeed` 20; nearest spawn under 2 s, far side of the Square under 8 s, any unlocked gate under 10 s (world-and-feel 2 and 8.4); the tutorial Common waits at the `lane` point behind the player's own cafe. Before F35: the alley centre in under 60 s. Tutorial arrow visible on the way (phone emulator run only) | F01, F13, F35 |
| S4 Catch, Common | Next to the tutorial Common (within 8 studs), trigger the prompt (`user_keyboard_input` `E`). Read the `CatchSchedule` the client received (client `execute_luau`, or the server's `[Catch]` line). Press `E` at the circle's target time; on a second stray, press 0.3 s late on purpose | One circle, shrinking over 1.40 s x (1 +/- 0.30) with a Basic Net, starting 0.6 s after the press. Within 0.045 s of the target is Perfect, within 0.11 s Good, else Miss. (v0.4) Perfect or Good always catches, no roll; an all-Perfect catch reports `charmGain` 8 and the caught cat's charm is the stray's `Charm` plus 8 (capped at 100). The late press is a Miss: the overlay ends at once, `CatchResult` grades `{ "miss" }`, success false, `pawsLeft` 2 (nil for a new player on the tutorial Common, who never runs out), toast `It slipped away! 2 paws left`, the cat jumps back 6 to 10 studs and the prompt returns for this player after 5 s. Before F34: Perfect 100%, Good 50%, Miss 0%; a failed Common stays with the prompt back after 2 s. Success: carry indicator, walk speed 16 (13 before F35; hook: `Humanoid.WalkSpeed`) | F26, F34, F07 |
| S5 Check in | `character_navigation` to own plot `Door`; (v0.4) next time to the back door | Within 8 studs: Cat found popup, `+50` first-catch reward for a new Common, book `2 / 50`, carry indicator gone, speed back to 20 (16 before F35). (v0.4) The back door checks in too | F07, F35 |
| S6 Role | Open the cat room, pick the new cat, assign it to `waiter_1` | It stands upright in a bow tie. Rate rises by its rating, times 1.5 if `waiter` is its favorite (Tuxedo, Snow): `1 x charmMultiplier` where charm 0 to 100 gives 0.8x to 1.2x (read `snapshot.cats[uid].charm`) | F25 |
| S7 Buy | At `$100` buy Tables; at `$400` buy the Bait bowl (hook: `Debug.setCoins` to skip the wait) | Table and two chairs appear, rate x1.10 exactly. A bowl appears at the `BaitBowl` anchor by the door | F08, F28 |
| S8 Refusals | At Tier 1: buy Tables level 3, Espresso level 3, Net level 2, Window plants; assign a cat to `greeter_1`; walk into the Park | Each refused with a toast that names the tier (`Needs Tier 2`), no coins taken, no server error; the gate holds | F24, F23 |
| S9 Bait | Buy Kibble (`$25`), stand at the bowl, use it. (hook: `Debug.readyBait`) | Kibble count drops by 1 at once, `BaitReadyAt` on the plot is `os.time() + 600`, HUD countdown `10:00`. Until ready the client's state holds only `lureId` and `readyAt`, never the rolled cat (client `execute_luau`: read the last ProfileSync). When ready: the cat sits eating at the bowl, the bait card shows name, rarity, stars and the two buttons. Tame adds it to the cat room with no net and no carry (`CatCaught` fires); Let go clears the bowl; the food is gone either way | F28 |
| S10 Night | Wait for the first night (120 s after a fresh server start, or `Debug.setPhase("night")`) | `Phase` flips to `night`. Each unlocked area holds exactly 10 strays (`Debug.counts("alley")`), the alley's three traps (two trash bins, one bag of garbage) each hold a stuck cat with chance 0.6 and at least one is always filled. Stuck cats show `CatId`, `CatName` and `Rarity` but no `Shiny` or charm on the model, prompt or attributes. Rate drops to 60% within one sync (hook: `snapshot.incomePerSecond`), recovers at dawn. The dealer cart appears on the street | F23, F31, F32 |
| S11 Rescue, bar | At a trash bin with a stuck Common (`Debug.spawnStuckCat("ginger", <spot>)`), start the rescue. Press when the marker is inside the zone, twice | The bar's marker moves at 0.8 bar lengths per second, the zone is 0.30 wide. Two hits free the cat; it is revealed (sparkle if shiny) and the player enters carry with `rescued = true`. Three misses end the attempt, the cat stays stuck; other players can retry after 3 s, the player who failed after 6 s. An attempt also ends as a fail at 15 s, when the player walks more than 14 studs away, dies or leaves | F27 |
| S12 Rescue, tree | Tier 2 test profile (hook: `Debug.setTier(player, 2)`), Park tree with a stuck Common | `rescueHits - 1` bar hits shake the branch, then one catch circle (Common shrink time, Pro Net windows 0.065 and 0.155) must score Good or Perfect; a miss means the cat climbs back and the attempt ends | F27 |
| S13 Dealer | At night within 12 studs of the cart, open the dealer screen. Buy one slot (hook: `Debug.setCoins`) | Three slots with food, cost and odds before buying, and "Fresh stock in m:ss" counting to the next 600 s window. A bought slot shows bought and cannot be bought again until the window changes; at the change mid-night the stock refreshes. Dealer food lands in `lures` and works in the bowl | F32 |
| S14 Rank up | Hook: `Debug.setCoins(player, 1500)` and give 5 distinct cats, open the rank up card, rank up | Card ticks cost and 5 different cats; Tier 2: coins drop by 1,500, `Tier` 2, income x1.25 over Tier 1 exactly, the Park gate opens, `waiter_2` and `greeter_1` open. With 4 cats the button is refused and the card says what is missing | F24 |
| S15 Shiny | Hook: `Debug.giveCat(player, "tabby", { shiny = true })` | Rating x1.5 over the same cat's base variant, sparkle on the model and card, the shiny page lists it, every player gets the Announce | F30, F14 |
| S16 Rich tip | By day with income above 0, hook `Debug.spawnRichTip(player)` | A rich customer in a top hat at a table; plot attributes `RichTipAmount = max(50, floor(dayRate x 45))` and `RichTipExpiresAt = now + 90`. Claiming within 12 studs adds the amount once; leaving it unclaimed adds it at expiry; never both. Leaving before expiry still pays it (save-on-leave), and the next player on that plot sees no tip | F31 |
| S17 Rename | Rename a working cat to `Biscuit` | The name shows over the cat (`DisplayName`) for every player and in the cat room. Empty, whitespace-only, 21 character, newline, `<b>` and control character names are refused with a toast; a 20 emoji name is allowed. A second rename within 5 s is dropped | F33 |
| S18 Persist (API access on) | `start_stop_play` stop, start again | Coins within rate x gap of the last value, cats, roles, tier, tables, bait (same cat, same ready time) and dealer bought slots back | F10, F28, F32 |
| S19 Offline | API access on: stop play, wait, start again (with `Debug.setLastSeen` this becomes a 5 s step) | Popup shows `floor(dayRateAtLogout x 0.25 x min(secondsAway, 3600))`, even if the player left at night. Claim adds exactly that once; a second claim adds nothing. A bait placed before leaving is ready if 600 s passed | F12, F28 |
| S20 Travel (v0.4) | Press Alley, then Areas, then Cafe (`user_mouse_input` on the top centre buttons); at Tier 1 tap the Park card; catch a cat and press Alley while carrying; press Cafe mid-catch | Lands at the alley entry and back home from anywhere; the Areas panel shows five cards, locked ones greyed with their tier; the Park card does nothing at Tier 1; every button is greyed while carrying and nothing moves; mid-catch Travel is refused (N47) | F19, F39 |
| S21 For Rent plots (v0.4) | One player on the server: `screen_capture` of each of the seven empty plots from the street. Then start a second player (Clients and Servers) and capture their plot | Every empty plot is a For Rent shop (shutters half down, dust sheets, sign, boxes, a sleeping doorstep cat with no prompt, lamp on at night), never grey boxes. The joining player's shutters roll up, the sign flips to OPEN and the Tabby walks in | F38, F36 |
| S22 Cafe from the street (v0.4) | Stand in the street outside own running cafe, `screen_capture`; walk inside and capture again | Working cats are visible through the glass front; the sign shows the owner's name, tier and rate; customers queue, sit and leave hearts; `+$X/s` tags over working cats within 40 studs; inside, the roof fades on the owner's screen only | F36, F37 |

Record pass or fail per step plus the console text. Any step that cannot run (hook missing, API access off,
feature not built) is marked skipped with the reason, not failed.

### 4.2 Circle feel and latency (F26, phone emulator and PC)

The designer's feel targets (data-model section 10, v0.4): a new player with a Basic Net catches a Common within
its three paws nearly every time; a Rare or Epic feels tense but fair; a Mythical with a Basic Net is a real risk
(five quick uneven circles on one paw); a Master Net makes it fair. Run each line 10 times and record the grade of
every circle (the server's `[Catch]` lines), the paws used and whether it was caught (before F34: the final
chance).

| Line | Setup (hooks) | Record | Target |
|---|---|---|---|
| C1 New player, Common | Fresh profile, Basic Net, `Debug.spawnStray("ginger", "alley")`, a person who has not played it | Grades, catches out of 10, paws used per catch | (v0.4) Caught within its three paws nearly every time: 9 or more of 10. Before F34: 7 or more of 10 within two tries |
| C2 Mythical, Basic Net | `Debug.spawnStray("midnight", "alley")`, net 0 | Grades per circle, how uneven the five shrink times look | Perfect on all five is rare; uneven speeds are visible |
| C3 Mythical, Master Net | Same with `Debug.setUpgrade(player, "net", 3)` | Grades, final chance | Feels fair: steady speeds, most circles Good or better |
| C4 Latency | Incoming Replication Lag 0.1 s, then 0.25 s, Common, net 0; record `player:GetNetworkPing()` on the server at each setting | Perfect rate pressing on the visual target, and the ping the server saw | The server subtracts half the ping, capped at 0.15 s. If the ping reflects the simulated lag, 0.1 s should grade like the 0 s run and 0.25 s should grade late. Record, do not ticket: Studio's lag setting may not match a real phone on mobile data, so the friend round on phones is the real test |
| C5 Touch | Phone emulator, tap the action button | Circle placement (x, y spread), button size, whether the thumb hides the ring | No circle under the thumb zone; button at least 44 px |
| C7 Sure catch (v0.4) | 20 Commons and 5 Rares; press every circle inside the good window, mixing Good and Perfect (by hand, or the abuse client's on-target presses offset by up to 0.08 s) | Catches out of 25, `charmGain` per catch | 25 of 25 caught, no roll; `charmGain` is 4 per Perfect, doubled when every circle is Perfect (world-and-feel 8.2) |
| C6 Phone on mobile data | A real phone on mobile data, then on Wi-Fi, a published test place (not Studio), C1 and C2 again | Grades per circle and the ping the server saw | Phone ping wanders 30 to 50 ms against the 45 ms Basic Perfect window (data-model 10). If Good is the best a careful player gets on mobile data, file a balance note for the designer with the numbers |

If the Basic Net feels mean on touch, the designer's rule is to widen `good` before anything else; file it as a
balance note with the numbers, owner designer.

### 4.3 Two player checks (Clients and Servers, 2 players)

1. Same stray: A starts a catch, B triggers the prompt a second later. Expected: B is refused while A's schedule
   runs; only one `CatchResult` and at most one carry. (F26.)
1b. Paws are per player (v0.4, F34; world-and-feel 8.1): A misses circle 1 of a Rare (`Debug.spawnStray("calico")`).
   Expected: the catch ends at once with no roll, the cat jumps back, A's paw row shows 1 left; B can start a catch
   after 2 s, A only after 5 s. A misses again: A's prompt is gone and A's `GrabBegin` is refused with "It won't
   trust you again tonight", while B still sees the prompt and has B's own 2 paws. A's misses never change B's.
   A leaves and rejoins the same server: still refused on that stray (paws survive a rejoin, reviewer N45).
2. Bump, 20 tries (F29). A carries a cat in the Alleyway at least 3 s into the carry and outside A's safe zone; B
   stands within 6 studs and bumps. Use two test profiles and the hooks to reset carries (or a forced roll for the
   protection rows). Expected: about half knock the cat loose (6 to 14 of 20 is inside the 95% range of a fair
   50% roll); on success the cat drops as a stray with `Dropped` true, keeps its catId, variant, charm and rescued
   flag, and scurries 6 to 10 studs; for 8 s only A can start a catch on it, then anyone except B, who can never
   catch a stray B knocked loose; (v0.4) A never runs out of paws on it: five misses in a row and A can still try
   again, after the 5 s wary wait each time (world-and-feel 8.3; before F34 it never flees on a failed catch,
   whatever its rarity); an all-Perfect re-catch adds no charm (`charmGain` 0, reviewer S36); it stays until
   caught or the next night wave; whoever catches it is `BumpImmune` for that carry; B never receives the cat. On a fail both see "It held on tight!" and A is immune
   for 3 s. Each protection on its own refuses the bump: under 3 s into the carry, within 15 studs of A's door or
   inside A's plot, B more than 6 studs away, B carrying, B bumped anyone in the last 12 s, B bumped A in the last
   60 s, A immune, `BumpEnabled` false (the prompt also hides), B naming itself or a UserId not in the server.
3. Locked area bump: a Tier 1 B inside the Park (walked past the gate in Studio) cannot bump a Tier 2 A there.
4. Rescue lock: A starts a rescue at a trap; B's `RescueBegin` there is refused until A's attempt ends, then
   allowed after 3 s, while A waits 6 s. A walking 15 studs away ends A's attempt as a fail.
5. Announce: A catches an Epic (`Debug.spawnStray("sphynx", "alley")`), finds any shiny and ranks up to Tier 3.
   Expected: B sees all three announcements. (F14, F30, F24.)
6. Visiting: B walks into A's cafe. Expected: B sees A's working cats in uniform with their names, A's tables and
   A's rich customer when there is one. (F18, F25, F33, F31; P2, record only.)

### 4.4 Abuse pass (server validation; anything accepted is a blocker, owner luau-reviewer)

Run from a client context with the QA LocalScript `tests/abuse/AbuseClient.client.luau`. It only exists in a
build made from `tests.project.json` (`rojo serve tests.project.json`, it lands in
`StarterPlayerScripts.TestsAbuse`) and only runs in Studio. In Play Solo or the second client of a Clients and
Servers session: press ` (backquote) to arm it, the key menu prints, then one key per case, or `]` for every case
in a row. From a client-context command bar: `_G.PurrPotAbuse.run("fakeStray")` or `_G.PurrPotAbuse.runAll()`.
Every line it prints starts with `[Abuse]`; `RESULT <case>: PASS|FAIL|SKIP|CHECK` is the verdict (CHECK: the
client cannot tell, read the server output). After a run, filter the server output for `[Net]`: a
`handler failed` line means the server errored on bad input (a major on its own); a `rate limit hit` line once a
second is the correct reaction to a flood. Remote names are the list in `src/shared/Remotes.luau`. The alley is
empty by day apart from the tutorial Common, so run `Debug.setPhase("night")` on the server before the catch
cases.

"Coins unchanged" below means unchanged apart from income. Every `ProfileSync` carries settled income and the
server's refusals sync too, so the script asks for a fresh sync first and allows `incomePerSecond` times the
seconds since then, plus one second and one coin for the server's whole-second clock. A spend still shows as a
drop and a second payout as a second sale.

The catch cases (keys 1 to 8, `[`, `;` and `'`) read the `CatchSchedule` the server sent and press on the
synced clock (`Workspace:GetServerTimeNow()`), the same clock the circles are drawn on; in Studio the server prints
a `[Catch]` line for every circle it grades (index, error in ms, grade). Key `[` wants a Rare or rarer stray, whose
catch outlasts the 1 per 2 s `GrabBegin` limit (`Debug.spawnStray("calico")`), and a second stray nearby; key `;`
wants a Common. Rows marked (manual) are run by hand from the command bar with
`Remotes.event(name):FireServer(...)`.

Catching and rescue (F26, F27, F23)

| Case | Call | Expected server behaviour |
|---|---|---|
| Fake stray (key 1) | `GrabBegin("not_a_stray")`, `CatchPress("not_a_stray", 1)` | Ignored, no answer, no error in console |
| Grab limit (key `[`) | `GrabBegin` on a second stray within 1 s of the first | Dropped by the 1 per 2 s limit: no answer, no schedule |
| Same stray again (key `[`) | `GrabBegin(id)` 2 s into its own catch | `GrabResult` `Keep going, the circles are coming`, no second schedule, one `CatchResult` |
| One catch at a time (key `[`) | 2 s into a catch, stand by another stray and `GrabBegin` it | `Finish this catch first`, no schedule |
| Retry wait (key `;`) | Miss a Common on purpose, `GrabBegin(id)` 2 s after the first `GrabBegin` (inside the wary wait), then once the wait is over, pressing on target | (v0.4) `CatchResult` success false, `pawsLeft` one fewer (2 on a fresh Common); refused `It's wary of you, give it a moment` inside StrayWarySeconds 5 from the miss; after it a new schedule carrying the paws the miss left, and the on-target presses catch it. Before F34: stayed true, `Give it a moment` inside 2 s |
| Out of paws (v0.4, key `.`; second client manual) | Miss the nearest stray until `pawsLeft` is 0 (one miss for a Legendary or Mythical: `Debug.spawnStray("void")`), then `GrabBegin(id)` once the wary wait is over | Toast `It won't trust you tonight`; refused `It won't trust you again tonight` with retry false, no schedule, until the stray despawns; the stray stays with `Paws_<UserId>` 0 on its model; a second client still gets a schedule |
| Far grab (key 2) | Teleport 200 studs away, `GrabBegin(id)` | Refused with `Too far away`, no schedule |
| Far press (key 8) | `GrabBegin` in range, teleport 200 studs away, press every circle on target | Not caught although every press is on target. (v0.4) Walking out of range is a Miss: a paw is lost, the cat jumps back. Before F34: a failed catch with no roll, toast `Too far away`; a Common stays, a Rare flees |
| Locked area | Tier 1, teleport past the Park gate, `GrabBegin(park stray)`, `RescueBegin(park trap)` | Refused, nothing locked, no schedule or challenge |
| Drop claims (Clients and Servers, 3 players) | After B bumps A loose: C `GrabBegin` within 8 s; B `GrabBegin` at any time; A fails a catch on a dropped Rare | Refused within 8 s for anyone but A; refused for B always; the Rare stays; (v0.4) A's `pawsLeft` is nil and A can retry after 5 s however often A misses (before F34: retried after 2 s) |
| Press without begin (key 3; client B part manual) | `CatchPress(id, 1)`, `CatchPress(id, 2)` on a stray nobody locked, and on one client B locked | Ignored |
| Press early (key 4) | `CatchPress(id, 1)` right after `GrabBegin`, before circle 1 starts | Ignored, not counted as the first press; the on-target press still grades |
| Press out of order (key 4) | `CatchPress(id, 2)` before circle 1 is judged | Ignored |
| Press repeated (key 4) | `CatchPress(id, i - 1)` once circle i is open, then circle i on target | Ignored; circle i still grades, every circle Good or Perfect |
| Press twice (manual) | `CatchPress(id, 1)` twice, the first early but after circle 1 starts, the second on target | Only the first press counts: circle 1 is a Miss (v0.4: and the attempt ends there) |
| Press with a time (key 5) | `CatchPress(id, 1, target, "perfect", 1)` 0.15 s after circle 1 starts | Extra arguments ignored, the server stamps the arrival time: circle 1 is a Miss (v0.4: the attempt ends, a paw is lost) |
| Press spam (key `'`) | `CatchPress(id, i)` every 0.1 s from `GrabBegin` on, moving to the next index once a circle has started | The first press after circle 1 starts is early, so circle 1 is a Miss; (v0.4) the attempt ends there and `grades` has one entry. Before F34 every circle scores 0. At most 10 presses per second reach the handler |
| No press (key 6) | `GrabBegin(id)` and never press | (v0.4) Circle 1 is a Miss at its target + good + 0.15 s and the attempt ends there, later circles never judged; success false, a paw lost (`Paws_<UserId>` on the model matches), `charmGain` 0; the cat jumps back 6 to 10 studs and stays; the lock clears. Before F34: every circle scores 0, the roll fails, `stayed` is true for a Common and false for a Rare that flees |
| Scripted perfect (key 7, five runs) | 10 catches pressing each circle on its target, repeated until 50 circles | Accepted as Perfect by design (data-model 10 exploit note). Expected: the server's exploit check flags it from its own stamped errors (Perfect rate above 95% over the last 50 circles; no `TelemetryReport` involved), the warn `[CatService] autopress_flag set for <userId>`. (v0.4) While flagged, `charmGain` is 0: key 7 fails a Purrfect catch that earns charm after 50 Perfect circles in a row. Then press 8 of 10 circles late (Good) for 50 circles and the flag clears at 85% or below (warn `autopress_flag cleared for <userId>`, an analytics event once analytics exists). Flag it, rejoin (API access on) and play 10 Good circles: still flagged, since a buffer under 50 never clears a saved flag (N46). Log, do not ticket, unless the flag never fires or never clears |
| Travel (v0.4, key `,`; rescue by hand) | `Travel` with `""`, `"HOME"`, `"../x"`, 123, `{}`, true, nil and a 41-character id, spaced past the 1 per s limit; `Travel("moon")` ten times in one frame; the next locked area at this tier; `Travel("home")` while carrying and during a catch; `Travel("home")`, then `Travel("alley")` 1 s later and again once 3 s are up. By hand: `Travel("home")` during a rescue hold | Malformed ids get no `TravelResult`, no toast and no move; the flood gets one answer; refused while carrying, during a catch or rescue (N47), into a locked area (`opens at Tier`) and inside 3 s (`Catch your breath first`); home lands within 12 studs of the own door and the alley inside its floor; nobody moves on a refusal and no `[Net] Travel handler failed` line |
| Paws on rejoin (v0.4, manual, API access on not needed) | Miss a Legendary (1 paw), leave and rejoin the same server, `GrabBegin(id)` | Still refused `It won't trust you again tonight` (N45) |
| Bad index (key 4) | `CatchPress(id, 0)`, `(id, 99)`, `(id, -1)`, `(id, 1.5)`, `(id, 0/0)`, `(id, "1")`, `(id, {})`, `(id, nil)` | Dropped silently by `Guard.int`, no error |
| Rescue without begin (manual) | `RescuePress(spot)` on an unlocked trap, `RescueCancel(spot)` on a trap client B locked | Ignored |
| Rescue spam (manual) | `RescuePress(spot)` 10 times a second | Misses cost paws; the attempt ends after 3 misses; the cat stays stuck |
| Rescue retry (manual) | `RescueBegin(spot)` again within 6 s of the same player's failed attempt; another client within 3 s | Refused until each one's retry time |
| Rescue hold (manual) | `RescueBegin(spot)` then no press for 16 s; `RescueBegin` then walk 20 studs away | Attempt ends as a fail at 15 s, or on leaving the 14 stud radius; the trap unlocks |
| Hidden rolls (manual) | Read every attribute and the prompt text of a stuck cat; read the last ProfileSync while a bait is not ready | No `Shiny` or charm on the stuck cat; the bait shows only `lureId` and `readyAt` |
| Rescue while carrying (manual) | `RescueBegin(spot)` while carrying | Refused with the carrying toast |
| Removed remotes | Look for `GrabEnd`, `RescueEnd`, `EquipLure` under `ReplicatedStorage.Remotes` | Not there |
| Bump target (manual) | `Bump(own UserId)`, `Bump("123")`, `Bump(1.5)`, `Bump(nil)`, `Bump(99999999)` (nobody in the server) | Dropped or refused, no error |

Economy, tiers and roles (F24, F25, F08)

| Case | Call | Expected server behaviour |
|---|---|---|
| Bad ids, malformed (key 9) | `BuyUpgrade(41 character string)`, `BuyUpgrade(123)`, `BuyUpgrade(nil)`, `BuyUpgrade({})`, `BuyUpgrade(true)`, `BuyDecor("Neon Sign")`, `PlaceCat(123, "waiter_1")`, `ToggleDecor("plants", "yes")`, `TutorialAdvance("two")`, then `TutorialAdvance(1e9)` 1.2 s later | Dropped by `Guard`: no toast, coins unchanged, no server error |
| Bad ids, unknown (key 9) | `BuyUpgrade("jetpack")`, `BuyDecor("jetpack")`, `BuyUpgrade("cafe_level")`, `BuyUpgrade("park_access")` | Refused; a warn toast is fine; nothing bought, coins unchanged. The two removed v0.2 upgrades are unknown now |
| Unaffordable (key 0) | `BuyUpgrade("tables")` with `$0` | Refused with `Not enough coins`, coins unchanged |
| Tier caps (key 0, script update) | Tier 1: `BuyUpgrade("tables")` to level 3, `("espresso")` to 3, `("net")` to 2; `BuyDecor("plants")`; `PlaceCat(uid, "greeter_1")` | Refused with a tier toast, coins unchanged, levels unchanged |
| Rank up, short | `RankUp()` with 1,500 coins and 4 different cats; with 5 cats and 1,499 coins; Tier 2 to 3 without an Epic | Refused, says what is missing, nothing spent |
| Rank up, double | `RankUp()` twice in one frame with exactly enough for one tier | One tier, one cost; the second is dropped by the 1 per 2 s limit or refused |
| Rank up at the top | `RankUp()` at Tier 5 | Refused, nothing spent |
| Ownership (key -) | `PlaceCat(other player's uid, "waiter_1")`, `SellCat(other uid)`, `UnplaceCat(other uid)`, `RenameCat(other uid, "x")` | Ignored, no toast, coins and cats unchanged |
| Other plot's slot (manual) | `PlaceCat(own uid, slot id that only exists in another plot)` and a made-up `barista_9` | Refused |
| Last working cat (manual) | `SellCat(uid)` on the only working cat | Refused with a toast |
| Double sale (key =) | `SellCat(uid)` twice in one frame (needs 2 cats; sells one for real) | One sale, one cat gone, coins up by its sellValue plus income only |
| Offline twice (key =) | `ClaimOffline()` twice 2.2 s apart | Paid at most once |
| Flood (Backspace) | 30 `RequestSync()` in one frame | At most 2 `ProfileSync` back; one `[Net] rate limit hit` line, not 29 |
| Tutorial (manual) | `TutorialAdvance(5)` from step 0, `TutorialAdvance(-1)`, `TutorialAdvance("2")` | Refused; only `tutorialStep + 1` is accepted (steps 0 to 5 in v0.3) |

Bait, dealer, rich tips and names (F28, F32, F31, F33)

| Case | Call | Expected server behaviour |
|---|---|---|
| Bait without bowl (manual) | `UseLure("kibble")` before buying the bowl | Refused |
| Bait far (manual) | `UseLure("kibble")` 30 studs from the bowl | Refused, food kept |
| Bait full (manual) | `UseLure("kibble")` twice in one frame with 2 Kibble | One food used, one bait saved |
| Bait none held (manual) | `UseLure("salmon")` with 0 Salmon, `UseLure("jetpack")`, `UseLure(7)` | Refused or dropped, nothing used |
| Bait early (manual) | `ResolveBait("tame")` before ready | Refused, bait kept |
| Bait choice (manual) | `ResolveBait("keep")`, `ResolveBait(nil)`, `ResolveBait("tame")` from 50 studs | Dropped or refused |
| Bait double tame (manual) | `ResolveBait("tame")` twice in one frame when ready | One cat added, bowl empty |
| Bait reroll (manual, API access on) | Place Kibble, note the hidden roll (hook: `snapshot.bait`), leave and rejoin | Same catId, variant and charm, same ready time |
| Dealer by day (manual) | `BuyDealerFood(1)` by day | Refused |
| Dealer far (manual) | `BuyDealerFood(1)` 30 studs from the cart | Refused |
| Dealer slot (manual) | `BuyDealerFood(0)`, `(4)`, `("1")`, `(1.5)` | Dropped |
| Dealer twice (manual) | `BuyDealerFood(1)` twice in one frame, then again after a rejoin the same night (API access on) | Bought once |
| Dealer server hop (manual, API access on) | Note the stock and buy slot 1, then join a second server (a second Studio session or a test place) at night within the same 600 s window | Same stock; slot 1 still bought |
| Dealer window (manual) | `BuyDealerFood(1)` just before a window change, then again just after | The second buy sees the new window's stock; the server recomputes the stock from the seed at purchase, never from a client value |
| Rich tip none (manual) | `ClaimRichTip()` with no tip | Ignored |
| Rich tip far (manual) | `ClaimRichTip()` 30 studs from the anchor | Refused |
| Rich tip double (manual) | `ClaimRichTip()` twice in one frame; `ClaimRichTip()` exactly at expiry | Paid once in total, never claim plus auto-credit |
| Rich tip owner (manual, two clients) | A has a tip and leaves; B takes A's plot before the expiry | A is paid on leave; B gets no tip and cannot claim A's |
| Rename bad (manual) | `RenameCat(uid, "")`, `("   ")`, 21 characters, `("a\nb")`, `("<b>x</b>")`, `("\0")`, invalid UTF-8 `("\255")`, `(uid, 123)`, `(uid, nil)` | Refused or dropped, name unchanged |
| Rename flood (manual) | `RenameCat(uid, "a")` then `("b")` within 5 s | Second dropped |
| Rename filter (live test server only) | A name the filter blocks | Refused with a toast when filtering errors or returns all hashes; otherwise the save keeps the raw name and `DisplayName` shows the broadcast-filtered text, filtered again each time the cat starts working, never the raw name to another player. Studio does not filter text the way live servers do, so this row runs in a private test server |
| Telemetry (manual) | `TelemetryReport("not_allowed", 1)`, 11 reports in a minute, `TelemetryReport("catch_circles", 1e308)` | Unknown names dropped, rate limited, no error |
| Client time | Change the client clock or send stale timestamps in any payload | No remote accepts a time argument; income, bait and dealer use server time only (code read, reviewer confirms) |

### 4.5 Performance (phone emulator, P2, record only)

`execute_luau` on the client: average `RunService.Heartbeat` delta over 10 s in the cafe with customers on and
off (hook or a client attribute), and during a five-circle catch. Budget from F15: customers under 2 ms per frame;
the whole scene under 16.7 ms on the emulator's default quality. Record `Stats:GetTotalMemoryUsageMb()` at join and
after 10 minutes, and the count of `ShinySparkle` emitters. (v0.4, F37, world-and-feel 8.8) Standing in the street
with eight running cafes on a phone-sized viewport: 30 or more frames per second; cafes beyond 80 studs culled and
roaming paused with nobody within 60 studs.
(Effects v1, reviewer S35 and the 2026-10-27 build review) At night on the phone emulator with all five areas
spawned (50 strays; hook `Debug.setPhase("night")` at Tier 5 so every gate is open), stand where the most strays
are in view and open the MicroProfiler (Ctrl+F6, or Settings, MicroProfiler): record the client frame time over
10 s and the share under the Effects labels. Target: the frame stays under 33 ms (30 frames per second) and no more
than 8 cats move on the client at once (the low budget). Record, do not ticket, unless the frame rate drops below
30.

### 4.6 Effects (v0.4, effects list "Effects v1", world-and-feel 7)

Precondition: `Main.client.luau` calls `Effects.start()` (engineer, after #77; not on main at 4f21b6f). Until it
does, mark every row skipped with that reason. Run on PC, then repeat E1, E2 and E6 on the phone emulator. Watch
the client output for anything from `Effects` through the whole section (E8). Every effect lives on this client
only: client parts go in `workspace.ClientEffects` and burst emitters on `Burst_*` attachments under
`workspace.Terrain`; neither exists on the server (server `execute_luau`: both absent).

| Row | Do | Expected |
|---|---|---|
| E1 Miss | Miss circle 1 of a Common on purpose (S4's late press). A second client watches from 20 studs. Then turn on Reduce Motion (Roblox settings) and miss again | A grey puff, a pink "!" over the head, the cat rears and hops back with its tail up; the server's 6 to 10 stud jump-back is drawn as travel during the hop, never a snap. The player who missed gets one small camera shake (about 0.18 s); the watcher sees the puff, "!" and hop (from `HissAt`) but no shake. The hiss sound plays with the puff (audio PR #69). With Reduce Motion on: no shake and no flash |
| E2 Catch and Purrfect | Catch a Common with one Good circle, then an all-Perfect catch (`Debug.spawnStray` and the abuse client's on-target presses, or by hand), then a Mythical all-Perfect | The Good catch bursts sparkles in the rarity colour, no gold. The all-Perfect catch adds a gold burst, a gold ring on the ground and gold confetti. On the phone emulator each burst is visibly smaller than on PC (12 particles at most) |
| E3 Claim | Clients and Servers: a second player joins and claims a For Rent plot while the first player watches from the street | The shutters roll up into their top edge with a dust puff, the For Rent sign flips and fades, a little confetti at the door. Before the asset thread's `CatCafe_Plot_ForRent` with `_Shutter` and `_Sign` parts: only the dust puff and confetti |
| E4 Rank up | Rank up to Tier 2 (S14) with the second player within 120 studs, then again with them 150 studs away. Then rejoin a profile saved at Tier 3 | Confetti and a smoke puff at the cafe door for every player within 120 studs, more confetti for the owner; nothing for the player 150 studs away. A rejoin at a saved tier plays the claim effect only, never rank up confetti (claim grace 2 s) |
| E5 Gate | After E4, walk to the Park gate, then away past 70 studs and back | Within 70 studs the barrier copy fades and swells with rising sparkles, confetti and a mint ring, once; walking away and back does not replay it in this session. A gate that opened while the player was far away dissolves when they first walk up |
| E6 Day ambient | By day, `screen_capture` at a running cafe front | A thin steam wisp over the espresso machine and two pastel butterflies looping over the flowers (or the pavement in front of each door until `_Flowers` exists). Chimney smoke only once the cafe roofs have `_Chimney` parts |
| E7 Night ambient | `Debug.setPhase("night")`, capture the street and the Square | Warm fireflies drifting near the street lamps (or `_Fireflies` boxes); no butterflies at night; they return at dawn |
| E8 Console | The whole section | No new error or warning naming `Effects` on the client, none on the server |

## 5. Manual checklist (Derek first, then friends)

Run on a phone preset and once on PC. Tick each line, note the build date. Placeholders (`PH_` parts, Part cats,
colored Part uniforms) are expected in the rough draft and are cosmetic tickets only.

Core loop (features.md section 2 done-when lines)
- [ ] F01 Join, own a plot, walk out of the back door to a stray in under 2 s (v0.4; before F35 cafe to alley and back in under 60 s)
- [ ] F19 (v0.4) Cafe, Alley and Areas buttons top centre work from anywhere; the Areas panel greys locked areas with their tier; all greyed while carrying
- [ ] F22 A v2 save loads as v3: tier 1, cafe level and park pass refunded, two cats working, no coins lost (API access on, an old dev save)
- [ ] F23 Day 5 minutes, night 5 minutes after a 2 minute first day; ten strays per unlocked area at each night start; uncaught strays vanish at the next night start; locked area gates hold
- [ ] F24 Rank up card ticks each requirement; Tier 2 with 1,500 coins and 5 different cats, refused with 4; income rises 25%; the Park gate opens; each tier opens its slots and shop caps
- [ ] F25 Assign a Tabby to Barista: it stands in an apron and earns 1.5x; the cat room shows it on all fours; Equip Best fills every open slot
- [ ] F26 Circles: one slow circle for a Common, five uneven ones for a Mythical with a Basic Net
- [ ] F34 (v0.4) Any mix of Good and Perfect always catches; a Miss ends the catch at once, the cat jumps back and the paw row loses one; at zero paws the prompt hides for you only; an all-Perfect catch shows the Purrfect burst and "Charm +N" (before F34: all Good is a coin flip, a failed Rare flees)
- [ ] F35 (v0.4) The Alleyway is right behind the cafes, both back alleys and the Square feel roomy; rarer cats are in the Square
- [ ] F36 to F38 (v0.4) From the street you see cats at work; signs show name, tier and rate; empty plots are For Rent shops, never grey boxes
- [ ] F27 Rescue: two hits free a Common from a bin; three misses end the attempt and the cat is still there; a tree rescue ends with one catch circle
- [ ] F28 Bait: Kibble in, 10:00 countdown, log off 10 minutes, rejoin and the same cat is waiting; Tame adds it, Let go clears it, the food is gone either way; odds and the per-cat split are on the food card before buying
- [ ] F29 Bump: half the time the cat drops and anyone can net it; no bump near the carrier's door or in the first 3 s; the re-catcher cannot be bumped; the bumper never gets the cat
- [ ] F30 A shiny earns 1.5x, sparkles, shows on the shiny page and is announced
- [ ] F31 Rate drops to 60% at nightfall and recovers at dawn; a rich tip pays 45 s of the day rate whether claimed or not
- [ ] F32 Dealer at night only; same stock after a rejoin in the same night; a bought slot cannot be bought again; odds shown before buying
- [ ] F33 A name shows over the cat for other players; a filter failure keeps the old name with a toast
- [ ] F07 Carry: slower walk, carry indicator, check in at the door; leaving mid-carry still saves the cat (API access on)
- [ ] F10 Rejoin keeps coins, cats, roles, tier, upgrades, decor, foods, bait and dealer purchases (API access on)
- [ ] F12 Leave 10 minutes, return: popup shows 25% of the day rate x seconds away, claim once
- [ ] F13 Fresh account finishes the loop in under 10 minutes without help; prompts never show again on repeat joins
- [ ] F14 Everyone sees Epic and better catches, every shiny and rank ups to Tier 3 and above

Phone and UI
- [ ] All HUD text readable at 390 x 844; no element under the notch or behind the Roblox top bar
- [ ] Every tappable control at least 44 px; no accidental catches when tapping HUD buttons near a stray
- [ ] Circles never sit under the thumb or the action button; the grade of each circle is readable (v0.4: PERFECT, GOOD and MISS pops, the paw row, no percentage; before F34 the final percentage)
- [ ] The rescue bar and its paws are readable on the phone preset
- [ ] Shop, food and dealer cards show cost, effect and odds before purchase; nothing is bought with one accidental tap
- [ ] Every refused action shows a toast that says why (tier, distance, cooldown)
- [ ] Toasts and popups dismiss and never stack off screen
- [ ] No fake timers, no "last chance" wording, no pressure to spend (young audience rule). The bait countdown and the dealer's night are real timers that change nothing if missed: the bait cat waits, the dealer returns next night

Data and errors
- [ ] No red output in the console in a 10 minute session (yellow warnings listed in the report)
- [ ] Joining with Studio API access off shows a visible "progress will not save" notice (state `dataSaves = false`)
- [ ] Leaving during a purchase, a catch, a rescue, a bait resolve or a rank up never duplicates coins or cats
- [ ] F22 newer-save guard (API access on, dev DataStore only): a save whose `version` is above the code's is neither loaded nor saved, and the player is kicked with "The game just updated, please rejoin". Test by joining a v3 save with a v2 build, or with an engineer hook that writes `version = 99` to a dev profile

## 6. Ten minute loop script (Phase 2 exit test) with expected numbers

Fresh account, phone preset, timer running. The steps are features.md section 8; the numbers come from
data-model v0.3 and become spec checks as each feature lands.

1. Join. Plot owned, Tabby working as Barista in an apron, HUD `$50` and `1.5/s` within 5 s (Common 1/s, charm 50,
   favorite role 1.5x, tier 1.0, day 1.0).
2. (v0.4) Walk out of the back door into the Alleyway. A Common stray waits right behind your cafe even by day
   (tutorial guarantee below step 2). One slow circle (1.40 s, Basic Net). Good or Perfect catches it; a Miss
   costs one of its three paws and you try again after 5 s (the tutorial Common never runs out for a new player).
   Before F34: Perfect catches for sure, Good half the time, a miss allows a retry after 2 s.
3. Walk home at speed 16 (13 before F35), check in at either door. Cat found popup, `+50` reward, book `2 / 50`.
4. Assign the new cat as Waiter. It stands up in a bow tie. Rate rises by 0.8 to 1.2 (charm), or 1.2 to 1.8 for a
   Tuxedo or Snow, so the HUD reads between `2.3/s` and `3.3/s`.
5. Buy Table 1 at `$100` (rate x1.10), then the Bait bowl at `$400`, then Kibble at `$25` and put it in. The
   countdown shows `10:00`.
6. First night by minute two: ten strays in the alley and a stuck cat in each of the three traps with chance 0.6,
   at least one always (RescueMinStuck). Rescue it with the bar. The rate drops to 60% for the night.
7. Free play until minute 10. Expected: three or four different cats, two roles filled, two tables, a bait cat on
   the way, the rank up card showing what Tier 2 still needs (1,500 coins and 5 different cats).
8. Leave for 10 minutes, rejoin. Offline popup shows `floor(dayRate x 0.25 x 600)`, for example `412` at a day rate
   of `2.75/s`, and the bait cat is waiting at the bowl. Tame it.
9. Pass: steps 1 to 7 under 10 minutes, no console errors, no open blocker tickets. Analytics (hook or Creator
   Hub): onboarding steps `joined`, `saw_alley`, `first_catch`, `first_checkin`, `first_role`, `first_table`,
   `first_bait`, `first_bait_resolved` fired once each, in order; `tier_2` when reached.

Extra checks for v0.3 and v0.4 (features.md section 8): the bump test over 20 tries (section 4.3 item 2); any mix
of Good and Perfect always catches and a Miss always ends the attempt (C7 and S4; before F34, all-Perfect and
all-Good give 100% and 50%); paws per player (section 4.3 item 1b); travel greyed while carrying (S20); For Rent
plots on a near-empty server (S21); the dealer stock is identical after a
rejoin in the same night (section 4.4); Tier 2 is reached in 10 to 20 minutes of normal play (time it on two
fresh accounts and record the minute).

## 7. Reporting

One file per run, `docs/playtests/YYYY-MM-DD.md`, in the `playtest-report` format: summary, bugs, balance,
confusion, requests, quotes. Tickets use the skill's severity scale (blocker, major, minor, cosmetic), carry
repro steps, expected, actual, evidence path and an owner (engineer, ui-designer, asset-artist, designer). Exploit
shaped findings go to luau-reviewer as blockers. QA never writes the fix.

## 8. Open requests to other threads

1. Engineer, Debug hooks for v0.3 (Studio-only like the rest, reached through `PurrPotDebug`): a shiny option on
   `spawnStray` and `giveCat`; `Debug.readyBait(player?)` (sets `placedAt` 600 s back);
   `Debug.setNightIndex(n)` or `Debug.setDealerStock(player?, { lureIds })`; `Debug.spawnRichTip(player?)`; and a
   way to force the next bump roll (`Debug.forceBump(true or false)`). Done: `setTier`, `giveLure`,
   `setLastSeen`, `setSaveVersion`, the `[Catch]` line per graded circle (F26, PR #40) and the bridge (PR #50).
   v0.4 (F34): `Debug.paws(player?, strayId)` to read a player's paws on a stray (nil when unlimited),
   `Debug.setAutoPress(player?, true or false)` to set or clear the flag without 50 scripted circles and the
   `[Catch]` line to print the attempt's end reason (miss, out of range, done) and `charmGain`.
2. Engineer, pure functions for unit tests (section 3.1): the circle schedule builder and judge, the rescue bar
   position and hit test, the bump checks as a predicate over positions and times, the rank up requirement
   check, the bait roll, the dealer stock roll, `Economy.settle` across phase boundaries, and name trimming, each
   in `src/shared` with the random source passed in.
3. Designer, answered in design v0.3.1: the dealer stock and bought marks key on a global 600 s window, so a
   server hop shows the same stock (section 4.4, Dealer server hop and Dealer window).
4. Designer, answered in design v0.3.1: every area gets at least one stuck cat each night (RescueMinStuck 1).
5. Studio plan thread: the `playtest-report` skill section 2 still describes the per-serve loop ("tap a cat to
   serve"); replace it with section 4.1 of this plan.

## 9. Known gaps

The cloud harness cannot load modules that touch `Instance.new`, events, DataStores, TextService or
`RunService:IsServer()`, and its type check treats most `Enum` types loosely; `./check.sh` with luau-lsp is the
truth for types. Text filtering only behaves for real on live servers. Nothing here replaces a human playing on a
real phone for ten minutes.

## 10. v0.2 rows kept until F27 lands

While `main` still runs the 4 s rescue hold, these replace S11 and S12 above and the rescue rows of section 4.4.
Delete this section when F27 merges. The v0.2 grab rows went with F26 (PR #40).

| Step | Expected |
|---|---|
| Rescue (v0.2) | At night, hold `E` 4 s at a stuck cat: the bar fills, `Rescued!`, always succeeds; letting go at 2 s resets the bar with no fail text |
