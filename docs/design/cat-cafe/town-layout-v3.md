# Town layout v3: a wider street and a central Town Square (2026-10-27)

Derek, 2026-10-27 22:44: "the main town should be wider so that it can have a central middle area for like code cat and spin wheel and more cleaned up".

**v3.1 (section 7, Derek 2026-10-27 23:56 and 23:57): the Alley Square is gone, the Neighbourhood takes its place at the street's north end, and the Woods and the Sewer move to the west and east so each area sits straight down one arm of the Town Square. Where section 7 differs from sections 1 to 6, section 7 wins.**

**v3.2 (section 8, Derek 2026-10-28 01:42): the four side areas are 4 times their v3.1 floor, each grows away from the town behind a gate that stays where it is, and the walk inside each area winds so it takes longer. Where section 8 differs from section 7, section 8 wins.**

**v4 (proposed 2026-10-28, waiting on Derek's OK): [hometown-cannon.md](hometown-cannon.md). The town keeps its square, cafes and Alleyway, loses its four area gates, and the wild areas move far out, reached by the Cat Cannon. Once Derek says yes, it wins over sections 7 and 8 where they differ.**

Feature F76. Owner: game-designer thread. Sketch: [town-layout-v3.svg](town-layout-v3.svg) (north is up). This replaces the street plaza in [areas-and-stations.md](areas-and-stations.md) B2, and it moves the areas around the town, so it goes in before the Neighbourhood kit placement. Studs, y 0 is the floor top, world X runs across the street (west is -X) and Z along it (south is -Z), as in layout v2.

## 1. What changes and why

As built (layout v2), Cafe Street is 24 studs wide and the Spin Wheel, the Golden Fish Market, the Codes Cat and the night dealer's cart are squeezed into its north end with the player spawn, the walk to the Alley Square arch and the Codes circle all in the same strip. v3 does three things:

- **A wider street.** StreetHalfWidth 12 becomes 16, so the road and sidewalks are 32 wide and the cafes sit 4 studs farther out on each side.
- **A Town Square in the middle.** The four rows of cafes split into two pairs of rows with a 96 x 64 square between them, at the middle of the street. Every station moves there, around a fountain, each in its own corner with room to stand.
- **A tidier street.** The street itself keeps only lamps, benches and the cafes' front gardens. The bunting, the big "Cat Cafe" sign and the stations all live in the square.

## 2. The town

| piece | v2 | v3 |
|---|---|---|
| Cafe Street | x -12 to 12, z -100 to 88 | x -16 to 16, z -124 to 124 |
| Town Square | none | x -48 to 48, z -32 to 32, in the safe zone |
| Square gardens | none | x 48 to 63 and -63 to -48, z -32 to 32: trees and flower beds, with a small arch in the middle of each side into the back alley |
| Cafe rows | 4 rows at z -66, -22, 22, 66 | inner rows at z -58 and 58, outer rows at z -102 and 102 |
| Cafe plots | centre x ±34, plot x 20 to 48 | centre x ±38, plot x 24 to 52, back wall 52 to 53, yard 53 to 63 |
| Back alleys (Alleyway) | x 59 to 89, z -101.5 to 88 | x 63 to 93, z -125.5 to 124 |
| Alley Square | x -89 to 89, z 88 to 152 | x -93 to 93, z 124 to 188 |
| Park | centre (0, -130), gate z -101 | centre (0, -154), gate z -125 |
| Woods | centre (-74, -134), gate z -101 | centre (-78, -158), gate z -125 |
| Sewer | centre (74, -134), gate z -101 | centre (78, -158), gate z -125 |
| Neighbourhood | centre (0, 222.5), gate z 151.5 | centre (0, 258.5), gate z 187.5 |
| Ground | 600 | 680 (the Neighbourhood's far wall is at z 328.5) |

The street ends meet the areas as before: the Park gate at the south end, the arch into the Alley Square at the north end, and the Woods and Sewer openings at the south ends of the back alleys. Areas keep their sizes; only their positions move.

**Plot order.** Plots 1 to 4 are the inner rows next to the square (1 and 2 south, 3 and 4 north, west then east), and 5 to 8 the outer rows. So a server with a few players has everyone by the square, and the beginner's cafe (plot 1) is a short walk from the stations.

## 3. The Town Square

The square is paved, with a wide cross of open paving through it: the street's line north to south (x -8 to 8) and a lane east to west (z -6 to 6) to the two side arches. Nothing stands on the cross, so the walk between the cafes, the arches and the gates is never blocked. The four stations stand in the four quarters, each turned to face the fountain.

| what | where (x, z) | faces | notes |
|---|---|---|---|
| Fountain with a cat statue | (0, 0) | | radius 6, the landmark; low rim players can sit on |
| Player spawn | (0, -14) | north | on the street line, looking at the fountain |
| Spin Wheel (F49) | (-28, 16) | the fountain | the spin is still a walk-up prompt within 14 studs |
| Golden Fish Market (F53) | (28, 16) | the fountain | counter toward the fountain |
| Codes Cat stand (F65) | (-28, -16) | the fountain | its CodesCircle 6 studs in front, toward the fountain, radius 4 |
| Night dealer's cart | (28, -16) | the fountain | parks here at dusk; the dealer stands at its town side |
| Side arches into the back alleys | (-63, 0) and (63, 0) | | 10 wide, red SAFE ZONE stripes on the square side as at the other edges |

Dressing for the asset thread: the fountain (`CatCafe_Square_Fountain`), eight benches in a ring 11 studs from the fountain with gaps on the cross, four lamp posts where the cross meets the ring, bunting strung lamp to lamp, a "Cat Cafe" sign arch over the street at each end of the square (z -32 and 32), the two side arches (`CatCafe_Square_ArchAlley`, or the alley kit's small arch), the garden beds and trees, and a paving pattern with a paw print in the middle. Each station keeps its own model.

The square is a safe zone like the street: no tackles, and it shows the Safe zone chip. The place marker the UI shows for the plaza ("Plaza", red dot while a free spin waits) now points at the square and reads "Town Square".

## 4. Walking times (NormalWalkSpeed 20)

| from | to | about |
|---|---|---|
| the farthest cafe door | the fountain | 110 studs, 5.5 s (v2: the plaza was 8 s from the farthest door) |
| an inner row cafe door | the fountain | 65 studs, 3.3 s |
| the spawn | the Park gate | 111 studs, 5.6 s |
| the spawn | the Alley Square arch | 138 studs, 6.9 s |
| any cafe | its own back alley | through the back door, as now |

The Alleyway is still behind every cafe, so the longer street costs nothing for catching. Fast travel lands where it did relative to each area.

## 5. Contract for the engineer

- **Config.World:** StreetHalfWidth 16, StreetSouthZ -124, StreetNorthZ 124, GroundSize 680, AlleyInnerX 63, AlleyOuterX 93, AlleySouthZ -125.5, SquareSouthZ 124, SquareNorthZ 188, ParkCenterZ -154, ParkGateZ -125, WoodsCenterX -78, WoodsCenterZ -158, WoodsGateZ -125, SewerCenterX 78, SewerCenterZ -158, SewerGateZ -125, NeighbourhoodCenterZ 258.5, NeighbourhoodGateZ 187.5. New: TownSquareHalfWidth 48, TownSquareHalfDepth 32, TownSquareLaneHalfWidth 8 (the street line) and 6 (the east to west lane), TownSquareArchWidth 10.
- **Layout.plotPlacement:** inner rows at z ±(TownSquareHalfDepth + PlotRowGap + PlotWidth / 2) = ±58 and outer rows 44 farther out, plot order as in section 2.
- **Layout stations:** `spinWheel`, `fishMarket`, `codesCat`, `dealerCart` and `playerSpawn` as in section 3, each turned to face (0, 0). The manhole stays in the middle of the Alley Square, now at z 160.
- **Alley dressing and anything else written as an absolute number** in Layout or WorldBuilder that belongs to the back alleys moves out by 4 on X; anything south of the street's end moves by -24 on Z and anything north of it by +36. Index Boards, gate fences, travel arrivals and the area gates already follow their area or gate.
- **The safe zone** covers the square and its gardens. The side arches are new edges of the Alleyway, painted like the others.
- **The F72 intro** shots 4 to 9 use absolute positions; [intro-cutscene.md](intro-cutscene.md) section 2b has the v3 numbers.
- **Saves:** nothing in a profile stores a world position, so no save change. Players on a server that updates are simply in the new town after a rejoin.

## 6. QA checks

1. From the spawn, every station is in view and none of them blocks the walk to either arch or the Park gate.
2. Each station's prompt or circle works from its own quarter, and standing in the Codes circle does not cover the Spin Wheel's prompt.
3. The farthest cafe door to the fountain takes under 6 seconds on foot.
4. Tackling is off everywhere in the square, and on in the back alley one step past a side arch.
5. Strays never walk into the square (the side arches keep them in the Alleyway as the street arch does).

## 7. v3.1: the compass (Derek, 2026-10-27 23:56 and 23:57)

Derek, 23:56: "for the town layout the top part of alleyway doesn't need to be there its a little big just make that neighborhold". And 23:57: "figure out how to make the areas feel easier to access the one you want without the map feeling too segmented".

Feature F77. Sketch: [town-layout-v3.svg](town-layout-v3.svg) now shows v3.1.

### 7a. The idea

The Town Square is the hub and the paved cross through it points at the four areas, one per direction, like a compass: the Neighbourhood north up the street, the Park south down the street, the Woods west and the Sewer east, each straight through a side arch and across a back alley. Standing at the fountain you can see every gate down its arm, a signpost names them, and a paw path in each area's colour runs from the fountain to its gate. Today three of the four gates sit together at the south end and the Alley Square sits between the town and the Neighbourhood, so the far areas feel like a maze of walls; v3.1 makes every area one straight walk from the middle.

### 7b. What changes

| piece | v3 | v3.1 |
|---|---|---|
| Alley Square | x -93 to 93, z 124 to 188 | removed |
| Alleyway | two back alleys and the Alley Square | the two back alleys only, x 63 to 93 and -93 to -63, z -125.5 to 125.5, closed at both ends; they meet through the Town Square's side arches |
| Neighbourhood | centre (0, 258.5), gate z 187.5 in the Alley Square's north wall | centre (0, 196), gate z 125 at the street's north end (the Park's mirror), its own near wall from x -70 to 70 at z 126 |
| Park | centre (0, -154), gate z -125 | unchanged |
| Woods | 66 x 64, centre (-78, -158), opening at the west back alley's south end | 120 x 120 (the kit's pine ring around the Great Oak clearing), centre (-155, 0), its gate at (-94, 0) in the west back alley's outer wall, straight across the alley from the west side arch |
| Sewer | 66 x 64, centre (78, -158), opening at the east back alley's south end | 90 x 90 (the kit brings its own 16 high brick walls), centre (140, 0), its gate at (94, 0), across from the east side arch |
| Woods and Sewer gates | 30 wide, the alley's whole width | 24 wide like the Park and Neighbourhood gates, z -12 to 12 |
| Side arches | 10 wide | 12 wide, the same as the square's east to west lane |
| Manhole into the Sewer | middle of the Alley Square | removed; the Sewer gate is 30 studs across the alley from the square |
| Ground | 680 | 600 |

The Woods and the Sewer grow to their kits' sizes, which also meets the 100 x 90 floor rule in [areas-and-stations.md](areas-and-stations.md) A1 (the Woods 120 x 120, the Sewer 90 x 90 of walkable floor inside its walls, so the Sewer's set is a little larger outside). Each area kit is one set model in its own space with its gate on the set's -Z side, and the world places it at the area's centre turned so -Z faces the Town Square: no turn for the Neighbourhood, a half turn for the Park, a quarter turn each way for the Woods and the Sewer. The Neighbourhood's plan is unchanged; it just starts 62.5 studs closer. No area has to stay small: the Park's 80 x 56 is the one left under the rule, and it can grow southward when its set arrives without moving anything else.

### 7c. Walking from the fountain (NormalWalkSpeed 20)

| to | v3 | v3.1 |
|---|---|---|
| Park gate | 125 studs, 6.3 s | 125, 6.3 s |
| Neighbourhood gate | 188 through the Alley Square, 9.4 s | 125, 6.3 s |
| Woods gate | 189 through a side arch and down the alley, 9.5 s | 94 in a straight line, 4.7 s |
| Sewer gate | 189, 9.5 s | 94, 4.7 s |

From a cafe, the nearest area is now at most about 5 seconds away: the outer rows sit by the Park and Neighbourhood gates, and every back door is on an alley whose middle opens onto the Woods or the Sewer.

### 7d. Easy to find, not segmented

- **The signpost.** A finger signpost (`CatCafe_Square_Signpost`) takes the place of the bench on the south-west of the fountain's ring, so it is the first thing a new player sees left of the fountain from the spawn. Four arms point at the four gates with each area's name and icon; an arm for an area the player's tier has not opened shows a lock and "Tier N". The arms are a SurfaceGui each client draws from its own tier.
- **Paw paths.** The arms of the cross carry a line of paw prints in each area's colour from the fountain to its gate: leaf green to the Park, warm orange to the Neighbourhood, deep green to the Woods, slate blue to the Sewer. The prints continue a few studs past each gate into the area, and across the back alley on the east to west line.
- **Looking in.** Each gate is a big themed arch seen straight down its arm. A locked gate keeps its see-through bars, so you always see what is behind it. Where an area's wall faces the town, it is see-through but not walk-through: railings, a hedge with gaps or a tree line in front of an invisible wall, not a blank brick wall. The area's look also spills out around its gate: hedges and flower beds at the street's south end for the Park, picket fences and a postbox at the north end for the Neighbourhood, trees leaning over the west alley wall for the Woods, pipes and a steam vent on the east alley wall for the Sewer.
- **The Areas button stays.** Fast travel still lands just inside each gate, and the Areas panel lists only opened areas (as built in #358).

### 7e. The Alleyway without its Square

- **Spawn points.** Still 24: two `lane` points behind every cafe (16), and the 8 points that were in the Alley Square move to the four ends of the back alleys, two at each end, now zone `nook`. Epic, Legendary and Mythical strays take only free `nook` points, as they took `square` points. Suggested points, with s = -1 for the west alley and 1 for the east: (70s, 119), (84s, 121), (82s, -119), (68s, -121); each is at least 10 studs from every lane point.
- **Rescue spots.** The trash bins stay. The garbage bags move from the Alley Square's north wall to the west back alley's outer wall at z 80, between the cafe rows, at least 9 studs from every spawn point (reviewer N77).
- **Dressing.** The Square's mural, staff door, fire escape, dumpster corner and crates move to the two north dead ends (mural and staff door on the west end wall, fire escape and crates on the east). The south dead ends get a dumpster corner each. The outer walls' building backs skip the new gate openings.
- **Arrival.** The Alley travel button lands just inside the side arch on the side of the player's own cafe (west with no cafe), at (72s, 0.1, -8) facing along the alley. If Travel only takes one arrival per area, use the west one.
- **Index Board.** One just inside each side arch on the alley side, by the convention in `Layout.indexBoards`: 8 studs in and 9 to the right of the path for a player walking out of the square, turned 20 degrees toward it, so about (-71, 0, -9) west and (71, 0, 9) east.
- **Arches.** The street arch and the two "ALLEY SQUARE" arches go. The side arches carry the "THE ALLEYWAY" label on their square side.

### 7f. Contract for the engineer

- **Config.World:** remove SquareSouthZ and SquareNorthZ; add AlleyNorthZ 125.5 (the alleys' north end walls, the mirror of AlleySouthZ). StreetNorthZ stays 124 (the street now ends at the Neighbourhood gate). NeighbourhoodCenterZ 196, NeighbourhoodGateZ 125. WoodsCenterX -155, WoodsCenterZ 0, WoodsWidth 120, WoodsDepth 120, SewerCenterX 140, SewerCenterZ 0, SewerWidth 90, SewerDepth 90, and in place of WoodsGateZ and SewerGateZ a gate on an X side: WoodsGateX -94, SewerGateX 94, both 24 wide. TownSquareArchWidth 12. GroundSize 600.
- **Gates on an X side.** The area builder places gates on a Z side today (`gateZ`, the turn from the centre). The Woods and the Sewer need a gate on their +X (Woods) and -X (Sewer) side, with the wall, the Index Board, the travel arrival, the night closing and the gate billboard all following that side. The kits come as sets with the gate on their -Z side (Model-Agent), so the builder turns each set and its spawn points and props together by the area's turn; for the graybox until then, an offset (dx, dz) from the old plan becomes (dz, -dx) for the Woods and (-dz, dx) for the Sewer, so the side that faced the town still does.
- **Layout.alley:** rects are the two back alleys only; walls add the north and south end walls and leave 24 stud openings at z -12 to 12 in the outer walls; roam keeps 5 off the outer and end walls; spawn points and zones, rescue spots, arrival and boards as in 7e. Remove `Layout.manhole`.
- **Layout.neighbourhood:** `nearWall` back on, with its gate opening, since the Square's north wall is gone.
- **The safe zone** is unchanged. The side arches stay the square's only edges onto the Alleyway; the Woods and Sewer gates are ordinary area gates.
- **The F72 intro** has new numbers for shots 5, 6, 8 and 9 in [intro-cutscene.md](intro-cutscene.md) section 2c.
- **Saves:** no change. A stray that was in the Alley Square at the update is simply gone after the restart.

### 7g. QA checks

1. From the fountain, all four gates can be seen down the arms of the cross, and the signpost's arms point at the right ones.
2. A Tier 1 player sees "Tier 2", "Tier 3", "Tier 4" and "Tier 5" locks on the signpost and can see into every locked area through its gate.
3. Each gate is under 6.5 seconds on foot from the fountain, and the Woods and Sewer gates are reached in a straight line through the side arches.
4. Epic and rarer Alleyway strays appear only at the alley ends.
5. Strays never cross between the back alleys and the Woods or Sewer, and never enter the Town Square.
6. The Alley travel button lands in the back alley on the player's side.

## 8. v3.2: bigger side areas with longer walks (Derek, 2026-10-28 01:42)

Derek, 01:42: "expand all areas on the side to at least 4x the size it feels a little cramped if a lot of players were here", then "and the walking should feel longer". In the same message: "the bridge over the water in the sewer needs some way of getting up and also shouldn't be able to juts walk through it".

Feature F81.

### 8a. Sizes

Each area doubles its width and depth, so its floor is 4 times as big. The gate, the compass and the straight arms stay as in section 7: every gate is where it is now, so the walk from the fountain to each gate does not change, and each area grows away from the town behind its gate.

| area | v3.1 floor | v3.2 floor | v3.2 centre (x, z) | gate (unchanged) | far wall |
|---|---|---|---|---|---|
| Park | 80 x 56 | 160 x 120 (4.3 times) | (0, -186) | z -125, on its north side | z -246 |
| Neighbourhood | 140 x 140 | 280 x 280 | (0, 266) | z 125, on its south side | z 406 |
| Woods | 120 x 120 | 240 x 240 | (-215, 0) | x -94, on its east side | x -335 |
| Sewer | 90 x 90 | 180 x 180 | (185, 0) | x 94, on its west side | x 275 |
| Ground | 600 | 880, centred on the fountain | | | |

The Park gets a little more than 4 times, since it was the one area left under the 100 x 90 rule in [areas-and-stations.md](areas-and-stations.md) A1. Nothing overlaps: the Woods (z -120 to 120) ends 6 studs short of the Neighbourhood's near wall (z 126), and the Park (x -80 to 80) and the Sewer (z -90 to 90) are clear of everything else. The Alleyway and the Town Square do not change.

### 8b. Longer walks: a winding way in

More open floor alone would make each area feel empty, not far. So each area gets a main path from its gate to its far wall that winds about 1.6 times the straight distance. Blockers across the area (hedges, fences, house blocks, tree clumps, rock walls, the water channel) have their gaps on alternating sides, so nobody can walk straight from the gate to the back. Short cuts through a blocker are fine where they are a small detour of their own (a stile, a hole in a fence a cat can use first). Spots worth reaching (traps, landmarks, spawn clusters) sit along the path and at the far end, not by the gate.

| area | straight, gate to far wall | path | on foot at NormalWalkSpeed 20 | carrying a cat at CarryWalkSpeed 16 |
|---|---|---|---|---|
| Park | 120 | about 190 | about 10 s | about 12 s |
| Neighbourhood | 280 | about 450 | about 23 s | about 28 s |
| Woods | 240 | about 380 | about 19 s | about 24 s |
| Sewer | 180 | about 290 | about 15 s | about 18 s |

Walking speeds do not change. Each area's way in, as a brief for its set:

- **Park.** The gravel path runs south from the gate to a duck pond in the middle, which it rounds on both sides. Two hedge rows cross the width, one between the gate and the pond and one past it, with gaps at opposite ends. The far half has the bandstand, the playground and the flower garden on a loop path. The rescue trees line the far loop.
- **Neighbourhood.** Whisker Lane runs north from the gate into a street of house blocks with fenced front gardens. The street bends around two blocks before it reaches the playground hub. A crescent cul-de-sac loops around the far third, with the back gardens, the corner shop and the allotments at the far end. The house blocks are the blockers, and the fences have gaps where a cat could squeeze through.
- **Woods.** A dirt trail leaves the gate west into the pines. Dense tree clumps and fallen logs make it zigzag, and a stream crosses it once with a log bridge. The Great Oak clearing sits at the far west end of the trail, with the treehouse and the lookout tower nearby. The tents, the mushroom ring and the berry bushes are along the way.
- **Sewer.** Brick tunnels run east from the gate around a central water channel. A walkway follows each bank, and two bridges cross the channel, one near the gate and one at the far end. Side tunnels hold the market stalls, the rat houses and the junk throne. The far chamber has the boat, the raft and the hammock.

### 8c. Bridges, decks and water (all areas, from the Sewer bridge)

- **Getting up.** Every raised walkway a player can stand on (a bridge, catwalk, deck or platform) has steps or a ramp at each end. Steps rise at most 1 stud each, and ramps are no steeper than 30 degrees, so a character walks up without jumping.
- **Solid.** A bridge's deck, posts and railings collide, so a player walks over a bridge and never through it. Railings are at least 3 studs high. A cat can hop a railing (F79 hops), but a player cannot.
- **Water.** A channel of water can only be crossed on its bridges. It is sunken, and an invisible wall runs along each bank with gaps only at the bridges. This is part of the winding way in the Sewer and at the Woods' stream.

### 8d. Spawn points, zones and traps

Each set brings its cat spots as now, more of them for the bigger floor, split into two zones: `near`, the half of the area by the gate, and `deep`, the far half. Epic, Legendary and Mythical strays take only free `deep` points, the rule the Alleyway's `nook` points already follow. As built (#467) there is no fallback to other points, so a wave never puts an Epic or rarer stray by the gate. So the rarer the cat, the longer the walk to it. Commons and Rares take any point. StraySpawnSpacingStuds 12 still applies.

| area | spawn points, v3.1 | v3.2 | of them `deep` | rescue traps, v3.2 |
|---|---|---|---|---|
| Park | 14 | 40 | 24 | tree x3, trashcan x2 |
| Neighbourhood | 26 | 72 | 44 | shed x2, gutter x2 |
| Woods | 17 | 64 | 38 | hollow_log x2, bramble_bush x2, and the tree house branch as a fifth trap of type `tree` (#475) |
| Sewer | 20 | 52 | 32 | grate x2, drain_pipe x2 |

At least one trap of each kind is in the `deep` half.

The Great Oak's top nook (Derek, 2026-10-28 01:35, a higher rare chance up there; built in #475) is one Woods spot with zone `rare`. Only a Rare or rarer stray takes it, and a Rare or rarer stray takes a free `rare` point before any other. Waves place their rarest strays first, so the oak top holds the wave's rarest cat whenever that is Rare or better, about 73% of Woods waves of four. The odds do not change, so this keeps Derek's 01:50 same-odds rule: the nook decides where the rarest cat sits, not how rare it is. Wave sizes stay as Derek set them at 01:34 (data-model section 9), so a bigger area has its strays spread farther apart.

### 8e. Contract for the engineer

- **Config.World:** ParkCenterZ -186, ParkWidth 160, ParkDepth 120; NeighbourhoodCenterZ 266, NeighbourhoodWidth 280, NeighbourhoodDepth 280; WoodsCenterX -215, WoodsWidth 240, WoodsDepth 240; SewerCenterX 185, SewerWidth 180, SewerDepth 180; GroundSize 880. The gates (ParkGateZ, NeighbourhoodGateZ, WoodsGateX, SewerGateX), SideGateHalfWidth and everything in the town stay.
- **Until a set is rebuilt** for its new size, Layout keeps that set and its cat spots and traps where they are now, at the v3.1 centre (a `setCenter` apart from the area's `center`). The gate end then looks as it does today, and the new floor, walls and night closing cover the full v3.2 rect behind it. Graybox props follow the set.
- **Zones:** each area's spawn points carry `zone` "near" or "deep", from the set's manifest, or by distance from the gate (the far half is deep) for a set without them. The Epic and rarer zone rule in the spawn pick takes the zone name per area (Alleyway `nook`, the side areas `deep`). Until a set has deep points, every point counts as both.
- **Follows the rect already:** the walls, the floor, the stray roam bounds, the night sweep, the tackle and catch checks for being inside an area, and the gate billboard. Travel arrivals, Index Boards and the gate fences follow the gates, which do not move.
- **Saves:** no change.

### 8f. For the set builder

Each set is rebuilt for its v3.2 floor with its gate still on its -Z side: the Park 160 x 120, the Neighbourhood 280 x 280, the Woods 240 x 240 and the Sewer 180 x 180 of walkable floor. Each set needs the way in from 8b, the bridge and water rules in 8c, and the spot and trap counts in 8d, with each spot tagged `near` or `deep` in the manifest. Keep each set's landmarks and spots from v3.1 and spread them along the new path. The far end gets the best-looking landmark, so the long walk has something at the end of it.

### 8g. QA checks

1. Each gate is still under 6.5 s on foot from the fountain.
2. From each gate, the far wall cannot be reached in a straight line, and the main path to it takes about the time in 8b.
3. Every raised walkway can be walked onto from both ends without jumping, and no bridge, deck or railing can be walked through.
4. The Sewer channel can only be crossed on its bridges.
5. Epic and rarer strays in the side areas appear only at `deep` points.
6. With 20 players in one area, nobody spawns or stands inside another player, and strays still spread over the whole floor.

