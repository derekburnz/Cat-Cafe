# Tier 6 and Tier 7: the Desert and the Ruins (draft)

Status: draft by the game-designer thread, 2026-11-09. Epic #2580: cats #2581 and #2582, layouts #2583, model check #2584, QA review #2585, stations #2586. Nothing is built until the drafts pass Model-Agent's model check and QA-Planner's review, and Derek2 OKs them.

Derek2, 2026-11-09: "Start drafting 20 new cats for Tier 6 and Tier 7 10 cats each check the models make one area a desert (can add cats like a sphinx etc...) and for ruins can make like golem/hyroglyph cat/gargoyle and draft the areas for them also get QA planner to check models for issues and map etc... make sure cannon properly points at the new locations and no flat overflowing grass lands for the areas. After drafted think of BIG stations that could help late game like current yard sale/ fish pond etc..."

## 1. The two new tiers (draft numbers; Pace sets the final ones)

| | Tier 6 | Tier 7 |
|---|---|---|
| Cafe name | Royal Cafe | Wonder Cafe |
| Area | Desert | Ruins |
| Cost | ~70B (draft) | ~1.8T (draft) |
| Different cats | 42 | 52 |
| Rarity need | 2 Mythical or better | 3 Mythical or better |
| Slots | 12 | 14 |
| Tier multiplier | 2.25 | 2.5 |
| Area income (`AREA_INCOME`) | 243 (x3, like every area before it) | 729 |

- The cat counts follow the ladder. Each new area adds 10 cats, so Tier 6 asks for about 70% of the cats a Tier 6 player can reach, as Tier 5 does now.
- **Pace bands** to be set from the first run, with targets:
  - Tier 6 about 5 to 7 h after Tier 5 in one sitting.
  - Tier 7 about 8 to 11 h after Tier 6.
  - The Tier 1 to 5 times stay exactly as they are, because nothing here changes them.
- Caps, the upgrade ladder and the bowl levels for Tiers 6 and 7 follow the same steps as Tiers 4 and 5. Gameplay drafts those with the Pace run.

## 2. Where they go and the cannon

The five areas today sit about 2000 studs from the Town Square: the Park to the south, the Neighbourhood north, the Woods west, the Sewer east and the Alleyway south-west (Config.World). The two free diagonals near the town side are south-east and north-east.

| Area | Centre (x, z) | Direction from town | Barrel aim (at the camp pad) |
|---|---|---|---|
| Desert | (1400, -1400) | south-east | about 129° |
| Ruins | (1400, 1400) | north-east | about 51.5° |

**Aim at the pad, for every area** (answers QA #2585, point 1). Each camp sits at the town end of its area, off the centre line, so a barrel aimed at the area's middle points 6 to 7° away from where the flight lands. `Layout.cannonAim` changes to aim at the destination's landing-pad centre, `atan2(pad.x, pad.z)`, for every area, so the barrel always points where you land. The Park, Neighbourhood, Woods and Sewer pads sit on their axes, so they don't move. The Alleyway moves by about 2.4°, and `Intro.cannonAim` follows it, since the cutscene uses the same aim.

For comparison, the existing aims are Park 180°, Neighbourhood 0°, Woods -90°, Sewer 90° and Alleyway about -135°. Every area's direction is still at least 38° from its neighbours, so the barrel visibly turns to each one.

**Cannon checks** (QA-Planner, on the map draft):
1. The town cannon's turret turns to about 129° for the Desert and about 51.5° for the Ruins, and the flight arc leaves the barrel that way. For every area, the gap between the barrel and the line to the pad is under 1°.
2. The flight lands on the new camp's pad. Town to the new pads is about 1790 to 1800 studs (the 1980 in the first draft was the distance to the area's middle). The Alleyway's pad is about 1900 studs, so the new flights are a little shorter, and their flight time should be within 10% of the Alleyway's.
3. The camp cannons list both new areas, the Desert and Ruins camp cannons list Town Square first, and the Cannon button jumps to the right cannon.
4. Each picker shows "(opens at Tier 6)" or "(opens at Tier 7)" before the area opens.
5. From either new area, the flight never crosses another area's set in view.

## 3. No flat grassland, anywhere

Derek2: "no flat overflowing grass lands for the areas". For both areas:
- **No grass at all.** The floor and everything out to the backdrop is the area's own ground: sand and sandstone for the Desert, cut stone, packed earth and rubble for the Ruins. No default Baseplate or green terrain shows anywhere: not under the set, not past its walls, not on the way in during the cannon flight.
- **The edges are walls and backdrops, not open plain.** In the Desert these are dunes, mesas and canyon walls. In the Ruins they are cliff edges falling away into mist, with broken walls. The backdrop ring rises to hide the horizon, as `CatCafe_Town_Backdrop` does.
- **Not flat.** Each area has height changes along its paths: dune ridges, steps, ramps, a sunken courtyard. They stay walkable, and every jump and step follows the tall-blocker rule in hometown-cannon §6b, so blockers are about 9 studs and can't be jumped.
- **Long, rectangular paths** with side paths, as in hometown-cannon's v4 notes, so carriers running back can be seen and tackled.
- QA-Planner flies in from the cannon and walks the full edge of each area, looking for gaps, grass, and floating or flat-plain spots.

## 4. The Desert (Tier 6)

**Size and orientation.** 150 wide by 560 deep, with the long axis along world Z. The camp is on the north end, the town side. Spawn points are drafted at about 66 (26 near the camp, 40 deep). The wave follows the current per-area wave (#2557), with 5 rescue spots. The odds are the same as every area: 54 / 29 / 11 / 4.8 / 1.2.

**Zones, camp first:**
1. **Oasis Camp** (the camp, 30 deep). A palm-ringed pool with a stone well, striped canopies, the landing pad, the Index Board, the camp cannon and the camp extra's spot (section 8). It is the only green in the area: three palms and reeds at the water, not grass.
2. **Dune Sea.** Rolling dune ridges, 9 to 12 studs high (a jump clears about 7.2, so no path or area edge is under 9), form the walls of two winding paths that cross twice. There are sand ripples underfoot and half-buried pots and old crates to hide behind.
3. **Red Canyon.** A narrow slot canyon, 14 to 18 wide, with tall red rock walls and two side alcoves. It is the main route deep, and it's easy to be cornered there, which is good for tackles.
4. **Mirage Flats.** A wide sunken pan of cracked clay with heat shimmer. The shimmer is a soft distortion that Reduce Motion turns off. It has the only open sightlines.
5. **Sunken Pyramid.** At the far end, a small stepped pyramid half sunk in sand, with a courtyard of broken obelisks. This is the deep zone where Mythicals stay (town-layout-v3 §8d).

**Rescue spots (5):**
- Two sand dunes a cat is stuck in up to its chest.
- Two clay urns.
- A collapsed canopy.

Nothing sharp or painful is used: no cactus traps (young audience).

**Night.** The desert night is deep blue with many stars and a big moon. The areas close at night as usual.

**Palette:** sand (232, 205, 150), sandstone (204, 150, 96), canyon red (176, 88, 60), oasis teal (64, 168, 160), canopy stripes in the rarity colours.

## 5. The Ruins (Tier 7)

**Size and orientation.** 140 wide by 600 deep, with the long axis along world Z. The camp is on the south end, the town side. Spawn points are drafted at about 70 (28 near, 42 deep). The wave follows the current per-area wave, with 5 rescue spots and the same odds.

**Zones, camp first:**
1. **Broken Gate Camp.** A camp inside a fallen temple gate, with two lit braziers (soft fire, no smoke spam), the landing pad, the Index Board, the camp cannon and the camp extra's spot.
2. **Statue Avenue.** A long paved road lined with gargoyle statues on plinths on both sides. The Gargoyle Cat hides among them, sitting still like a statue. Low walls split the avenue into three lanes.
3. **Fallen Colonnade.** Rows of toppled and standing pillars to weave between, with arches overhead, at two heights joined by ramps.
4. **Glyph Halls.** Narrow corridors of carved walls (the Hieroglyph Cat's home), lit by glowing glyph strips. The halls are a small maze with three ways through, and it's the best place to lose someone chasing you.
5. **Golem Courtyard.** At the far end, a sunken round courtyard with a great stone throne and a dry fountain. This is the deep zone where Mythicals stay.

**Edges.** On the long sides, the plateau ends in cliffs that drop into soft mist, behind broken walls about 9 studs tall so nobody walks off. At the far end there's a tall ruined wall with a giant cat-head carving.

**Falling into the mist** (answers QA #2585, point 4). The 9-stud walls mean nobody should get there, but there is a catch for anything that does:
- A catch zone sits 30 studs below the plateau, hidden in the mist. There's no floor to stand on.
- A **player** who reaches it fades out and back in on the Broken Gate Camp's landing pad, as a cannon landing does. There's no damage, no death screen and no loss.
- A **carried cat** (net or backpack) drops the moment its carrier falls, as a tackle does. That cat, and any **dropped cat or stray** that reaches the zone, goes straight back to its home spot, as if it had walked home. It is never lost.
- The server does the catch. A client can't send itself or a cat there for a free teleport, since it only moves to the camp pad you would fly to anyway.

**Rescue spots (5):**
- Two rubble piles.
- Two stone urns.
- A broken bridge ledge. The cat sits on the far stub of the bridge, about 5 studs across the gap. The rescue is done on foot from the near side, and the prompt reaches across, inside the rescue's reach (7 studs). The near edge has a low broken parapet with an invisible wall over it, 9 studs in all, so nobody can step into the gap. Nobody needs to cross the gap, and no jump is needed.

**Night.** A violet sky, with the glyph strips glowing brighter.

**Palette:** old stone (150, 145, 135), sandstone (196, 170, 128), jade (80, 160, 120), glyph gold (232, 190, 80), vine green kept to small trims (no grass).

## 6. The 20 cats

The same shape as every area: 4 Common (one for each role), 2 Rare, 2 Epic, 1 Legendary and 1 Mythical. The colours are fur, second and third, following `cats.ROSTER`. Each cat has the usual models: walking, `_Sit`, `_Work`, and the gold and rainbow coats.

### 6a. Desert cats

| id | Name | Rarity | Role | Pattern | Coat (fur / second / third) | Blurb | Model notes |
|---|---|---|---|---|---|---|---|
| `sandy` | Sandy | Common | barista | solid | (226, 196, 140) / (246, 230, 200) / (120, 90, 60) | "Shakes a little sand out of every cup." | base body |
| `dune` | Dune | Common | waiter | stripes | (214, 168, 110) / (170, 120, 70) / (250, 235, 210) | "Stripes like wind on a dune." | base body, wavy stripes taken dark (`fur_toffee`) so it doesn't read as Biscuit or Sandy |
| `dusty` | Dusty | Common | greeter | patches | (190, 160, 130) / (240, 225, 205) / (110, 85, 65) | "Waves hello in a little puff of dust." | base body, grey-brown `fur_bramble` patches on a `floor_tile` base so it doesn't read as Cream |
| `sunny` | Sunny | Common | entertainer | points | (250, 230, 180) / (210, 140, 70) / (90, 60, 40) | "Always finds the warmest spot." | base body, points in deep `fur_ginger` for contrast |
| `fennec` | Fennec Cat | Rare | greeter | solid | (232, 196, 150) / (255, 240, 220) / (80, 60, 50) | "Those ears hear a tip from across town." | large ears (1.4x, so the greeter's Boater still fits), slim body |
| `camel` | Camel Cat | Rare | waiter | patches | (196, 150, 100) / (240, 220, 190) / (160, 40, 50) | "Carries three trays at once on its saddle." | woven saddle blanket with a little hump cushion, kept low on the rump behind the waiter Vest's cinch strap |
| `scarab` | Scarab Cat | Epic | barista | gradient | (40, 120, 110) / (90, 200, 160) / (230, 190, 80) | "Shiny as a beetle, twice as busy." | matte teal-green shell cape on the back (`PropSlot = "Back"`; no gloss in the pipeline) |
| `mirage` | Mirage Cat | Epic | entertainer | gradient | (240, 200, 160) / (160, 200, 240) / (255, 255, 255) | "Now you see it, now it's serving you." | slightly see-through shimmer coat (Transparency 0.15 on the body Part, set in Roblox, never the eyes; the gold and rainbow Mirage are fully opaque) |
| `pharaoh` | Pharaoh Cat | Legendary | waiter | solid | (40, 40, 50) / (232, 190, 80) / (40, 90, 170) | "Rules the cafe from a cushion." | striped gold-and-blue headdress, gold collar in the bow tie's slot (the waiter's BowTie stays off) |
| `sphinx` | Sphinx | Mythical | barista | solid | (210, 170, 110) / (232, 190, 80) / (60, 110, 180) | "Asks a riddle before every order." | lion-like body at 1.3x at most, headdress in the Head slot (the BaristaCap stays off), a plain stone coat (`fur_dune`) with faint carved lines and gold only on the headdress, so the Gold Sphinx reads differently, glowing blue eyes |

`sphinx` is a new id. The DJ Cat's id is `sphynx` (the breed), and the two must not be confused: the model name is `CatCafe_Cat_Sphinx` and the DJ Cat stays `CatCafe_Cat_Sphynx`. Model-Agent checks the two can't clash.

### 6b. Ruins cats

| id | Name | Rarity | Role | Pattern | Coat (fur / second / third) | Blurb | Model notes |
|---|---|---|---|---|---|---|---|
| `pebble` | Pebble | Common | barista | solid | (140, 140, 135) / (200, 198, 190) / (70, 70, 70) | "Small, grey and very hard to move off the counter." | base body |
| `rubble` | Rubble | Common | waiter | patches | (160, 150, 135) / (110, 100, 90) / (220, 210, 195) | "A little bit of everything, held together by naps." | base body, uneven patches |
| `clay` | Clay | Common | greeter | solid | (190, 110, 70) / (230, 170, 130) / (90, 50, 30) | "Warm as a fresh pot." | base body |
| `ivy` | Ivy | Common | entertainer | stripes | (120, 130, 110) / (80, 140, 90) / (210, 210, 190) | "Climbs everything, falls off nothing." | base body, leafy green stripes |
| `glyph` | Hieroglyph Cat | Rare | barista | patches | (222, 196, 150) / (60, 50, 40) / (232, 190, 80) | "Its coat tells the whole cafe's story." | glyph markings as geometry (small inset blocks in `patches`, no decal), so they hold up in gold and rainbow |
| `torch` | Torch Cat | Rare | greeter | solid | (120, 80, 60) / (240, 170, 60) / (255, 230, 150) | "Lights the way to your table." | a small held torch with a soft flame (no particles under Reduce Motion) |
| `gargoyle` | Gargoyle Cat | Epic | waiter | solid | (110, 115, 120) / (80, 85, 90) / (200, 70, 60) | "Sits so still you'll think it's a statue." | stone coat, small folded wings, a little horn nub |
| `mosaic` | Mosaic Cat | Epic | entertainer | patches | (60, 120, 170) / (232, 190, 80) / (200, 90, 70) | "Made of a thousand tiny tiles." | tile patches built as geometry, about 30 tiles at most |
| `golem` | Golem Cat | Legendary | barista | solid | (130, 125, 115) / (90, 200, 170) / (60, 55, 50) | "Big, gentle and very good at carrying trays." | chunky stone body (about 1.2x), glowing rune lines |
| `jade_guardian` | Jade Guardian | Mythical | greeter | gradient | (70, 160, 120) / (232, 190, 80) / (20, 60, 50) | "The temple's oldest guard, awake at last." | a jade statue with gold trim, glowing eyes and floating rune rings (still under Reduce Motion) |

Golem, Hieroglyph and Gargoyle are Derek2's. The Golem is the Legendary because it's the cat most players will chase. The Jade Guardian is the Mythical so the top cat feels rarer than all three. If Derek2 would rather the Golem be the Mythical, they swap with no other change.

**Model check result** (Model-Agent, #2584): 10 pass, 9 fixed above, and Mirage confirmed. Three rules for the whole set:
- The palette is full (128 of 128), and there's no second palette texture. Every colour uses the nearest existing swatch. The colours more than ΔE 10 off get these hand-picked swatches, and Gameplay's colour tables use the same names:
  - Camel saddle: `bowl_red`.
  - Jade Guardian dark trim: `leaf_dark`.
  - Sphinx and Pharaoh blue: `galaxy_blue`.
  - Scarab: `dumpster_green` with `sign_teal`.
  - Golem runes: `sign_teal`.
  - Ivy fur: `fur_moss`.
  - Mosaic: `paw_sewer`, `fur_golden` and `terracotta`.

  The RGB values in the tables are the design intent. The model uses the swatch. Model-Agent logs this in decisions.md with the first cat PR.
- The Desert beige cats each get a clear second colour (Dune, Dusty and Sunny above). Sandy stays plain as the base sand cat.
- Markings are geometry, never decals. Everything is matte, except the golds.

### 6c. Model check (Model-Agent, sub-issue)
For every cat, Model-Agent checks:
- The silhouette reads from 30 studs.
- The coat works in gold and rainbow.
- The extras (ears, wings, headdress, torch, shell) keep to the outfit slots, so role outfits still fit on body B.
- `Outfit_<piece>` attachments are in place.
- The size fits the carry pose and `Catching.CARRIED_POSE`. This matters most for the Sphinx at 1.2x and above, and the Golem.
- Polycounts stay inside the style guide.
- The names follow asset-pipeline.

Anything that fails comes back to Design with a fix.

## 7. Everything else a new area touches (checklist for Gameplay)

The build lists each of these with its new rows:
- `Catalog.areas`, `Catalog.tiers` and `AREA_INCOME`.
- Config.World centres and sizes.
- `Layout` sets, camps, cannons and landing pads.
- `WorldBuilder`.
- `Theme`, `Format`, `Demo`, `DecorPictures` and `Effects/Presets`, which each name the areas today.
- The Index tracks and milestones for two more areas.
- Each zone's crate (a Desert Crate and a Ruins Crate).
- `PityAreaWeights` (Desert 35, Ruins 40, keeping the lean toward the high areas).
- The Live Events shower weights (live-events.md §2c), which stay equal.
- The Rescue Rally steps.
- Quests that name areas.
- The tier's caps and upgrades.
- `GrandOpening` (it has a check for Tier 5).
- The rank-up screen.
- Leaderboards that show a top tier.
- A stress re-run with 112 live strays across seven areas (QA #2585).
- The mist catch zone in the Ruins (section 5).

**Smaller QA points (#2585):**
- **Mirage Cat:** the 0.15 transparency is on the bare body only. Outfits stay opaque. A gold or rainbow coat replaces the shimmer, so the cat draws at full opacity. A carried Mirage Cat looks the same as one on the ground.
- **Heat shimmer:** it turns off under Reduce Motion and under Low performance. It uses one screen-space effect per client, never one per part.
- **Cannon picker:** seven rows scroll on a phone, as #2339 lays out. The picker lists the areas in tier order.

## 8. Big late-game stations (first draft, Derek2 picks)

These are stations in the vein of the Yard Sale, the Fish Pond and the Lost and Found. Each is free, with no Robux and nothing sold, and gives late-game players a new use for things they already have lots of: duplicate cats, idle working cats and spare coins.

| Station | Where | What it does | Why late game |
|---|---|---|---|
| **Oasis Spa** | Desert camp (its camp extra) | Leave a working cat for 1 game hour and it comes back +1 level, up to `CatMaxLevel` 50. One slot, with 2 more for golden fish (100 and 250) | Levelling slows at high levels, and this is a free steady push |
| **Relic Museum** | Ruins camp (its camp extra) | Give duplicate cats to fill exhibits, one per cat type. Each finished room (an area's 10 cats) gives a permanent +2% tips | Late-game duplicates sell for very little next to income, and this gives them a lasting use |
| **Caravan Post** | Town Square, by the cannon | Send 3 working cats on a 2 to 6 hour trip. They leave the cafe while away and bring back coins, food and a few golden fish, with more for higher rarities. One caravan at a time | An idle loop for long breaks, and it makes a deep roster matter |
| **Dig Site** | Desert, Mirage Flats | Once a game day, dig a sand patch for a set prize: coins (minutes of income), a food, sometimes a golden fish | A daily reason to fly to the Desert |
| **Statue Workshop** | Ruins, Statue Avenue | Turn a duplicate Legendary or Mythical into a stone statue of that cat for your cafe: a Rare decoration with the Rare bonus (+4%) | Shows off rare catches, and cuts duplicates |
| **Star Observatory** | Town, on a rooftop deck | Shows the next 3 days' Lucky, Golden and Rainbow Days, and the next pity cat's area 10 minutes early | Pure information, for players who plan their time |

My picks for the first two to build are the **Oasis Spa** and the **Relic Museum**, one camp extra each, because they match the existing camp-extra slots (`Layout.campExtras`). Each station gets its own spec and a Pace check before it's built.

## 9. Open questions for Derek2
1. The cafe names (Royal Cafe, Wonder Cafe) and the draft costs: OK, or other ideas? QA notes that "Royal Cafe" sits next to the Royal Bowl and the Royal Velvet Booth. If that's too close, I'd suggest "Sunstone Cafe" instead. "Grand Cafe" is already the Tier 5 name, and "Golden" would sit next to golden fish.
2. Should the Golem be the Legendary (as drafted) or the Mythical?
3. Which two big stations come first? I'd pick the Oasis Spa and the Relic Museum.
