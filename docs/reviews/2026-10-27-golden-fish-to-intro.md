# Review: the Golden Fish Market to the intro cutscene (PRs #311 to #348)

Reviewer: luau-reviewer thread, 2026-10-27, about 20:20 to 23:40 UTC. This review is read only; no game files changed. Each verdict is also a COMMENT review on its PR, posted on the head named here. It follows `2026-10-27-neighbourhood-to-short-night.md`. Everything was checked against the design as it stood at each PR: the golden fish proposal (#280, approved by Derek at 19:27), design v0.8 to v0.10.1 (#293, #297, #314, #342), `intro-cutscene.md` (approved 20:45) and the quests proposal (#343).

Status is as of main at 04853a5 (#346 merged). #348 (the engineer half of the intro) passed at 74e1dd3 and carries the `automerge` label. Findings are numbered on from the last doc: S80 and N166 to N193. No blocker was raised in this range.

Two things changed about how PRs merge during this range. GitHub Actions stopped at 20:15 UTC when the private repo's free minutes ran out (the job message reads as a payments failure); Derek made the GitHub repo public at 21:00 and every blocked PR was re-run and merged by 21:25. The Roblox experience stays private. From 22:02 (Derek, #344) a reviewed PR turns on GitHub auto-merge with a merge commit; the `automerge` label is only for when GitHub refuses that, which it does until main has required checks (#350 records the ruleset).

## Verdicts

| PR | Thread | Head | Verdict |
|---|---|---|---|
| #312 Golden Fish Market window: crates, odds card, reveal and perks (F53) | ui-designer | 9c4b2a0, then e2bf396 | Sound. N166 and N167 closed in #317 |
| #315 everyday moments, signature effects for Legendary and Mythical cats, Codes Cat circle glow | vfx-animator | cd73476, then 7f12df6 | Sound. No findings |
| #316 Cafe Crates and the Golden Fish Market, server side (F53) | engineer | 508196e to 3f70bb6 | N168 and N169 fixed before the merge. N170 open for the designer. S80 raised, closed by #320 |
| #317 Decor Index tab, style slots and decor spots (F53 part 2) | ui-designer | 41d3d87, then 1bfce94 | N171 and N172 fixed before the merge. Closes N166 and N167 |
| #319 Upgrades pop the button and flash the stars | ui-designer | baf5303 | Sound. No findings |
| #321 food grade badges and the Spin Odds list (F69) | ui-designer | b8f8130 | Sound. No findings |
| #322 F69 food rarity grades on LureDef | engineer | f5ff1b3 | Sound. No findings |
| #323 Tip Jar 60 and 120 minute gifts on bigger cards (F68) | ui-designer | fb0a45c | Sound. ui-contract.md needed main merged in first |
| #325 F54 Index rewards and wheel rebalance | engineer | 70be319 | Sound. N173 is a note for the designer |
| #326 Pick up for a dropped cat, "walking home" (F67, UI side) | ui-designer | 4d8c1b8 | Sound. N174 optional, open |
| #331 F65 Codes Cat and codes | engineer | a4ba124, then 190ed51 | N176 and N177 fixed before the merge. N175 open while `GroupId` is 0 |
| #332 Index forever bonuses: gold luck and faster bait (F54 v0.10, UI side) | ui-designer | 304f69e | Sound. N178 and N179 optional, open |
| #333 night fences use the fence art | engineer | 264d008, then d42a0c1 (merge 6699fc3) | N180 and N181 fixed before the merge |
| #334 code box: walk into the Codes Cat's circle (F65, UI side) | ui-designer | ff1bfcf | Sound. N182 and N183 closed in #345 |
| #335 F54 follow-ups: luck boards, state fields, placedAt | engineer | 3095a39 to bc0b905 | N184 and N185 fixed before the merge |
| #336 crate opening, golden fish sparkle, Mythical cafe styles (F53, effects) | vfx-animator | a479c4e, then 087c9f0 | N186 to N188 fixed before the merge |
| #341 Blossom Tree petals from the canopy model | vfx-animator | 6dd03d6 | Sound. Closes S80 |
| #345 intro cutscene UI: bars, captions, Skip, Tutorial tile (F72) | ui-designer | b65aedf | Sound. Closes N182 and N183 |
| #346 potion glows and the Mystery Visitor (F64, effects), quest potion glows | vfx-animator | dac0454, then 859df1c | N189 to N191 fixed before the merge |
| #348 intro cutscene: save flag, landing spot and camera (F72) | engineer | 74e1dd3 | Sound. N192 optional, N193 a note. On automerge |

QA, design, assets, tooling and docs-only PRs in the range (#311, #313, #314, #318, #320, #324, #327 to #330, #337 to #340, #342 to #344, #347, #349 and #350) were merged on their owners' checks. #338 (the 32 new sound ids) and #330 (the Market stall, coin and HUD icon) were read for payload changes and had none. Where a docs or assets PR closed a finding, the table names it.

## What was checked

**Golden Fish Market and crates (#312, #316, #317, #330, #336).**
- **Monetization.** Golden fish are earn-only and nothing in the range names Robux. The odds card shows each rarity's chance and every piece's chance before an open, the lucky twentieth states its number and swaps to the golden odds, and the reveal (#312) and the effects pop (#336) paint the won rarity's colour before anything shows and only grow, so no better colour ever shows first. A tap skips the reveal; Reduce Motion makes it a fade.
- **Remotes.** `OpenCrate` (1 a second, plus a 2 s cooldown per player) and `BuyFishItem` (2 a second) sit behind the global limiter with `Guard.id` on both ids; every cost comes from `Catalog.fishShop`, `CrateDef.price` and `Config`; range is the player's own root against the tagged stall; a refusal always answers `CrateResult(crateId, "", false, 0)` with a toast and a sync.
- **The roll.** `Crates.roll` walks `Catalog.rarityOrder` with the clamped roll times the odds total (Common 0 to 60, Rare to 87, Epic to 97, Legendary to 99.5, Mythical the rest); the lucky twentieth uses the golden odds, `luckAfter` resets on Epic or better and caps at 19. `open` now rolls before it takes the banked crate or the fish (N168), so a throw in the roll can never cost the player anything. `crate_opened` sends three fields, which is all `Telemetry.customFields` keeps (N169).
- **Spots and styles.** The server (`refreshDecor`) and the UI (`DecorPieces.spotsUsed`) count placed furniture and decorations the same way, the cap tops out at 8 anchors, and a style piece in use can be removed again (N171). The Index pieces count against the cap on both sides (N170, a design line still wanted). `StyleController` keeps each part's own colour and material and restores them when the attribute clears; the plot shell's `_Paint` and `_Wallpaper` child models have been tagged by `rbx_export.py` since #320, which closed S80 (only the live v11 place predates it).
- **Effects (#336, #341).** `Decor` tweens and instances are all in per-piece lists that `stop` empties; a failed build backs off from 2 s to 30 s; `using` counts only pieces whose look built, so Ambient gives up no steady emitter for nothing; the loop runs under `pcall` and warns once (N186 to N188). `canopyOf` prefers a child model ending `Canopy` or `Blossom` over a part that happens to come first (#341).

**Index rewards, forever bonuses and the wheel (#325, #332, #335).**
- **Claims.** `IndexRewardService.pay` marks the claim before paying, so a throw cannot leave a re-claimable milestone; spins over the cap go through `Spin.bank`; crates resolve through `Prizes.crateFor`, the same `"highest"` rule the UI's `CrateLogic.resolve` uses. Save version 8 keeps a claim only when `Catalog.indexPrizes[page][milestoneId]` exists.
- **Gold luck and bait speed.** Shared rolls take the best `totals().goldLuck` among loaded players whose tier opens the area, capped at `GoldLuckMax` 1.5; bait uses the owner's own. `ProfileSchema` clamps a loaded `readyAt` to `[placedAt, placedAt + LureWaitSeconds]`, so tampering can only shorten a wait. The UI's `IndexRewards.totals` and `FoodOdds.waitSeconds` are the server's maths, and `totals()` now rounds its sums to six decimals before the caps so both sides land on the same second (N184). `goldLuck` and `baitSpeed` ride `UI.update` as numbers, `GoldLuck` and `GoldLuckFrom` go on each Index Board every 3 s under `xpcall` (N185), and `BaitView.placedAt` is sent for the bowl bar.

**Codes Cat (#331, #334, #345).**
- **CodeService.** The lock is tested before range, so a locked player learns nothing from range answers; malformed and unknown text both count toward the lock; the text is never saved or shown; the group call is the only yield, `busy` drops re-entrant redeems and `Codes.refusal` runs again after it; the code id is written to `codesRedeemed` (save version 9) before `Payout.pay`. `RedeemCode` is 1 per 2 s. Range is measured flat from the station pivot (N176) and the client caches each station's circle (N177).
- **The box.** `CodeEntry.clean` keeps `%w` only, a subset of `Codes.normalize`, so nothing the box sends can count as a wrong code; one answer per try through a token; a window the player opened meanwhile stays (N182, #345); Redeem rests 2 s after each send so the server limiter is never hit (N183, #345).

**Night fences (#333).** The art segments stand where the code-built bars stood, turned to face the cafes; `hideForDay` is the only server code that touches a `NightFence`, and it clears `CanCollide`, `CanQuery` and `CanTouch` on every part, so strays and server rays never meet a fence. The client shows them while `AreasOpen` is false and restores `CanQuery` with `CanCollide` (N180), and `Beam` and `Trail` follow `NightEnabled` (N181). The merge commit 6699fc3 differs from git's automatic merge only in `docs/engineering/modules.md`.

**Food grades, Tip Jar and the Upgrades pop (#319, #321, #322, #323).** `FoodGrade.of` reads the catalog's `rarity` first and lands on the design's grade by id otherwise, and #322's seven grades match #321's defaults exactly. `TipJarLogic.prize` takes both the old and the v0.10 row shapes, a coin gift stays `max(least, floor(dayRate x seconds))`, and `PrizeChips.set` only rewrites amounts on the per-second tick. The Upgrades celebration fires only when a render sees a level above the one the row recorded.

**Pick up (#326).** `kind = "pickup"` comes only from a `PickUp` attribute that is exactly `true`, so every existing prompt keeps the swing flow, and a pickup hold fires `pickUpBegan`, never `grabBegan`. The server half (F67) is still to come.

**Effects for the new moments (#315, #346).**
- **Signature cats and the circle (#315).** Client only, reading tags and attributes; the nearest `signatureCats` within range run at Rate 2 or less; per-character work connects on the character's own `ChildAdded` so it goes with the character.
- **Potions and the Mystery Visitor (#346).** `Net.on` goes through `Remotes.event`, which is `WaitForChild` with no timeout, so `MysteryGiftResult` is hooked from the Remotes folder's `ChildAdded` and the connection drops itself once the event appears. A root or hand that streams out clears its glow and a later pick rebuilds it; `switchOn` resets the rate before the split across two hands, so nothing compounds. `giftColour` resolves the colour before the first `Emit`. The glows stay inside `potionGlows` (6, 3, 0 in Low performance), own glow first. The F73 quest potions got their glows in the same PR.

**The intro cutscene (#345, #348).**
- **Server.** `IntroDone(shot, replay)` goes through `Guard.int` 0 to 9 and `Guard.bool`, 1 a second, touches only the caller's own profile and logs at most 20 events a player. The landing (x -8, z 11 in plot space, facing the back door) is applied after the root exists and one Heartbeat later; nothing else on main moves a character on `CharacterAdded`, and the deferred `onLoaded` runs after `PlotService.assign`. Save version 10 adds `introSeen`; every older save plays the intro once (Derek's answer 2). `tutorialButton` is the ninth settings key.
- **Client.** IntroController's `ProfileSync` handler fires before UIController's (LIFO), and the `task.defer` lets `applyState` set the state first. Every staged clone, tween, local transparency, the held roof, the wheel pivot, the sky preview, the camera, the PlayerModule controls and `ProximityPromptService.Enabled` go back in `finish`, guarded against a second call. Lighting tweens are cancelled before a new apply. The UI's Skip fires once per play with a token-guarded fallback, and the Tutorial tile shows by default without the shared key.

## Open findings

| Id | Owner | Finding |
|---|---|---|
| N170 | game-designer | The five F48 Index pieces count against the decor spot cap on both sides (`Crates.takesSpot`, `DecorPieces.spotsUsed`). One line in golden-fish.md section 4 saying so, or an exclusion for `source == "index"` if they should not |
| N173 | game-designer | Note: a player who claimed `cats10` before F54 keeps the piece and gains the milestone's permanent bonus, but never its new one-shot items. Alpha testers only; one line in golden-fish.md |
| N174 | ui-designer | Optional: `CatchPrompt.refresh()` can flash "Catch" for a frame after a pickup hold while the card reads "Picking up..."; skip the refresh while waiting |
| N175 | engineer | When `IsInGroupAsync` fails the player reads "Join the Cat Cafe group" although nothing was checked. Moot until `GroupId` is set |
| N178 | ui-designer | Optional: `fitPerks` writes `perksScale.Scale` from a signal that scale changes; skip the write within 0.005 to rule out per-frame churn |
| N179 | ui-designer | Optional: the bowl's fill bar uses today's wait as its total. `BaitView.placedAt` is sent since #335, so `readyAt - placedAt` is available |
| N192 | engineer | Optional: `IntroController.play(true)` refuses a replay only while carrying; the catch and rescue holds rely on the UI's `introBlocked`. A check in the controller would make it self-contained |
| N193 | qa-playtester | Note: the night sweep can move a frozen newcomer to the street mid-intro, so shot 9 ends outside the front door then. Harmless |
| F64 server | engineer | Not yet built: `ActivePotions`, the `MysteryVisitor` and `MysteryGift` tags, `UsePotion`, `OpenMysteryGift` and `MysteryGiftResult`. Tag each model as it enters Workspace (README hook 16); a tagged clone parked in ReplicatedStorage and moved later gets no effect |
| F64 UI | ui-designer | Not yet built: the gift card and `giftOpen` on `MysteryGiftResult` |

Carried from earlier docs: N143 (game-designer, asset-artist), N144 (qa-playtester), N153, N155, N159 and N141 (ui-designer), N142 (engineer), N73, N62, N63, N51, N53, N55, N56 and N13 (game-designer), S11 (Derek), README:41 EquipLure (lead).

## Notes for the next reviewer

- CI's luau-lsp 1.70.1 rejects `local ok, err = pcall(fn)` when `fn` returns nothing (one result); `xpcall(fn, handler)` or an inline `pcall(function() ... end)` passes (#335, #336). A typed local is still the shape for `x or {}` on an optional table (#312).
- Verify a hand-resolved merge commit with `git merge-tree --write-tree <parent1> <parent2>` and diff that tree against the head: only the hand-resolved files should differ (#316 twice, #333).
- A remote the server does not have yet cannot go through `Net.on`, which waits forever. Hook the Remotes folder's `ChildAdded` and drop the connection once the event appears (#346).
- Roblox fires a signal's connections newest first, so a handler that must read what an earlier-connected handler wrote should `task.defer` its work (#348). The shared `Signal` spawns handlers in no fixed order, so the same applies there.
- `Telemetry.custom` keeps three fields; fold extra values into one (#316). `UI.update` partials cannot carry nil, so a new state field must be sent as a value on every sync (#335).
- A long-running client or server loop takes a `pcall` and warns once, so one odd instance does not end the effect for the session (#335, #336, #346).
- The auto-merge rule from #344: reviewed PR, owning thread calls `enable_pr_auto_merge` with a merge commit; the `automerge` label only when GitHub refuses, never both, since the label starts a second CI run.
