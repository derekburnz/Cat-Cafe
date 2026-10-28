# Area sets: how the world places them

Built by `assets/cat-cafe/blender/{areakit,neighbourhood,woods,sewer,parkset,woodsset}.py` from the approved drafts
in `/mnt/project-files/Model-Agent/area-drafts/`. The Park and `CatCafe_Woods_SetV32` are sized for town layout v3.2
(town-layout-v3.md section 8, F81); the Neighbourhood, the Sewer and the v3.1 `CatCafe_Woods_Set` are still sized
for v3.1 (section 7) until they are rebuilt.

| Set | Footprint (studs) | Tris | Parts | Area in v3.1 |
|---|---|---|---|---|
| `CatCafe_Neighbourhood_Set` | 139 x 139.5 | 43,892 | 2,182 | 140 x 140, centre (0, 196), gate z 125 |
| `CatCafe_Woods_Set` | 119 x 119 | 20,126 | 880 | 120 x 120, centre (-155, 0), gate x -94 |
| `CatCafe_Sewer_Set` | 93.2 x 93.3 | 36,400 | 1,249 | 90 x 90 walkable, centre (140, 0), gate x 94 |
| `CatCafe_Park_Set` | 159.5 x 119.75 | 54,766 | 2,807 | v3.2: 160 x 120, centre (0, -186), gate z -125 |
| `CatCafe_Woods_SetV32` | 240 x 240 | 106,248 | 4,582 | v3.2: 240 x 240, centre (-215, 0), gate x -94 |

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
- The Sewer's own brick walls are 16 high and wrap WorldBuilder's 1 stud walls at 44.5 to 45.5; its tiled floor
  slab is 0.4 thick, so its spots sit at y 0.4.
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

Blockers: the tree line (thicket 9 to 9.3 high with pines in it) and the rock ridge (boulders 6 to 8 high) each carry a
30 high `_Barrier` on their footprint, and the outer wall band has one all round but the gate.

## Spots for cats

`manifest.json` lists each set's spots under `points_roblox` as `{label: [[x, y, z], ...]}` relative to the pivot,
in the set's own (unturned) space. Turn them with the set (the same CFrame as `PivotTo`). Each spot is a clear
floor or seat for one cat: none is inside a colliding part.

- Neighbourhood: porch 9, flowerbed 9, hub 3 (tyre, under the slide, sandpit), garden 2, shed 1, driveway 4,
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
- Sewer: catwalk 1, throne 1, toy_pile 1, valve 1, cart 1, pipe_end 1, stall 3, house 4, sofa 1, deck 2, boat 1,
  raft 1, trolley 1, hammock 1.
- Park (v3.2, 40 spots, each `[x, y, z, zone]`, zone `near` for the gate half (z < 0) or `deep`): near 16 (plaza 1,
  flowerbed 3 at y 0.62, bench 1, picnic 2, blanket 1, oak 2, blossom 1, jetty 1 at y 1.2, bank 1, willow 1,
  kiosk 1, lawn 1), deep 24 (bank 1, oak 1, lawn 3, hedge 1, bandstand 3 at y 1.15, loop 2, slide 1, swings 1,
  sandbox 1 at y 0.55, seesaw 1, roundabout 1 at y 0.72, playground 1, fountain 1, roses 2, topiary 1, garden 1,
  far 2).

Labels starting with `trap_` are rescue trap spots, where a stuck cat sits inside its prop. Woods v3.2 builds its
traps into the set as v3.1 did, and each trap spot adds a fifth number, the piece's turn in set space (a hollow
log's open end faces the piece's local +X; a bramble is round): `trap_hollow_log` (78, 0, -40, near, 20) and
(92, 0, 26, deep, -20), `trap_bramble_bush` (-84, 0, -50, near, 0) and (-86, 0, 30, deep, 0), and
`trap_treehouse_branch` (-88.85, 15.45, 68.06, deep). The v3.1 sets:
Woods `trap_hollow_log` (-14, 0, 22), `trap_bramble_bush` (14, 0, 22) and `trap_treehouse_branch`
(-36.44, 15.45, 17.36: up the tree house's trunk); Sewer `trap_grate` (-31, 0.4, 2) and
`trap_drain_pipe` (-40, 0.4, -35). The Neighbourhood's shed (59.2, 0, 40) has a jammed door for the shed rescue.

The Park's trap props are placed by the world, not built into the set: each trap spot is `[x, y, z, zone, turn]`
and the prop stands there turned `turn` degrees (CFrame.Angles(0, math.rad(turn), 0) in set space; a rescue
tree's branch points along its -X, a bin's open lid is at its back). `trap_tree` (-28, 0, -16, near, 180),
(-18, 0, 27, deep, 180), (20, 0, 53, deep, -90); `trap_trashcan` (10, 0, -38.5, near, 0), (-14, 0, 23.5, deep, 90).
Each has a 3.4 x 3.4 footprint clear of the set's solid parts.

## Checks

All four pass the build gate (budget 80,000, transforms, one material, swatch UVs, naming), the toolkit QA with 0
visible overlaps (`toolkit_qa.md`; the floating parts listed there stand on the world floor), and a part-overlap
check between pieces (0 pairs sinking more than 0.15 studs into each other) plus a spot check (0 spots inside a
colliding part).
