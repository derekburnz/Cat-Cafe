# Cat Cafe audio files and sources log

Owner: sound-designer. Rules: `.claude/skills/audio-pipeline/SKILL.md`. What each cue should sound like: `docs/audio/cat-cafe/sound-list.md`.

```
music/      CatCafe_Music_<Name>.ogg     stereo seamless loops and stingers
ambience/   CatCafe_Amb_<Name>.ogg       stereo seamless beds; CatCafe_Amb_Loop<Name>.ogg mono 3D loops (none since 2026-10-27)
sfx/        CatCafe_Sfx_<Name>.ogg       mono, 3D or 2D game sounds
ui/         CatCafe_Ui_<Name>.ogg        mono interface sounds
sheets/     CatCafe_Sheet_<Name>.ogg     sound sheets: several short sounds in one upload (sound list 5.13); World mono, Moments and Music stereo
sheet-parts/<kind>/CatCafe_*.ogg         each sheet's parts, gated one by one and never uploaded on their own
gates.md    written by audio_gate.py; never edit by hand
synth/      synth.py (effects and jingles), music.py (the music beds) and ambience.py (retired beds): our own sounds made from code; rerun to rebuild
upload.py   uploads every file here to Roblox (Open Cloud) and writes the ids into Cues.luau and this log
uploaded.json  written by upload.py: file -> Roblox asset id
```

Only upload-ready files live here. Creator Store sounds used as they are need no file, only a log row. DAW projects, raw recordings and stems stay out of Git; the row says where they are.

## Sources log

One row per file or Creator Store asset, added the moment it is picked, before upload. A row with no license is not uploaded. CC-BY rows also go in `CREDITS.md` at the repo root.

| cue | file or Creator Store id | origin | license | author | link or where kept | uploaded id | added |
|---|---|---|---|---|---|---|---|
| `uiClick` | `ui/CatCafe_Ui_Click.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 123281023369868 | 2026-10-26 |
| `uiError` | `ui/CatCafe_Ui_Error.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 100658806415053 | 2026-10-26 |
| `catchStart` | `sfx/CatCafe_Sfx_CatchStart.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 96760734642727 | 2026-10-26 |
| `circleAppear` | `sfx/CatCafe_Sfx_CircleAppear.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 103026194958680 | 2026-10-26 |
| `netSwing` | `sfx/CatCafe_Sfx_NetSwing.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 70879520668287 | 2026-10-26 |
| `circlePerfect` | `sfx/CatCafe_Sfx_CirclePerfect.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 126376086540474 | 2026-10-26 |
| `circleGood` | `sfx/CatCafe_Sfx_CircleGood.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 93601709619890 | 2026-10-26 |
| `circleMiss` | `sfx/CatCafe_Sfx_CircleMiss.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 109577366461065 | 2026-10-26 |
| `catchSparkle` | `sfx/CatCafe_Sfx_CatchSparkle.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 91641836065515 | 2026-10-26 |
| `catchMiss` | `sfx/CatCafe_Sfx_CatchMiss.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 119698339547500 | 2026-10-26 |
| `coinPop` | `sfx/CatCafe_Sfx_CoinPop.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 84089684524419 | 2026-10-26 |
| `purchase` | `sfx/CatCafe_Sfx_Purchase.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 116389589868688 | 2026-10-26 |
| `ambCafeDay` | `ambience/CatCafe_Amb_CafeDay.ogg` (removed 2026-10-27) | synthesized by `synth/ambience.py`; retired 2026-10-27, Derek replaced the ambience with quiet music (last upload 136952289794282, whose murmuring crowd sounded eerie in the cafe) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `ambCafeNight` | `ambience/CatCafe_Amb_CafeNight.ogg` (removed 2026-10-27) | synthesized by `synth/ambience.py`; retired 2026-10-27, Derek replaced the ambience with quiet music (last upload 104494733188299) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `ambAlleyDay` | `ambience/CatCafe_Amb_AlleyDay.ogg` (removed 2026-10-27) | synthesized by `synth/ambience.py`; retired 2026-10-27, Derek replaced the ambience with quiet music (last upload 83744712629616) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `ambAlleyNight` | `ambience/CatCafe_Amb_AlleyNight.ogg` (removed 2026-10-27) | synthesized by `synth/ambience.py`; retired 2026-10-27, Derek replaced the ambience with quiet music (last upload 82664754116384) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `ambParkDay` | `ambience/CatCafe_Amb_ParkDay.ogg` (removed 2026-10-27) | synthesized by `synth/ambience.py`; retired 2026-10-27, Derek replaced the ambience with quiet music (last upload 75896689856230) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `ambParkNight` | `ambience/CatCafe_Amb_ParkNight.ogg` (removed 2026-10-27) | synthesized by `synth/ambience.py`; retired 2026-10-27, Derek replaced the ambience with quiet music (last upload 120595462689856) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `checkInBell` | `sfx/CatCafe_Sfx_CheckInBell.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 124730012199621 | 2026-10-26 |
| `strayFlee`, `bumpLoose` | `sfx/CatCafe_Sfx_StrayFlee.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 114582331349747 | 2026-10-26 |
| `jingleCatFound` | `music/CatCafe_Music_JingleCatFound.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 118123593035931 | 2026-10-26 |
| `jingleRankUp` | `music/CatCafe_Music_JingleRankUp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 85819178163551 | 2026-10-26 |
| `musicDayA` | `music/CatCafe_Music_DayA.ogg` | composed and synthesized by `synth/music.py` | original (Cat Cafe) | sound-designer | this repo | 83352686708210 | 2026-10-27 |
| `musicDayB` | `music/CatCafe_Music_DayB.ogg` | composed and synthesized by `synth/music.py` | original (Cat Cafe) | sound-designer | this repo | 105502030061552 | 2026-10-27 |
| `musicNightA` | `music/CatCafe_Music_NightA.ogg` | composed and synthesized by `synth/music.py` | original (Cat Cafe) | sound-designer | this repo | 104937902594770 | 2026-10-27 |
| `loopCafeDoor` | `ambience/CatCafe_Amb_LoopCafeDoor.ogg` (removed 2026-10-27) | synthesized by `synth/ambience.py`; retired 2026-10-27, Derek replaced the ambience with quiet music (last upload 98253223255392) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `catHiss` | `sfx/CatCafe_Sfx_CatHiss.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 112692442470029 | 2026-10-26 |
| `pawLost` | `sfx/CatCafe_Sfx_PawLost.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 115646034851877 | 2026-10-26 |
| `purrfectChime` | `sfx/CatCafe_Sfx_PurrfectChime.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 101827371438540 | 2026-10-26 |
| `gateOpen` | `sfx/CatCafe_Sfx_GateOpen.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 129683906883492 | 2026-10-26 |
| `shuttersUp` | `sfx/CatCafe_Sfx_ShuttersUp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 88936101264758 | 2026-10-26 |
| `signFlip` | `sfx/CatCafe_Sfx_SignFlip.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 97178553934391 | 2026-10-26 |
| `announce` | `sfx/CatCafe_Sfx_Announce.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 132783050282387 | 2026-10-26 |
| `purr` | `sfx/CatCafe_Sfx_Purr.ogg` | synthesized by `synth/synth.py`; rebuilt 2026-10-27 as a real purr (replaces the upload 134709393284855, a low rumble) | original (Cat Cafe) | sound-designer | this repo | 98395715075799 | 2026-10-27 |
| `carryPurr` | `sfx/CatCafe_Sfx_CarryPurr.ogg` | synthesized by `synth/synth.py`; rebuilt 2026-10-27 as a real purr (replaces the upload 73628889177188, a low rumble) | original (Cat Cafe) | sound-designer | this repo | 122312250965460 | 2026-10-27 |
| `uiOpen` | `ui/CatCafe_Ui_Open.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 137136098721051 | 2026-10-27 |
| `uiClose` | `ui/CatCafe_Ui_Close.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 136390381178341 | 2026-10-27 |
| `uiToast` | `ui/CatCafe_Ui_Toast.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 101668755145423 | 2026-10-27 |
| `uiTab` | `ui/CatCafe_Ui_Tab.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 132990737294484 | 2026-10-27 |
| `uiToggle` | `ui/CatCafe_Ui_Toggle.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 87744600545017 | 2026-10-27 |
| `uiHint` | `ui/CatCafe_Ui_Hint.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 84709734267357 | 2026-10-27 |
| `uiRankReady` | `ui/CatCafe_Ui_RankReady.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 125474672370745 | 2026-10-27 |
| `uiDealerOpen` | `ui/CatCafe_Ui_DealerOpen.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 76779738636330 | 2026-10-27 |
| `uiRename` | `ui/CatCafe_Ui_Rename.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 126356996133307 | 2026-10-27 |
| `straySprint` | `sfx/CatCafe_Sfx_StraySprint.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 90925740178919 | 2026-10-27 |
| `shove` | `sfx/CatCafe_Sfx_Shove.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 108455272441129 | 2026-10-27 |
| `bumpHeld` | `sfx/CatCafe_Sfx_BumpHeld.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 74229186579543 | 2026-10-27 |
| `holdFill` | `sfx/CatCafe_Sfx_HoldFill.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 102979949179030 | 2026-10-27 |
| `catDrop` | `sfx/CatCafe_Sfx_CatDrop.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 82672663045710 | 2026-10-27 |
| `zoneSafe` | `sfx/CatCafe_Sfx_ZoneSafe.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 102307932367391 | 2026-10-27 |
| `zoneArea` | `sfx/CatCafe_Sfx_ZoneArea.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 122475758992868 | 2026-10-27 |
| `travelPoof` | `sfx/CatCafe_Sfx_TravelPoof.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 136895580073047 | 2026-10-27 |
| `catPlaced` | `sfx/CatCafe_Sfx_CatPlaced.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 112209746211990 | 2026-10-27 |
| `shiftChime` | `sfx/CatCafe_Sfx_ShiftChime.ogg` | synthesized by `synth/synth.py` (#1191: a shop-only cat starts its shift) | original (Cat Cafe) | sound-designer | this repo | 93382811999608 | 2026-11-05 |
| `stationReady` | `sfx/CatCafe_Sfx_StationReady.ogg` | synthesized by `synth/synth.py` (#1133/#1154/#1232: a camp station has something waiting) | original (Cat Cafe) | sound-designer | this repo | 122405628888661 | 2026-11-05 |
| `catRest` | `sfx/CatCafe_Sfx_CatRest.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 100485229755444 | 2026-10-27 |
| `giftClaim` | `sfx/CatCafe_Sfx_GiftClaim.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 74934447836735 | 2026-10-27 |
| `indexReward` | `sfx/CatCafe_Sfx_IndexReward.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 127241224294798 | 2026-10-27 |
| `goldReveal` | `sfx/CatCafe_Sfx_GoldReveal.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 134771896552643 | 2026-10-27 |
| `shimmerRare` | `sfx/CatCafe_Sfx_ShimmerRare.ogg` (removed 2026-10-28) | synthesized by `synth/synth.py`; retired 2026-10-28, the constant loop around rare strays was annoying, replaced by `rareNear` (last upload 124510027027761) | original (Cat Cafe) | sound-designer | this repo | - | 2026-10-27 |
| `uiSpinTick` | `ui/CatCafe_Ui_SpinTick.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 133333553770736 | 2026-10-27 |
| `uiSpinWin` | `ui/CatCafe_Ui_SpinWin.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 79008493792613 | 2026-10-27 |
| `uiSpinBusy` | `ui/CatCafe_Ui_SpinBusy.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 133956483226854 | 2026-11-01 |
| `uiSlider` | `ui/CatCafe_Ui_Slider.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 87070259611294 | 2026-10-27 |
| `uiGiftReady` | `ui/CatCafe_Ui_GiftReady.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 107614584511698 | 2026-10-27 |
| `uiBadge` | `ui/CatCafe_Ui_Badge.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 127086916799354 | 2026-10-27 |
| `uiSpinStart` | `ui/CatCafe_Ui_SpinStart.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 101675886953192 | 2026-10-27 |
| `duskBell` | `sfx/CatCafe_Sfx_DuskBell.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 72074823724688 | 2026-10-27 | retired 2026-11-05, no longer played
| `stingDusk` | `music/CatCafe_Music_StingDusk.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 110881711300369 | 2026-10-27 |
| `stingDawn` | `music/CatCafe_Music_StingDawn.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 105006150455225 | 2026-10-27 |
| `catPickUp` | `sfx/CatCafe_Sfx_CatPickUp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 109834386589176 | 2026-10-27 |
| `getaway` | `sfx/CatCafe_Sfx_Getaway.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 138475700063366 | 2026-10-27 |
| `announceMythical` | `sfx/CatCafe_Sfx_AnnounceMythical.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 95418238847080 | 2026-10-27 |
| `tipPile` | `sfx/CatCafe_Sfx_TipPile.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 131455934857825 | 2026-10-27 |
| `richArrive` | `sfx/CatCafe_Sfx_RichArrive.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 72229334389341 | 2026-10-27 |
| `richTip` | `sfx/CatCafe_Sfx_RichTip.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 134978111441854 | 2026-10-27 |
| `uiCodeRedeem` | `ui/CatCafe_Ui_CodeRedeem.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 139056960178897 | 2026-10-27 |
| `visitorCollector` | `sfx/CatCafe_Sfx_VisitorCollector.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 79131004801316 | 2026-10-27 |
| `uiTrade` | `ui/CatCafe_Ui_Trade.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 87866050266126 | 2026-10-27 |
| `visitorMystery` | `sfx/CatCafe_Sfx_VisitorMystery.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 109251583263849 | 2026-10-27 |
| `giftOpen` | `sfx/CatCafe_Sfx_GiftOpen.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 114143832834959 | 2026-10-27 |
| `potionDrink` | `sfx/CatCafe_Sfx_PotionDrink.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 89037651167310 | 2026-10-27 |
| `tackleLunge` | `sfx/CatCafe_Sfx_TackleLunge.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 131297265053036 | 2026-10-27 |
| `tackleMiss` | `sfx/CatCafe_Sfx_TackleMiss.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 90894734407033 | 2026-10-27 |
| `catLevelUp` | `sfx/CatCafe_Sfx_CatLevelUp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 75904013038713 | 2026-10-27 |
| `uiDailyStamp` | `ui/CatCafe_Ui_DailyStamp.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 123343224842944 | 2026-10-28 |
| `jingleDailyCard` | `music/CatCafe_Music_JingleDailyCard.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 138202971136133 | 2026-10-28 |
| `rareNear` | `sfx/CatCafe_Sfx_RareNear.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 134220486232962 | 2026-10-28 |
| `waterStep` | `sfx/CatCafe_Sfx_WaterStep.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 71465595506771 | 2026-10-28 |
| `cannonLaunch` | `sfx/CatCafe_Sfx_CannonLaunch.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 102075028148467 | 2026-10-28 |
| `cannonClouds` | `sfx/CatCafe_Sfx_CannonClouds.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 108064008516131 | 2026-10-28 |
| `cannonLand` | `sfx/CatCafe_Sfx_CannonLand.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 103029343434588 | 2026-10-28 |
| `cloudHop` | `sfx/CatCafe_Sfx_CloudHop.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 76704372473776 | 2026-10-28 |
| `campCheckIn` | `sfx/CatCafe_Sfx_CampCheckIn.ogg` | synthesized by `synth/synth.py` | original (Cat Cafe) | sound-designer | this repo | 79340353325458 | 2026-10-28 |
| `sheetWorld` | `sheets/CatCafe_Sheet_World.ogg` | synthesized by `synth/synth.py` (parts: `bellhopBell`, `rainbowNear`, `campSplash`, `campBasket`, `campRattle`) | original (Cat Cafe) | sound-designer | this repo | 73129093144324 | 2026-11-01 |
| `sheetMoments` | `sheets/CatCafe_Sheet_Moments.ogg` | synthesized by `synth/synth.py` (parts: `jingleEpic`, `jingleLegendary`, `jingleMythical`, `jingleRainbow`, `jingleLuckyDay`, `rallyCheer`, `uiReelTick`, `uiReelStop`, `uiTradeTick`, `uiTradeDone`) | original (Cat Cafe) | sound-designer | this repo | 79195889382293 | 2026-11-01 |
| `sheetDecor` | `sheets/CatCafe_Sheet_Decor.ogg` | synthesized by `synth/synth.py` (parts: `decorBlossomTree`, `decorBathtubSofa`, `decorHollowLog`, `decorIceCream`, `decorDuckFountain`, `decorJukebox`, `decorCatTree`) | original (Cat Cafe) | sound-designer | this repo | 108434963257406 | 2026-11-02 |
| `sheetCatch` | `sheets/CatCafe_Sheet_Catch.ogg` | synthesized by `synth/synth.py` (parts: `netSmack`, `netBounce`, `strayHop`, `wordGreat`, `wordExcellent`) | original (Cat Cafe) | sound-designer | this repo | 110336837728633 | 2026-11-02 |
| `sheetCatch3` | `sheets/CatCafe_Sheet_Catch3.ogg` | synthesized by `synth/synth.py` (parts: `pawSwat`, `netWobble`, `netPop`, `wordNice`; Catch v3, #1884) | original (Cat Cafe) | sound-designer | this repo | 119641670692404 | 2026-11-06 |
| `sheetRescue` | `sheets/CatCafe_Sheet_Rescue.ogg` | synthesized by `synth/synth.py` (parts: `rescueStart`, `rescueHitBin`, `rescueHitBag`, `rescueHitTree`, `rescueHitCan`, `rescueHitTone`, `rescueMiss`, `rescueDrop`, `rescueFail`, `rescueDone`, `teamRescue`) | original (Cat Cafe) | sound-designer | this repo | 112281216042656 | 2026-11-02 |
| `sheetCafe` | `sheets/CatCafe_Sheet_Cafe.ogg` | synthesized by `synth/synth.py` (parts: `orderPour`, `orderDing`, `trayClink`, `tipBank`) | original (Cat Cafe) | sound-designer | this repo | 94516523486015 | 2026-11-02 |
| `sheetMusic` | `sheets/CatCafe_Sheet_Music.ogg` | composed and synthesized by `synth/music.py` (parts: `musicDayC` "Paw Prints", `musicDayD` "Market Morning", `musicNightB` "Night Owls"; Derek approved by ear 2026-11-03, #980) | original (Cat Cafe) | sound-designer | this repo | 101914371530807 | 2026-11-03 |
| `musicTutorial` "Step by Step" | `music/CatCafe_Music_Tutorial.ogg` | composed and synthesized by `synth/music.py` (#1541: the tutorial's own loop, 16 bars at 96 BPM, 40 s) | original (Cat Cafe) | sound-designer | this repo | 112232482675173 | 2026-11-05 |
| `sheetMusicJukebox` | `sheets/CatCafe_Sheet_MusicJukebox.ogg` | composed and synthesized by `synth/music.py` (parts: `musicJukeboxRainyWindow` "Rainy Window", `musicJukeboxCatnapWaltz` "Catnap Waltz", `musicJukeboxBakeryBounce` "Bakery Bounce", `musicJukeboxStarlightPurr` "Starlight Purr"; #1168 row 2, the Jukebox Pass; the sheet is named Music* so the audio gate treats it as a music sheet; Derek's overnight go-ahead 2026-11-06, upload after merge) | original (Cat Cafe) | sound-designer | this repo | 119723228198008 | 2026-11-06 |
| `sheetMusicAreas` | `sheets/CatCafe_Sheet_MusicAreas.ogg` | composed and synthesized by `synth/music.py` (parts: `musicAreaDesert` "Sunstone Caravan", `musicAreaRuins` "Glyph Halls"; #2662 for #2651, Tier 6 and 7 area music) | original (Cat Cafe) | sound-designer | this repo | 133058435990072 | 2026-11-09 |
| `sheetLate` | `sheets/CatCafe_Sheet_Late.ogg` | synthesized by `synth/synth.py` (parts: `spaSplash`, `spaChime`, `museumBell`, `circleHold`; #2927, the late stations and the first catch's held ring) | original (Cat Cafe) | sound-designer | this repo | 104681497739384 | 2026-11-10 |
| `catSold` | `sfx/CatCafe_Sfx_CatSold.ogg` | synthesized by `synth/synth.py` (#2952, selling a cat; upload after merge) | original (Cat Cafe) | sound-designer | this repo | - | 2026-11-10 |
| `sheetBait` | `sheets/CatCafe_Sheet_Bait.ogg` | synthesized by `synth/synth.py` (parts: `foodKibble`, `foodTuna`, `foodSalmon`, `foodSardines`, `foodCaviar`, `foodMoonMilk`, `foodStarTreat`, `offlineClaim`; #983) | original (Cat Cafe) | sound-designer | this repo | 100201013800031 | 2026-11-03 |
| `trailerMusic` | not in the repo: `Sound-Agent/trailer/CatCafe_Trailer_Music_28s.wav` in the project library | composed and synthesized by `synth/trailer.py` (the DayA theme as a 28 s cue at 120 BPM, no lyrics), for the store page video only | original (Cat Cafe) | sound-designer | project library | not uploaded | 2026-11-03 |
| `trailerCafeBed` | not in the repo: `Sound-Agent/trailer/sfx/CatCafe_Trailer_CafeBed_8s.wav` in the project library | mixed from the game's own `purr`, `coinPop` and the Cafe sheet's parts, for the store page video only | original (Cat Cafe) | sound-designer | project library | not uploaded | 2026-11-03 |
