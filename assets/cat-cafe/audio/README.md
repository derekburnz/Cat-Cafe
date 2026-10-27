# Cat Cafe audio files and sources log

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
| `uiClick` | `ui/CatCafe_Ui_Click.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 100998799358810 | 2026-10-26 |
| `uiError` | `ui/CatCafe_Ui_Error.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 80135751380842 | 2026-10-26 |
| `catchStart` | `sfx/CatCafe_Sfx_CatchStart.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 92586398019542 | 2026-10-26 |
| `circleAppear` | `sfx/CatCafe_Sfx_CircleAppear.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 135049952895026 | 2026-10-26 |
| `netSwing` | `sfx/CatCafe_Sfx_NetSwing.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 89396147858929 | 2026-10-26 |
| `circlePerfect` | `sfx/CatCafe_Sfx_CirclePerfect.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 80668948664944 | 2026-10-26 |
| `circleGood` | `sfx/CatCafe_Sfx_CircleGood.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 104110576862212 | 2026-10-26 |
| `circleMiss` | `sfx/CatCafe_Sfx_CircleMiss.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 82265210012821 | 2026-10-26 |
| `catchSparkle` | `sfx/CatCafe_Sfx_CatchSparkle.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 96610512551224 | 2026-10-26 |
| `catchMiss` | `sfx/CatCafe_Sfx_CatchMiss.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 72335633309097 | 2026-10-26 |
| `coinPop` | `sfx/CatCafe_Sfx_CoinPop.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 80305681313349 | 2026-10-26 |
| `purchase` | `sfx/CatCafe_Sfx_Purchase.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 135044364239461 | 2026-10-26 |
| `ambCafeDay` | `ambience/CatCafe_Amb_CafeDay.ogg` | synthesized by `synth/ambience.py` | original (Cat Cafe) | sound-designer | this repo | 136952289794282 | 2026-10-26 |
| `ambCafeNight` | `ambience/CatCafe_Amb_CafeNight.ogg` | synthesized by `synth/ambience.py`; rebuilt for design v0.5 as the closed cafe (the 2026-10-26 upload 84916609751628 had night customers and is no longer used) | original (Cat Cafe) | sound-designer | this repo | 104494733188299 | 2026-10-27 |
| `ambAlleyDay` | `ambience/CatCafe_Amb_AlleyDay.ogg` | synthesized by `synth/ambience.py` | original (Cat Cafe) | sound-designer | this repo | 83744712629616 | 2026-10-26 |
| `ambAlleyNight` | `ambience/CatCafe_Amb_AlleyNight.ogg` | synthesized by `synth/ambience.py` | original (Cat Cafe) | sound-designer | this repo | 82664754116384 | 2026-10-26 |
| `ambParkDay` | `ambience/CatCafe_Amb_ParkDay.ogg` | synthesized by `synth/ambience.py` | original (Cat Cafe) | sound-designer | this repo | 75896689856230 | 2026-10-26 |
| `ambParkNight` | `ambience/CatCafe_Amb_ParkNight.ogg` | synthesized by `synth/ambience.py` | original (Cat Cafe) | sound-designer | this repo | 120595462689856 | 2026-10-26 |
| `checkInBell` | `sfx/CatCafe_Sfx_CheckInBell.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 75991488445164 | 2026-10-26 |
| `strayFlee`, `bumpLoose` | `sfx/CatCafe_Sfx_StrayFlee.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 115429958262894 | 2026-10-26 |
| `jingleCatFound` | `music/CatCafe_Music_JingleCatFound.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 102912195564834 | 2026-10-26 |
| `jingleRankUp` | `music/CatCafe_Music_JingleRankUp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 77815750894397 | 2026-10-26 |
| `loopCafeDoor` | `ambience/CatCafe_Amb_LoopCafeDoor.ogg` | synthesized by `synth/ambience.py` | original (Cat Cafe) | sound-designer | this repo | 98253223255392 | 2026-10-26 |
| `catHiss` | `sfx/CatCafe_Sfx_CatHiss.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 133059376390215 | 2026-10-26 |
| `pawLost` | `sfx/CatCafe_Sfx_PawLost.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 120814540941175 | 2026-10-26 |
| `purrfectChime` | `sfx/CatCafe_Sfx_PurrfectChime.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 115362387345274 | 2026-10-26 |
| `gateOpen` | `sfx/CatCafe_Sfx_GateOpen.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 89970899972584 | 2026-10-26 |
| `shuttersUp` | `sfx/CatCafe_Sfx_ShuttersUp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 137368825957454 | 2026-10-26 |
| `signFlip` | `sfx/CatCafe_Sfx_SignFlip.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 108862500995197 | 2026-10-26 |
| `announce` | `sfx/CatCafe_Sfx_Announce.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 140320161816899 | 2026-10-26 |
| `purr` | `sfx/CatCafe_Sfx_Purr.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 134709393284855 | 2026-10-26 |
| `carryPurr` | `sfx/CatCafe_Sfx_CarryPurr.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 73628889177188 | 2026-10-26 |
| `uiOpen` | `ui/CatCafe_Ui_Open.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 114730761775875 | 2026-10-27 |
| `uiClose` | `ui/CatCafe_Ui_Close.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 129207225359334 | 2026-10-27 |
| `uiToast` | `ui/CatCafe_Ui_Toast.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 97064648437698 | 2026-10-27 |
| `uiTab` | `ui/CatCafe_Ui_Tab.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 122895842124214 | 2026-10-27 |
| `uiToggle` | `ui/CatCafe_Ui_Toggle.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 75685910002998 | 2026-10-27 |
| `uiHint` | `ui/CatCafe_Ui_Hint.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 110637750950745 | 2026-10-27 |
| `uiRankReady` | `ui/CatCafe_Ui_RankReady.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 98501439978038 | 2026-10-27 |
| `uiDealerOpen` | `ui/CatCafe_Ui_DealerOpen.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 109906464637138 | 2026-10-27 |
| `uiRename` | `ui/CatCafe_Ui_Rename.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 109980626119711 | 2026-10-27 |
| `straySprint` | `sfx/CatCafe_Sfx_StraySprint.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 77220581372843 | 2026-10-27 |
| `shove` | `sfx/CatCafe_Sfx_Shove.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 135377461302918 | 2026-10-27 |
| `bumpHeld` | `sfx/CatCafe_Sfx_BumpHeld.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 83302918660784 | 2026-10-27 |
| `holdFill` | `sfx/CatCafe_Sfx_HoldFill.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 126544733880801 | 2026-10-27 |
| `catDrop` | `sfx/CatCafe_Sfx_CatDrop.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 104205348504396 | 2026-10-27 |
| `zoneSafe` | `sfx/CatCafe_Sfx_ZoneSafe.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 106879168380819 | 2026-10-27 |
| `zoneArea` | `sfx/CatCafe_Sfx_ZoneArea.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 103566569518372 | 2026-10-27 |
| `travelPoof` | `sfx/CatCafe_Sfx_TravelPoof.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 99298919905979 | 2026-10-27 |
| `catPlaced` | `sfx/CatCafe_Sfx_CatPlaced.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 101433267853089 | 2026-10-27 |
| `catRest` | `sfx/CatCafe_Sfx_CatRest.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 116178484251299 | 2026-10-27 |
| `giftClaim` | `sfx/CatCafe_Sfx_GiftClaim.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 80009297129343 | 2026-10-27 |
| `indexReward` | `sfx/CatCafe_Sfx_IndexReward.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 103563370361429 | 2026-10-27 |
| `goldReveal` | `sfx/CatCafe_Sfx_GoldReveal.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 124772067869145 | 2026-10-27 |
| `shimmerRare` | `sfx/CatCafe_Sfx_ShimmerRare.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 124510027027761 | 2026-10-27 |
| `uiSpinTick` | `ui/CatCafe_Ui_SpinTick.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 109150468833128 | 2026-10-27 |
| `uiSpinWin` | `ui/CatCafe_Ui_SpinWin.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 137789027351769 | 2026-10-27 |
| `uiSlider` | `ui/CatCafe_Ui_Slider.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 110732370632116 | 2026-10-27 |
| `uiGiftReady` | `ui/CatCafe_Ui_GiftReady.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 109161742998311 | 2026-10-27 |
| `uiBadge` | `ui/CatCafe_Ui_Badge.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 132178490173046 | 2026-10-27 |
| `uiSpinStart` | `ui/CatCafe_Ui_SpinStart.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 89767919141598 | 2026-10-27 |
| `duskBell` | `sfx/CatCafe_Sfx_DuskBell.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 94140238394787 | 2026-10-27 |
| `stingDusk` | `music/CatCafe_Music_StingDusk.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 72211264391144 | 2026-10-27 |
| `stingDawn` | `music/CatCafe_Music_StingDawn.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 78519815757270 | 2026-10-27 |
| `catPickUp` | `sfx/CatCafe_Sfx_CatPickUp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 117560666331463 | 2026-10-27 |
| `getaway` | `sfx/CatCafe_Sfx_Getaway.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 128887999985652 | 2026-10-27 |
| `announceMythical` | `sfx/CatCafe_Sfx_AnnounceMythical.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 93649795285321 | 2026-10-27 |
| `tipPile` | `sfx/CatCafe_Sfx_TipPile.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 131031584416450 | 2026-10-27 |
| `richArrive` | `sfx/CatCafe_Sfx_RichArrive.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 132811455211745 | 2026-10-27 |
| `richTip` | `sfx/CatCafe_Sfx_RichTip.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 89094982389204 | 2026-10-27 |
| `uiCodeRedeem` | `ui/CatCafe_Ui_CodeRedeem.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 128875832136345 | 2026-10-27 |
| `visitorCollector` | `sfx/CatCafe_Sfx_VisitorCollector.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 89641081512860 | 2026-10-27 |
| `uiTrade` | `ui/CatCafe_Ui_Trade.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 96571316013787 | 2026-10-27 |
| `visitorMystery` | `sfx/CatCafe_Sfx_VisitorMystery.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 76865491597271 | 2026-10-27 |
| `giftOpen` | `sfx/CatCafe_Sfx_GiftOpen.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 116810371894969 | 2026-10-27 |
| `potionDrink` | `sfx/CatCafe_Sfx_PotionDrink.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 135212660589235 | 2026-10-27 |
