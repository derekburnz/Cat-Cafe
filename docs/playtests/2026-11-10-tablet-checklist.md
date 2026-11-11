# Tablet quality check (#3024, 2026-11-10)

QA-Planner. Derek2: "do a tablet quality check because lots of tablets leave faster then phone".

## Why

Research-Agent's read (onboarding_v6 and first_hour_v2, Nov 8 and 9, tablet n=20 against phone n=47, so direction
only): tablets start as well as phones (first catch 60% against 57%, still playing at 5 minutes 47% against 29%), then
fall away between 5 and 10 minutes. 9 tablet players at 5 minutes become 2 at 10. The steps there are the bait (bait
resolved 15% against 25%; 3 of 8 who put bait down) and the rescues, then five cats and Tier 2 (both 10% against
17 to 21%).

So the check looks hardest at the bait bowl, the bait wait and cutscene, the rescue minigame and the HUD around them.

## Sizes

The place keeps Roblox's default landscape orientation, so every size is held sideways. In points (what Roblox lays out
in):

| Name | Device | Size | Aspect |
|---|---|---|---|
| ipadmini | iPad mini 6 | 1133 x 744 | 3:2 |
| ipad43 | older 9.7 and 10.2 inch iPads | 1024 x 768 | 4:3 |
| tablet | iPad 10th gen, iPad Air | 1180 x 820 | 3:2 (CI devices run) |
| ipadpro | iPad Pro 12.9 | 1366 x 1024 | 4:3 |
| tab1610 | Galaxy Tab A and most Android tablets | 1280 x 800 | 16:10 |
| fire7 | Amazon Fire 7 | 1024 x 600 | 16:9.4 |

Two tablet facts to keep in mind:
- `Scale.compute` uses the smaller of width/1280 and height/720, so a 4:3 iPad (1024 x 768) draws at 0.8 with a design
  height of 960. The HUD has a lot more height than on a PC, and anything placed from the middle or the top can sit far
  from the thumbs.
- Roblox's thumbstick and jump button are 120 px on any screen whose short side is over 500 px. The jump button sits at
  (W-170, H-210) and the thumbstick reaches up to about H-220, so the bottom corners hold more than on a phone.

## Cloud (QA-Planner)

- [ ] `node uigate.mjs --tablets`: every scene at the five sizes above has no tap target under 44 px, no text under 9 px,
      nothing off screen or under the top bar, and no script error. The run is too long for one sitting on 4 cores,
      so run it per size with `--profile`.
- [ ] The thumbstick and jump-button warnings ("thumbs") on tablet sizes: list every pressable under them.
- [ ] Specs that place touch buttons from the screen size (`NetButtonPlace`, Drop and the carry banner, #3010) pass
      at 1024 x 768 and 1024 x 600.

## Studio, device emulator (Laptop-Tester or Desktop-Tester)

Use a dev copy on current main, a fresh save, and Studio's Device emulator: iPad mini, iPad (4:3), iPad Pro 12.9 and
a 16:10 Android tablet, landscape. Take one screenshot per row on the iPad (4:3) and on the Android tablet.

1. **First 2 minutes.** Intro, first move, cannon, first catch. Every button can be reached and nothing overlaps.
   *Pass:* no blocker, matching what a phone gets.
2. **Bait bowl (the biggest tablet loss).** Buy the bowl, put bait down, wait, watch the bait cutscene (#2957), and
   catch the cat it brings. Use Refill (#3014) on an empty bowl and on a full one.
   *Pass:* every prompt shows, Refill and the bowl card fit with no part under the jump button or thumbstick, the
   cutscene ends with control back, and the cat can be caught.
3. **Rescue minigame.** Start and finish each rescue type in the Park and the Alleyway.
   *Pass:* the rescue bar and its button are 44 px or more and clear of the jump button, the camera keeps the cat in
   view, and the time is enough with a thumb (try it twice).
4. **HUD at 4:3 and 16:10.** The goal card, top bar, coins, the Cats, Index and Store tiles, the bag and Drop buttons
   (#3010), and the Cafe and Cannon buttons.
   *Pass:* nothing overlaps, nothing under Roblox's top bar or the safe area, and the goal card reads on one or two
   lines.
5. **Windows.** Shop, Cats, Index, Quests, Settings and Trade.
   *Pass:* opens and closes with a tap, lists scroll, and the close button is reachable.
6. **Catch circle and Net/Tackle.** Five catches.
   *Pass:* the circle is fully on screen and Net and Tackle sit by the jump button, not on it.
7. **10 minutes.** Play from a fresh save to five cats.
   *Pass:* no new console errors (the #2635 touch HUD crash must not come back), and no step that only works with a
   keyboard.
8. **Frame rate.** Stand in the Park and in the Desert with the Studio emulator's frame rate shown.
   *Pass:* 30 fps or more in the emulator. A real mid-range tablet, if one is around, is worth more than the emulator
   here.

## Done when

Every blocker found is filed (Gameplay or UI) or fixed, and Research-Agent's Nov 11+ read shows tablets at or above
phones for bait resolved and played 10 minutes.

## Cloud results (2026-11-10)

All 313 UI gate scenes ran at ipad43, ipadmini and fire7. They took about an hour each on 4 cores. The others are left
for CI or a later run.
- **Cats search box is 35 to 39 px tall** on all three. A tablet gets the PC layout at the touch floor scale, so parts
  without `Scale.tapHeight` fall under 44. Filed as #3056.
- The Index Gold and Rainbow pages clip 1.6 to 1.8 px of the Rewards badge's outline. This is cosmetic and is in #3056.
- The IntroNext scene failed only on ipad43, because it checked the read bar against the hidden lower bar. That was a
  false alarm, and the gate now checks it only where the bar shows. On touch the read bar and caption stay clear of Skip
  and Next at 4:3.
- Nothing is under the thumbstick or the jump button in the HUD, carry, Bait, Rescue, Net, Tackle, goal card or Drop
  scenes, checked with the tablet's bigger thumbstick zone. The tutorial Hide x (33.6 px) was already accepted on phones.

Nothing found in the cloud explains the 5 to 10 minute drop on its own. The Studio rows 2, 3 and 7 (bait, rescue,
10 minutes) are where to look next.
