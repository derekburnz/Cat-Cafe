# src/client/Effects -> StarterPlayerScripts.Client.Effects

Owner: vfx-animator (Luau reviewed by luau-reviewer). Rules: `.claude/skills/animation-vfx/SKILL.md`. What each effect is for and its status: `docs/vfx/cat-cafe/effects-list.md`.

Everything here runs on this client only. Effects read replicated world state (tags and attributes) and this player's own CatchSchedule and CatchResult events. They never fire a remote, never change game state and never move a part the server moves for gameplay; the small turns they draw on a cat's parts stay on this client.

| File | What |
|---|---|
| `init.luau` | `Effects.start()` starts everything once; `Effects.tier()` says "low" (phone or tablet) or "high". |
| `Presets.luau` | Every tuning number: palette swatches, the low and high budgets, emitter and burst presets, confetti, motion, timings. Pure. |
| `Logic.luau` | The rules with no services: device tier, nearest-in-budget picks, catch grades, claim versus rank up, which gates a rank up opens, the idle, hiss, confetti and butterfly curves. Pure, so it can be unit tested. |
| `Context.luau` | The budget, where the player is, day or night, Reduce Motion, the `Workspace.ClientEffects` folder and the client-only effect part. |
| `Particles.luau` | Emitters from presets, one pooled hidden emitter per burst kind, part confetti on one shared loop, the flat flash ring, the pop-up "!" mark. |
| `Pose.luau` | Moves a cat's body, head, tail and front paws by part name. Anchored parts get the server CFrame times a turn around each joint (the server's CFrame is re-read whenever it changes); a Motor6D rig, once there is one, gets the same turns in `Transform`. |
| `Cats.luau` | Which cats move: the nearest few in range. Role idles (barista taps, waiter sways, greeter waves, entertainer bats a yarn ball), naps with floating z's, stuck cats struggling, strays looking around, the hiss hop. Shiny cats in range sparkle. |
| `Catch.luau` | A Miss: hiss puff, "!" and the hop, plus a small camera shake for the player who missed. A catch: a sparkle in the rarity colour. A Purrfect: gold burst, ring and confetti. |
| `Plots.luau` | Rank up confetti and a smoke puff at the cafe front, the For Rent shutters rolling up when a plot is claimed, an area gate's barrier dissolving the first time it opens for this player. |
| `Ambient.luau` | Espresso steam, chimney smoke, butterflies by day and fireflies at night, the nearest sources only. |

## Hooks for the luau-engineer

1. **Start it** in `Main.client.luau`, after the controllers. Nothing runs until then:
   ```luau
   require(script.Parent.Effects).start()
   ```
2. **Miss (F34)**: when a Miss ends a catch, set `HissAt = Workspace:GetServerTimeNow()` on the stray model before the jump-back, so every nearby player sees the hiss. The catcher's own CatchResult already plays it. Do the jump-back as one `PivotTo` or a fast walk; the client draws the hop either way.
3. **Naps (F37)**: set `Pose = "nap"` on a cat model while it naps (roaming cats, the For Rent doorstep cat). Any other value, or none, means awake.
4. **Role**: working cats read `Role` (data-model section 13) and fall back to their station's `SpotType` through `SpotId`, which works today.
5. **Rig**: if you weld a cat to its Body to cut replication (reviewer S35 option 2), use Motor6Ds named after their Part1 (`Body`, `Head`, `Tail`, with an anchored `Root`), not WeldConstraints. With WeldConstraints a local turn drags the whole cat.

## What it reads

| Effect | Source |
|---|---|
| Cats that move | tags `Stray` and `StuckCat`; models inside a `Plot` with `CatId` or `Pose` |
| Role idle | `Role`, else `SpotId` to `Plot/Spots/<id>` `SpotType` |
| Nap | `Pose = "nap"` |
| Shiny sparkle | `Shiny = true` on a stray or working cat |
| Hiss | CatchResult with a 0 score (the catcher), `HissAt` changing (everyone) |
| Catch sparkle, Purrfect | CatchResult success; all scores 1 is a Purrfect |
| Rank up | a `Plot`'s `Tier` rising with the same `OwnerUserId`, 2 s or more after the owner changed |
| Shutters | a `Plot`'s `OwnerUserId` going from 0 to a player; parts ending `_Shutter` and `_Sign` inside a model named `...ForRent...` |
| Gate dissolve | tag `AreaGate` with `RequiresTier`; this player's own plot `Tier` crossing it |
| Steam | parts or attachments ending `_Steam`, else the top of each plot's `Espresso` model |
| Chimney smoke | parts ending `_Chimney` |
| Butterflies (day) | parts ending `_Flowers`, else the pavement in front of each plot's `Door` |
| Fireflies (night) | parts ending `_Fireflies`, else the street lamps' `_Bulb` parts |
| Day or night | `ReplicatedStorage.Clock` attribute `Phase` |

## Budgets

`Presets.budget.low` (touch with no keyboard) and `.high`. Phone: 8 moving cats within 60 studs at 30 updates a second, 4 steady emitters, 3 shiny sparkles, 6 butterflies, bursts of 12 at most, 14 confetti pieces, 80 confetti pieces alive at most on any device. Everything is chosen by distance once a second (cats twice a second), not every frame. Reduce Motion turns off the camera shake and the flash ring, holds the z's still and cuts confetti to 40 %.

Textures are Roblox's built-in particle sprites until our own are uploaded; put the uploaded id in `Presets.textures` (`shinySparkle` first). No animation ids are used yet, so there is no `AnimationIds.luau` until the first Animation Editor clip.
