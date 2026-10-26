# src/client/Audio -> StarterPlayerScripts.Client.Audio

Owner: sound-designer (Luau reviewed by luau-reviewer). Rules: `.claude/skills/audio-pipeline/SKILL.md`. What each cue should sound like: `docs/audio/cat-cafe/sound-list.md`.

| File | What |
|---|---|
| `init.luau` | The Audio module: builds the four channels, plays cues, runs music by the day and night clock and ambience by zone, turns moments into sounds. |
| `Cues.luau` | Every cue id with its channel, volume, pitch range, spam gap, voices, 3D range and asset ids. The only place asset ids live. Pure. |
| `Logic.luau` | The rules with no Roblox services in them (voice pooling, the pentatonic step, which music bed or ambience plays, ducking, rarity jingles, grade, food and trap cues), so they can be unit tested. |

Nothing here runs until the engineer wires it in. Until a cue has an uploaded id in `Cues.luau`, playing it does nothing, so the hooks below are safe to add before any file is uploaded.

## Hooks for the luau-engineer

1. **Start it** in `Main.client.luau`, before the controllers:
   ```luau
   local Audio = require(script.Parent.Audio)
   Audio.start()
   ```
   `start()` makes the SoundGroups `Music`, `Ambience`, `Sfx` and `Ui` in SoundService, preloads the short P0 cues and starts reading the `Phase` and `PhaseEndsAt` attributes on `ReplicatedStorage.Clock` (read only, the same way WorldController does).
2. **Settings** on every `ProfileSync` (UIController already handles it) and on each settings toggle:
   ```luau
   Audio.applySettings(state.settings) -- { music: boolean, sfx: boolean }
   ```
   Music off mutes `Music`; sound off mutes the other three. Music and ambience start on the first call, so a player who turned music off never hears a note.
3. **Moments**: once `src/client/Moments.luau` exists (one Signal per moment, names and arguments in the sound list section 6):
   ```luau
   Audio.bindMoments(Moments)
   ```
   Moments that do not exist yet are skipped, so the table can grow one feature at a time. Arguments are checked, so a missing one only loses a sound. Grades work as `"perfect"` or `"Perfect"`.
4. **Zone** for ambience, from whatever already knows where the player is (WorldController's alley check, a zone part):
   ```luau
   Audio.setZone("Alley") -- "Cafe", "Alley", "Park"; later "Neighbourhood", "Woods", "Sewer"; nil for none
   ```
5. **UI sounds**: the ui-designer's `Theme.sounds` ids become one injected function, `playSound = Audio.play`, called with cue ids: `uiClick` (click), `purchase` (buy), `uiError` (error), `jingleCatFound` (catFound), plus `uiOpen`, `uiClose`, `uiToast`, `uiTab` and the rest of sound list 5.8.
6. **World loops** on props, from the code that builds or streams them in:
   ```luau
   local stop = Audio.loop("loopFountain", fountainPart) -- call stop() to fade it out; the part's removal also ends it
   ```

## API

| Call | Does |
|---|---|
| `Audio.start()` | Builds the channels, preloads, follows the clock. |
| `Audio.applySettings(settings)` | Mutes channels by the player's settings; the first call starts music and ambience. |
| `Audio.play(cueId, at?, step?)` | Plays a cue once. `at` is a BasePart, an Attachment or a Vector3 for 3D; nil plays it flat. `step` raises it one note of the pentatonic scale per step (circles 1 to 5, rescue hits). Returns the Sound or nil. |
| `Audio.loop(cueId, at?)` | Starts a looped cue and returns a function that fades it out. |
| `Audio.setZone(zone)` | Picks the ambience bed `amb<Zone><Day/Night>`, crossfading over 1.5 s. |
| `Audio.bindMoments(moments)` | Connects every moment Audio knows to its sounds. |

## How it behaves

- Music follows the server clock on every client at once: day beds A then B (B after 150 s), night beds A then B. On a phase change the bed fades out over 2 s, the dusk or dawn stinger plays, and the new A bed fades in. A missing B bed falls back to A.
- Stingers, the rank up jingle, the shiny reveal and the Legendary and Mythical jingles duck the music to 40 % while they play. A catch or rescue ducks the music to 60 % and the ambience to 50 % until its result arrives (30 s at most).
- Each cue has a pool of Sounds (`voices`); when all are busy the oldest restarts, so a coin shower never makes a hundred Sounds. `minGap` drops repeats that come too fast.
- A Sound on a part goes away with the part (streaming), and its pool slot is rebuilt on the next play.
- The server never plays sounds, and this module never fires remotes or changes game state.
