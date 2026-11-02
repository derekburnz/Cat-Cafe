# Review: Neighbourhood to the short night (PRs #243 to #310)

Reviewer: luau-reviewer thread, 2026-10-27, about 15:40 to 20:15 UTC. This review is read only; no game files changed. Each verdict is also a COMMENT review on its PR, posted on the head named here. It follows `2026-10-27-night-close-to-spin-wheel.md`. Everything was checked against the design as it stood at each PR: v0.6, the golden fish proposal (#280, approved by Derek at 19:27), design v0.8 (#293, Gavin's round 3) and v0.9 (#297, the short night).

Status is as of main at b9a0a6f (#310 merged). #307 (the server side of the short night) passed at 0d0b056 and is on automerge. Findings are numbered on from the last doc: S66 to S79 and N143 to N165.

## Verdicts

| PR | Thread | Head | Verdict |
|---|---|---|---|
| #244 Neighbourhood grows to 140 x 140 with 18 spawn points | engineer | 95a2a2e, then fdc0072 | S66 fixed before the merge. N143 optional, open |
| #260 working cats sit on the seated body | engineer | cd38f76 | Sound. Closes S50. S67 closed by VFX #262, merged first. N144 designer side done in #261, QA rows open |
| #262 seated working cats doze at night and never sink | vfx-animator | 861e2a4 | Sound. Closes S67 |
| #263 cat bodies move piece by piece, with blinks and ear flicks | vfx-animator | 647c1a3, then fa6380a | S68 and N145 fixed before the merge. N146 closed by #266 |
| #265 server side of in-game bug reports | engineer | 67fed25, then 62b4cde | Sound. N147 and N148 fixed before the merge. N149 closed by QA #275 |
| #266 resting cafe cats mix the sitting and lying bodies | engineer | fc45986, then bf030ce | Sound. N150 settled by Derek's mix; the sound half closed in #268 |
| #267 Report a bug window in Settings > Help | ui-designer | 50a736f | Sound. S69 closed by #269. N151 closed by #270 |
| #268 resting cats purr when they sit as well as loaf | sound-designer | 1019876 | Sound. Closes N150. N152 closed by QA #274 |
| #269 Report a bug window sent to the server | engineer | 7f66b7b | Sound. Closes S69 |
| #270 bug report window follows Shared.BugReport | ui-designer | 213937e | Sound. Closes N151. N153 open, N154 closed in #301 |
| #273 owner's name capped on the cafe sign | engineer | 36d339a | Sound. N155 optional, open |
| #277 effects list points at tests/specs | vfx-animator | 2eff5cf | Sound. No findings |
| #278 sleeping cats breathe with the belly, z's rise per breath | animation-engineer | 6a9d205, then f7a11ed | S70 fixed before the merge |
| #284 stretch on waking, slower lie-down, one leg at a time walk | animation-engineer | f9c39fe, then 5ab1642 | S71 and N156 fixed before the merge |
| #286 Index rewards as pictures with amounts, plus Index Boards | ui-designer | 9145614, then a572001 | S72 and N157 fixed before the merge |
| #287 game-style button fills | ui-designer | a79519c | Sound. No findings |
| #289 a lying cat never drops below the floor | animation-engineer | fc177c1 | Sound. No findings |
| #290 strays nap when idle and stretch before walking off | engineer | 3896d25 | Sound. Merged after #291 on purpose. N158 since fixed |
| #291 stretch only to walk off, paws peek out lying down | animation-engineer | 7e193f8 | Sound. No findings. Merged before #290 |
| #294 golden fish HUD counter and cut-down short numbers (F52) | ui-designer | 37d6e15 | Sound. N159 optional, open |
| #295 golden fish: save version 7 and the first fish sources (F52) | engineer | c0bdb31, then f57e81d | S73 and N160 fixed before the merge. N161 settled with the UI |
| #298 Index Boards stand inside each area's entrance (F50) | engineer | 8fe65a3, then 54a2b76 | S74 fixed before the merge. S75 raised for the UI |
| #299 the lying paw turns are in the manifest | animation-engineer | fe35629 | Sound. No findings |
| #300 Index Boards skip the tagged templates in storage | ui-designer | ceed438 | Sound. Closes S75 |
| #301 Index All Cats page, fish and crate prizes on the wheel (F54) | ui-designer | d109402, then 20527c4 | S76 and N162 fixed before the merge. S77 raised for the engineer |
| #303 sounds for the short night and the v0.8 features | sound-designer | 651ae00 to 6971a4b | Sound. N163 fixed before the merge |
| #304 getaway ring, speed lines, startled stars, dusk haze and sunrise sparkle | vfx-animator | e7c5f87, then 2e305a0 | S78 and N164 fixed before the merge |
| #305 UI catalog carries the crates | engineer | d534320 | Sound. Closes S77 |
| #306 short night: dusk countdown, closed areas, sunrise banner (F66) | ui-designer | 7bee2f6 | Sound. No findings |
| #307 short night: areas close at dusk, a sunrise wave (F66) | engineer | 436ba63, then 0d0b056 | S79 and N165 fixed. On automerge |

QA, design, assets, tooling and docs-only PRs in the range (#243, #245 to #259, #261, #264, #271, #272, #274 to #276, #279 to #283, #285, #288, #292, #293, #296, #297, #302 and #308 to #310) were merged on their owners' checks. Where they closed one of these findings, the table names them. S65 from the last doc was closed by the style guide update in #246, and N140 by #234's merge.

## What was checked

**The Neighbourhood (#244).**
- The area is x -70 to 70 and z 152.5 to 292.5, so the gate and the Square's north wall meet it as before, and the extended wall segments close the whole near side. Paths sit 0.05 studs above the floor with no coplanar faces.
- All 18 spawn points match `Catalog.areas`. None sits on a road or within 8 studs of a rescue prop.
- The gate job on CI runs luau-lsp 1.70.1, which refuses `for _, rect in spec.paths or {}`: the union with the empty table type cannot be called. A typed local fixes it (S66). The same rule bit #298 at `WorldBuilder.luau:1041` and `:1044` (S74): `gates[areaId] ~= nil` on a non-optional type, and `(x or nil) or {}`.

**Cat bodies and motion (#260, #262, #263, #266, #268, #278, #284, #289, #290, #291, #299).**
- **Seated body.** `cloneCat(def, gold, sitting)` tries `<Name>_Gold_Sit`, `<Name>_Sit`, `<Name>_Gold` and `<Name>` and returns `seated` only when a `_Sit` clone came back. A cat with no seat export stays on body A with no `Pose`. The `_Sit` pivot is the base centre with identity rotation, so the facing at each station is unchanged. The seated body keeps upright axes, so `WorldTags.anchorOf` measures real height again (S50 closed).
- **Merge order.** `Effects/Pose.luau` and `Cats.luau` compared `Pose` with `"upright"` only. A seated cat at night would have taken the leg-based `restDrop` and sunk into the counter (S67). VFX #262 treated `"sit"` the same and merged first.
- **Piece poses.** Each manifest turn is conjugated into its joint's axes once at bind. `pose.body ~= rig.kind` keeps the sleep and loaf off body B and the lick off body A. Blinks squash only Block and MeshPart eyes, write `Size` only when the value changes, and `Pose.release` restores every size, so a rebind never reads a squashed size as the open one. Selene's Roblox std has no methods on `CFrame.identity`, so it is aliased to a local (S68).
- **Resting mix (#266, Derek's "mix").** Nap spots 1 and 3 sit on body B (`Pose = "sit"`, a paw lick for 9 s of every 60 by day, a doze at night). Spots 2 and 4 stay on body A with the sleep and loaf poses. `placement.slot` is always a string, so `slot:match("^nap_(%d+)$")` is safe. Audio's `Logic.restingPurrs` purrs a seated napper by day and a lying one only while it loafs, and never at night (#268).
- **Breath (#278).** Every `_Body` part was being resized on nearly every tick, up to 19 parts on a marked cat: about 2,400 `Size` writes a second on a phone at night, each with its own change signal and spatial update (S70). Now only blocks at least a quarter of the body's height resize, in `SWELL_STEP` 0.01 steps. The sizes are client-local on anchored parts the server never resizes, and `release` restores them before any rebind.
- **Waking (#284, #291).** Every nap-to-loaf turn counted as waking, so every resting cat stood up and did the full stretch before each loaf, about once every 75 s (S71), and all cats in range stretched in unison at dawn (N156). #291 then removed the style-change wake altogether: a stretch plays only from the server's `StretchAt` on a stray, or every 35 to 80 s for a still stray. Working cats no longer stretch at dawn and seated cats never do, as Derek asked.
- **Floor clearance (#289).** `bindBelly` measures the body's clearance in its own axes, and `liftOf` caps every lying lift at clearance minus `lieGap` (0.02 times Scale), so the Munchkin, the Chonk and the Tuxedo sit at the gap instead of in the floor.
- **Stray naps (#290).** A stray naps (`Napping`) on a third of its wander pauses and wakes only to walk: the server sets `StretchAt`, waits 3.6 s, then walks. A catch lock clears `Napping` with no `StretchAt`, so a caught stray plays no stretch. `StretchAt` is set before `Napping` goes false, in the same frame. #291 had to land first so the client timed the stretch from `StretchAt` alone.
- **Manifest (#299).** The lying paw turns (front ±30, back ±26) are in `manifest.json`, so `Presets.catPoses` no longer differs from it.

**Bug reports (#265, #267, #269, #270).**
- **Validation.** `BugReport.text` bounds the raw string to 4 bytes a character before any work, requires valid UTF-8, removes control bytes but keeps newlines, trims, and cuts to 500 bytes on a character boundary. Under 3 bytes is refused. `kind` falls back to `"bug"`, and `clientErrors` reads only indices 1 to 3, each cleaned and cut to 200 bytes. The window runs the same function, so what it sends is exactly what the server stores.
- **Rate limits.** 1 per 20 s per player, 10 per player per server (kept across a rejoin) and 200 per server, all checked before any write.
- **Saving.** `SetAsync` in `pcall` to `BugReports_v1`, key `r_<day>_<os.time()>_<userId>` (Studio playtests use `s_`), with `{ userId }` as the `userIds` metadata (N148). Area, tier, coins, cats, device, phase, place version and job id all come from the server. The text is never shown to another player, so skipping the chat filter is right.
- **Wiring.** `UI.events.reportBug(text, kind, clientErrors)` is forwarded to `Net.fire("ReportBug", ...)` in the same argument order the server handler takes (S69, #269). The window settles a pending report only on an exact `Shared.BugReport.Messages` match, so an unrelated warn toast in the same second no longer unlocks it (N151, #270).

**The cafe sign (#273).** `CafeName.shown` counts code points with `utf8.len` and cuts at `utf8.offset(name, 13) - 1`, so a name over 12 characters never ends in half a letter. `OwnerName` is capped at the source, and the server's SignBoard line uses the same call.

**Rewards UI, Index Boards and buttons (#286, #287, #294, #298, #300, #301, #305).**
- **Prize parts.** `IndexRewards.prizeParts` orders coins, fish, foods, spins, crates, tag, decor, bonus, then unknown number fields, so a catalog change shows up instead of vanishing. Coins use the Tip Jar rule `max(coins, floor(dayRate x coinSeconds))`. `need` or `needs` and `gold` or `track` are read only through `IndexRewards.need` and `isGold`.
- **Index Boards.** `_hang` now forgets a prompt that is no longer in the model, so a board whose Screen streams out and back in gets its prompt again (S72). Portraits are built the first time the player comes within range (N157). The placed boards are `ModelStreamingMode.Atomic` and hang from each gate's pivot, with the street arch as the Alleyway's fallback and a missing asset skipped (#298). The five templates in `ReplicatedStorage.Assets` carry the `IndexBoard` tag, so `_attach` returns unless the model is under Workspace (S75, #300).
- **Short numbers.** `ShortNumber` cuts down and never rounds up: 1,999,999 reads `1.99M`. NaN shows "0" and anything above -1 has no sign. The fish counter stays hidden while `goldenFish` is nil. `FishCoin` is drawn from frames, with no asset to upload.
- **Crates.** `CrateLogic.resolve` turns `"highest"` into the plain crate of the highest-tier area whose tier is at or below the player's, first in `Catalog.areas` order on a tie, and never a golden crate. The engineer confirmed the server's F54 payout uses the same rule. The catalog handed to `UI.init` had no `crates`, so the UI resolved nothing (S77, closed in #305).
- **All Cats page.** Cells carry `areaRank x 100000 + rarity x 1000 + index`, so pages cannot overlap, and portraits load ten per frame through a token-cancelled queue that `_buildIndex` and `destroy` both bump. The six tab names scale down to 9 px so "Neighbourhood" fits a phone (N162).
- **Buttons (#287).** Only colours and decoration changed. The gloss, rim and tiles sit under the label, and the tiles are skipped while `Theme.textures.buttonTiles` is empty.

**Golden fish (#295).**
- **Save.** Version 7 adds `goldenFish`, `lifetimeGoldenFish`, `crates`, `crateLuck`, `fishPerks`, `stats.cratesOpened` and `stats.fishEarned`. `migrate` floors each through `asInt`, keeps lifetime at or above the wallet, cleans crates, luck and perks against the catalog, and drops unknown ids.
- **Rules.** `GoldenFish.credit` floors and ignores 0 or less; `trySpend` refuses negative costs and overdrafts. A first catch pays, a first gold pays again (3x when one catch is both, confirmed by the designer), rank up pays for Tiers 2 to 5 only, and Tip Jar step 12 pays through the same `credit`. Bait never pays the repeat reward because a bait cat is added with `"bait"` and never becomes a carry. Telemetry logs fish under `golden_fish`, separate from coins.
- **Wiring.** `UIController.applyState` forwards state field by field and did not pass `goldenFish` on, so #294's counter stayed hidden (S73). It now forwards `goldenFish`, `crates`, `crateLuck` and `fishPerks`, and the UI's `PlayerState` and `PartialState` carry them.

**The short night (#303, #304, #306, #307).**
- **Clock.** `ClockService.publish` sets `AreasOpen` together with `Phase` and `PhaseEndsAt`. Night is 90 s, a new server opens with a full 300 s day, `DuskWarningSeconds` is 15 and `NightSweepSeconds` 2. The UI reads the three attributes once at the end of the frame, so a new Phase is never paired with the old PhaseEndsAt.
- **Server (#307).** At dusk every stray and trap clears once any catch or rescue on it ends; a Dropped stray is checked in for its last carrier while they are in the server; everyone in a catching area is sent home every 2 s with a carried cat checked in on arrival. `GrabBegin`, `RescueBegin`, `Shove.refusal` and `Travel` to any area refuse at night with `Clock.CLOSED_TEXT`; "home" still works. `tutorialTick` waits for sunrise. The Alleyway's night fence is a gate under `World.Gates` with no `AreaGate` tag, `CanCollide` off on the server and `ModelStreamingMode.Persistent` (N165).
- **Banners.** UI #306 shows "Night falls in 15 s!" to players in an area (and to one who walks in during the warning) and "Sunrise! Fresh cats in every area." on a night-to-day change, and Audio #303 rings the dusk bell, all from the Clock attributes. #307 also sent both as `Announce`, which would have shown each twice with an extra chime (S79). The server Announces, `ClockService.dusk` and the two texts are gone.
- **Travel.** `pressTravel` blocks everything but "home" while `AreasOpen` is false, which matches what `TravelService.landingFor` refuses. The Alley button and every Go grey with a moon. `NightClock.areasOpen` closes only on an explicit `false`, so a server without F66 keeps them working.
- **Effects (#304).** `Logic.timedState` gives the seconds left and whether a state is new, so the getaway ring and the startled bump play once. `rush` bumped its token before the range check, so a rush change seen from out of range cancelled the pending `endLines` and left Trails on the catcher for good (S78); it now ends the lines on that return. `Shove.stars` merges per head and extends to the later end. `Logic.areasTurn` ignores the first value, so joining at night plays nothing.
- **Audio (#303).** `Logic.duskBellIn` is nil at night or more than 1 s after the moment, so a late join rings nothing. `freshStart` ignores a `CarryStartedAt` seen on join. `plotCue` plays `visitorMystery` only when `MysteryGiftAt` goes from 0 to above 0; the clearing stays quiet because the server also clears an unopened gift at `MysteryGiftKeepSeconds` or on a plot release. `announceMythical` plays only once it has a file.
- **Per-character listeners.** Both Audio and Effects watch every player's character. Each player now keeps only its current character's connections, dropped on `CharacterRemoving` (N163, N164).

## Open findings

| Id | Owner | Finding |
|---|---|---|
| N143 | game-designer, asset-artist | Optional: the Neighbourhood's entry side shows the Square's 10-stud Alleyway brick wall. A row of hedges or fences along the inner face would hide it when the kit lands |
| N144 | qa-playtester | `test-plan.md:127` and `:166` still describe upright working cats and name `EffectsUpright.spec` for F25. Working cats sit on the seated body since #260 and #261 |
| N153 | ui-designer | Optional: `Screens/BugReport.luau:10` is a 143-character header line, and `Components/ClientErrors.luau:3` says lines are only "cut to 200 bytes" (they are cleaned as the server would) |
| N155 | ui-designer | Optional: `Screens/CafeSigns.luau:272` falls back to the owner's full `DisplayName` when `OwnerName` is empty. Wrap it in `CafeName.shown` so the 12-character rule holds on that path |
| N159 | ui-designer | Optional: `ShortNumber` cuts down, so with 1,230,000 coins and a 1,234,567 cost both read `$1.23M` while the button stays grey. A round-up mode for costs behind `Format.cost` would keep a shown balance at or above a shown price always able to pay |
| N141 | ui-designer | Optional, carried: the fold tabs are 44 x 34 design px and shrink on small phones |
| N142 | engineer | Optional, carried: an `isPane` helper next to `isTube` in WorldController |
| F64 UI | ui-designer | Not yet built: the UI plays `giftOpen` with the `MysteryGiftResult` card (#303 moved it off the attribute). Until then opening a gift is silent |

Carried over from earlier docs: N73, N62, N63, N51, N53, N55, N56 and N13 (game-designer), S11 (Derek), and README:41 EquipLure (lead). QA's S33 row now describes all eight settings, so that item is closed.

## Notes for the next reviewer

- CI's luau-lsp 1.70.1 is stricter than the laptop's: `x or {}` where `x` is an optional table, and `t[k] ~= nil` on a non-optional type, both fail. Use a typed local (S66, S74). Selene's Roblox std has no methods on `CFrame.identity`, so alias it (S68). cloudcheck runs only the specs, so a green local cloudcheck says nothing about the gate.
- Most should-fixes in this range were again two halves of one feature: the client comparison (S67), the remote forward (S69), the state forward (S73), the catalog table (S77), the template tag (S75) and the duplicated banner (S79). Whenever `ProfileSync` or `Catalog` gains a field, check `UIController.applyState` and the catalog table handed to `UI.init`. Whenever the server adds a moment, check whether the UI, Audio or Effects already derive it from an attribute.
- Paired motion changes need a merge order: the client's read of a new server attribute lands first (#291 before #290), and a server pose change lands after the client handles the new value (#262 before #260).
- Contracts to hold the F54 and F64 builds to: the `"highest"` crate is the plain crate of the highest-tier area the player's tier opens, first in `Catalog.areas` order on a tie; `giftOpen` plays with `MysteryGiftResult`, not when `MysteryGiftAt` clears.
- `Audio` and `Effects` both follow every player's character now. A new per-character watch should keep its connections and drop them on `CharacterRemoving`.
- The StyLua gate checks `src` only, and it wants a call's last table argument hugged onto the opening line (S76).
