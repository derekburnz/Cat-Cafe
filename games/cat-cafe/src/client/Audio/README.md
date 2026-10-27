# src/client/Audio -> StarterPlayerScripts.Client.Audio

Owner: sound-designer (Luau reviewed by luau-reviewer). Rules: `.claude/skills/audio-pipeline/SKILL.md`. What each cue should sound like: `docs/audio/cat-cafe/sound-list.md`.

| File | What |
|---|---|
| `init.luau` | The Audio module: builds the four channels, plays cues, runs music by the day and night clock and ambience by zone, turns moments into sounds. |
| `Cues.luau` | Every cue id with its channel, volume, pitch range, spam gap, voices, 3D range and asset ids. The only place asset ids live. Pure. |
| `Logic.luau` | The rules with no Roblox services in them (voice pooling, the pentatonic step, which music bed or ambience plays, ducking, slider gain, rarity jingles, grade, food and trap cues, the hold fill speed, zone chimes, which strays twinkle, which resting cat purrs, the dusk bell's timing, the Mythical sting and the plot cues), so they can be unit tested. |

Hooks 1, 2 and 4 are wired (PR #66) and the moments too (PR #91). All 76 synthesized files have uploaded ids (44 on 2026-10-26 and 27, the last 32 on 2026-10-27 evening). A cue with no id yet (the music beds) plays nothing, so a hook is safe to add before its file exists.

## Hooks for the luau-engineer

1. **Start it** in `Main.client.luau`, before the controllers:
   ```luau
   local Audio = require(script.Parent.Audio)
   Audio.start()
   ```
   `start()` makes the SoundGroups `Music`, `Ambience`, `Sfx` and `Ui` in SoundService, preloads the short P0 cues and starts reading the `Phase` and `PhaseEndsAt` attributes on `ReplicatedStorage.Clock` (read only, the same way WorldController does).
2. **Settings and carrying** (UIController already handles both): settings with the first `ProfileSync` and again whenever they change (the settings switches), carrying on every `ProfileSync`. A settings call with nothing changed changes nothing, so calling it more often is harmless:
   ```luau
   Audio.applySettings(state.settings) -- { music: boolean, sfx: boolean, musicVolume: number?, sfxVolume: number? }
   Audio.setCarrying(state.carrying ~= nil)
   ```
   Music off mutes `Music`; sound off mutes the other three, and a muted channel loads nothing (no downloads on mobile data). The sliders `musicVolume` and `sfxVolume` (0 to 1, missing means full) scale the same channels by the slider squared; a switch that is off wins and a slider at 0 counts as off. Music and ambience start on the first call, so a player who turned music off never hears a note. The carry purr follows `carrying`, so a missed moment can never leave it purring.
3. **Moments**: once `src/client/Moments.luau` exists (one Signal per moment, names and arguments in the sound list section 6):
   ```luau
   Audio.bindMoments(Moments)
   ```
   Moments that do not exist yet are skipped, so the table can grow one feature at a time. Arguments are checked, so a missing one only loses a sound. Grades work as `"perfect"` or `"Perfect"`. Design v0.4 adds `PawLost`, `Purrfect`, `PlotOpened(position)` (a For Rent plot opens: shutters and sign, for everyone nearby), a `position` on `AreaUnlock(areaId, position)` so the gate sound comes from the gate, and an optional `rarity` on `Announce(text, rarity)` so the shout-out chime rises with rarity. Design v0.5 retires `PawLost` (F40) and adds `Shove(role, position)` for every shove that lands (F41), fired on every nearby player's device before `BumpLoose` or `BumpHeld` when the target was carrying; `role` is `"shover"`, `"target"` or `"bystander"` and `position` the target's, so the sounds play in 3D from where it happened. The 2026-10-27 features add `CatDrop(position)`, `Travel(destination)`, `UnplaceCat(uid)`, `TipJarClaim(step)`, `IndexReward(areaId, milestoneId)`, fire `CircleAppear` and `CatPlaced` (engineer PR #224) and rename `ShinyReveal` to `GoldReveal`. The Spin Wheel window plays its own `uiSpinStart`, `uiSpinTick` and `uiSpinWin`, so Audio binds no wheel moment. `RareStrayNearby` is gone: the `Stray` world loop below does it.
4. **Zone** for ambience, from whatever already knows where the player is (WorldController's alley check, a zone part):
   ```luau
   Audio.setZone("Alley") -- "Cafe", "Alley", "Park"; later "Neighbourhood", "Woods", "Sewer"; nil for none
   ```
   Crossing between the safe street (nil or `"Cafe"`) and a catching area also plays `zoneArea` or `zoneSafe` with the Safe zone chip: one per 4 s, none for 2 s after a `Travel`.
5. **UI sounds**: the ui-designer's `Theme.sounds` ids become one injected function, `playSound = Audio.play`, called with cue ids: `uiClick` (click), `purchase` (buy), `uiError` (error), `jingleCatFound` (catFound), plus `uiOpen`, `uiClose`, `uiToast`, `uiTab` and the rest of sound list 5.8.
6. **World loops** need only a CollectionService tag on the part or model (a model plays from its PrimaryPart). Audio follows the tags itself, streaming in and out with the parts:

   | Tag | On | Plays |
   |---|---|---|
   | `CafeDoor` | each cafe's front door | `loopCafeDoor`, chatter and cups spilling out, 30 studs; only while the plot has an owner (`OwnerUserId`) and it is day, since For Rent shops are shut and the cafe closes at night (v0.5) |
   | `Fountain` | the park fountain | `loopFountain` |
   | `FishTank` | the fish tank decor | `loopFishTank` |
   | `WorkingCat` | a cat at its station | `purr`, only on the 3 nearest within 14 studs, never one the player hid (`HiddenLocal`) |
   | `Stray` | a stray with `Gold`, or `Rarity` Epic and up | `shimmerRare`, only on the 3 nearest within 40 studs |

   The nearest resting cafe cat within 14 studs purrs too, by day (`Logic.restingPurrs`): the Napping children of each `Plot`'s `Cats` folder, one sitting on the seated body (`Pose` "sit", PR #266) the whole day, one on the lying body only while `Effects.isLoafing(model)` (vfx-animator PR #222). Only one, so it is always a cat Effects is animating (reviewer N131, N150).
7. **Holding a prompt** needs nothing: Audio listens to ProximityPromptService's hold events and plays `holdFill` on any Custom prompt with a HoldDuration (a stray's, a stuck cat's, a manhole's), stretched so its pop lands on the trigger, faded out if the key is let go early, silent while the cat is still running.
8. **A gold cat in your arms** needs nothing either: Audio watches your character for a `HeldCat` model with `Gold` (or `Gold` turning on) and plays `goldReveal` once per cat.
9. **Design v0.8 and v0.9** need only the attributes in data-model section 13, which Audio follows itself: the `Clock` (`duskBell` DuskWarningSeconds before night, read from `Config.DuskWarningSeconds` once it exists, else 15), every character's `RushUntil` (`getaway`, 3D on the catcher) and `CarryStartedAt` (`catPickUp`, 3D on the carrier; your own stays quiet for 2 s after your catch or rescue), and your own plot's `TipPiles` going down (`tipPile`), `CollectorUntil` arriving (`visitorCollector`) and `MysteryGiftAt` appearing (`visitorMystery`). An `Announce` with rarity Mythical plays `announceMythical` once it has a file. The UI plays `uiCodeRedeem` (or `uiError`) from `CodeResult`, `giftOpen` with the `MysteryGiftResult` card, `uiTrade` and `potionDrink`. The gift clearing is not a cue on purpose: the server also clears an unopened gift after MysteryGiftKeepSeconds or on a plot release, and that must not sound like an opening.

   Anything else that loops while something is out (like the dealer cart) uses `Audio.loop(cueId, part)`, which returns a function that fades it out.

## API

| Call | Does |
|---|---|
| `Audio.start()` | Builds the channels, preloads, follows the clock. |
| `Audio.applySettings(settings)` | Mutes and scales channels by the player's settings (switches and volume sliders); the first call starts music and ambience. |
| `Audio.setCarrying(isCarrying)` | Starts or stops the carry purr. |
| `Audio.play(cueId, at?, step?)` | Plays a cue once. `at` is a BasePart, an Attachment or a Vector3 for 3D; nil plays it flat. `step` raises it one note of the pentatonic scale per step (circles 1 to 5, rescue hits). Returns the Sound or nil. |
| `Audio.loop(cueId, at?)` | Starts a looped cue and returns a function that fades it out. |
| `Audio.setZone(zone)` | Picks the ambience bed `amb<Zone><Day/Night>`, crossfading over 1.5 s, and chimes when crossing between the safe street and a catching area. |
| `Audio.bindMoments(moments)` | Connects every moment Audio knows to its sounds. |

## How it behaves

- Music follows the server clock on every client at once: day beds A then B (B from halfway through the phase), night beds A then B. On a phase change the bed fades out over 2 s, the dusk or dawn stinger plays, and the new A bed fades in. A missing B bed falls back to A.
- Stingers, the rank up jingle, the gold reveal, the Index reward, the wheel win and the Legendary and Mythical jingles duck the music to 40 % while they play. A catch or rescue ducks the music to 60 % and the ambience to 50 % until its result arrives (30 s at most).
- Each cue has a pool of Sounds (`voices`); when all are busy the oldest restarts, so a coin shower never makes a hundred Sounds. `minGap` drops repeats that come too fast.
- A loop on a part ends when the part is destroyed. A one-shot on something the server may remove in the same frame (a fleeing stray, the leaving dealer cart, a rescue trap) plays at its position instead, so the removal cannot cut it off. A pooled Sound whose part streamed out is simply reparented on its next play.
- Tagged world loops wait for the first `applySettings` like music, restart when the sound setting changes, and end when the tagged instance leaves the tag or streams out. Twice a second Audio also starts loops on tagged models whose parts streamed in late, restarts one whose part streamed out under it, and rechecks the `WorkingCat` purrs, the `Stray` twinkles and the resting purr against the player's position, so a full server never runs dozens at once.
- The cat's hiss on a Miss follows the `HissAt` attribute the server sets on the `Stray` model, and its sprint away follows `FleeingUntil` (v0.5, played on the cat so it runs off with it), so every player nearby hears both, each at most once per cat per second. `CatchFail` only plays the catcher's own miss sound.
- The server never plays sounds, and this module never fires remotes or changes game state.
