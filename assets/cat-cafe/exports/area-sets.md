# Area sets: how the world places them

Built by `assets/cat-cafe/blender/{areakit,neighbourhood,woods,sewer,parkset,woodsset,sewerset}.py` from the
approved drafts in `/mnt/project-files/Model-Agent/area-drafts/`. The Park, `CatCafe_Woods_SetV32`,
`CatCafe_Sewer_SetV32` and `CatCafe_Neighbourhood_SetV32` (neighbourhoodset.py) are sized for town layout v3.2
(town-layout-v3.md section 8, F81); the v3.1 `CatCafe_Neighbourhood_Set`, `CatCafe_Woods_Set` and
`CatCafe_Sewer_Set` are still sized for v3.1 (section 7).

| Set | Footprint (studs) | Tris | Parts | Area in v3.1 |
|---|---|---|---|---|
| `CatCafe_Neighbourhood_Set` | 139 x 139.5 | 43,892 | 2,182 | 140 x 140, centre (0, 196), gate z 125 |
| `CatCafe_Woods_Set` | 119 x 119 | 20,126 | 880 | 120 x 120, centre (-155, 0), gate x -94 |
| `CatCafe_Sewer_Set` | 93.2 x 93.3 | 36,400 | 1,249 | 90 x 90 walkable, centre (140, 0), gate x 94 |
| `CatCafe_Park_Set` | 159.5 x 119.75 | 54,766 | 2,807 | v3.2: 160 x 120, centre (0, -186), gate z -125 |
| `CatCafe_Woods_SetV32` | 240 x 240 | 105,040 | 4,510 | v3.2: 240 x 240, centre (-215, 0), gate x -94 |
| `CatCafe_Sewer_SetV32` | 179.2 x 179.15 | 89,112 | 4,471 | v3.2: 180 x 180, centre (185, 0), gate x 94 |
| `CatCafe_Neighbourhood_SetV32` | 279.5 x 279.8 | 112,292 | 5,321 | v3.2: 280 x 280, centre (0, 266), gate z 125 |

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
- Park (v3.2, 40 spots, each `[x, y, z, zone]`, zone `near` for the gate half (z < 0) or `deep`): near 16 (plaza 1,
  flowerbed 3 at y 0.62, bench 1, picnic 2, blanket 1, oak 2, blossom 1, jetty 1 at y 1.2, bank 1, willow 1,
  kiosk 1, lawn 1), deep 24 (bank 1, oak 1, lawn 3, hedge 1, bandstand 3 at y 1.15, loop 2, slide 1, swings 1,
  sandbox 1 at y 0.55, seesaw 1, roundabout 1 at y 0.72, playground 1, fountain 1, roses 2, topiary 1, garden 1,
  far 2).
- Neighbourhood v3.2 (`CatCafe_Neighbourhood_SetV32`, 72 spots, each `[x, y, z, zone]`, zone `near` for the gate half
  (z < 0) or `deep`): near 28 (porch 12 at y 1.0, flowerbed 8 at y 0.7, garden 1, car 2 at y 0.29 and 0.34,
  bus_stop 1 at y 1.65, post_box 1, verge_bench 2, bins 1), deep 44 (porch 6 at y 1.0, flowerbed 2 at y 0.62 and
  0.7, garden 1, shop_bench 1, shop_step 1 and fruit_stall 1 at y 0.3, tyre 1, slide 1 at y 4.0 on the deck,
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
the bungalow's front gutter, 7.05 up, by the downpipe at the house's corner).

The Park's trap props are placed by the world, not built into the set: each trap spot is `[x, y, z, zone, turn]`
and the prop stands there turned `turn` degrees (CFrame.Angles(0, math.rad(turn), 0) in set space; a rescue
tree's branch points along its -X, a bin's open lid is at its back). `trap_tree` (-28, 0, -16, near, 180),
(-18, 0, 27, deep, 180), (20, 0, 53, deep, -90); `trap_trashcan` (10, 0, -38.5, near, 0), (-14, 0, 23.5, deep, 90).
Each has a 3.4 x 3.4 footprint clear of the set's solid parts.

## Checks

All sets pass the build gate (budget 80,000, 120,000 for the v3.2 Woods, Sewer and Neighbourhood; transforms, one material, swatch
UVs, naming), the toolkit QA with 0 visible overlaps (`toolkit_qa.md`; the floating parts listed there stand on the
world floor or are meant, such as a falling drip), and a part-overlap check between pieces (0 pairs sinking more
than 0.15 studs into each other) plus a spot check (no spot inside a colliding part except trap spots, where the
cat sits inside its trap, and the Woods' seats inside the oak and the tree house).
