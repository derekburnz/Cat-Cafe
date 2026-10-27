# src/client/Effects -> StarterPlayerScripts.Client.Effects

Owner: vfx-animator (Luau reviewed by luau-reviewer); cat motion (`Pose.luau`, `Cats.luau`, and the cat-motion parts of `Logic.luau` and `Presets.luau`: motion, catPoses and nap) is the Animation-Engineer's since 2026-10-27. Preview cat motion outside Studio with `assets/cat-cafe/anim/preview/`. Rules: `.claude/skills/animation-vfx/SKILL.md`. What each effect is for and its status: `docs/vfx/cat-cafe/effects-list.md`.

Everything here runs on this client only. Effects read replicated world state (tags and attributes) and this player's own CatchSchedule and CatchResult events. They never fire a remote, never change game state and never move a part the server moves for gameplay; the small turns they draw on a cat's parts stay on this client.

| File | What |
|---|---|
| `init.luau` | `Effects.start()` starts everything once; `Effects.tier()` says "low" (phone or tablet, or Low performance on) or "high"; `Effects.applySettings(settings)` follows the Screen shake and Low performance switches; `Effects.isLoafing(model)` says whether a resting cafe cat is sat up in a loaf (for Audio's purr). |
| `Presets.luau` | Every tuning number: palette swatches, the low, high and Low performance budgets, emitter and burst presets, confetti, motion, timings. Pure. |
| `Logic.luau` | The rules with no services: device tier, the settings effects follow and the budget they pick, nearest-in-budget picks, catch grades, claim versus rank up, which gates a rank up opens, when a rush or a startle is new and how long it runs, dusk versus sunrise, the idle, nap curl, walk and gallop, pant, hiss, confetti and butterfly curves. Pure, so it can be unit tested. |
| `Context.luau` | The budget, the Screen shake and Low performance settings, where the player is, day or night, Reduce Motion, the `Workspace.ClientEffects` folder, the client-only effect part and the camera shake. |
| `Particles.luau` | Emitters from presets, one pooled hidden emitter per burst kind, part confetti on one shared loop, the flat flash ring (any size), the pop-up "!" mark. |
| `Pose.luau` | Moves a cat's body, head, tail, legs, eyes and ears. Pieces by name (`Head`, `Tail`, `LegF1`, `Eye1`, `EarL` and so on, or ending so); on the older exported cats where every body part is named like the body, legs by shape and place, in the body part's own axes. On the new bodies (PR #259) each hinged piece is a Model pivoted at its joint and turns about that pivot, the eyes and ears riding the head: Model-Agent's piece poses (`Presets.catPoses`, from the manifest's `cat_poses`) go in exactly as the manifest gives them with the idle on top, an eye is squashed flat to blink and an ear flicks back and out about its base. A breath swells the body: its own blocks grow up and out from the bottom of the body, and the head, tail and legs ride up by how high their joint is (Offsets `belly`; sizes are written only when the swell changes and put back on release). `Pose.kindOf` tells the walking body (hinged back legs) from the sitting one (front legs only). Outfit parts ride what their `Follows` attribute names and are never taken for a leg. A cat with `Pose = "upright"` (F25) turns in the floor's axes about the floor under its body and never sinks; one with `Pose = "sit"` (seated at its station on the sitting body, PR #260) never sinks either. Anchored parts get the server CFrame times a turn around each joint (the server's CFrame is re-read whenever it changes), and the speed the server moves the cat is measured so the legs keep pace; a Motor6D rig, once there is one, gets the same turns in `Transform`. |
| `Cats.luau` | Which cats move: the nearest few in range. Role idles (barista taps, waiter sways, greeter waves, entertainer bats a yarn ball), naps curled up and breathing with floating z's that keep time with the breath (every working cat at night, when the cafe is closed), resting cafe cats sitting up into a still loaf now and then by day, a resting cat on the sitting body washing a paw now and then, blinks and ear flicks on every cat, stuck cats struggling, strays looking around, a stretch as a napping stray gets up to walk off and now and then while a stray stands still (never in a seat), a slow lie-down and a quicker get-up, a walk one leg at a time at a wander and a trot or gallop when faster, with dust kicked up at a run, the pant after a sprint, the hiss hop. Gold cats in range sparkle (a carried one too), and a gold cat picked up bursts with gold sparkles. |
| `Catch.luau` | A Miss: hiss puff, "!" and the hop, plus a small camera shake for the player who missed. A catch: a sparkle in the rarity colour. A Purrfect: gold burst, ring and confetti. |
| `Chase.luau` | The getaway (F55): a ring as wide as the push spreading from the catcher's feet with a puff of dust, speed lines off the catcher while their Catch Rush lasts, a skid of dust under each pushed player. Startled (F57): the dizzy stars over the player who missed for as long as they are slowed, and a camera bump for them. |
| `Plots.luau` | Rank up confetti and a smoke puff at the cafe front, the For Rent shutters rolling up when a plot is claimed, an area gate's barrier dissolving the first time it opens for this player, a violet haze over the gates as the areas close at dusk and a sparkle and a warm ring as they open at sunrise (F66). |
| `Ambient.luau` | Espresso steam, chimney smoke, butterflies by day and fireflies at night, the nearest sources only. |
| `Shove.luau` | A shove (F41): a puff where it lands, dust at the shoved player's feet, dizzy stars round their head, and a camera bump for them. `Shove.stars(head, seconds)` also circles a startled player's head; stars already there just run longer. |
| `Wheel.luau` | The Spin Wheel station (F49): whenever anyone spins, the world wheel turns for everyone within 120 studs, easing to a stop over 3.4 s with the rim lights chasing round and the pointer knocked by each slice edge, then a sparkle at the pointer and the lights blink. It stops inside the won slice (`LastSlice`), never by an edge, at an angle every client works out the same. |

## Hooks for the luau-engineer

1. **Start it** in `Main.client.luau`, after the controllers. Nothing runs until then:
   ```luau
   require(script.Parent.Effects).start()
   ```
2. **Miss (F34)**: when a Miss ends a catch, set `HissAt = Workspace:GetServerTimeNow()` on the stray model before the jump-back, so every nearby player sees the hiss (PR #71 does this, then walks the stray 6 to 10 studs away at 24 studs/s). The hop starts as far in as the attribute is late, so it lines up with the walk, and a miss that is already over when it replicates plays nothing. The catcher's own CatchResult already plays it. A one `PivotTo` jump-back works too; the client draws the hop either way.
3. **Naps (F37)**: set `Napping = true` on a cat model while it naps (cats at `NapSpots`, the For Rent doorstep cat); `Pose = "nap"` also works. Anything else, or none, means awake.
4. **Role**: working cats read `Role` (data-model section 13) and fall back to their station's `SpotType` through `SpotId`, which works today.
5. **Rig**: if you weld a cat to its Body to cut replication (reviewer S35 option 2), use Motor6Ds named after their Part1 (`Body`, `Head`, `Tail`, with an anchored `Root`), not WeldConstraints. With WeldConstraints a local turn drags the whole cat.
6. **Streaming (reviewer S37)**: set `ModelStreamingMode = Atomic` on stray and plot cat models so a cat streams in and out whole. Effects copes without it (a cat with no Body yet is tried again every 2 s, and any part arriving makes it bind again whole), but a half-streamed cat cannot move.
7. **For Rent (reviewer N50)**: at a claim the server removes or hides the For Rent dressing for everyone. Effects only draws a copy of the shutters and sign rolling up and fading, and only within 120 studs, so a far player relies on the server's change.
8. **Chase (F40)**: `FleeingUntil` on the stray (server time the sprint and rest end) makes it pant once it stops. The gallop needs nothing: it comes from how fast the server moves the cat.
9. **Shove (F41)**: on a shove, set `ShovedAt = Workspace:GetServerTimeNow()` and `ShovedBy = <shover's UserId>` on the shoved player's character, so everyone nearby sees it. The knockback stays yours, on the target's client.
10. **Settings**: call `Effects.applySettings(settings)` wherever `Audio.applySettings` is called (the first ProfileSync and every `UI.settings.changed`), with the switches as shown: `{ screenShake = ..., lowPerformance = ... }`. `screenShake = false` turns off the camera shake of a missed catch and the bump of a shove (a running one stops at once). `lowPerformance = true` swaps in `Presets.budget.lowPerformance` on any device within a second, and `Effects.tier()` then says "low", so the street's customer cap comes down with it. A missing key means shake on and Low performance off, so Low performance must default to off on the Settings screen. Calling it before `start()` or with unchanged settings is fine.
11. **Stray naps (Derek 2026-10-27)**: a stray may nap in a pause of its wander with `Napping = true`. To wake it on its own, set `StretchAt = Workspace:GetServerTimeNow()` as you clear `Napping` and wait about 3.6 s before walking it, so it gets up and stretches first; a catch, miss or shove just clears `Napping`.
12. **Getaway and Startled (F55, F57)**: set `RushUntil` (server time the Catch Rush ends) on the catcher's character and `StartledUntil` (server time the slow ends) on the character of the player who missed, as data-model section 13 has them. Each change to a time ahead of now plays; setting either back to 0 or a past time early ends the speed lines. For a skid of dust under each player the getaway pushes, also set `PushedAt = Workspace:GetServerTimeNow()` on their character; without it the ring still shows the push.
13. **Night (F66)**: nothing more than the Clock's `AreasOpen` (data-model section 13). The haze and the sparkle play when it turns, never for the first value a client sees, so a player joining at night sees nothing until sunrise.

## What it reads

| Effect | Source |
|---|---|
| Cats that move | tags `Stray` and `StuckCat`; models inside a `Plot` with `CatId`, `Napping` or `Pose` |
| Role idle | `Role`, else `SpotId` to `Plot/Spots/<id>` `SpotType` |
| Nap | `Napping = true` (or `Pose = "nap"`); a `WorkingCat` (or one with a `SpotId`) while `Phase` is `"night"` |
| Loaf | `Napping = true` on a cat with no station, by day: 24 s of every 75, each cat at its own offset from its `Uid` and the server clock, so every player sees the same cat loaf at the same time |
| Sleep and loaf poses | the nap and the loaf on the walking body (pieces `LegB1` and `LegB2`): manifest `sleep` and `loaf`, lowered by `lift` times the model's `Scale` but never past 0.02 studs (at its scale) above the floor, so the short-legged Munchkin lies on the floor rather than in it; the older Part cats fold their own legs |
| Paw lick | `Napping = true` on the sitting body (front legs only) by day: 9 s of every 60, each cat at its own offset like the loaf; manifest `lick` with the head bobbing and the paw rubbing in bursts |
| Sleeping breath | nap, doze and loaf: the belly fills and lets out (`Logic.breath`), the top of the back rising `motion.nap.breathe` (doze, loaf: their own `breathe`) studs |
| Z's | nap and doze: three labels taking turns, one each breath out, rising and growing over `nap.life` breaths and starting again (`Logic.napZ`) |
| Blinks and ear flicks | every cat with `Eye1`/`Eye2` and `EarL`/`EarR` pieces (or parts): a blink about every 4 s, eyes shut asleep or dozing and half shut in a loaf; an ear flick every 5 to 8 s, half as often asleep |
| Doze on its feet or seat | the nap rule on a cat with `Pose = "upright"` (F25) or `Pose = "sit"` (PR #260): head droop and nod, no sink; `Pose` changing rebinds the cat |
| Walk, trot and gallop | the speed the server moves the cat: one leg at a time below 3.4 studs a second, a trot from 4, a gallop from 9, full at 18 |
| Stretch | `StretchAt` (server time) on a `Stray` getting up from a nap to walk off; a `Stray` standing still, every 35 to 80 s; never a seated cat |
| Pant | a `Stray` standing still while its `FleeingUntil` is ahead of the server time |
| Gold sparkle | `Gold = true` (or the old `Shiny = true`) on a stray, a working or napping cat, or a player's `HeldCat` |
| Gold burst | a gold `HeldCat` appearing (a gold cat caught or rescued), or `Gold` (or `Shiny`) turning true |
| Shove | `ShovedAt` changing on a character to a server time under 0.6 s old; `ShovedBy` places the puff |
| Getaway ring | `RushUntil` on a character changing to a server time ahead of now while no rush was running: a ring 20 studs across (twice the push radius) and dust at their feet, within `ambientRadius` or on this player |
| Speed lines | `RushUntil` ahead of the server time: `rushLines` trails off the body until then; a character that arrives mid-rush gets them without the ring |
| Pushed dust | `PushedAt` changing on a character to a server time under 0.6 s old |
| Startled stars | `StartledUntil` on a character changing to a server time ahead of now: the shove's stars until then, and a camera bump when it is this player and no startle was running |
| Dusk haze, sunrise sparkle | the Clock's `AreasOpen` turning false or true, at every `AreaGate` within 70 studs whose `RequiresTier` this player's cafe has reached |
| Hiss | CatchResult not a success (the catcher), `HissAt` changing to a server time under 0.6 s old (everyone) |
| Catch sparkle, Purrfect | CatchResult success; every grade `"perfect"` is a Purrfect (the v0.3 scores, all 1, still work) |
| Rank up | a `Plot`'s `Tier` rising with the same `OwnerUserId`, 2 s or more after the owner changed |
| Shutters | a `Plot`'s `OwnerUserId` going from 0 to a player; parts ending `_Shutter` and `_Sign` inside a model named `...ForRent...` |
| Gate dissolve | tag `AreaGate` with `RequiresTier`; this player's own plot `Tier` crossing it |
| Steam | parts, attachments or object Models ending `_Steam`, else the top of each plot's `Espresso` model |
| Chimney smoke | parts or object Models ending `_Chimney` |
| Butterflies (day) | parts or object Models ending `_Flowers`, else the pavement in front of each plot's `Door` |
| Fireflies (night) | parts ending `_Fireflies`, else the street lamps' `_Bulb` parts |
| Spin wheel turning | tag `SpinWheel` with `LastSpinAt` (server time) changing and `LastSlice` (1 to 6, set just before it); its `Wheel` Model (pivoted at the hub, turns about its own Z axis), `Pointer` and `RimLight` parts |
| Hidden cats | `HiddenLocal = true`, set on this client only when Show other cats is off: no motion, gold sparkle, burst, hiss or loaf until it clears (picked again within half a second) |
| Day or night | `ReplicatedStorage.Clock` attribute `Phase` |
| Areas open | `ReplicatedStorage.Clock` attribute `AreasOpen` (F66) |

## Budgets

`Presets.budget.low` (touch with no keyboard) and `.high`. Phone: 8 moving cats within 60 studs at 30 updates a second, 4 steady emitters, 3 gold sparkles, 6 butterflies, bursts of 12 at most, 14 confetti pieces, 80 confetti pieces alive at most on any device. The Low performance setting uses `.lowPerformance` on any device: 4 moving cats within 45 studs at 20 updates a second, 2 steady emitters at half their rate, 1 gold sparkle, 2 butterflies, bursts at 35 % and 8 at most, 8 confetti pieces, 2 sets of z's. Speed lines on a player in a Catch Rush: 3 on a PC, 2 on a phone, 1 in Low performance, and only on players within `ambientRadius` (always on this player). Everything is chosen by distance once a second (cats twice a second), not every frame, so a budget change shows within a second. Reduce Motion turns off the camera shake and the flash ring, holds the z's still and cuts confetti to 40 %; the Screen shake setting turns off the camera shake alone.

Textures are Roblox's built-in particle sprites until our own are uploaded; put the uploaded id in `Presets.textures` (`goldSparkle` first). No animation ids are used yet, so there is no `AnimationIds.luau` until the first Animation Editor clip.
