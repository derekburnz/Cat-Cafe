# Intro cutscene and Tutorial button (F72)

Approved by Derek on 2026-10-27 at 20:45 ("1 yes, 2 yes, 3 keep them but keep it brief"), from his ask at 20:11: a quick camera fly-through of the map before a new player can play, the most important information first because players skip at once, quick scene changes, a small Skip button bottom right after a couple of seconds, and a button at the top that replays it and can be dismissed. Storyboard with a pacing preview: `intro-cutscene-storyboard.html` in the project library folder Tutorial-Agent/ (open it in a browser). Design: Tutorial-Agent thread. Build: Gameplay-Engineer (camera, server flag, landing spot) and UI-Engineer (captions, Skip, Tutorial tile, Settings rows).

## 1. Rules

- **Who sees it.** Every player whose profile `introSeen` is false, once, on join. The field defaults to false on every save, existing ones included, so the friends already testing see it on their next join (Derek, answer 2). No migration flips it.
- **When it starts.** After the first ProfileSync that carries a plot. Until then the normal loading cover stays up.
- **Where new players land** (Derek, answer 1). When a player whose `introSeen` is false spawns, the server places the character just inside its own cafe's back door, facing the door (plot-local about x -8, z 11, the back door being at x -8 in the back wall at z 14). The character is frozen while the intro runs, so the move is never seen. Replays move nobody.
- **While it runs.** The HUD, world markers and proximity prompts are hidden on this client, the character's controls are off and the camera is Scriptable. The player stands in the safe zone, so nobody can shove them.
- **Skip.** Appears 2.0 s in on the first play and at once on a replay. Ends the intro on the spot.
- **The end** (after shot 9 or on Skip). Camera back to Custom, controls, prompts, markers and HUD back on, the first step hint shows as today. The client fires `IntroDone(shot, replay)`.
- **Replay.** The Tutorial tile and the Settings row play it again with Skip at once. Nothing is saved except telemetry.
- **Step hints.** `tutorialStep` 0 to 5 and their hints are unchanged.

## 2. Shots

Total 23.7 s. Studs, y up. Shots 1 to 3 and 9 are relative to the player's plot: `p = Layout.plotPlacement(plotIndex)` gives `px`, `pz` and `s` (-1 for the west row, +1 for the east row); the street is toward world -s on x. The tutorial stray point is `(66s, 0, pz - 7)` (alley point 2p - 1). Camera positions and heights are starting points to tune in Studio; "look" is the CFrame.lookAt target.

| # | Starts | Length | Caption | Camera from (position, look) | Camera to (position, look) | Move |
|---|---|---|---|---|---|---|
| 1 | 0.0 | 3.5 | Catch stray cats behind your cafe! | (px - 30s, 9, pz - 6), the sign (px - 14.3s, 7, pz) | via (px, 38, pz - 10), (px + 20s, 0, pz - 7); end (60s, 7, pz - 17), the stray (66s, 1, pz - 7) | One continuous crane over the roof into the alley, Quad InOut through the via point. Skip fades in during this shot. |
| 2 | 3.5 | 2.5 | Tap as each circle closes! | (61s, 4.5, pz - 15), the stray | (63s, 3.2, pz - 12), the stray | Continuous slow push, Linear. Demo catch: the circle closes 0 to 1.3 s, PERFECT pops at 1.3, sparkle to 2.0, the demo cat fades at 1.9. |
| 3 | 6.0 | 3.0 | Bring cats home. Give them jobs. Earn tips! | (px - 6s, 22, pz - 18), (px + 6s, 1, pz - 4) | (px - 8s, 18, pz - 8), (px + 8s, 2, pz) | Hard cut. The own roof fades as it does for an owner inside. Working cats, customers and the rate tags are the live ones. |
| 4 | 9.0 | 2.7 | Rank up your cafe to open new areas | (0, 45, 10), (0, 0, -40) | (0, 12, -82), the Park gate (0, 4, -102) | Hard cut, Quad InOut. The gate sign is the real gate billboard. |
| 5 | 11.7 | 1.8 | Every area has its own cats | Park (0, 40, -95), (0, 0, -132); Neighbourhood (0, 60, 160), (0, 0, 228); Woods (-74, 40, -96), (-74, 0, -136); Sewer (74, 40, -96), (74, 0, -136) | Each pushes 6% toward its look point | Four hard cuts of 0.45 s, each with a title card: THE PARK, THE NEIGHBOURHOOD, THE WOODS, THE SEWER. |
| 6 | 13.5 | 2.5 | Find all 50 cats for Index rewards | (-4, 5, 84), the Alleyway Index Board (-9, 4, 95.5) | (-6.5, 4.5, 89), the board | Hard cut, Quad Out. The board shows this player's own page. |
| 7 | 16.0 | 2.7 | Free spin every day. Codes at the Codes Cat! | (-2, 13, 92), (-4, 2, 76) | (2, 9, 60), the wheel (-7.5, 5, 79) | Continuous sweep out through the street arch and over the plaza, Quad InOut. The world wheel turns two spins, easing out, on this client. |
| 8 | 18.7 | 3.0 | Night closes the areas. Fresh cats at sunrise! | (0, 70, 60), (0, 0, 125) | (0, 66, 64), (0, 0, 125) | Hard cut. Lighting ClockTime runs to night 0.35 to 0.95 s, holds to 1.8, sunrise 1.8 to 2.3; Square strays fade out 0.45 to 0.85 s; ten local strays pop in from 2.1 s. |
| 9 | 21.7 | 2.0 | Go catch your first cat! | (0, 66, 64), (0, 0, 125) | 12 studs behind and 6 above the character, looking at its head | Continuous swoop, Quad InOut, then CameraType Custom. |

Fallbacks: if no `CodesCat` station is in the Workspace yet (F65), shot 7's caption is "Spin the wheel for a free prize every day!". If an area has not streamed in by its cut, that cut is skipped and the others take its time.

## 3. Gameplay-Engineer

- Profile `introSeen` (boolean, default false) in the next save version bump, sent in ProfileSync. Settings key `tutorialButton` (boolean, default true) as a ninth `SetSetting` key.
- Remote `IntroDone(shot, replay)`: `shot` an integer 0 to 9 (0 when it played to the end, otherwise the shot showing when Skip was pressed), `replay` a boolean; 1 per second. The first non-replay call sets `introSeen` and syncs. Every call logs the custom event `intro_cutscene` with `finished` or `skipped`, the shot and `replay`, so the growth thread can see where people drop off.
- The landing spot in section 1, applied on CharacterAdded while `introSeen` is false.
- A client `IntroController` (`src/client/Controllers`): waits for the first ProfileSync with a plot when `introSeen` is false, or for the UI's replay event; disables controls and `ProximityPromptService.Enabled`; runs the shots with TweenService on a Scriptable camera; calls the UI functions below; restores everything on the end or on Skip, also if the character respawns mid-intro.
- Streaming is on: `Player:RequestStreamAroundAsync` for the next shot's look point one shot ahead, in a pcall.
- Everything staged is local and removed at the end: the shot 2 demo cat (a clone of the Tabby stray model at the stray point, with real strays within 4 studs hidden through LocalTransparencyModifier for shots 1 and 2), the wheel spin, the shot 8 Lighting tween (restore the replicated value), the faded Square strays and the sunrise clones. Nothing replicates and no gameplay remote fires.

## 4. UI-Engineer

- `Screens/Intro.luau`: letterbox bars (9% of the screen height each, black at about 92%), one caption line bottom centre above the lower bar in FredokaOne with the dark outline (pops from 0.9 to full size in 0.2 s on each shot, at most about 45 characters), nine shot dots on the top bar with the current one gold, the shot 5 title cards, the shot 2 demo ring drawn with the catch circle look at the stray's screen position, and the Skip pill.
- Skip: a small outlined "Skip »" pill on the lower bar at the right, at least 44 px tall on touch, fading in after `skipAfter` (2.0 on the first play, 0 on a replay); gamepad ButtonB too.
- Ending: the bars slide out over about 0.45 s while the HUD fades back in.
- Tutorial tile: in the HUD's top right tile row, left of Gifts, the same 58 px square as the others, gold with a "?" and "Tutorial", a small red × in its corner. Tap replays. × hides it, sends `tutorialButton = false` and toasts "Tutorial hidden. Replay it from Settings." Hidden while `settings.tutorialButton` is false, greyed while carrying or holding a catch or rescue, and it glows twice the first time it appears after an intro.
- Settings, Screen section: a "Tutorial button" switch bound to `tutorialButton` and a "Replay tutorial" row that plays the intro.
- Contract: roughly `UI.intro.start({ skipAfter })`, `UI.intro.setShot(index, caption, titleCard?)`, `UI.intro.demoCatch(worldPosition)`, `UI.intro.finish()`, and events `introSkip(shot)`, `introReplay()`, `tutorialButtonHide()`. Final names go in ui-contract.md.

## 5. QA checks

1. A fresh account sees the intro once. Skip appears at 2.0 s and ends it at once. The character stands inside its back door with the first hint and its trail showing.
2. A rejoin does not play it again. An existing save plays it once on its next join.
3. The Tutorial tile replays it with Skip at once and moves nobody. × hides it, it stays hidden after a rejoin, and the Settings switch brings it back.
4. After the intro ends or is skipped at any shot, no demo cat, extra stray, spun wheel or night lighting is left, prompts work and the camera follows the character.
5. On a phone-sized screen the captions fit on one line and Skip is easy to tap.
