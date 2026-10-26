# Review: client Audio module (PR #45)

Reviewer: luau-reviewer thread, 2026-10-26 about 23:10 UTC, on head 3fd319b (sound-designer commit 5f7e33c). Read only; no game files changed. Covers `games/cat-cafe/src/client/Audio/` (`init.luau`, `Cues.luau`, `Logic.luau`, `README.md`) and the two doc lines. Checked against `docs/audio/cat-cafe/sound-list.md`, data-model v0.3.1 and CatService on main after #40 (e6fe7c5).

## Verdict

Sound, and safe to merge while it is inert: nothing requires it and every cue has empty ids. It never fires a remote, never changes game state and keeps asset ids in one file. One should-fix (S34) before the moments are wired: the stray flee sound is parented to a model the server destroys in the same frame, so it will be cut off. Four nits. CI was green on 3fd319b; main has moved, so merge main in first.

## Checked and fine

- **No network.** No `FireServer`, `InvokeServer`, `Net` or `HttpService` anywhere in the module. Moment handlers type-check every argument (`num`, `str`, `vec`), so a missing or odd value only loses a sound.
- **Clock.** Reads `Phase` and `PhaseEndsAt` on `ReplicatedStorage.Clock` and never writes them. The values match ClockService (`"day"`, `"night"`). On a phase change the new bed starts from 0, so a stale `PhaseEndsAt` read in the same frame does not matter.
- **Timers.** `bedGeneration` drops every bed timer from an older phase, and `catchToken` drops the 30 s catch-duck fallback once a result arrives. `duckWhile` releases once, on `Ended` or after 8 s, whichever comes first.
- **Crossfades.** A new tween on the same Sound cancels the fade-out, and the fade-out only stops a Sound that is no longer the bed, so switching back to a bed mid-fade keeps it playing.
- **Pools and loops.** One-shots reuse up to `voices` Sounds per cue and restart the oldest, so a coin shower cannot grow the instance count. `bedSounds` holds one Sound per bed cue (13 at most). Loops end through their stop function or with their part, and `shimmering` drops strays whose part is gone. Nothing runs per frame.
- **Ids from the design.** Lure ids (`kibble`, `tuna`, `salmon`, dealer foods), trap types (`trash_bin`, `garbage_bag`, `tree`, `trashcan`), area ids and the `Stray` / `StrayId` and `RescueSpot` / `RescueSpotId` tags and attributes all match the Catalog, WorldBuilder and CatService.
- **Streaming, for the record.** A part that streams out is parented to nil rather than destroyed, so the pool prune (`sound.Parent == nil`) does not see it. That is harmless: `place` reparents the Sound on its next use. The README line about streaming is a little off for the same reason.

## Findings

**S34 (should-fix, sound-designer) The flee sound is cut off.** `StrayFlee` plays `strayFlee` parented to the stray model (`init.luau:529`). On a failed catch of a Rare or rarer cat, CatService fires `CatchResult` (`CatService.luau:692`) and despawns the stray in the same server frame (`:714`). On the client the sound either starts on a part that is destroyed a frame later, which stops it, or finds no part and plays flat. The same will happen to `dealerLeave` if the dealer build removes the cart when it leaves. Fix: play one-shots on a part that is about to go at its position, for example `Audio.play("strayFlee", if part then part.Position else nil)`, which uses the Terrain attachment path; keep parts for loops, which should end with the part.

**N40 (nit) The B bed switch is a fixed 150 s.** The sound list says each bed plays the first or second half of a phase, but `BED_SECONDS = 150` is fixed (`init.luau:36`). It matches the 300 s phases that #47 brings, but on main today (day 180, night 120) the night B bed never plays and day B gets 30 s. Use `phaseLength(phase) / 2` so the switch follows Config.

**N41 (nit) The carry purr follows moments instead of state.** `carryPurr` starts on `CarryStart` and stops only on `CheckIn` or `BumpLoose` with role `carrier` (`init.luau:564` to `:581`). If a carry ever ends another way, or a moment is missed, the purr loops for the rest of the session. ProfileSync already sends `carrying`, and data-model 10c puts `CarryingCatId` on the carrier's character. Follow one of those, the same reason the music reads the Clock instead of NightStart and DayStart.

**N42 (nit, phones) Muted channels still load and play.** With music off, `crossfade` still creates the bed Sound, sets its SoundId and plays it at channel volume 0, so a phone on mobile data downloads every bed it reaches. The same goes for ambience with sound off. Treat a muted channel as no bed (crossfade to nil) and refresh when the setting turns back on.

**N43 (nit) `Audio.start()` can run twice.** `build()` is guarded, but `preload` and `followClock` are not, so a second call doubles the clock connections and every dusk and dawn stinger. Add a `started` flag like `built`.

## For the engineer (wiring)

When `Moments.luau` lands, `StrayFlee` can carry the stray's position, read when `CatchResult` arrives, so Audio does not need to find a model that is about to be destroyed.

## Build checklist status

Unchanged by this PR. Open here: S34, N40 to N43.
