# Purr Pot audio files and sources log

Owner: sound-designer. Rules: `.claude/skills/audio-pipeline/SKILL.md`. What each cue should sound like: `docs/audio/cat-cafe/sound-list.md`.

```
music/      CatCafe_Music_<Name>.ogg     stereo seamless loops and stingers
ambience/   CatCafe_Amb_<Name>.ogg       stereo seamless beds; CatCafe_Amb_Loop<Name>.ogg are mono 3D loops on props
sfx/        CatCafe_Sfx_<Name>.ogg       mono, 3D or 2D game sounds
ui/         CatCafe_Ui_<Name>.ogg        mono interface sounds
gates.md    written by audio_gate.py; never edit by hand
synth/      synth.py (effects and jingles) and ambience.py (looping beds): our own sounds made from code; rerun to rebuild
upload.py   uploads every file here to Roblox (Open Cloud) and writes the ids into Cues.luau and this log
uploaded.json  written by upload.py: file -> Roblox asset id
```

Only upload-ready files live here. Creator Store sounds used as they are need no file, only a log row. DAW projects, raw recordings and stems stay out of Git; the row says where they are.

## Sources log

One row per file or Creator Store asset, added the moment it is picked, before upload. A row with no license is not uploaded. CC-BY rows also go in `CREDITS.md` at the repo root.

| cue | file or Creator Store id | origin | license | author | link or where kept | uploaded id | added |
|---|---|---|---|---|---|---|---|
| `uiClick` | `ui/CatCafe_Ui_Click.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 100998799358810 | 2026-10-26 |
| `uiError` | `ui/CatCafe_Ui_Error.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 80135751380842 | 2026-10-26 |
| `catchStart` | `sfx/CatCafe_Sfx_CatchStart.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 92586398019542 | 2026-10-26 |
| `circleAppear` | `sfx/CatCafe_Sfx_CircleAppear.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 135049952895026 | 2026-10-26 |
| `netSwing` | `sfx/CatCafe_Sfx_NetSwing.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 89396147858929 | 2026-10-26 |
| `circlePerfect` | `sfx/CatCafe_Sfx_CirclePerfect.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 80668948664944 | 2026-10-26 |
| `circleGood` | `sfx/CatCafe_Sfx_CircleGood.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 104110576862212 | 2026-10-26 |
| `circleMiss` | `sfx/CatCafe_Sfx_CircleMiss.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 82265210012821 | 2026-10-26 |
| `catchSparkle` | `sfx/CatCafe_Sfx_CatchSparkle.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 96610512551224 | 2026-10-26 |
| `catchMiss` | `sfx/CatCafe_Sfx_CatchMiss.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 72335633309097 | 2026-10-26 |
| `coinPop` | `sfx/CatCafe_Sfx_CoinPop.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 80305681313349 | 2026-10-26 |
| `purchase` | `sfx/CatCafe_Sfx_Purchase.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 135044364239461 | 2026-10-26 |
| `ambCafeDay` | `ambience/CatCafe_Amb_CafeDay.ogg` | synthesized by `synth/ambience.py` | original (Purr Pot) | sound-designer | this repo | 136952289794282 | 2026-10-26 |
| `ambCafeNight` | `ambience/CatCafe_Amb_CafeNight.ogg` | synthesized by `synth/ambience.py` | original (Purr Pot) | sound-designer | this repo | 84916609751628 | 2026-10-26 |
| `ambAlleyDay` | `ambience/CatCafe_Amb_AlleyDay.ogg` | synthesized by `synth/ambience.py` | original (Purr Pot) | sound-designer | this repo | 83744712629616 | 2026-10-26 |
| `ambAlleyNight` | `ambience/CatCafe_Amb_AlleyNight.ogg` | synthesized by `synth/ambience.py` | original (Purr Pot) | sound-designer | this repo | 82664754116384 | 2026-10-26 |
| `ambParkDay` | `ambience/CatCafe_Amb_ParkDay.ogg` | synthesized by `synth/ambience.py` | original (Purr Pot) | sound-designer | this repo | 75896689856230 | 2026-10-26 |
| `ambParkNight` | `ambience/CatCafe_Amb_ParkNight.ogg` | synthesized by `synth/ambience.py` | original (Purr Pot) | sound-designer | this repo | 120595462689856 | 2026-10-26 |
| `checkInBell` | `sfx/CatCafe_Sfx_CheckInBell.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 75991488445164 | 2026-10-26 |
| `strayFlee` | `sfx/CatCafe_Sfx_StrayFlee.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 115429958262894 | 2026-10-26 |
| `jingleCatFound` | `music/CatCafe_Music_JingleCatFound.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 102912195564834 | 2026-10-26 |
| `jingleRankUp` | `music/CatCafe_Music_JingleRankUp.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 77815750894397 | 2026-10-26 |
| `loopCafeDoor` | `ambience/CatCafe_Amb_LoopCafeDoor.ogg` | synthesized by `synth/ambience.py` | original (Purr Pot) | sound-designer | this repo | 98253223255392 | 2026-10-26 |
| `catHiss` | `sfx/CatCafe_Sfx_CatHiss.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 133059376390215 | 2026-10-26 |
| `pawLost` | `sfx/CatCafe_Sfx_PawLost.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 120814540941175 | 2026-10-26 |
| `purrfectChime` | `sfx/CatCafe_Sfx_PurrfectChime.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 115362387345274 | 2026-10-26 |
| `gateOpen` | `sfx/CatCafe_Sfx_GateOpen.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 89970899972584 | 2026-10-26 |
| `shuttersUp` | `sfx/CatCafe_Sfx_ShuttersUp.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 137368825957454 | 2026-10-26 |
| `signFlip` | `sfx/CatCafe_Sfx_SignFlip.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 108862500995197 | 2026-10-26 |
| `announce` | `sfx/CatCafe_Sfx_Announce.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 140320161816899 | 2026-10-26 |
| `purr` | `sfx/CatCafe_Sfx_Purr.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 134709393284855 | 2026-10-26 |
| `carryPurr` | `sfx/CatCafe_Sfx_CarryPurr.ogg` | synthesized by `synth/synth.py` | original (Purr Pot) | sound-designer | this repo | 73628889177188 | 2026-10-26 |
