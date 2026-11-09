# Test plan: the Desert (Tier 6) and the Ruins (Tier 7)

QA-Planner, 2026-11-09. For #2585 (QA review), epic #2580. Spec: `docs/design/cat-cafe/tier6-7-areas.md` (PR #2587). Run it on each build PR as it lands (layouts #2583, cats #2584 and the Gameplay rows in spec section 7), in the dev copy of the place, never the live one. Steps marked **cloud** run in the test runner; the rest need Studio (Desktop-Tester or Laptop-Tester, emulator for the phone rows).

## Part A: review of the map draft (done on the doc, before anything is built)

Findings on PR #2587 as of 2026-11-09. None blocks the draft; items 1 to 4 need an answer in the spec before Gameplay builds.

1. **The barrel aims at the area's middle, the flight lands at the camp.** `Layout.cannonAim` is `atan2(center.x, center.z)`, and the camps sit at the town end. For the Desert the pad is about (1400, -1135), so the flight leaves at about 129° while the barrel points at 135°; the Ruins is 51.5° against 45°. That's a 6 to 7° gap you can see, where the Alleyway's is about 2.4°. Either aim at the camp pad for every area (one line in `cannonAim`) or say the gap is fine.
2. **Flight distance.** Town to the new pads is about 1790 to 1800 studs, not the 1980 in section 2 (that is the centre). The Alleyway's pad is about 1900. If flight time scales with distance this is fine; if it's a fixed time the arc is just a little steeper. Fix the number in the spec.
3. **Dune ridges 6 to 9 studs tall can be jumped at 6.** Section 3 says blockers are about 9 studs so they can't be jumped, but section 4 has the Dune Sea path walls at 6 to 9. A default character clears about 7.2 studs. Anything that marks the edge of a path or of the area should be 9 or more; 6-stud ridges are fine only inside a path.
4. **Ruins cliffs and the broken-bridge rescue.** The walls along the cliff edge stop players, but say what happens to things that fall: a dropped cat, a stray pushed by a tackle, a carrier NPC, a player on the cannon landing. Each needs a floor under the mist or a reset at a set height. The broken-bridge rescue ("the cat on the far side of a gap") must be reachable on foot or by the rescue prompt's reach; say which.
5. **Mirage Cat transparency 0.15.** See-through bodies on Roblox can sort wrongly with outfits, the carried pose and the gold and rainbow coats. Model-Agent should check it in all three coats with an outfit on, carried, and next to another cat.
6. **Heat shimmer.** Roblox has no cheap screen distortion; whatever stands in for it (a moving decal or particles) needs a phone cost check and must be off under Low performance as well as Reduce Motion.
7. **Seven areas in the pickers.** The cannon picker and the camp cannons go from five rows to seven. With the phone layout issue (#2339, about 1.5 rows on a short screen), check the picker fits or scrolls cleanly on a phone.
8. **Names.** "Royal Cafe" sits next to the Royal Bowl and the Royal Velvet Booth; worth a second look by Derek2. The `sphinx` / `sphynx` split is good; also check that searching "sphinx" in the Cats window doesn't confuse the two.
9. **Load.** Seven areas at `StrayLiveMax` 16 each is 112 live strays, up from 80. The stress check in the release gate (8 players, 500 cats) should be re-run with both new areas built.

## Part B: test plan once built

### B1. Cannon (spec section 2)
- [ ] Town cannon: pick the Desert, the turret turns to its aim and the flight leaves the barrel that way; same for the Ruins. Screenshot each.
- [ ] The flight lands on the new camp's pad, inside `LandingPadRadius`, facing into the area. Try with 3 players landing together.
- [ ] Desert and Ruins camp cannons list Town Square first, then the other areas; the Cannon button walks to the right cannon.
- [ ] Below Tier 6 the Desert row reads "(opens at Tier 6)" and can't be picked; below Tier 7 the same for the Ruins. Server refuses a forced fire (remote with the area id) below the tier.
- [ ] From each new area to each other area, the flight never shows another area's set below.
- [ ] Carrying a cat: the cannon refuses, as elsewhere.
- [ ] **cloud** `Cannon.spec` and `Layout.spec`: aim, pad and picker rows for 7 areas; tier locks.

### B2. Terrain and edges (section 3)
- [ ] Fly in to each area and screenshot the approach: no grass, no Baseplate, no green terrain anywhere in view.
- [ ] Walk the full edge of each area: no gap, no way out, no spot where the horizon shows flat plain. Note any spot in a screenshot with its position.
- [ ] Every path wall and edge blocker is 9 studs or more; try to jump each one.
- [ ] Each height change (dune ridge, steps, ramps, sunken courtyard, pyramid steps, colonnade ramps) is walkable up and down, and nothing traps a player, a stray or a carrier.
- [ ] Ruins: walk to each cliff wall; drop a carried cat at the wall; tackle a carrier at the wall. Nothing falls into the mist, or if it does it resets.
- [ ] Terrain decoration (grass blades) is off in both areas.

### B3. Layout and spawns (sections 4 and 5)
- [ ] Each zone exists in order from the camp, matching the spec.
- [ ] **cloud** Spawn points: about 66 (Desert) and 70 (Ruins), split near and deep as drafted; Mythicals only pick deep points (a spec guard over many rolls).
- [ ] 5 rescue spots per area, each reachable and its prompt usable on touch (#2315); the broken-bridge spot works as the spec decides.
- [ ] Strays wander and hide without getting stuck in the canyon, the Glyph Halls maze or behind pots and crates; carriers find their way back through the maze.
- [ ] Phone camera in the Red Canyon and the Glyph Halls: walls don't hide the player for long.
- [ ] Night: both areas close at night like the others.

### B4. Cats (section 6; Model-Agent's checks are #2584)
- [ ] All 20 cats appear in the Index, Cats window and Fresh Catch board with the right names, rarity colour and blurbs.
- [ ] Each cat walks, sits and works; gold and rainbow coats look right.
- [ ] Carry pose: every cat, and the Sphinx and Golem in particular, sits right in the carry pose with no clipping into the player.
- [ ] Role outfits fit on all 20; extras (ears, wings, headdress, torch, shell, rune rings) don't clash with them.
- [ ] Reduce Motion: no torch particles, rune rings still.
- [ ] `sphinx` and `sphynx` are two separate cats everywhere (save, Index, trade).

### B5. Everything else (section 7)
- [ ] **cloud** `Pace.spec` with Tiers 6 and 7: Tiers 1 to 5 times unchanged; new bands set from the first run.
- [ ] Rank up to Tier 6 and 7: the rank-up screen, area unlock hint and Grand Opening check.
- [ ] Desert and Ruins crates, pity area weights, Rescue Rally steps, quests naming areas, leaderboards' top tier.
- [ ] A Tier 5 save from before the update loads and plays with no error (ProfileSchema migration).
- [ ] Stress: 8 players, 7 areas full of strays; server heartbeat 55 or more, client memory under 1.2 GB.
- [ ] No new console errors in a 10-minute session in each new area.

## Who does what
- Part A: QA-Planner (this doc and the comment on PR #2587).
- B1 to B3 and B5: Desktop-Tester or Laptop-Tester in Studio once each PR lands; cloud steps by QA-Planner.
- B4: with Model-Agent's checks under #2584.
- Results go in a dated report in `docs/playtests/`, gaps as issues under #2580.
