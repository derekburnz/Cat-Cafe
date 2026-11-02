# Area sets: how the world places them

Built by `assets/cat-cafe/blender/{areakit,neighbourhood,woods,sewer,parkset,parkf85,neighbourhoodf85,woodsset,woodsf85,sewerset,sewerf85}.py` from the
approved drafts in `/mnt/project-files/Model-Agent/area-drafts/`. The Park, `CatCafe_Woods_SetV32`,
`CatCafe_Sewer_SetV32` and `CatCafe_Neighbourhood_SetV32` (neighbourhoodset.py) are sized for town layout v3.2
(town-layout-v3.md section 8, F81); the v3.1 `CatCafe_Neighbourhood_Set`, `CatCafe_Woods_Set` and
`CatCafe_Sewer_Set` are still sized for v3.1 (section 7). `CatCafe_Park_SetF85`, `CatCafe_Neighbourhood_SetF85`,
`CatCafe_Woods_SetF85` and `CatCafe_Sewer_SetF85` are F85's long Park, Neighbourhood, Woods and Sewer
(hometown-cannon.md section 6b), each with its own camp and backdrop ring (the Park and the Neighbourhood a new gate
and night fence too).

| Set | Footprint (studs) | Tris | Parts | Area in v3.1 |
|---|---|---|---|---|
| `CatCafe_Neighbourhood_Set` | 139 x 139.5 | 43,892 | 2,182 | 140 x 140, centre (0, 196), gate z 125 |
| `CatCafe_Woods_Set` | 119 x 119 | 20,126 | 880 | 120 x 120, centre (-155, 0), gate x -94 |
| `CatCafe_Sewer_Set` | 93.2 x 93.3 | 36,400 | 1,249 | 90 x 90 walkable, centre (140, 0), gate x 94 |
| `CatCafe_Park_Set` | 159.5 x 119.75 | 54,766 | 2,807 | v3.2: 160 x 120, centre (0, -186), gate z -125 |
| `CatCafe_Woods_SetV32` | 240 x 240 | 105,040 | 4,510 | v3.2: 240 x 240, centre (-215, 0), gate x -94 |
| `CatCafe_Sewer_SetV32` | 179.2 x 179.15 | 89,112 | 4,471 | v3.2: 180 x 180, centre (185, 0), gate x 94 |
| `CatCafe_Neighbourhood_SetV32` | 279.5 x 279.8 | 115,000 | 5,478 | v3.2: 280 x 280, centre (0, 266), gate z 125 |
| `CatCafe_Park_SetF85` | 119.5 x 309.75 | 100,392 | 5,541 | F85: 120 x 310 wild part, the camp 30 more (340) |
| `CatCafe_Neighbourhood_SetF85` | 179.5 x 429.8 | 118,148 | 6,129 | F85: 180 x 430 wild part, the camp 30 more (460) |
| `CatCafe_Woods_SetF85` | 160 x 489.5 | 132,212 | 6,208 | F85: 160 x 490 wild part, the camp 30 more (520) |
| `CatCafe_Sewer_SetF85` | 119.2 x 569.15 | 134,420 | 7,362 | F85: 120 x 570 wild part, the camp 30 more (600) |

## Placing a set

- One Model per area in `ReplicatedStorage.Assets`. Its pivot is the area centre on the floor's top (Layout
  `floorY`), and its gate side is local **-Z**. Place it with
  `set:PivotTo(CFrame.new(cx, floorY, cz) * CFrame.Angles(0, turn, 0))`, where `turn` makes -Z face the Town
  Square: 0 for the Neighbourhood, a half turn for the Park, a quarter turn each way for the Woods and the Sewer.
- The set brings its own ground dressing (roads, paths, stream, canal), houses, trees and borders. Drop the
  graybox paths and stand-in props for that area once the set is in.
- WorldBuilder keeps the area floor and walls. The wall facing the town should be invisible (Transparency 1, still
  colliding): each set puts a see-through border on that side (low hedge blocks with gaps for the Neighbourhood,
  low bushes for the Woods, a low brick wall with a railing for the Sewer). The other three walls can stay; the
  sets' hedges, thicket and brick walls stand just inside them and cover them.
- The v3.1 Sewer's own brick walls are 16 high and wrap WorldBuilder's 1 stud walls at 44.5 to 45.5. Both Sewer
  sets have a tiled floor slab 0.4 thick, so their floor spots sit at y 0.4.
- Collision (PR #452): parts at least 0.35 thick collide, and so do thin ones down to 0.12 thick when at least
  0.9 long (planks, decks, rungs, rails). Round parts collide with a block 75% of their size. `_Decor`, `_Water`,
  `_Glow`, `_Bulb`, `_Tube` and `_Flowers` parts never collide. `_Bulb` and `_Pane` parts light at night through
  WorldController.
- `_Barrier` parts are invisible walls (Transparency 1) that always collide. The Park pond has a ring of them on its
  stone kerb, open only where the jetty goes out, plus walls along the jetty's sides and end (8c: water is crossed or
  entered only where the set allows). The v3.2 sets also stand a 30 high `_Barrier` on every blocker (the Park's
  hedge rows) and in the band their outer walls stand in, all round but the gate. A default jump clears 7.2, more
  from a bench or an urn, and WorldBuilder's side area walls are 6 high, so without these a player could hop a
  hedge to skip the winding walk, or hop into an area that is still locked. The barriers stop the camera nowhere
  (Popper ignores invisible parts).
- Ladders have an invisible TrussPart (`..._Climb`) behind their rungs, so players climb them: the Great Oak's
  inside ladder, the tree house, the lookout tower and the Neighbourhood slide.

## The Park (v3.2)

Place it at the v3.2 centre (0, floorY, -186) with the half turn, so its -Z gate side faces the Town Square. It needs
Config.World ParkCenterZ -186, ParkWidth 160, ParkDepth 120 (8e). It brings its own walls just inside WorldBuilder's:
runs of hedge, brick, iron railing on a hedge, and old stone with a bricked-up gate, 9.4 to 10.4 high between stone
pillars on the far and side walls, and on the town side a plinth with a railing and flower boxes, open to the town.
The gate model stands in the gap between the two lantern pillars at x +-21.5 (set space).

The way in winds: plaza, east along the flower beds to the only gap in the first hedge row (x 31 to 45, z -34.5),
back west to the pond and round it either side, out to the north-west to the only gap in the second hedge row
(x -45 to -31, z 20), then the loop round the bandstand. The hedge rows are 8 to 8.8 high with a barrier on them. The playground hangs off the loop to the west, the rose
garden to the east. About 210 studs gate to bandstand against 120 straight.

## The Park (F85)

F85 (hometown-cannon.md section 6b) makes the Park a long rectangle, 120 x 340 with its camp. Five new models, so the
live Park stays as it is until the game switches all five together:

| Model | What | Place it |
|---|---|---|
| `CatCafe_Park_SetF85` | the wild part, 120 x 310 | the area's centre on its floor, with the area's turn, as every set |
| `CatCafe_Camp_ParkF85` | the camp, 120 wide and 30 deep, across the set's -Z end | the same CFrame as the set |
| `CatCafe_Park_GateF85` | the Park gate over a 24 stud opening (CampOpeningWidth) | the gate position, z -155 in set space |
| `CatCafe_Park_NightFenceF85` | its night fence, 24 wide | the gate's pivot, no offset |
| `CatCafe_Park_BackdropF85` | the backdrop ring round 120 x 340 | the same CFrame as the set |

It needs Config.World ParkWidth 120 and ParkDepth 310 (the wild part; the camp is CampDepth in front of it) and the
Park's `openingHalfWidth` 12. The camp model's `camp` entry in the manifest gives its rect (x -59.5 to 59.5, z -186
to -156 in set space), the gate line z -156 and the opening; its `pad`, `cannon`, `basket` and `index_board` spots
are where Layout's camp spots already are (pad 0, -13; cannon 0, -26.5; basket -11, -13 in camp space).

The set's walls are the v3.2 Park's (hedge, brick, iron railing on a hedge, old stone) just inside WorldBuilder's at
x +-60 and z +155, and on the camp side a plinth with a railing and flower boxes, open to the camp, with lantern
pillars at x +-17.5 either side of the gate. Four low pieces stand across the way, none of them wall to wall (Derek 11-02, 19:30: "it should be easily navigatable just little areas to walk around to continue forward"):
short islands with open ground round them, so the way on is a few steps round an end and the far end is never in a
straight line. Each is low enough to see over and has a 30 high `_Barrier` on its own run only:

| z (set space) | Piece | The way on |
|---|---|---|
| -113 to -111 | a clipped box hedge island, 3.4 to 4 high, x -30 to 6 | round either end |
| -50 to -47.6 | two short railings on a plinth with flower boxes, x -40 to -18 and 18 to 40, lantern pillars at their ends | the middle (36 wide) or by either wall |
| 8.2 to 15.8 | the stream, 6 wide between stone kerbs with an iron rail 3 high, out of the west wall and into a drain at x 10 | round its east end, or the footbridge at x -24, deck 10 wide |
| 73 to 75 | a second box hedge island, x -14 to 24 | round either end |

The footbridge spans z 3 to 21 at x -24: a deck 10 wide at 1.6 high, a ramp of 4 at each end (22 degrees), solid
railings. The walk from the pad: the plaza and the picnic lawn, round the first hedge, round the duck pond (players
wade in it, as in v3.2), between the railings, past the glasshouse (a tall piece, 15.6 high, with a barrier on its
plinth) and the orchard, round the stream's end or over the footbridge, through the rose garden, round the second
hedge, past the playground to the bandstand loop at the far end. The shortest walk from the gate to the far corner is
about 315 (walk check on the Part model, 357 with the 24 wide gaps), and a player no longer has to jump or climb
anything to get there.

## The Neighbourhood (F85)

F85 (hometown-cannon.md section 6b) makes the Neighbourhood a long rectangle, 180 x 460 with its camp. Five new
models, so the live Neighbourhood stays as it is until the game switches all five together:

| Model | What | Place it |
|---|---|---|
| `CatCafe_Neighbourhood_SetF85` | the wild part, 180 x 430 | the area's centre on its floor, with the area's turn, as every set |
| `CatCafe_Camp_NeighbourhoodF85` | the camp, 180 wide and 30 deep, across the set's -Z end | the same CFrame as the set |
| `CatCafe_Neighbourhood_GateF85` | the Neighbourhood gate over a 24 stud opening (CampOpeningWidth) | the gate position, z -215 in set space |
| `CatCafe_Neighbourhood_NightFenceF85` | its night fence, 24 wide | the gate's pivot, no offset |
| `CatCafe_Neighbourhood_BackdropF85` | the backdrop ring round 180 x 460 | the same CFrame as the set |

It needs Config.World NeighbourhoodWidth 180 and NeighbourhoodDepth 430 (the wild part; the camp is CampDepth in
front of it) and the Neighbourhood's `openingHalfWidth` 12. The camp model's `camp` entry in the manifest gives its
rect (x -89.5 to 89.5, z -246 to -216 in set space), the gate line z -216 and the opening; its `pad`, `cannon`,
`basket` and `index_board` spots are where Layout's camp spots already are.

The set's walls are the v3.2 Neighbourhood's runs of picket fence, hedge and brick just inside WorldBuilder's at
x +-90 and z +215, with a 30 high `_Barrier` all round but the way in; on the camp side a low town hedge, open to the
camp, with a street lamp either side of the gate. Five pieces cross the way, none of them wall to wall (Derek 11-02, 19:30: "it should be easily navigatable just little areas to walk around to continue forward"):
each stops short of both walls, with a gravel side path or open ground past its ends, and the low ones are split into
short runs. The low ones are about 4 high, so a hunter sees a carrier coming but has to go round, each with a 30 high
`_Barrier` on its own runs only; the house blocks are the tall pieces, with a barrier from the house fronts back (the
front gardens stay open):

| z (set space) | Piece | The way on |
|---|---|---|
| -172 to -122 | the first house block, houses back to back, x -61.5 to 63 (the two end houses each side went) | Cat Lane, x 15 to 39, or a side path past either end |
| -57 to -54 | the village green's picket fence with a box hedge behind, 3.6 to 4 high, in two runs: x -62 to -12 and 12 to 62 | the middle, by the ALLOTMENTS post, or by either wall |
| 10.6 to 17.4 | road works dug along Paw Road, two pens of red and white barriers 3.7 high round a trench, x -62 to 18 and 42 to 64 | the steel plates at x 18 to 42, or the road past either pen |
| 22 to 72 | the second house block, back to back, with a bungalow, x -63 to 57 | Mitten Lane, x -39 to -15, or a side path past either end |
| 149 to 152 | the garden wall, brick under a hedge about 4 high, x -62 to 18 and 42 to 64 | the Paw Parade arch, x 18 to 42, or by either wall |

The walk from the pad: Whisker Lane past the bus stop to Cat Lane (or a side path), through the first block to Green
Side and Whisker Green (picnic tables, the village sign, the ice cream van), between the fence's runs into the
allotments, over the plates or round a pen at the road works, along Paw Road to Mitten Lane (or a side path), through
the second block to Mitten Row and the back gardens (trampoline, paddling pool, greenhouse), under the Paw Parade arch
or round the wall's end and over the last street to the far end: the corner shop against the far wall, the playground
beside it and two houses across. The shortest walk from the gate to the far end is about 440 to 460 (walk check on the
Part model; 465 to 540 with the 24 wide gaps).

## The Woods (F85)

F85 (hometown-cannon.md section 6b) makes the Woods a long rectangle, 160 x 520 with its camp. Three new models, so
the live Woods stays as it is until the game switches them together. The Woods gate already spans a 24 stud opening
(CampOpeningWidth), so `CatCafe_Woods_Gate` and `CatCafe_Woods_NightFence` stay as they are:

| Model | What | Place it |
|---|---|---|
| `CatCafe_Woods_SetF85` | the wild part, 160 x 490 | the area's centre on its floor, with the area's turn, as every set |
| `CatCafe_Camp_WoodsF85` | the camp, 160 wide and 30 deep, across the set's -Z end | the same CFrame as the set |
| `CatCafe_Woods_Gate` | the Woods gate over its 24 stud opening, as now | the gate position, z -245 in set space |
| `CatCafe_Woods_BackdropF85` | the forest and mountain ring round 160 x 520 | the same CFrame as the set |

It needs Config.World WoodsWidth 160 and WoodsDepth 490 (the wild part; the camp is CampDepth in front of it), with
the Woods' `openingHalfWidth` 12 as now. The camp model's `camp` entry in the manifest gives its rect (x -79.5 to
79.5, z -276 to -246 in set space), the gate line z -246 and the opening; its `pad` (0, -258), `cannon`
(0, -270.5), `basket` (-11, -258) and `index_board` (-19, -247.5) are where the v3.2 camp's are, 125 further out.
The Fish Pond (`CatCafe_Camp_Woods_FishPond`) keeps its place beside the way out: (21.5, -250) in set space.

The set's walls are the v3.2 Woods' runs of mossy cliff, thicket, dry stone under a thicket and now and then a log
palisade, between old trees, just inside WorldBuilder's at x +-80 and z +245, the stream coming out of a cliff on
each side; a 30 high `_Barrier` all round but the way in; on the camp side a split rail fence with bushes, open to the
camp, with a lantern either side of the gate. Five pieces cross the way, none of them wall to wall (Derek 11-02, 19:30: "it should be easily navigatable just little areas to walk around to continue forward"):
short islands with open ground between and round them, so the way on is a short walk round an end. The low four are
about 4 high, so a hunter sees a carrier coming but has to go round, each with a 30 high `_Barrier` on its own runs
only; the tree line is the tall one and breaks the view of the far half:

| z (set space) | Piece | The way on |
|---|---|---|
| -172 to -168 | the fallen timber in two piles, big trunks end to end, about 4 high, x -58 to -18 and 18 to 54 | the middle (the trail, between two lanterns) or by either wall |
| -98 to -82 | the stream from the waterfall at the east wall, rock edges with log rails 3 high, ending at x -26 in a rock lip with boulders and ferns | round its west end, or the log bridge at x -1, deck 10 wide |
| -14 to -6 | the tree line in two copses, a thicket 9 to 10 high with pines 18 to 24, x -56 to -22 and 12 to 50 | the middle or by either wall |
| 70 to 72 | a dry stone wall in two stretches, 3.4 high under cap stones, stone piers 5.4 high at every end, x -52 to -12 and 24 to 56 | the middle (lanterns at the stretches' ends) or by either wall |
| 147 to 153 | a mossy boulder ridge, one island about 3.6 high, x -24 to 20 | round either end; the trail goes east of it under the GREAT OAK arch at x 46 |

The walk from the pad: the dirt trail nearly straight up the middle, between the timber piles, over the log bridge,
between the copses and the wall's stretches, round the ridge's east end under the arch and west into the Great Oak's
clearing, with the tree house (50, 210) and the lookout tower (12, 230) beside it. The shortest walk from the gate to
the far end is about 480 to 500 (walk check on the Part model; 605 to 625 with the 24 wide gaps).

Stream centre line `z = -90 - 3 * (1 - cos(2 * pi * (x + 46) / 90))`, otherwise as v3.2: water 8 wide, rock edges
1.3 high with log rails, grass banks, `CatCafe_Woods_Stream_Barrier` on both rails and across the west end, open at
the bridge (deck 10 wide at 2.0 on three logs, a ramp at each end).

## The Sewer (F85)

F85 (hometown-cannon.md section 6b) makes the Sewer a long rectangle, 120 x 600 with its camp, the longest run home
of the five. Three new models, so the live Sewer stays as it is until the game switches them together. The Sewer gate
already spans a 24 stud opening (CampOpeningWidth), so `CatCafe_Sewer_Gate` and `CatCafe_Sewer_NightFence` stay as
they are:

| Model | What | Place it |
|---|---|---|
| `CatCafe_Sewer_SetF85` | the wild part, 120 x 570 | the area's centre on its floor, with the area's turn, as every set |
| `CatCafe_Camp_SewerF85` | the camp, 120 wide and 30 deep, across the set's -Z end | the same CFrame as the set |
| `CatCafe_Sewer_Gate` | the Sewer gate over its 24 stud opening, as now | the gate position, z -285 in set space |
| `CatCafe_Sewer_BackdropF85` | the town works ring round 120 x 600 | the same CFrame as the set |

It needs Config.World SewerWidth 120 and SewerDepth 570 (the wild part; the camp is CampDepth in front of it), with
the Sewer's `openingHalfWidth` 12 as now. The camp model's `camp` entry in the manifest gives its rect (x -59.5 to
59.5, z -316 to -286 in set space), the gate line z -286 and the opening; its `pad` (0, -298), `cannon`
(0, -310.5), `basket` (-11, -298) and `index_board` (-19, -287.5) are where the v3.2 camp's are, 195 further out.
The Lost and Found (`CatCafe_Camp_Sewer_LostFound`, Layout.campExtras.sewer) keeps its place 3.5 inside the gate
line: (20, -289.5) in set space.

The set's walls are the v3.2 Sewer's runs of brick, blind arcade, white tile under a teal band, pipe runs and stone
between brick piers, just inside WorldBuilder's at x +-60 and z +285: 18 high round the open yard, 24 high under the
roof from the tunnel front on, with seven finished tunnel mouths in the side walls (iron bars or an iron door), a
barred one in the far wall, the canal's water mouths and stone columns at the far corners; a 30 high `_Barrier` all
round but the way in; on the camp side the town wall either side of the gate, as v3.2. Six pieces cross the way, none of them wall to wall (Derek 11-02, 19:30: "it should be easily navigatable just little areas to walk around to continue forward"):
each is an island or stops short of one wall, and the open ends swap sides. The low four are about 4 high (the water
behind guard rails), so a hunter sees a carrier coming but has to go round, each with a 30 high `_Barrier` on its own
line only (on the guard rails' line and across the end for the water); the tunnel front and the vault wall are the
tall ones and hide the halls behind them:

| z (set space) | Piece | The way on |
|---|---|---|
| -211 to -199 | the yard's canal, sunken between kerbs with guard rails, in through a grate in the west wall, ending in a drain grate at x 8 | round its east end (47 wide), or the brick bridge at x -26, 12 wide, steps and parapets |
| -150 to -147 | the tunnel front, brick 24 high where the roof begins, "THE SEWER" over the middle arch | any of three open arches: x -49.5 to -26.5 and 26.5 to 49.5 (23 wide, a lantern either side) and x -5 to 5 |
| -78 to -72 | the rubble where the roof came down: broken slabs, brick lumps and rebar, about 4 high, an island from x -34 to 10, daylight through the hole above | round either end; timber props hold up the cracked beam at x 26 to 50 |
| -5 to 5 | the channel, sunken between railed kerbs, in through a grate in the east wall, ending in a drain grate at x -8 | round its west end (47 wide), or the steel catwalk at x 24, 9 wide |
| 90 to 96 | the vault wall, brick to the roof, "CAT TOWN" over its east arch | two deep vaulted arches, x -46 to -22 and 28 to 52 (springing at 3.5) |
| 181 to 189 | the pipe bank: three big pipes on the floor, about 4.5 high, flanged every 6, an island from x -24 to 24 with flanged ends and a valve | round either end |

The walk from the pad: across the yard (barrels, tyres, cones, suitcases) round the canal's east end, through the
tunnel front's middle arch into the junk market (three stalls, a crate deck, the hanging sign, a grate trap), round
the rubble, through the pump room (the big pipe and its valve, the beached bathtub boat and raft) round the channel's
west end, through the lost and found (the lounge, the yarn trolley, the pipe hammock, a drain pipe trap) to the vault's
west arch, past cat town (can, teapot and box houses round a square, the cart on its rails, a grate trap), round the
pipe bank and across the throne room (a drain pipe trap by the east wall) to the junk throne on its dais (34, 270.5)
in front of the pipe organ, with the culvert pouring out of the far wall into the pool at x 0. The shortest walk from
the gate is about 560 to the throne (walk check on the Part model; 685 with the 24 wide gaps), and the whole floor is
now walkable without a jump.

The roof (24, 1.2 thick) starts at the tunnel front; the yard is open to the sky. Nine grated skylights and the hole
over the rubble let the day in; brick beams cross the width on pillars at x +-28 (two pillars a beam, clear of the
way), with cage lamps (`_Bulb`) hanging from them, pipe runs along both walls under the roof, and wall lanterns on
every other pier. As in v3.2, if the halls read too dark in game, PointLights on the cage lamps would fix it.

## The Alleyway blockers (F85)

The Alleyway is laid out by Layout.luau from kit pieces, not as one set, so its F85 blockers (hometown-cannon.md
section 6b: "the F84 set, 90 x 281, with low blockers along the lanes") are six prop models (`alleyblockers.py`)
that go in `Layout.alley.props` through `laneProp`, three rows across each 30 stud lane. The way through moves about:
by the buildings, by the wall or down the middle (Derek 11-02: "the gaps also don't always have to be on the sides
can be a bit wider ... don't want it feeling too tightly cramped").

| Model | Length | What | Tris | Parts |
|---|---|---|---|---|
| `CatCafe_Alley_Blocker_Bins` | long | four wheelie bins and two bag piles on a bin-store slab, about 3.9 high, 2.5 deep | 1,176 | 77 |
| `CatCafe_Alley_Blocker_BinsShort` | short | two bins and a bag pile | 644 | 40 |
| `CatCafe_Alley_Blocker_Pallets` | long | five pallet stacks with a FISH crate, a strap, a tarp and boxes, about 4 high, 2.9 deep | 3,392 | 294 |
| `CatCafe_Alley_Blocker_PalletsShort` | short | two stacks with a tarp, a FISH crate and boxes | 1,590 | 131 |
| `CatCafe_Alley_Blocker_Skip` | long | a WHISKER SKIPS skip of rubble on scaffold boards, a bulk bag of sand and cones; 5.4 deep | 2,670 | 220 |
| `CatCafe_Alley_Blocker_Van` | long | a FRESH FISH box van, 8.4 high (the tall one, it hides the lane past it), back doors open, a crate set down behind | 2,564 | 184 |

Each pivots on the lane's middle line on the floor with its pile against the wall at local -X.
A long pile runs from local x -13.35 to 1 and the way through is local x 1 to 15 (14 studs) at +X: rotY 0 puts the
gap at world +x, rotY 180 at world -x. A short pile runs from x -13.35 to -6.5; two on one spot, one at rotY 0 and one
at rotY 180, leave a 13 stud way through down the middle of the lane (x -6.5 to 6.5). The `_Barrier` (16 x 30 x 0.5
on a long pile, 8.5 x 30 x 0.5 on a short one, along local z 0 from x -15 to the pile's end) arrives invisible,
CanCollide true, CanQuery false and anchored, so nobody jumps it and the camera passes through. A lamp post at the
pile's end leans its lamp (`_Bulb`, lit at night) over the way through. Every row stands on the line of a
`CatCafe_Alley_StringLightsLong` (alleyDressing hangs one in every gap between the buildings, poles at local x -14
and 14): each pile stops 0.15 short of the wall pole's base, so that pole stands between the pile and the wall (1.65
studs, too narrow to pass). In a side row the other pole stands in the way through and leaves 12.5 studs to walk; in
a middle row both poles stand behind the piles and the middle is clear.

| Lane (x) | z | Model | rotY | Gap |
|---|---|---|---|---|
| west (-78) | 88.025 | BinsShort | 0 | down the middle (x -84.5 to -71.5) |
| west (-78) | 88.025 | PalletsShort | 180 | (the pair with the row above) |
| west (-78) | 18.25 | Skip | 180 | by the buildings (x -93 to -79) |
| west (-78) | -53.675 | Pallets | 0 | by the block (x -77 to -63) |
| east (78) | 88.025 | Pallets | 180 | by the block (x 63 to 77) |
| east (78) | 18.25 | Van | 0 | by the buildings (x 79 to 93) |
| east (78) | -88.025 | PalletsShort | 0 | down the middle (x 71.5 to 84.5) |
| east (78) | -88.025 | BinsShort | 180 | (the pair with the row above) |

All in lane space. The east lane's third row is at -88.025 rather than -53.675 because the east Warehouse's crate
stack stands in that gap. Two lane spawn points sit near a row, (-86, -49) by the west Pallets and (86, -93) by the
east short pair; both stay clear of the piles.

## The Alleyway as one lane (11-02)

Derek 11-02: "I don't think they should be separated into two lanes just make it one big one". The block down the
middle goes and the Alleyway is one lane 90 wide: in set space the walls' inner faces stand at x +-45 and the lane
runs z -125.5 to 125.5 with the camp at +z (lane space x +-78 maps to set space x +-30). Gameplay's Layout places
the pieces; these are the art. The six piles above stay for any other use, and the one lane takes four whole rows
(`alleyblockers.py` ROWS), each one model across the full width, built from the same piles end to end from the walls
with a lamp post leaning over the way through:

| Model | z (set space) | Way through (x) | Tris |
|---|---|---|---|
| `CatCafe_Alley_Blocker_RowCamp` | 88.025 | -13 to 13, the middle (26) | 8,840 |
| `CatCafe_Alley_Blocker_RowVan` | 18.25 | -45 to -19, by the west buildings (26); the van hides the lane past it | 9,382 |
| `CatCafe_Alley_Blocker_RowSkip` | -53.675 | 20 to 45, by the east buildings (25) | 8,916 |
| `CatCafe_Alley_Blocker_RowFar` | -88.025 | -16.1 to 13, the middle (29) | 7,586 |

Place each at (0, z) with rotY 0. Every pile carries its own `_Barrier` (30 high, invisible, CanCollide true,
CanQuery false) from the wall to the way through, and RowFar adds a barrier-only span from x -45 to -40.6, where its
west pile starts clear of the west Warehouse's crate stack. The east Warehouse's crate stack stands in RowSkip's way
through, which leaves 21 to walk. Lane spawn points (+-22, z - 7) and (+-38, z + 9) and the nooks stay at least 3.4
from every pile.

`CatCafe_Alley_StringLightsWide` (poles 88 apart at the building fronts, sag 3, 48 bulbs, 1,244 tris) hangs at x 0 on
the two gaps between buildings that have no row (z -18.25 and 53.675). The south end wall takes three buildings
side by side at x -31, 0 and 31, turned 180 and 0.75 out (NarrowHouses, ClockHouse, Grocer); 31 between centres
because the side windows' sills make them 30.8 wide.

The buildings are finished all round: 12 deep (3 until Derek 11-02: "make sure the buildings with sides are fully
finished not just wall acting as a front of the house"), so each runs 10 past the outer wall with windows down both
sides on every floor above the wall, its roof and cornices the full depth and a back wall with windows. The pivot,
width and facade line do not change, so Layout's slots hold. The city backdrop's first row moved back 10
(`wildbackdrop.py`) to clear them. The camp (`CatCafe_Camp_Alleyway`) is one wide apron with walls out to the side
walls, the Index Board spot at (-27.3, -2.5) in camp space, one wide string of lights across and flower beds along
the camp line; one `CatCafe_Alley_ArchStreet` at x 0 on the camp line is the way in.

## The Woods (v3.2)

`CatCafe_Woods_SetV32` is a new model, so the live game keeps `CatCafe_Woods_Set` (v3.1) until Gameplay moves the
Woods to its v3.2 Config (WoodsCenterX -215, WoodsWidth 240, WoodsDepth 240, 8e) and switches `Layout.woods.set` to
the new name in the same change. Place it at (-215, floorY, 0) with the same quarter turn as the v3.1 set, so its -Z
gate side faces the Town Square; the gate is at set space z -120. Drop the v3.1 spots, traps and graybox trees with
it. Once it is live, the v3.1 set can be removed.

Walls (Derek 01:39: more varied and higher): just inside WorldBuilder's, the far and side walls are runs of mossy
cliff (12 to 13.5), thicket (10.4 to 11.2), log palisade (about 11) and dry stone under a thicket (11.2 to 11.8),
with old trees 15 to 18 high standing between the runs. The town side is a split rail fence with bushes, open to the
town, and a lantern either side of the gate at x +-19.6.

The way in winds (8b): the dirt trail leaves the gate past the campsite (east, x 80) and the berry meadow (west) to
the only gap in the tree line (x 36 to 52, z -66), back west past the mushroom ring to the only crossing of the
stream, the log bridge (x -38, z -6), east past the berry patch to the only gap in the rock ridge (x 28 to 44,
z 46), and west to the Great Oak's clearing (centre (-38, 88)), with the tree house (-86, 74) and the lookout tower
(2, 102) beside it. About 380 studs gate to oak against 240 straight: 19 s on foot, 24 s carrying a cat.

Water (8c): the stream runs the whole width, from a waterfall at the east wall to the west wall, centre line
`z = -6 - 4 * (1 - cos(2 * pi * (x + 38) / 100))`. Water 8 wide with a dark bed, a rock edge 1.3 high and a grass
bank either side (16.4 across in all). `CatCafe_Woods_Stream_Barrier` stands on both rock edges, open only at the
bridge, and along the bridge's sides. The bridge's deck is 6 wide at 2.0, with a plank ramp at each end
(22 degrees, 5 long) and log railings 3.4 high.

Blockers: the tree line (overlapping bush masses about 9.5 high round a solid core, with pines in it) and the rock ridge (boulders 6 to 8 high) each carry a
30 high `_Barrier` on their footprint, and the outer wall band has one all round but the gate.

## The Sewer (v3.2)

`CatCafe_Sewer_SetV32` is a new model, so the live game keeps `CatCafe_Sewer_Set` (v3.1) until Gameplay moves the
Sewer to its v3.2 Config (SewerCenterX 185, SewerWidth 180, SewerDepth 180, 8e) and switches `Layout.sewer.set` to
the new name in the same change. Place it at (185, floorY, 0) with the same quarter turn as the v3.1 set, so its -Z
gate side faces the Town Square; the gate is at set space z -90 (the town wall leaves x -16 to 16 open). Drop the
v3.1 spots, traps and graybox props with it.

The way in winds (8b): the gate opens on an open storm drain yard (walls 18 high). A canal crosses the yard's whole
width at z -61, sunken between kerbs, and its only crossing is a brick bridge at x 44 (deck at 2.4 with two steps
up at each end, brick parapets 3 high). Behind it the tunnel front (z -40 to -37, 24 high, "THE SEWER" over the
channel) has three arches: the open walk-in arch at x 44, the channel's arch and a barred arch at x -44 you see the
west hall through. From the front back the sewer is roofed at 24 (Derek 01:39), with grated skylights over the
channel, the pool and each hall. Two halls run either side of the central channel (x -4 to 4). The east hall's
cross wall (z 4 to 7, "JUNK MARKET" sign) leaves one archway at its east end (x 66 to 85): the market stalls are
before it, the cat houses after it. The channel has two steel catwalks (deck at 3.2, steps and railings): one in the
yard at z -47.4, out to the yard's west bank, and one at the far end at z 50, the only way into the west hall. The
west hall holds the junk throne (-46, 80) by the far wall, and its near end is the far chamber with the boat, the
raft and the hammock. About 280 studs gate to throne and 330 to the far chamber, against 180 straight.

Derek's asks: the culvert pours out of a brick headwall built into the far wall at x 0, into the pool (01:40); every
tunnel mouth in the walls is finished with stone jambs, a voussoir arch, depth and iron bars, an iron door or a
water grate (01:41); the bridges have steps and solid parapets or railings (01:42); the outer walls vary between
brick, blind arcade, white tile under a teal band, pipe runs and stone, between brick piers, with stone columns at
the far corners (01:39).

Water (8c): the canal, the channel, the west hall's branch (z 12, x -50 to -4) and the pool are sunken (water
`_Water` 0.04 to 0.3 on a dark bed at 0, kerbs to 1.6). `CatCafe_Sewer_SetV32_..._Canals_Barrier` stands on every
kerb and round the pool, open only at the three bridges, and along the bridges' sides; a low barrier runs from the
pool to the culvert under its pipe so nobody walks round the pool's far side. The outer wall band has a 30 high
`_Barrier` all round but the gate.

Light: the halls are lit by the skylights and the world's Ambient by day, six cage lamps and the wall lanterns
(`_Bulb`) at night. If the halls read too dark in game, PointLights on the cage lamps would fix it.

## The Neighbourhood (v3.2)

`CatCafe_Neighbourhood_SetV32` is a new model, so the live game keeps `CatCafe_Neighbourhood_Set` (v3.1) until
Gameplay moves the Neighbourhood to its v3.2 Config (NeighbourhoodCenterZ 266, NeighbourhoodWidth 280,
NeighbourhoodDepth 280, 8e) and switches the set name in the same change. Place it at (0, floorY, 266) with no turn;
the gate is at set space z -140, where the set leaves x -23 to 23 open for the gate model. Drop the v3.1 spots, traps
and graybox props with it.

The way in winds (8b): Whisker Lane runs north from the gate to the first street (z -112), which runs east along the
first block's front gardens to the block's only gap, a lane at x 41 to 51. North of it the second street (z -46)
runs back west between the blocks to the second block's gap at x -51 to -41, and the road beyond passes the village
green (oaks, picnic tables, benches, flower beds) to the playground hub at (-14, 70): tyre swing, a slide with a
ladder up to a railed deck at 4, swings, sandpit, roundabout and seesaw. Paw Crescent loops round the hub, with two
houses on its west leg, one on its east leg by a turning circle and five plots round its far side: two houses, the
corner shop at the far end (z 117 to 129), a bungalow and a house. The back gardens (washing line, trampoline,
paddling pool, playhouse, bird bath, gnomes, a greenhouse) lie behind the crescent's west side and the allotments
(veg beds, greenhouse, potting shed, scarecrow, compost bins, water butt, sunflowers) behind its east side, each
reached by a footpath between two crescent houses under a GARDENS or ALLOTMENTS fingerpost. Walked on a 0.5 stud grid
with a player 2 wide: about 340 studs from the gate to the corner shop, 300 to 380 into the back gardens and 370 to
470 through the allotments (505 to the farthest corner), against 280 straight. Every spot is reachable on foot.

Blockers: both house blocks run wall to wall with one gap each, and a 30 high `_Barrier` stands on each block from the
house fronts back, so the front gardens (porches, flower beds) stay open to cats and players. The crescent's outer
houses and the fences between them carry a barrier line too, open only at the two footpaths. Front fences are white
pickets with one picket missing, low brick walls or box hedges, each with a gate gap on the garden path. The outer
walls are runs of clipped hedge, brick with ivy and a close-board fence with a rose trellis, 9 to 11 high between
brick piers, with a 30 high `_Barrier` in their band all round but the gate; the town side is low hedge blocks on a
planter kerb, see-through as 7d asks.

## Spots for cats

`manifest.json` lists each set's spots under `points_roblox` as `{label: [[x, y, z], ...]}` relative to the pivot,
in the set's own (unturned) space. Turn them with the set (the same CFrame as `PivotTo`). Each spot is a clear
floor or seat for one cat: none is inside a colliding part.

- Neighbourhood v3.1: porch 9, flowerbed 9, hub 3 (tyre, under the slide, sandpit), garden 2, shed 1, driveway 4,
  bins 1, van 1.
- Woods v3.2 (`CatCafe_Woods_SetV32`, 64 spots, each `[x, y, z, zone]`): near 26 (bridge 1, waterfall 1, tent 2,
  log_bench 2 at y 2.06, camp 1, berry_bush 4, leaf_pile 2, stump 3 at y 1.66, rock 3 at y 2.0, fern 4, log 2,
  mushroom_ring 1 at y 0.05), deep 38 (bridge 1, log_bench 3, berry_bush 5, leaf_pile 2, stump 2, rock 4, fern 5,
  log 1, glow_mushrooms 3, log_pile 1, glade 2, oak_nook 3, treehouse 1 at y 10.3, treehouse_foot 1, tower 1,
  clearing 2, dell 1). As in v3.1, `nook_great_oak` (3, at y 18 and 18.3) is the rare-biased nook inside the oak's
  top, kept apart from the 64.
- Woods F85 (`CatCafe_Woods_SetF85`, 71 spots, each `[x, y, z, zone]`, zone `near` for the camp half (z < 0) or
  `deep`): near 28 (bridge 2, waterfall 1, berry_bush 6, leaf_pile 2, stump 4 at y 1.66, fern 4, log 1, mushroom_ring
  1 at y 0.05, glow_mushrooms 1, rock 4 at y 2.0, log_pile 1, glade 1), deep 43 (berry_bush 5, leaf_pile 3, stump 2,
  fern 5, log 1, glow_mushrooms 3, rock 4, log_pile 1, glade 2, dell 1, tent 2, log_bench 5 at y 2.06, old_camp 1,
  oak_nook 3, treehouse 1 at y 10.3, treehouse_foot 1, tower 1, clearing 2). `nook_great_oak` (3, at y 18 and 18.3)
  is kept apart from the 71, as in v3.2; Layout uses the third, on the cushion.
- Woods v3.1: oak_nook 3, nook_great_oak 3 (inside the Great Oak's top, y 18: the rare-biased nook), bridge 1, tent 2,
  mushroom_ring 1, treehouse 1 (on the cabin cushion, y 10.3), tower 1, fern 2, berry_bush 1, rock 2, stump 1,
  leaf_pile 1, log 1.
- Sewer v3.1: catwalk 1, throne 1, toy_pile 1, valve 1, cart 1, pipe_end 1, stall 3, house 4, sofa 1, deck 2, boat 1,
  raft 1, trolley 1, hammock 1.
- Sewer v3.2 (`CatCafe_Sewer_SetV32`, 52 spots, each `[x, y, z, zone]`; zone by region, not by z: `near` is the
  yard and the market, the first half of the walk, `deep` everything past the cross wall's arch): near 20 (bridge 1
  at y 2.8, puddle 1, barrel 1, tyres 1, cones 1, crates 1, suitcases 1, glow_mushrooms 2, bank 4, arch 1, stall 3,
  deck 1 at y 2.55, market 2), deep 32 (bridge 1 at y 3.6, suitcases 1, glow_mushrooms 5, deck 1 at y 2.55, house 4,
  square 2, cart 1 at y 3.65, valve 1, pipe_end 1, catwalk_foot 2, pool 1, throne 1 at y 3.3, organ 1, toy_pile 1,
  sofa 1 at y 1.88, trolley 1 at y 1.0, throne_room 2, boat 1 at y 1.82, raft 1 at y 2.2, hammock 1 at y 2.4,
  chamber 2). Floor spots are at y 0.4.
- Sewer F85 (`CatCafe_Sewer_SetF85`, 60 spots, each `[x, y, z, zone]`, zone `near` for the camp half (z < 0) or
  `deep`; floor spots at y 0.4): near 25 (bridge 1 at y 2.8, puddle 1, barrel 1, tyres 1, cones 1, crates 1,
  suitcases 1, glow_mushrooms 3, bank 2, arch 1, stall 3, deck 1 at y 2.55, market 1, pipe_end 1, valve 1, boat 1 at
  y 1.82, raft 1 at y 2.2, pump_room 2, catwalk_foot 1), deep 35 (bridge 1 at y 3.6 on the catwalk, suitcases 1,
  glow_mushrooms 6, deck 1 at y 2.55, pipe_end 1, catwalk_foot 1, sofa 1 at y 1.88, trolley 1 at y 1.0, hammock 1 at
  y 2.4, lost_found 2, house 4, square 2, cart 1 at y 3.65, town 3, throne 1 at y 4.5 on the dais, organ 1, dais 1,
  toy_pile 1, pool 2, throne_room 2, pipes 1).
- Park (v3.2, 40 spots, each `[x, y, z, zone]`, zone `near` for the gate half (z < 0) or `deep`): near 16 (plaza 1,
  flowerbed 3 at y 0.62, bench 1, picnic 2, blanket 1, oak 2, blossom 1, jetty 1 at y 1.2, bank 1, willow 1,
  kiosk 1, lawn 1), deep 24 (bank 1, oak 1, lawn 3, hedge 1, bandstand 3 at y 1.15, loop 2, slide 1, swings 1,
  sandbox 1 at y 0.55, seesaw 1, roundabout 1 at y 0.72, playground 1, fountain 1, roses 2, topiary 1, garden 1,
  far 2).
- Park F85 (`CatCafe_Park_SetF85`, 48 spots, each `[x, y, z, zone]`, zone `near` for the camp half (z < 0) or
  `deep`): near 20 (plaza 1, flowerbed 3 at y 0.62, bench 1, picnic 2, blanket 2 at y 0.06, oak 1, blossom 1, jetty 1
  at y 1.2, bank 2, willow 1, kiosk 1, lawn 1, glasshouse 2 at y 0.5 on its steps, orchard 1), deep 28 (bench 1,
  picnic 2, blanket 1 at y 0.06, lawn 3, stream 2, fountain 1, roses 2 (one at y 0.57), topiary 1, sundial 1, swings 1,
  slide 1, sandbox 1 at y 0.55, seesaw 1, roundabout 1 at y 0.72, playground 1, bandstand 3 at y 1.15, loop 2, far 3).
- Neighbourhood F85 (`CatCafe_Neighbourhood_SetF85`, 74 spots, each `[x, y, z, zone]`, zone `near` for the camp half
  (z < 0) or `deep`): near 29 (porch 4 at y 1.0, flowerbed 4 at y 0.62 and 0.7, bus_stop 1 at y 1.65, post_box 1,
  verge_bench 2, bins 1, car 1 at y 0.34, oak 1, picnic 2, green_bench 1, birdbath 1, van 1 at y 0.34, veg_bed 3 at
  y 0.6, greenhouse 1 at y 0.52, scarecrow 1, compost 1, water_butt 1, allotments 1, works_hut 1), deep 45 (porch 7 at
  y 1.0, flowerbed 7 at y 0.7, verge_bench 1, car 1 at y 0.34, birdbath 1, greenhouse 1 at y 0.52, sunflowers 1,
  allot_bench 1, works 2 at y 0.34, trampoline 1 at y 1.73, washing 1, deckchair 1, gnomes 1,
  pool 1, playhouse 1, garden_bench 1, garden 2, verge 1, shop_step 1 at y 0.4, fruit_stall 1 and shop_bench 1 at
  y 0.3, tyre 1, slide 1 at y 4.0 on the deck, swings 1, sandbox 1 at y 0.55, roundabout 1 at y 0.72, seesaw 1,
  play_bench 1, lawn 1, far 2 at y 0.05 and 0.3).
- Neighbourhood v3.2 (`CatCafe_Neighbourhood_SetV32`, 72 spots, each `[x, y, z, zone]`, zone `near` for the gate half
  (z < 0) or `deep`): near 28 (porch 12 at y 1.0, flowerbed 8 at y 0.7, garden 1, car 2 at y 0.29 and 0.34,
  bus_stop 1 at y 1.65, post_box 1, verge_bench 2, bins 1), deep 44 (porch 6 at y 1.0, flowerbed 2 at y 0.62 and
  0.7, garden 1, shop_bench 1 and fruit_stall 1 at y 0.3, shop_step 1 at y 0.4, tyre 1, slide 1 at y 4.0 on the deck,
  swings 1, sandbox 1 at y 0.55, roundabout 1 at y 0.72, seesaw 1, oak 1, picnic 1, green_bench 1, van 1 at y 0.24,
  trampoline 1 at y 1.73, washing 1, deckchair 1, gnomes 1, pool 1, playhouse 1, garden_bench 1, birdbath 1,
  greenhouse 2 at y 0.52, veg_bed 4 at y 0.6, water_butt 1, scarecrow 1, compost 1, potting_bench 1, sunflowers 1,
  allot_bench 1, allotments 2).

Labels starting with `trap_` are rescue trap spots, where a stuck cat sits inside its prop. Woods v3.2 builds its
traps into the set as v3.1 did, and each trap spot adds a fifth number, the piece's turn in set space (a hollow
log's open end faces the piece's local +X; a bramble is round): `trap_hollow_log` (78, 0, -40, near, 20) and
(92, 0, 26, deep, -20), `trap_bramble_bush` (-84, 0, -50, near, 0) and (-86, 0, 30, deep, 0), and
`trap_treehouse_branch` (-88.85, 15.45, 68.06, deep, -106.26: the tree house's turn; its branch points along the
piece's local -X, as the Park's rescue trees do). Sewer v3.2 builds its traps in too, each with the piece's turn
(a drain pipe's mouth faces the piece's -Z; a grate is square, turn 0): `trap_grate` (-38, 0.4, -78, near, 0) and
(70, 0.4, 40, deep, 0), `trap_drain_pipe` (81.7, 0.4, -77, near, 90) and (-81.7, 0.4, 22, deep, -90). The v3.1 sets:
Woods `trap_hollow_log` (-14, 0, 22), `trap_bramble_bush` (14, 0, 22) and `trap_treehouse_branch`
(-36.44, 15.45, 17.36: up the tree house's trunk); Sewer `trap_grate` (-31, 0.4, 2) and
`trap_drain_pipe` (-40, 0.4, -35). The Neighbourhood's shed (59.2, 0, 40) has a jammed door for the shed rescue.
Neighbourhood v3.2 builds its traps in, each with the piece's turn: `trap_shed` (126.4, 0, -89.3, near, 0), in the
corner garden at the first block's east end, and (85.3, 0, 83.4, deep, -90), in the allotments (a garden shed with a
jammed door on the piece's -Z; the spot is just inside the door); `trap_gutter` (-53.4, 7.05, -60.5, near, 180), on
the bungalow facing the second street, and (5.7, 7.05, 112.8, deep, 34), on the crescent's bungalow (the cat lies in
the bungalow's front gutter, 7.05 up, by the downpipe at the house's corner). Neighbourhood F85 builds its traps in
the same way, three of the four deep and none within 100 studs of the camp (6b): `trap_shed` (65.4, 0, -33.3, near, 0)
in the allotments and (76.7, 0, 108.6, deep, 90) in a back garden; `trap_gutter` (36.4, 7.05, 28.5, deep, 0) on the
second block's bungalow and (62.4, 7.05, 180.5, deep, 0) on the far row's bungalow. Woods F85 builds its five in as
v3.2 does, four deep and none within 100 studs of the camp (6b): `trap_hollow_log` (62, 0, -128, near, 20) between the
timber and the stream and (-62, 0, 122, deep, -20) past the stone wall; `trap_bramble_bush` (-62, 0, 18, deep, 0) in
the dell and (64, 0, 176, deep, 0) past the ridge; `trap_treehouse_branch` (54.16, 15.45, 215.11, deep, 87.21).
Sewer F85 builds its four in as v3.2 does, three deep and none within 100 studs of the camp (6b): `trap_grate`
(-34, 0.4, -92, near, 0) in the junk market and (-36, 0.4, 112, deep, 0) in cat town; `trap_drain_pipe`
(-51.7, 0.4, 49, deep, -90) in the lost and found and (51.7, 0.4, 256, deep, 90) in the throne room.

The Park's trap props are placed by the world, not built into the set: each trap spot is `[x, y, z, zone, turn]`
and the prop stands there turned `turn` degrees (CFrame.Angles(0, math.rad(turn), 0) in set space; a rescue
tree's branch points along its -X, a bin's open lid is at its back). `trap_tree` (-28, 0, -16, near, 180),
(-18, 0, 27, deep, 180), (20, 0, 53, deep, -90); `trap_trashcan` (10, 0, -38.5, near, 0), (-14, 0, 23.5, deep, 90).
Each has a 3.4 x 3.4 footprint clear of the set's solid parts. The F85 Park's are placed the same way, four of the
five deep and none within 100 studs of the camp (6b): `trap_tree` (46, 0, -24, near, 0), (-46, 0, 30, deep, 180),
(46, 0, 98, deep, 0); `trap_trashcan` (-8, 0, 64, deep, 0), (-46, 0, 140, deep, 90).

## Checks

All sets pass the build gate (budget 80,000, 120,000 for the v3.2 Woods, Sewer and Neighbourhood, 150,000 for the
F85 Park, Neighbourhood, Woods and Sewer; transforms, one material, swatch
UVs, naming), the toolkit QA with 0 visible overlaps (`toolkit_qa.md`; the floating parts listed there stand on the
world floor or are meant, such as a falling drip), and a part-overlap check between pieces (0 pairs sinking more
than 0.15 studs into each other) plus a spot check (no spot inside a colliding part except trap spots, where the
cat sits inside its trap, and the Woods' seats inside the oak and the tree house). The Woods' old trees stand in the wall line between
the runs and sink into them by design, and the F85 Woods' blockers meet the side walls' plants (up to 0.82); in the
F85 Sewer the pipe bank runs into the side walls (0.5), the rubble meets the wall courses (0.34) and the timber props
stand in it (1.2), and the tunnel front's end piers meet the roof's rim (0.25); no other pairs. The Sewer kit's
stall caps, bunting caps, yarn balls and teapot spout and the v3.2 tunnel front's padlock now touch what they hang on,
so the v3.1 and v3.2 Sewer sets list no floating parts either. The Alleyway blockers and rows pass the same QA (0
visible, 0 floating, z-fight 0) and, placed in the whole lane layout with its buildings, crate stacks, string lights,
laundry lines and loose props, touch none of them; in the one lane composed whole (rows, 12 deep buildings, south end,
camp, arch, backdrop) the only pairs are the ones already live, the two Warehouse crate stacks on their doorsteps
(0.45) and a loose crate on the MusicShop's step (0.33).
