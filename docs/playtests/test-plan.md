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
yet is skipped with the reason "not built", not failed.

**Design v0.4** (Derek's rough draft playtest, 2026-10-26) jumps the queue: F34 catching stakes (the first Miss
ends the catch with no roll, any mix of Good and Perfect always catches, paws per player per stray, a Perfect charm
bonus), F35 the Alleyway behind the cafes with walk speed 20, F19 fast travel at P0, then F36 to F39 (cafe shell,
cafe life, For Rent plots, UI patterns). Rows that change say "(v0.4)" and keep the v0.3 behaviour in a "before
F34" or "before F35" clause, so the same table works on either build.

**Design v0.5** (Gavin's round 2, 2026-10-27, features.md section 2c, docs PR #122) changes rows that are built or
in progress: F40 a missed cat sprints `fleeStuds` (12 for a Common up to 32 for a Mythical) away and anyone can try
again with no limit, replacing F34's paws; F41 Shove inside catching areas replaces F29's Bump prompt; F42 shiny
coats and a 5% shiny chance; F43 one dealer stock for every player and server in a window; F44 the cafe closes at
night and the bait bowl moves to the back step. Rows that change say "(v0.5, F4x)" and keep what `main` does now
in a "before F4x" clause.

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
     `setUpgrade(player?, id, level)`, `spawnStray(catId, areaId?, shiny?)` (returns the StrayId; shiny since PR #119), `setPhase("day"
     or "night")`, `clock()`, `spawnStuckCat(catId, rescueSpotId?, shiny?)` (`rescue_alley_1` by default, the Park
     trees are `rescue_park_1` and `rescue_park_2`), `richTip(player?, staySeconds?)` (a rich tip now, returns the
     amount, PR #123), `counts(areaId?)`, `dataSaves()`,
     `baitReady(player?)` (brings the bowl's cat now and returns its catId, PR #108) and `teleport(player?, areaId)`
     (onto an area's first spawn point, past its gate). In Studio the server prints a `[Catch]` line per graded
     circle and a `[Rescue]` line per judged rescue press.
   - Still asked for (section 8): shiny on `giveCat`, `setDealerStock` or a dealer window offset and a forced bump
     (v0.5 shove) roll. Steps marked (hook) use these; without the hook the step
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
| `AudioLogic.spec` | Sound rules (sound-designer, PR #64 and #69; QA edges): voice limits and the minimum gap, pitch ranges, music and ambience by phase and zone, moment lookups, the shout-out step per rarity in `Catalog.rarityOrder`, the nearest world loops within a radius (the edge counts, a max of 0 keeps none), every cue on a known channel with asset ids only, every P0 cue present | sound list 2 to 6 |
| `EffectsLogic.spec` | Effects v1 pure logic (vfx-animator, PR #77; QA edges): touch-only devices get the low budget; Purrfect only when every grade is Perfect, a CatchResult with no success flag is a failure; nearest picks within the radius (the edge counts), nearest first, at most the limit; a plot claim, release, owner swap and rank up told apart, a tier rise inside the 2 s claim grace or from tier 0 is not a rank up; every gate a skipped tier crosses opens, none already open; pulse, hiss, landing, confetti and butterfly curves stay bounded; phone bursts 12 or fewer, 4 steady emitters | effects list, Effects v1 |
| `DealerRows.spec` | Night dealer shop rows (ui-designer, PR #105): a food rolled into two slots shows once with both open slot numbers, bought slots drop out of the open list so Buy sends the next one, the price is the server's, foods the catalog does not know are skipped; the restock clock counts m:ss and stops at 0:00 | data-model 8b |
| `FoodOdds.spec` | The odds text on every food card (ui-designer, PRs #101 and #105, reviewer N69; QA edges): percentages to two decimals with trailing zeros dropped; every catalog food's line names the five rarities in `Catalog.rarityOrder`, a 0% share included, and adds up to 100; a food with no odds says so; the per-cat split adds back up to each rarity's share at every tier, names exactly the cats of the unlocked areas and the area the next rank up adds; the shiny chance and the five charm star odds match `Config` | data-model 8 |
| `Dealer.spec` | The dealer's stock roll and windows (engineer, PR #110): windows DealerWindowSeconds long that restock at the next one; the same three dealer foods for the same player, window and tier, Studio's negative test UserIds included; no Star Treat at Tier 1; the tier weights over many players and windows; bought marks clear only when the window moves forward and every slot counts as bought while the window is behind the saved one (N32). (v0.5) F43 makes one stock for everyone, see its row | data-model 8b |
| `Rescue.spec` | The rescue minigames (engineer, PR #115): a tree is shaken then caught, every other trap is the bar; a bar needs `rescueHits` and a tree one fewer, never under one; zones stay on the bar and move each hit, so the same time misses the next zone; each rarity's speed, width, hits, three paws and a 15 s deadline; a Common freed from a bin in two hits; three misses end it without the cat; presses before the marker moves or after the deadline are ignored; Give up is a fail; a missed or unpressed tree circle sends the cat back up | data-model 10b |
| `RescueMarker.spec` | `Shared.RescueMarker`, the one marker the server judges and the bar draws (ui-designer, PRs #109 and #120): out to the right end and back at the rarity's speed, waiting at its phase before it starts, on the bar over a long attempt; the zone test with its tolerance | data-model 10b |
| `PromptKey.spec` | Action pill captions for prompts that are not cats (ui-designer, PR #113): letter keys as themselves, short number, modifier and gamepad keys, no key on touch where the pill is the button; square caps for one or two characters, wider for words | world-and-feel 6 |
| `RichTipState.spec` | The rich tip marker over your cafe (ui-designer, PR #117): the amount, whole seconds left rounded up so a live tip never reads 0:00, the share of the stay left; nothing without a positive amount or after expiry | data-model 12 |
| `SlotLabelState.spec` | Role slot labels on your own cafe (ui-designer, PR #125): the next locked slot of each role, four at Tier 1, the next one after a rank up, none at the top tier; a free slot labelled in place of its locked one, slots a cat works skipped; "catch a cat" when every cat has a role; nothing while the cats are unknown | data-model 4b |

v0.3 specs QA writes as each feature lands (the engineer is asked to keep these as pure functions in
`src/shared`, section 8):

| Feature | Spec | Checks |
|---|---|---|
| F22 | `Catalog.spec`, `ProfileSchema` cases in `CatStats.spec` | Mythical rarity row (5 circles, 0.65 s, 6 hits, 12,000 sell); 20 slice cats, 10 per area, four Common, two Rare, two Epic, one Legendary, one Mythical each; every `favoriteRole` one of four; 10 role slots with tiers (2, 4, 6, 8, 10 open per tier); five `TierDef`s; upgrades without `cafe_level` and `park_access`; shop and dealer foods with five-rarity odds summing to 100; the 2 to 3 migration (refunds from the frozen v2 cost tables, caps, `tier = 1`, `method`, Equip Best on load, no coins lost); a saved `version` above the code's is refused, not rebuilt |
| F23 | `Clock.spec`, `Config.spec` | 300 s day and 300 s night after a 120 s first day; WaveSize 10 fits every area's spawn points; RescueMinStuck 1 |
| F24 | `Economy.spec` | Rank up requirements: cost, distinct cats (shinies not counted twice), rarity needs; Tier 2 with 1,500 coins and 5 cats, refused with 4; tier multiplier 1.25 raises income 25%; tier caps on tables, espresso and net; decor `requiresTier` |
| F25 | `EquipBest.spec`, `Economy.spec` | Favorite role 1.5x; Equip Best matches brute force on ten slots |
| F26 | `Circles.spec` (on main) | Schedule: circle count by rarity, lead-in 0.6 s, gaps 0.40 to 0.75 s, shrink times within the net's jitter, Master Net with no jitter, lock length; judging: error within perfect is Perfect, within good Good, else Miss, latency cap 0.15 s; `Config.spec` invariant CircleGapMin above the widest good window plus the latency cap (0.40 > 0.18 + 0.15), so a late press can never land on the next circle. Before F34 the scores 1.0, 0.5 and 0 and their mean as the chance are tested too; F34 retires them |
| F34 | `Circles.spec`, `Catalog.spec`, `Config.spec`, a paws module if pure | The attempt ends at the first Miss: grades up to and including it, later circles never judged; success exactly when every circle is Good or Perfect, no roll; `patience` 3, 2, 2, 1, 1 replaces `fleesOnFail`; paws per player per stray, set on the first catch start, one lost per Miss, never below 1 for the `dropOwner` and the tutorial Common; StrayWarySeconds 5 for the player who missed, GrabRetrySeconds 2 for everyone else; charm gain 4 x Perfects, doubled when all are Perfect, 0 with `flags.autoPress` or on a Dropped stray (S36), caught charm `min(100, stray + gain)`; paws are dropped only when the stray despawns, never when the player leaves (N45); the flag sets above 95% Perfect over the last 50 and clears only when the buffer holds a full 50 at 85% or below, so a short buffer after a rejoin never clears a saved flag (N46); (v0.5) F40 retires the paws, see its row |
| F35 | `Catalog.spec`, `Config.spec`, `Layout.spec` (on main), the spawn pick if pure | 24 alley spawn points, 16 `lane` and 8 `square`; Epic and rarer take only free `square` points, and with the Square full a rare stray waits for the next wave (world-and-feel 2, engineer PR #86), Commons and Rares any; NormalWalkSpeed 20, CarryWalkSpeed 16; the tutorial Common at the `lane` point behind the player's own cafe. Check 4 (docs PR #83) on a 1 stud grid over the Alleyway floor: every spawn point reachable from every yard gate, a spawn under 2 s from every back door at walk speed, the carry from any Square point to any back door under 25 s at carry speed (layout v2: 22.1 s worst, plot 1 to the far east of the Square); the roam rects (PR #102) lie on the floor clear of every wall, keep 5 studs off both outer walls and off the Square's north wall, and hold every spawn point 2 studs inside; the manhole sits on the Square floor inside the roam, more than its 8 stud prompt from the arrival point and out of every rescue's reach |
| F19 | a travel check if pure | `home` or an area id; a locked area, carrying, holding a catch or rescue lock (N47) or inside TravelCooldownSeconds 3 is refused |
| F27 | `Rescue.spec`, `RescueMarker.spec` (on main) | Bar marker position at any server time (speed, bounce, start phase), zone hit with tolerance 0.03, hits per rarity, three paws, `shake_catch` ends in one circle with Pro Net windows |
| F28 | `Catching.spec`, `FoodOdds.spec`, `Config.spec` (on main) | Bait roll: rarity from the food's odds (`pickRarity`), the cat uniform over that rarity in every unlocked area (`pickBaitCat`: 240 even rolls land on each cat of the pool equally at every tier, the roll edges stay in the pool, never nil); the card's per-cat split names exactly the cats the roll can pick; `LureWaitSeconds` 600, `BaitBowlRangeStuds` 12, `BaitResolveRangeStuds` 20, `ShinyChanceBait` 0.02 |
| F29 | new `Bump.spec` (if the checks are a pure predicate) | Each protection on its own: range 6, grace 3 s, safe radius 15, cooldown 12 s, same target 60 s, immunity, carrying bumper, self as target, `BumpEnabled` false; drop claims: only the old carrier for 8 s, never the bumper, a dropped stray never flees (v0.5: F41 Shove, see its row) |
| F30 | `CatStats.spec` | Shiny 1.5x in the rating; shiny chances 0.02, 0.02, 0.10 (v0.5, F42: 0.05, 0.05, 0.10) |
| F31 | `Economy.spec` | Settle across a phase boundary integrates 1.0 by day and 0.6 by night; offline pays the day rate; rich tip `max(50, floor(dayRate x 45))` |
| F32 | new `Dealer.spec`; `DealerRows.spec` (UI, on main) | Same stock for the same UserId, `floor(os.time() / 600)` window and tier, a new stock in the next window, bought marks cleared only by a window change; tier weights over 20,000 seeds (Star Treat 0% at Tier 1, about 10% per slot at Tier 5); the buy check refuses a slot whose recomputed food is not the `lureId` the client named (reviewer S42); (v0.5) F43 replaces the per-player, per-tier stock, see its row |
| F33 | `Economy.spec` or a `Names` module | Trim, 1 to 20 characters by `utf8.len` (a 20 emoji name passes, 21 fails), invalid UTF-8, control characters, newlines, `<` and `>` refused, whitespace-only refused |
| F40 (v0.5) | `Catalog.spec`, `Config.spec`, `Circles.spec` | `fleeStuds` 12, 16, 20, 26, 32 by rarity in place of `patience`; StrayFleeSpeed 26, above NormalWalkSpeed 20; StrayRestSeconds 1.5; `patience`, StrayWarySeconds and StrayJumpBackStuds gone; `CatchSchedule` and `CatchResult` carry no `pawsLeft`; the flee target, if pure, is `fleeStuds` straight away from the player and clamped into the area's roam |
| F41 (v0.5) | new `Shove.spec` (if the checks are a pure predicate) | Each check on its own: both players inside one catching area the shover has unlocked (never on the street, in a cafe or a yard), range 6, the target holds no catch or rescue lock, back door safe radius 15, cooldown 8 s, the same target 20 s, ShoveKnockbackStuds 10; on a carrier the 50% knock-loose with every F29 protection |
| F42 (v0.5) | `Config.spec`, `FoodOdds.spec` | ShinyChanceNet and ShinyChanceBait 0.05, ShinyChanceRescue still 0.10; every food card's extras line reads "Shiny 5%" |
| F43 (v0.5) | `Dealer.spec` | The same three foods for any two UserIds in one window, whatever their tier; one DealerSlotWeights row 50 / 33 / 14 / 3 over 20,000 windows; bought marks still per player |
| F44 (v0.5) | `Config.spec`, `Layout.spec` | CustomerSpawnSecondsNight gone, NightIncomeMultiplier still 0.6; the plot's `BaitBowl` anchor on the back step behind the cafe, facing the Alleyway, clear of the back door and the yard gate |

Not covered by unit tests, by design: anything that needs DataStores, Players, RemoteEvents, TextService,
physics or the world. `DataService`, `CatService`, `CafeService`, `Net`, `WorldBuilder` and all of `src/client`
except the pure `Audio/Logic`, `Audio/Cues`, `Effects/Logic`, `Effects/Presets` and the `UI/Components` modules
`DealerRows`, `FoodOdds`, `PromptKey`, `RichTipState` and `SlotLabelState` are Studio-only and covered by sections
4 to 6.

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
| S3 Walk to alley | (v0.4) From the farthest cafe's back door, `character_navigation` to the nearest stray spawn point. Press Alley, then each unlocked Areas card. Catch a stray on the Square point farthest from that cafe (`Debug.spawnStray` puts it on a free point; move it with the hook if needed) and carry it to the nearer of the cafe's two doors. Time each walk with `os.clock()` in `execute_luau` | (v0.4, world-and-feel 2 and check 4 as of docs PR #83) `Humanoid.WalkSpeed` 20; the nearest spawn under 2 s; Alley lands inside the Square just past the street arch, every Areas card lands just inside its gate; the carry home under 25 s at walk speed 16 (`Layout.spec` bounds it at about 22 s by the back door). The tutorial Common waits at the `lane` point behind the player's own cafe. Before F35: the alley centre in under 60 s. Tutorial arrow visible on the way (phone emulator run only) | F01, F13, F19, F35 |
| S4 Catch, Common | Next to the tutorial Common (within 8 studs), trigger the prompt (`user_keyboard_input` `E`). Read the `CatchSchedule` the client received (client `execute_luau`, or the server's `[Catch]` line). Press `E` at the circle's target time; on a second stray, press 0.3 s late on purpose | One circle, shrinking over 1.40 s x (1 +/- 0.30) with a Basic Net, starting 0.6 s after the press. Within 0.045 s of the target is Perfect, within 0.11 s Good, else Miss. (v0.4) Perfect or Good always catches, no roll; an all-Perfect catch reports `charmGain` 8 and the caught cat's charm is the stray's `Charm` plus 8 (capped at 100). The late press is a Miss: the overlay ends at once, `CatchResult` grades `{ "miss" }`, success false, `pawsLeft` 2 (nil for a new player on the tutorial Common, who never runs out), the catch HUD shows `It slipped away! 2 paws left` with the paw row one down (a server toast before engineer PR #91, reviewer S39; never both), the cat jumps back 6 to 10 studs and the prompt returns for this player after 5 s. Before F34: Perfect 100%, Good 50%, Miss 0%; a failed Common stays with the prompt back after 2 s. (v0.5, F40) The Miss sends the cat sprinting about 12 studs away (`fleeStuds` for a Common) at speed 26 with `FleeingUntil` set, the HUD says "It got away! Chase it!" with no paw row, `GrabBegin` is refused "It's running!" until it stops and rests 1.5 s, then this player or anyone can try again with no limit; `CatchResult` has no `pawsLeft`. Success: carry indicator, walk speed 16 (13 before F35; hook: `Humanoid.WalkSpeed`) | F26, F34, F40, F07 |
| S5 Check in | `character_navigation` to own plot `Door`; (v0.4) next time to the back door | Within 8 studs: Cat found popup, `+50` first-catch reward for a new Common, book `2 / 50`, carry indicator gone, speed back to 20 (16 before F35). (v0.4) The back door checks in too | F07, F35 |
| S6 Role | Open the cat room, pick the new cat, assign it to `waiter_1` | It stands upright in a bow tie. Rate rises by its rating, times 1.5 if `waiter` is its favorite (Tuxedo, Snow): `1 x charmMultiplier` where charm 0 to 100 gives 0.8x to 1.2x (read `snapshot.cats[uid].charm`) | F25 |
| S7 Buy | At `$100` buy Tables; at `$400` buy the Bait bowl (hook: `Debug.setCoins` to skip the wait, or `Debug.setUpgrade(nil, "lure_bowl", 1)`). A second client watches from the street | Table and two chairs appear, rate x1.10 exactly. A bowl appears just inside the garden fence, right of the path (`Plot/Bait`), clear of the pots, flowers, fence posts and the Tier 2 bench; walking up shows the owner an "Add food" prompt, the second client sees the bowl but no prompt (v0.5, F44: the bowl sits outside on the back step facing the Alleyway, where other players see the bait cat eating but only the owner gets the prompt) | F08, F28 |
| S8 Refusals | At Tier 1: buy Tables level 3, Espresso level 3, Net level 2, Window plants; assign a cat to `greeter_1`; walk into the Park | Each refused with a toast that names the tier (`Needs Tier 2`), no coins taken, no server error; the gate holds | F24, F23 |
| S9 Bait | With the bowl (S7) and Kibble (`$25`, or `Debug.giveLure(nil, "kibble", 2)`), press "Add food" and use Kibble from 15 studs, then beside the bowl. Rejoin once while it waits (API access on). Then `Debug.baitReady()` (returns the rolled catId) and Tame; repeat with Let go. Once on a fresh profile at tutorial step 4 | From 15 studs: "Walk to your bait bowl first.", food kept. Up close: Kibble drops by 1 at once, toast "Kibble is in the bowl. A cat will come by in 10 minutes.", `BaitReadyAt` on the plot is `os.time() + 600`, the HUD chip counts down from 10:00 and carries on after the rejoin. Until ready the client's ProfileSync `bait` holds only `lureId` and `readyAt`, never `cat` (client `execute_luau`: read the last ProfileSync). Within a second of `baitReady` the cat it named stands beside the bowl, head over it, seen from the street; the bait card pops with its name, rarity, stars, Tame and Let go; the prompt reads "See the cat". Tame (within 20 studs): it joins the cat room with method `bait` and its rolled variant and charm, no net and no carry, `CatCaught` fires, an Epic or rarer announces "<player> tamed a(n) <Rarity> <Cat> at their bait bowl!" and the bowl empties. Let go: "The <Cat> wandered off, full of food.", bowl empty. The food is gone either way. At tutorial step 4 the first food moves the tutorial to step 5 | F28 |
| S10 Night | Wait for the first night (120 s after a fresh server start, or `Debug.setPhase("night")`) | `Phase` flips to `night`. Each unlocked area holds exactly 10 strays (`Debug.counts("alley")`), the alley's three traps (two trash bins, one bag of garbage) each hold a stuck cat with chance 0.6 and at least one is always filled. Stuck cats show `CatId`, `CatName` and `Rarity` but no `Shiny` or charm on the model, prompt or attributes. (v0.4, F35) Right after the wave every Epic, Legendary and Mythical stray in the Alleyway stands in the Square (`Position.Z` between SquareSouthZ 88 and SquareNorthZ 152), never in a back alley; `Debug.spawnStray` falls back to point 1 when nothing is free, so judge this on the wave's own strays. Rate drops to 60% within one sync (hook: `snapshot.incomePerSecond`), recovers at dawn. Before F44 customers keep coming as night owls, one every 12 s (F31). (v0.5, F44) The cafe closes instead: customers leave, the sign shows Closed with a moon, working cats nap at their stations and no customer comes until dawn, while the rate stays at 60%. The dealer cart appears on the street | F23, F31, F32, F44 |
| S11 Rescue, bar | At a trash bin with a stuck Common (`Debug.spawnStuckCat("ginger", <spot>)`), start the rescue. Press when the marker is inside the zone, twice | The bar's marker moves at 0.8 bar lengths per second, the zone is 0.30 wide. Two hits free the cat; it is revealed (sparkle if shiny) and the player enters carry with `rescued = true`. Three misses end the attempt, the cat stays stuck; other players can retry after 3 s, the player who failed after 6 s. An attempt also ends as a fail at 15 s, when the player walks more than 14 studs away, dies or leaves. Rarer cats get a faster marker and a narrower zone (`RescueBarSpeed` Rare 1.0 up to Mythical 1.6, `RescueZoneWidth` 0.24 down to 0.12) and need `rescueHits`. Studio prints one `[Rescue]` line per press. `RescueBegin` is refused with its reason while carrying ("Check in the cat you are carrying first"), while someone else is rescuing ("Someone else is rescuing it"), mid-catch ("Finish this catch first") and from more than 12 studs ("Too far away"); `GrabBegin` is refused mid-rescue ("Finish this rescue first"); Give up ends the attempt as a fail | F27 |
| S12 Rescue, tree | Tier 2 test profile (hook: `Debug.setTier(player, 2)`), Park tree with a stuck Common (`Debug.spawnStuckCat("ginger", "rescue_park_1")`) | `rescueHits - 1` bar hits shake the branch, then one catch circle (Common shrink time, Pro Net windows 0.065 and 0.155) must score Good or Perfect; a miss means the cat climbs back and the attempt ends | F27 |
| S13 Dealer | At night within 12 studs of the cart, open the dealer screen. Buy one slot (hook: `Debug.setCoins`). Then keep the screen open across a 600 s window change (hook: a dealer window offset) and press Buy on a row as the countdown reaches 0:00 | Three slots with food, cost and odds before buying, and "Fresh stock in m:ss" counting to the next 600 s window. A food rolled into two slots shows once as "x2 Stock"; Buy sends `BuyDealerFood(slot, lureId)` for its first open slot and the row drops to "x1 Stock", then "Sold out". A `DealerStock` comes back after every Buy, bought or refused, so the button never hangs. A bought slot cannot be bought again until the window changes; at the change mid-night the stock refreshes. The Buy at 0:00 either lands in the old window and buys, or lands after the change naming the old food and is refused with coins kept; it never buys a food the screen did not show (reviewer S42). The screen then shows the new stock. Dealer food lands in `lures` and works in the bowl. (v0.5, F43) Every player on every server sees the same three foods in a window whatever their tier (check with a second client, then a second server); each still buys each slot once. Before F43 the stock is per player and tier | F32 |
| S14 Rank up | Hook: `Debug.setCoins(player, 1500)` and give 5 distinct cats, open the rank up card, rank up | Card ticks cost and 5 different cats; Tier 2: coins drop by 1,500, `Tier` 2, income x1.25 over Tier 1 exactly, the Park gate opens, `waiter_2` and `greeter_1` open. With 4 cats the button is refused and the card says what is missing | F24 |
| S15 Shiny | Hook: `Debug.spawnStray("tabby", "alley", true)`, catch it and check it in | The stray sparkles before the catch (`Shiny` true on the model, F30 net shinies, PR #119); caught, it rates x1.5 over the same cat's base variant, sparkles on the model and card, the shiny page lists it and every player gets the Announce. (v0.5, F42) It also wears its own shiny coat on the same mesh (frost for now) | F30, F42, F14 |
| S16 Rich tip | By day with income above 0 and at least one table (N81), hook `Debug.richTip()`, then `Debug.richTip(nil, 20)` for the expiry steps | A rich customer in a top hat at a table; plot attributes `RichTipAmount = max(50, floor(dayRate x 45))` and `RichTipExpiresAt = now + 90` (now + 20 with the short stay). Claiming within 12 studs adds the amount once (farther: "Walk closer to collect the tip"); leaving it unclaimed adds it at expiry; never both. Leaving before expiry still pays it (save-on-leave), and the next player on that plot sees no tip | F31 |
| S17 Rename | Rename a working cat to `Biscuit` | The name shows over the cat (`DisplayName`) for every player and in the cat room. Empty, whitespace-only, 21 character, newline, `<b>` and control character names are refused with a toast; a 20 emoji name is allowed. A second rename within 5 s is dropped | F33 |
| S18 Persist (API access on) | `start_stop_play` stop, start again | Coins within rate x gap of the last value, cats, roles, tier, tables, bait (same cat, same ready time) and dealer bought slots back | F10, F28, F32 |
| S19 Offline | API access on: stop play, wait, start again (with `Debug.setLastSeen` this becomes a 5 s step) | Popup shows `floor(dayRateAtLogout x 0.25 x min(secondsAway, 3600))`, even if the player left at night. Claim adds exactly that once; a second claim adds nothing. A bait placed before leaving is ready if 600 s passed | F12, F28 |
| S20 Travel (v0.4) | Press Alley, then Areas, then Cafe (`user_mouse_input` on the top centre buttons); at Tier 1 tap the Park card; catch a cat and press Alley while carrying; press Cafe mid-catch | Alley lands inside the Square just past the street arch, each unlocked Areas card just inside its gate, Cafe back home from anywhere; the Areas panel shows five cards, locked ones greyed with their tier; the Park card does nothing at Tier 1; every button is greyed while carrying and nothing moves; mid-catch Travel is refused (N47) | F19, F39 |
| S21 For Rent plots (v0.4) | One player on the server: `screen_capture` of each of the seven empty plots from the street. Then start a second player (Clients and Servers) and capture their plot; then the second player leaves | Every plot has its pastel shell (`CatCafe_Plot_Cafe_Mint`, `_Blush`, `_Butter` or `_Lilac` by plot number, engineer PR #88) and every empty plot shows `Plot/Dressing/ForRent`: shutters half down, dust sheets, sign, boxes, a sleeping doorstep cat with no prompt, lamp on at night; never grey boxes. The joining player's For Rent dressing goes for everyone, Effects rolls the shutters up (E3), the name sign reads their name and the Tabby walks in. When they leave, For Rent comes back and their cats go | F38, F36 |
| S23 Tier dressing and roof (v0.4) | Own plot at Tier 1, then rank up through Tier 5 (`PurrPotDebug:Invoke("setTier", nil, n)` or S14), capturing the front at each tier. Walk in and out of the front door, then into the second player's cafe | Tier pieces add up and never vanish: Tier 1 awning and chalkboard, then flower boxes, the neon OPEN sign and string lights, the patio, the gold trim. Inside any cafe its roof fades out over about 0.3 s on your screen only (the player outside still sees it) and the camera does not zoom in front of it; it fades back when you leave. The back door opens onto the yard and the back alley | F36 |
| S22 Cafe from the street (v0.4) | Stand in the street outside own running cafe, `screen_capture`; walk inside and capture again | Working cats are visible through the glass front; the sign shows the owner's name, tier and rate by day ("Closed" at night; plot attributes `OwnerName`, `TierName`, `Rate`); customers queue, sit and leave hearts; `+$X/s` tags over working cats within 40 studs; inside, the roof fades (S23) (v0.5, F44: at night the sign shows Closed with a moon, no customers, the cats nap at their stations) | F36, F37 |
| S24 Cafe life (v0.4, engineer PR #85) | Clients and Servers, two running cafes next to each other; on one client count the `Customer` models in its `LocalCustomers` folder near each cafe for 60 s, then walk 100 studs away; phone emulator once. Unplace all but five cats, then place one again | Customers walk into both cafes, not just your own, while the camera is within 80 studs (`CafeLifeRangeStuds`), at most 24 at once on PC and 12 on a phone (`CustomersMaxLow`); none beyond 80 studs. Each stops at the counter for about 2 s with an `Order` (coffee, cake or milk), sits, gets `Served`, leaves. Coin pops only over your own cafe. Four of the five unplaced cats nap at the nap spots, best rated first (`Slot` `nap_1` to `nap_4`, `Napping` true), the fifth stays in the cat room; a placed cat leaves its nap spot for its station. Working cats carry the `WorkingCat` tag. (v0.5, F44) At night no customers come and the working cats nap at their stations; before F44 night owls come every 12 s | F37 |
| S25 Manhole (v0.4, engineer PR #102) | At Tier 1 walk to the manhole in the middle of the Alley Square (`Layout.manhole`, about (0, 124)) and hold its prompt; `Debug.setTier(nil, 5)` and hold it again; catch a cat and hold it while carrying; hold it right after an Alley button press | Skipped, not failed, while the `CatCafe_Sewer_Manhole` asset is missing (no manhole is built). The prompt reads "Climb down" over "Sewer", a 0.3 s hold from 8 studs. Below Tier 5 it answers like the Sewer's Areas card: a `TravelResult` with ok false and nothing moves. At Tier 5 the cover slides off, the Sewer sign hangs over it and the hold lands just inside the Sewer, where its Areas card lands. While carrying it is refused like every travel button, and the Travel cooldown covers the manhole and the buttons together | F19, F39 |
| S26 Alley dressing (v0.4, engineer PR #102) | `screen_capture` both back alleys and the Square by day and at night; stand within 60 studs of strays for 2 minutes and miss one near an outer wall; `Debug.spawnStuckCat("ginger", <spot>)` at each of the three rescue spots | Building backs, fire escapes, crate stacks, lights and laundry line the outer walls and the Square's north wall; nothing blocks a yard gate, the street arch or the Neighbourhood gate. Strays wander and jump back only on the open lane and Square, never into the 5 stud strip along the outer walls or the 3.5 studs under the north wall (`Layout.alley.roam`). The trash bins sit against the outer walls of both back alleys and the garbage bags under the Square's north wall (F27), each with its prompt reachable on foot | F35 |

Record pass or fail per step plus the console text. Any step that cannot run (hook missing, API access off,
feature not built) is marked skipped with the reason, not failed.

### 4.2 Circle feel and latency (F26, phone emulator and PC)

The designer's feel targets (data-model section 10, v0.5): a new player with a Basic Net catches a Common in a
try or two nearly every time; a Rare or Epic feels tense but fair; a Mythical with a Basic Net is a real chase (five
quick uneven circles, and a 32 stud sprint after each miss); a Master Net makes it fair. Run each line 10 times and
record the grade of every circle (the server's `[Catch]` lines), the tries used (paws before F40) and whether it was
caught (before F34: the final chance).

| Line | Setup (hooks) | Record | Target |
|---|---|---|---|
| C1 New player, Common | Fresh profile, Basic Net, `Debug.spawnStray("ginger", "alley")`, a person who has not played it | Grades, catches out of 10, tries per catch | (v0.5) Caught within three tries nearly every time: 9 or more of 10 (v0.4: within its three paws). Before F34: 7 or more of 10 within two tries |
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
1b. Chase after a miss (v0.5, F40; world-and-feel 8.1): A misses circle 1 of a Rare (`Debug.spawnStray("calico")`).
   Expected: the catch ends at once with no roll and the cat sprints about 16 studs away from A, faster than A
   walks, without leaving its area; while it runs and rests 1.5 s (`FleeingUntil`) both A's and B's `GrabBegin` are
   refused "It's running!"; then whoever reaches it first can try, A included, and A can miss and retry five times
   in a row. Before F40, paws per player (v0.4, F34): the cat jumps back and A's paw row shows 1 left; B can start a
   catch after 2 s, A only after 5 s; a second miss and A's `GrabBegin` is refused "It won't trust you again
   tonight" while B keeps B's own 2 paws; the paws survive A rejoining the same server (reviewer N45).
2. Bump, 20 tries (F29; v0.5, F41: the same test with the Shove button or key, the cooldowns 8 s and 20 s, and A pushed about 10 studs on every shove). A carries a cat in the Alleyway at least 3 s into the carry and outside A's safe zone; B
   stands within 6 studs and bumps. Use two test profiles and the hooks to reset carries (or a forced roll for the
   protection rows). Expected: about half knock the cat loose (6 to 14 of 20 is inside the 95% range of a fair
   50% roll); on success the cat drops as a stray with `Dropped` true, keeps its catId, variant, charm and rescued
   flag, and scurries 6 to 10 studs; for 8 s only A can start a catch on it, then anyone except B, who can never
   catch a stray B knocked loose; (v0.4) A never runs out of paws on it: five misses in a row and A can still try
   again, after the 5 s wary wait each time (v0.5: after each sprint) (world-and-feel 8.3; before F34 it never flees on a failed catch,
   whatever its rarity); an all-Perfect re-catch adds no charm (`charmGain` 0, reviewer S36); it stays until
   caught or the next night wave; whoever catches it is `BumpImmune` for that carry; B never receives the cat. On a fail both see "It held on tight!" and A is immune
   for 3 s. Each protection on its own refuses the bump: under 3 s into the carry, within 15 studs of A's door or
   inside A's plot, B more than 6 studs away, B carrying, B bumped anyone in the last 12 s, B bumped A in the last
   60 s (v0.5: 8 s and 20 s), A immune, `BumpEnabled` false (the prompt also hides), B naming itself or a UserId not in the server.
3. Locked area bump: a Tier 1 B inside the Park (walked past the gate in Studio) cannot bump a Tier 2 A there.
   (v0.5, F41; world-and-feel 8.3) Shove: A and B can shove each other anywhere in the Alleyway, carrying or not;
   nobody can shove on the street, in a cafe or a yard, or shove a player in the middle of a catch or rescue.
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
| Retry wait (key `;`) | Miss a Common on purpose, `GrabBegin(id)` 2 s after the first `GrabBegin` (inside the wary wait), then once the wait is over, pressing on target | (v0.4) `CatchResult` success false, `pawsLeft` one fewer (2 on a fresh Common); refused `It's wary of you, give it a moment` inside StrayWarySeconds 5 from the miss; after it a new schedule carrying the paws the miss left, and the on-target presses catch it. Before F34: stayed true, `Give it a moment` inside 2 s (v0.5, F40) Instead: refused `It's running!` while `FleeingUntil` is ahead, then a schedule with no `pawsLeft`, for this player as for anyone |
| Out of paws (v0.4, key `.`; second client manual) | Miss the nearest stray until `pawsLeft` is 0 (one miss for a Legendary or Mythical: `Debug.spawnStray("void")`), then `GrabBegin(id)` once the wary wait is over | The last Miss's `CatchResult` has `pawsLeft` 0 and the catch HUD says `It won't trust you tonight` (a toast before PR #91); refused `It won't trust you again tonight` with retry false, no schedule, until the stray despawns; the stray stays with `Paws_<UserId>` 0 on its model; a second client still gets a schedule (v0.5, F40: retired with the paws; the abuse client's key `.` case becomes a sprint check when F40 lands) |
| Far grab (key 2) | Teleport 200 studs away, `GrabBegin(id)` | Refused with `Too far away`, no schedule |
| Far press (key 8) | `GrabBegin` in range, teleport 200 studs away, press every circle on target | Not caught although every press is on target. (v0.4) Walking out of range is a Miss: a paw is lost, the cat jumps back (v0.5: it sprints instead). Before F34: a failed catch with no roll, toast `Too far away`; a Common stays, a Rare flees |
| Locked area | Tier 1, teleport past the Park gate, `GrabBegin(park stray)`, `RescueBegin(park trap)` | Refused, nothing locked, no schedule or challenge |
| Drop claims (Clients and Servers, 3 players) | After B bumps A loose: C `GrabBegin` within 8 s; B `GrabBegin` at any time; A fails a catch on a dropped Rare | Refused within 8 s for anyone but A; refused for B always; the Rare stays; (v0.4) A's `pawsLeft` is nil and A can retry after 5 s however often A misses (before F34: retried after 2 s) (v0.5, F40: after each sprint anyone but B can retry, C only once the 8 s are up) |
| Press without begin (key 3; client B part manual) | `CatchPress(id, 1)`, `CatchPress(id, 2)` on a stray nobody locked, and on one client B locked | Ignored |
| Press early (key 4) | `CatchPress(id, 1)` right after `GrabBegin`, before circle 1 starts | Ignored, not counted as the first press; the on-target press still grades |
| Press out of order (key 4) | `CatchPress(id, 2)` before circle 1 is judged | Ignored |
| Press repeated (key 4) | `CatchPress(id, i - 1)` once circle i is open, then circle i on target | Ignored; circle i still grades, every circle Good or Perfect |
| Press twice (manual) | `CatchPress(id, 1)` twice, the first early but after circle 1 starts, the second on target | Only the first press counts: circle 1 is a Miss (v0.4: and the attempt ends there) |
| Press with a time (key 5) | `CatchPress(id, 1, target, "perfect", 1)` 0.15 s after circle 1 starts | Extra arguments ignored, the server stamps the arrival time: circle 1 is a Miss (v0.4: the attempt ends, a paw is lost; v0.5: the cat sprints) |
| Press spam (key `'`) | `CatchPress(id, i)` every 0.1 s from `GrabBegin` on, moving to the next index once a circle has started | The first press after circle 1 starts is early, so circle 1 is a Miss; (v0.4) the attempt ends there and `grades` has one entry. Before F34 every circle scores 0. At most 10 presses per second reach the handler |
| No press (key 6) | `GrabBegin(id)` and never press | (v0.4) Circle 1 is a Miss at its target + good + 0.15 s and the attempt ends there, later circles never judged; success false, a paw lost (`Paws_<UserId>` on the model matches), `charmGain` 0; the cat jumps back 6 to 10 studs and stays; the lock clears. Before F34: every circle scores 0, the roll fails, `stayed` is true for a Common and false for a Rare that flees (v0.5, F40: no paw and no `Paws_` attribute; the cat sprints `fleeStuds` away with `FleeingUntil` set) |
| Scripted perfect (key 7, five runs) | 10 catches pressing each circle on its target, repeated until 50 circles | Accepted as Perfect by design (data-model 10 exploit note). Expected: the server's exploit check flags it from its own stamped errors (Perfect rate above 95% over the last 50 circles; no `TelemetryReport` involved), the warn `[CatService] autopress_flag set for <userId>`. (v0.4) While flagged, `charmGain` is 0: key 7 fails a Purrfect catch that earns charm after 50 Perfect circles in a row. Then press 8 of 10 circles late (Good) for 50 circles and the flag clears at 85% or below (warn `autopress_flag cleared for <userId>`, an analytics event once analytics exists). Flag it, rejoin (API access on) and play 10 Good circles: still flagged, since a buffer under 50 never clears a saved flag (N46). Log, do not ticket, unless the flag never fires or never clears |
| Travel (v0.4, key `,`; rescue by hand) | `Travel` with `""`, `"HOME"`, `"../x"`, 123, `{}`, true, nil and a 41-character id, spaced past the 1 per s limit; `Travel("moon")` ten times in one frame; the next locked area at this tier; `Travel("home")` while carrying and during a catch; `Travel("home")`, then `Travel("alley")` 1 s later and again once 3 s are up. By hand: `Travel("home")` during a rescue hold | Malformed ids get no `TravelResult`, no toast and no move; the flood gets one answer; refused while carrying, during a catch or rescue (N47), into a locked area (`opens at Tier`) and inside 3 s (`Catch your breath first`); home lands within 12 studs of the own door and the alley inside its floor; nobody moves on a refusal and no `[Net] Travel handler failed` line |
| Paws on rejoin (v0.4, manual, API access on not needed) | Miss a Legendary (1 paw), leave and rejoin the same server, `GrabBegin(id)` | Still refused `It won't trust you again tonight` (N45) (v0.5, F40: retired with the paws) |
| Bad index (key 4) | `CatchPress(id, 0)`, `(id, 99)`, `(id, -1)`, `(id, 1.5)`, `(id, 0/0)`, `(id, "1")`, `(id, {})`, `(id, nil)` | Dropped silently by `Guard.int`, no error |
| Rescue without begin (manual) | `RescuePress(spot)` on an unlocked trap, `RescueCancel(spot)` on a trap client B locked | Ignored |
| Rescue spam (manual) | `RescuePress(spot)` 10 times a second | Misses cost paws; the attempt ends after 3 misses; the cat stays stuck |
| Rescue retry (manual) | `RescueBegin(spot)` again within 6 s of the same player's failed attempt; another client within 3 s | Refused until each one's retry time: "Catch your breath, then try again" for the player who failed, "Give it a moment" for the rest |
| Rescue hold (manual) | `RescueBegin(spot)` then no press for 16 s; `RescueBegin` then walk 20 studs away | Attempt ends as a fail at 15 s, or on leaving the 14 stud radius; the trap unlocks |
| Hidden rolls (manual) | Read every attribute and the prompt text of a stuck cat; read the last ProfileSync while a bait is not ready | No `Shiny` or charm on the stuck cat; the bait shows only `lureId` and `readyAt` |
| Rescue while carrying (manual) | `RescueBegin(spot)` while carrying | Refused with the carrying toast |
| Rescue refusals (manual) | `RescueBegin(park trap)` at Tier 1, `RescueBegin` at a trap client B is rescuing, 2 s into a catch, from 20 studs, a second `RescueBegin` mid-attempt, and `GrabBegin(stray)` during a rescue | Each refused with its reason in a `GrabResult` (`This area opens at a higher tier. Rank up to rescue cats here`, `Someone else is rescuing it`, `Finish this catch first`, `Too far away`, `Keep going, the bar is up`, `Finish this rescue first`); no new challenge, nothing locked |
| Removed remotes | Look for `GrabEnd`, `RescueEnd`, `EquipLure` under `ReplicatedStorage.Remotes` | Not there: all three are gone on `main` |
| Bump target (manual) | `Bump(own UserId)`, `Bump("123")`, `Bump(1.5)`, `Bump(nil)`, `Bump(99999999)` (nobody in the server) | Dropped or refused, no error (F29 not built yet; v0.5 F41 may keep the `Bump` name for Shove) |
| Shove (v0.5, F41, manual, two clients) | `Bump(B)` on the street, in a cafe, inside B's safe radius, while B is mid-catch and mid-rescue, from 7 studs, twice within 8 s, and at the same B again within 20 s | Refused every time and nobody moves; inside the Alleyway with every check passed B is pushed about 10 studs, and a carrying B rolls the 50% knock-loose |

Economy, tiers and roles (F24, F25, F08)

| Case | Call | Expected server behaviour |
|---|---|---|
| Bad ids, malformed (key 9) | `BuyUpgrade(41 character string)`, `BuyUpgrade(123)`, `BuyUpgrade(nil)`, `BuyUpgrade({})`, `BuyUpgrade(true)`, `BuyDecor("Neon Sign")`, `PlaceCat(123, "waiter_1")`, `ToggleDecor("plants", "yes")`, `UseLure(7)`, `ResolveBait("keep")`, `TutorialAdvance("two")`, then `TutorialAdvance(1e9)` 1.2 s later | Dropped by `Guard`: no toast, coins unchanged, no server error |
| Bad ids, unknown (key 9) | `BuyUpgrade("jetpack")`, `BuyDecor("jetpack")`, `UseLure("jetpack")`, `BuyUpgrade("cafe_level")`, `BuyUpgrade("park_access")` | Refused; a warn toast is fine; nothing bought, coins unchanged, no food used and the bowl as it was. The two removed v0.2 upgrades are unknown now |
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
| Bait reroll (manual, API access on) | Place Kibble, `Debug.baitReady()` (returns the catId) and note the card, then leave and rejoin before choosing | The same cat, stars and variant at the bowl and on the card that pops again; the bowl never shows a new roll |
| Dealer by day (manual) | `BuyDealerFood(1, "sardines")` by day | Refused, coins kept |
| Dealer far (manual) | `BuyDealerFood(1, <slot 1's food>)` 30 studs from the cart | Refused, coins kept |
| Dealer slot (manual) | `BuyDealerFood(0, food)`, `(4, food)`, `("1", food)`, `(1.5, food)` | Dropped |
| Dealer twice (manual) | `BuyDealerFood(1, <slot 1's food>)` twice in one frame, then again after a rejoin the same night (API access on) | Bought once; the last `DealerStock` the client gets shows slot 1 bought |
| Dealer server hop (manual, API access on) | Note the stock and buy slot 1, then join a second server (a second Studio session or a test place) at night within the same 600 s window | Same stock; slot 1 still bought |
| Dealer window (manual) | `BuyDealerFood(1, <slot 1's food>)` just before a window change, then the same call just after | The first buys; the second is refused unless the new window rolled the same food into slot 1, because the server recomputes the stock from the seed at purchase, never from a client value (reviewer S42) |
| Dealer food (manual) | At night by the cart: `BuyDealerFood(1, <a food not in slot 1>)`, `BuyDealerFood(1, "kibble")` (a shop food), `BuyDealerFood(1, "jetpack")`, `BuyDealerFood(1, nil)`, `BuyDealerFood(1, 7)` | Nothing bought, coins kept; the first two are refused with a `DealerStock` back, the rest refused or dropped |
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

Precondition: `Main.client.luau` calls `Effects.start()` (on main since engineer PR #85). On an older build mark
every row skipped with that reason. Run on PC, then repeat E1, E2 and E6 on the phone emulator. Watch
the client output for anything from `Effects` through the whole section (E8). Every effect lives on this client
only: client parts go in `workspace.ClientEffects` and burst emitters on `Burst_*` attachments under
`workspace.Terrain`; neither exists on the server (server `execute_luau`: both absent).

| Row | Do | Expected |
|---|---|---|
| E1 Miss | Miss circle 1 of a Common on purpose (S4's late press). A second client watches from 20 studs. Then turn on Reduce Motion (Roblox settings) and miss again | A grey puff, a pink "!" over the head, the cat rears and hops back with its tail up; the server's 6 to 10 stud jump-back is drawn as travel during the hop, never a snap. The player who missed gets one small camera shake (about 0.18 s); the watcher sees the puff, "!" and hop (from `HissAt`) but no shake. The hiss sound plays with the puff (audio PR #69). With Reduce Motion on: no shake and no flash. (v0.5, F40) The hop becomes a sprint: the cat bolts `fleeStuds` with a dust puff, drawn as a run, never a snap |
| E2 Catch and Purrfect | Catch a Common with one Good circle, then an all-Perfect catch (`Debug.spawnStray` and the abuse client's on-target presses, or by hand), then a Mythical all-Perfect | The Good catch bursts sparkles in the rarity colour, no gold. The all-Perfect catch adds a gold burst, a gold ring on the ground and gold confetti. On the phone emulator each burst is visibly smaller than on PC (12 particles at most) |
| E3 Claim | Clients and Servers: a second player joins and claims a For Rent plot while the first player watches from the street | The shutters roll up into their top edge with a dust puff, the For Rent sign flips and fades, a little confetti at the door. Before the asset thread's `CatCafe_Plot_ForRent` with `_Shutter` and `_Sign` parts: only the dust puff and confetti |
| E4 Rank up | Rank up to Tier 2 (S14) with the second player within 120 studs, then again with them 150 studs away. Then rejoin a profile saved at Tier 3 | Confetti and a smoke puff at the cafe door for every player within 120 studs, more confetti for the owner; nothing for the player 150 studs away. A rejoin at a saved tier plays the claim effect only, never rank up confetti (claim grace 2 s) |
| E5 Gate | After E4, walk to the Park gate, then away past 70 studs and back | Within 70 studs the barrier copy fades and swells with rising sparkles, confetti and a mint ring, once; walking away and back does not replay it in this session. A gate that opened while the player was far away dissolves when they first walk up |
| E6 Day ambient | By day, `screen_capture` at a running cafe front | A thin steam wisp over the espresso machine and two pastel butterflies looping over the flowers (or the pavement in front of each door until `_Flowers` exists). Chimney smoke only once the cafe roofs have `_Chimney` parts |
| E7 Night ambient | `Debug.setPhase("night")`, capture the street and the Square | Warm fireflies drifting near the street lamps (or `_Fireflies` boxes); no butterflies at night; they return at dawn |
| E8 Console | The whole section | No new error or warning naming `Effects` on the client, none on the server |

### 4.7 Sound (v0.4, sound list v0.3, `src/client/Audio`)

Run with the sound setting on, PC first, in the same session as 4.6 so each effect and its sound are judged
together. Every Sound the client plays is named after its cue (`catHiss`, `purr`, `shuttersUp`...), so client
`execute_luau` can list the playing ones: descendants of `workspace` and `SoundService` with `IsA("Sound")` and
`IsPlaying`. Cues still waiting for an upload play nothing; record them as skipped, not failed.

| Row | Do | Expected |
|---|---|---|
| A1 Miss | E1's miss, with the second client 20 studs away | `circleMiss`, then the `catchMiss` whiff (2D, catcher only) and a `pawLost` pop when a paw goes (v0.5, F40: no paws, so no `pawLost`); the hiss (`catHiss`) plays 3D from the stray for both clients, from `HissAt` |
| A2 Catch and Purrfect | E2's catches | `catchSparkle` and the rarity jingle on every catch; `purrfectChime` only on the all-Perfect one |
| A3 Claim and gate | E3 and E5 | `shuttersUp` and `signFlip` 3D at the claimed plot for everyone near it; `gateOpen` 3D at the gate, heard within about 60 studs |
| A4 Lively street | Walk the street past running cafes, then stand inside a cafe with five working cats | Each cafe door plays its chatter and cups loop 3D, loudest at the nearest door; at most 3 `purr` Sounds play at once, only for cats within 14 studs |
| A5 Carry and settings | Catch a cat and carry it; turn Sound off, then on, then check in; turn Music off | A quiet purr while carrying. Sound off silences ambience, effects and UI at once and the purr comes back when it is on again; it stops at check in. Music has its own toggle and only silences music |
| A6 Shout-outs | `Debug.giveCat` a Common, then an Epic and a Mythical shout-out (S15 or catches) | The shout-out chime climbs one step per rarity (Common lowest, Mythical highest, the `rarityStep` table in `AudioLogic.spec`) |
| A7 Console | The whole section | No new error naming `Audio`; a missing asset id warns at most once per cue |

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
- [ ] F34 (v0.4) Any mix of Good and Perfect always catches; a Miss ends the catch at once, the cat jumps back and the paw row loses one; at zero paws the prompt hides for you only; an all-Perfect catch shows the Purrfect burst and "Charm +N" (before F34: all Good is a coin flip, a failed Rare flees). (v0.5, F40) No paws: a missed cat sprints off and you can chase it and try again as often as you like
- [ ] F35 (v0.4) The Alleyway is right behind the cafes, both back alleys and the Square feel roomy; rarer cats are in the Square
- [ ] F36 to F38 (v0.4) From the street you see cats at work; signs show name, tier and rate; empty plots are For Rent shops, never grey boxes; cafes look like the concept sketch (pastel shells, awnings, the roof lifts when you walk in), and a busy cafe looks busy
- [ ] F27 Rescue: two hits free a Common from a bin; three misses end the attempt and the cat is still there; a tree rescue ends with one catch circle
- [ ] F28 Bait: Kibble in, 10:00 countdown, log off 10 minutes, rejoin and the same cat is waiting; Tame adds it, Let go clears it, the food is gone either way; odds and the per-cat split are on the food card before buying (v0.5, F44: the bowl sits on the back step)
- [ ] F29 Bump: half the time the cat drops and anyone can net it; no bump near the carrier's door or in the first 3 s; the re-catcher cannot be bumped; the bumper never gets the cat (v0.5, F41 Shove: anyone can shove anyone in the Alleyway and areas, never on the street, in a cafe or mid-catch)
- [ ] F30 A shiny earns 1.5x, sparkles, shows on the shiny page and is announced (v0.5, F42: in its own shiny coat; food cards read 5%)
- [ ] F31 Rate drops to 60% at nightfall and recovers at dawn (v0.5, F44: the cafe closes for the night, customers leave and the cats nap); a rich tip pays 45 s of the day rate whether claimed or not
- [ ] F32 Dealer at night only; same stock after a rejoin in the same night (v0.5, F43: the same stock for everyone on every server in a 10 minute window); a bought slot cannot be bought again; odds shown before buying
- [ ] F33 A name shows over the cat for other players; a filter failure keeps the old name with a toast
- [ ] F07 Carry: slower walk, carry indicator, check in at the door; leaving mid-carry still saves the cat (API access on)
- [ ] F10 Rejoin keeps coins, cats, roles, tier, upgrades, decor, foods, bait and dealer purchases (API access on)
- [ ] F12 Leave 10 minutes, return: popup shows 25% of the day rate x seconds away, claim once
- [ ] F13 Fresh account finishes the loop in under 10 minutes without help; prompts never show again on repeat joins
- [ ] F14 Everyone sees Epic and better catches, every shiny and rank ups to Tier 3 and above

Phone and UI
- [ ] All HUD text readable at 390 x 844; no element under the notch or behind the Roblox top bar
- [ ] Every tappable control at least 44 px; no accidental catches when tapping HUD buttons near a stray
- [ ] Circles never sit under the thumb or the action button; the grade of each circle is readable (v0.4: PERFECT, GOOD and MISS pops, the paw row until F40, no percentage; before F34 the final percentage)
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
   (v0.5, F40) A Miss sends it sprinting a few studs; follow it and try again.
   Before F34: Perfect catches for sure, Good half the time, a miss allows a retry after 2 s.
3. Walk home at speed 16 (13 before F35), check in at either door. Cat found popup, `+50` reward, book `2 / 50`.
4. Assign the new cat as Waiter. It stands up in a bow tie. Rate rises by 0.8 to 1.2 (charm), or 1.2 to 1.8 for a
   Tuxedo or Snow, so the HUD reads between `2.3/s` and `3.3/s`.
5. Buy Table 1 at `$100` (rate x1.10), then the Bait bowl at `$400`, then Kibble at `$25` and put it in. The
   countdown shows `10:00`.
6. First night by minute two: ten strays in the alley and a stuck cat in each of the three traps with chance 0.6,
   at least one always (RescueMinStuck). Rescue it with the bar. The rate drops to 60% for the night (v0.5, F44: and the cafe closes until dawn).
7. Free play until minute 10. Expected: three or four different cats, two roles filled, two tables, a bait cat on
   the way, the rank up card showing what Tier 2 still needs (1,500 coins and 5 different cats).
8. Leave for 10 minutes, rejoin. Offline popup shows `floor(dayRate x 0.25 x 600)`, for example `412` at a day rate
   of `2.75/s`, and the bait cat is waiting at the bowl. Tame it.
9. Pass: steps 1 to 7 under 10 minutes, no console errors, no open blocker tickets. Analytics (hook or Creator
   Hub): onboarding steps `joined`, `saw_alley`, `first_catch`, `first_checkin`, `first_role`, `first_table`,
   `first_bait`, `first_bait_resolved` fired once each, in order; `tier_2` when reached.

Extra checks for v0.3 to v0.5 (features.md section 8): the bump test over 20 tries (section 4.3 item 2; v0.5 the shove test); any mix
of Good and Perfect always catches and a Miss always ends the attempt (C7 and S4; before F34, all-Perfect and
all-Good give 100% and 50%); a missed cat sprints and can be retried without limit (v0.5; paws per player before F40, section 4.3 item 1b); travel greyed while carrying (S20); For Rent
plots on a near-empty server (S21); the dealer stock is identical after a
rejoin or a server change in the same window (section 4.4; v0.5: for every player); Tier 2 is reached in 10 to 20 minutes of normal play (time it on two
fresh accounts and record the minute).

## 7. Reporting

One file per run, `docs/playtests/YYYY-MM-DD.md`, in the `playtest-report` format: summary, bugs, balance,
confusion, requests, quotes. Tickets use the skill's severity scale (blocker, major, minor, cosmetic), carry
repro steps, expected, actual, evidence path and an owner (engineer, ui-designer, asset-artist, designer). Exploit
shaped findings go to luau-reviewer as blockers. QA never writes the fix.

## 8. Open requests to other threads

1. Engineer, Debug hooks (Studio-only like the rest, reached through `PurrPotDebug`): a shiny option on `giveCat`;
   `Debug.setNightIndex(n)` or `Debug.setDealerStock(player?, { lureIds })` (a dealer window offset is enough once
   F43 shares the stock); and a way to force the next bump or shove roll (`Debug.forceBump(true or false)`). Done:
   `baitReady` (PR #108), shiny on `spawnStray` (PR #119) and `spawnStuckCat` (PR #115), `richTip` (PR #123),
   `setTier`, `giveLure`, `setLastSeen`, `setSaveVersion`, the `[Catch]` line per graded circle (F26, PR #40), the
   `[Rescue]` line per press (PR #115) and the bridge (PR #50).
   v0.4 (F34): `Debug.paws(player?, strayId)` to read a player's paws on a stray (not needed once F40 retires them),
   `Debug.setAutoPress(player?, true or false)` to set or clear the flag without 50 scripted circles and the
   `[Catch]` line to print the attempt's end reason (miss, out of range, done) and `charmGain`.
2. Engineer, pure functions for unit tests (section 3.1): the circle schedule builder and judge, the rescue bar
   position and hit test, the bump (v0.5 shove) checks as a predicate over positions and times, the rank up
   requirement check, the bait roll, the dealer stock roll, `Economy.settle` across phase boundaries, and name
   trimming, each in `src/shared` with the random source passed in. Done: the rescue bar (`Rescue`,
   `RescueMarker`), the bait roll (`Catching.pickBaitCat`) and the dealer stock (`Dealer`).
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
